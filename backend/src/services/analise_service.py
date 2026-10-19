"""
Serviço de análise: orquestra inferência, verificação SHA-256, buffer de contexto,
avaliação de risco, persistência de incidentes e notificações WebSocket.
"""

from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import logging
import time
from typing import Optional, Tuple
import uuid

from sqlalchemy.orm import Session

from src.api.v1.websocket.handler import (
    format_incident_summary_dict,
    get_guardian_ids_for_dependent,
    manager as ws_manager,
)
from src.domain.entities import (
    AcaoRequerida,
    CategoriaAmeaca,
    Incidente,
    Mensagem,
    PapelMenor,
    StatusIncidente,
    TipoEventoWS,
)
from src.domain.rules import (
    LIMIAR_CRITICO,
    avaliar_risco,
    detectar_papel_menor,
    normalizar_texto,
)
from src.infrastructure.bertimbau_engine import (
    ClassificadorStrategy,
    classify_text,
)
from src.infrastructure.in_memory_buffer import in_memory_buffer
from src.infrastructure.link_detector import DetectorDeLinks
from src.infrastructure.models import (
    DependentORM,
    IncidentORM,
    IncidentStatusHistoryORM,
)

logger = logging.getLogger(__name__)

_classificador_override: Optional[ClassificadorStrategy] = None


def set_classificador_override(strategy: Optional[ClassificadorStrategy]) -> None:
    global _classificador_override
    _classificador_override = strategy


class DependentNotFoundError(LookupError):
    """Exceção levantada quando o dependent_id não existe no banco."""


@dataclass
class ResultadoAnaliseMensagem:
    label: str
    category: str
    confidence: float
    has_link: bool
    action_required: str
    detected_role: str
    sha256_match: bool
    incident_id: Optional[str]
    inference_time_ms: float
    incident: Optional[Incidente]
    created: bool


def _to_naive_utc(dt: datetime) -> datetime:
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def _executar_pipeline_analise(
    db: Session,
    texto: str,
    message_hash: str,
    dependent_id: str,
    conversation_id: str,
    room_type: str,
    sender_id: str,
    is_from_minor: bool,
    is_direct: bool,
    timestamp: datetime,
) -> ResultadoAnaliseMensagem:
    start_perf = time.perf_counter()

    # 1. Verificação de integridade SHA-256 sobre o campo text exatamente como recebido (antes de normalizar)
    hash_calculado = hashlib.sha256(texto.encode("utf-8")).hexdigest().lower()
    integridade_valida = hash_calculado == (message_hash or "").strip().lower()

    # 2. Normalização textual (remove espaços redundantes e normaliza quebras de linha, preserva emojis/stopwords)
    texto_normalizado = normalizar_texto(texto)

    # 3. Busca o dependente
    dependent = (
        db.query(DependentORM).filter(DependentORM.id == dependent_id).first()
    )
    if not dependent:
        raise DependentNotFoundError(f"Dependente {dependent_id} não encontrado")

    timestamp_utc = _to_naive_utc(timestamp)

    # Cria objeto de mensagem de domínio
    mensagem = Mensagem(
        texto=texto_normalizado,
        remetente_id=sender_id,
        eh_do_menor=is_from_minor,
        timestamp=timestamp_utc,
        hash_sha256=(message_hash or "").strip().lower(),
        sala_tipo=room_type,
        id_conversa=conversation_id,
    )

    # 4. Ordem de processamento (regras-de-negocio.md seção 7):
    # Passo 7.1: Anexar a mensagem como posterior aos incidentes abertos da conversa
    incidentes_atualizados = in_memory_buffer.anexar_mensagem_posterior(
        conversation_id=conversation_id,
        msg=mensagem,
        now=timestamp_utc,
    )
    for inc_buf in incidentes_atualizados:
        inc_orm = (
            db.query(IncidentORM)
            .filter(IncidentORM.id == inc_buf.incident_id)
            .first()
        )
        if inc_orm:
            inc_orm.context_after = json.dumps(inc_buf.posterior_messages)
            inc_orm.updated_at = datetime.utcnow()
            db.add(inc_orm)

    # Passo 7.2: Classificar a mensagem (DetectorDeLinks + BERTimbau + AvaliadorDecisaoRisco)
    tem_link = DetectorDeLinks.detectar_link(texto_normalizado)
    if _classificador_override is not None:
        probabilidade_nocivo = _classificador_override.predict_probability(texto_normalizado)
        label = "nocivo" if probabilidade_nocivo >= 0.50 else "normal"
    else:
        label, probabilidade_nocivo = classify_text(texto_normalizado)

    limiar_comum = dependent.common_threshold
    categoria, acao_requerida = avaliar_risco(
        probabilidade_nocivo=probabilidade_nocivo,
        limiar_comum=limiar_comum,
        sala_tipo=room_type,
        tem_link=tem_link,
    )
    papel_detectado = detectar_papel_menor(
        eh_do_menor=is_from_minor,
        eh_direto=is_direct,
    )
    severidade = (
        "CRITICO" if probabilidade_nocivo >= LIMIAR_CRITICO else "COMUM"
    )

    # Passo 7.3: Se for incidente, criar com o contexto anterior e abrir para posteriores
    incidente_criado: Optional[Incidente] = None
    foi_criado = False
    incidente_orm: Optional[IncidentORM] = None

    if acao_requerida != AcaoRequerida.NONE:
        contexto_antes_dicts = in_memory_buffer.obter_contexto_anterior_dicts(
            conversation_id
        )
        contexto_antes_msgs = [
            Mensagem(
                texto=m["text"],
                remetente_id=m["sender_id"],
                eh_do_menor=m["is_from_minor"],
                timestamp=timestamp_utc,
                hash_sha256="",
                sala_tipo=room_type,
                id_conversa=conversation_id,
            )
            for m in contexto_antes_dicts
        ]

        incidente_id = f"inc-{uuid.uuid4().hex[:8]}"
        incidente_criado = Incidente(
            id=incidente_id,
            dependente_id=dependent_id,
            mensagem_principal=mensagem,
            categoria=categoria,
            severidade=severidade,
            confianca=probabilidade_nocivo,
            tem_link=tem_link,
            papel_detectado=papel_detectado,
            acao_requerida=acao_requerida,
            integridade_valida=integridade_valida,
            contexto_antes=contexto_antes_msgs,
            contexto_depois=[],
            status=StatusIncidente.DETECTADO,
            criado_em=timestamp_utc,
            atualizado_em=timestamp_utc,
        )

        incidente_orm = IncidentORM(
            id=incidente_criado.id,
            dependent_id=dependent_id,
            room_type=room_type,
            conversation_id=conversation_id,
            main_message_text=texto,
            main_message_sender_id=sender_id,
            main_message_is_from_minor=is_from_minor,
            main_message_timestamp=timestamp_utc,
            main_message_hash=(message_hash or "").strip().lower(),
            category=categoria.value,
            severity=severidade,
            confidence=probabilidade_nocivo,
            has_link=tem_link,
            detected_role=papel_detectado.value,
            action_required=acao_requerida.value,
            integrity_valid=integridade_valida,
            context_before=json.dumps(contexto_antes_dicts),
            context_after=json.dumps([]),
            status=StatusIncidente.DETECTADO.value,
            created_at=timestamp_utc,
            updated_at=timestamp_utc,
            escalated=False,
        )
        db.add(incidente_orm)
        db.flush()

        historico_orm = IncidentStatusHistoryORM(
            id=f"hist-{uuid.uuid4().hex[:10]}",
            incident_id=incidente_criado.id,
            from_status="DETECTADO",
            to_status=StatusIncidente.DETECTADO.value,
            note=None,
            guardian_name="Sistema",
            changed_at=timestamp_utc,
        )
        db.add(historico_orm)

        in_memory_buffer.abrir_incidente_para_posteriores(
            conversation_id=conversation_id,
            incident_id=incidente_criado.id,
            created_at=timestamp_utc,
        )
        foi_criado = True
    else:
        # Mensagem segura: nunca persiste o texto, apenas incrementa o contador agregado
        dependent.safe_messages_count = (dependent.safe_messages_count or 0) + 1
        db.add(dependent)

    # Passo 7.4: Adicionar a mensagem ao buffer circular (sempre por último)
    in_memory_buffer.adicionar_mensagem(conversation_id, mensagem)

    db.commit()

    # Notificações WebSocket em tempo real (regras-de-negocio.md seção 10)
    if foi_criado and incidente_orm is not None:
        db.refresh(incidente_orm)
        summary_data = format_incident_summary_dict(incidente_orm)
        all_guardians = get_guardian_ids_for_dependent(
            db, dependent_id, primary_only=None
        )
        ws_manager.notify_event_sync(
            TipoEventoWS.INCIDENT_CREATED.value, summary_data, all_guardians
        )
        if acao_requerida == AcaoRequerida.ALERT_PARENT_CRITICAL:
            primary_guardians = get_guardian_ids_for_dependent(
                db, dependent_id, primary_only=True
            )
            ws_manager.notify_event_sync(
                TipoEventoWS.INCIDENT_CRITICAL.value,
                summary_data,
                primary_guardians,
            )

    elapsed_ms = round((time.perf_counter() - start_perf) * 1000.0, 2)

    return ResultadoAnaliseMensagem(
        label=label,
        category=categoria.value,
        confidence=probabilidade_nocivo,
        has_link=tem_link,
        action_required=acao_requerida.value,
        detected_role=papel_detectado.value,
        sha256_match=integridade_valida,
        incident_id=incidente_criado.id if incidente_criado else None,
        inference_time_ms=max(elapsed_ms, 0.01),
        incident=incidente_criado,
        created=foi_criado,
    )


def analisar_mensagem_completa(
    db: Session,
    texto: str,
    message_hash: str,
    dependent_id: str,
    conversation_id: str,
    room_type: str,
    sender_id: str,
    is_from_minor: bool,
    is_direct: bool,
    timestamp: datetime,
) -> ResultadoAnaliseMensagem:
    return _executar_pipeline_analise(
        db=db,
        texto=texto,
        message_hash=message_hash,
        dependent_id=dependent_id,
        conversation_id=conversation_id,
        room_type=room_type,
        sender_id=sender_id,
        is_from_minor=is_from_minor,
        is_direct=is_direct,
        timestamp=timestamp,
    )


def processar_mensagem(
    db: Session,
    texto: str,
    message_hash: str,
    dependent_id: str,
    conversation_id: str,
    room_type: str,
    sender_id: str,
    is_from_minor: bool,
    is_direct: bool,
    timestamp: datetime,
) -> Tuple[Optional[Incidente], bool]:
    res = _executar_pipeline_analise(
        db=db,
        texto=texto,
        message_hash=message_hash,
        dependent_id=dependent_id,
        conversation_id=conversation_id,
        room_type=room_type,
        sender_id=sender_id,
        is_from_minor=is_from_minor,
        is_direct=is_direct,
        timestamp=timestamp,
    )
    return res.incident, res.created