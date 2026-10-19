"""
Serviço de gerenciamento de incidentes: transições de status, visualização idempotente, exclusão (LGPD) e listagem.
"""

from datetime import datetime
import logging
from typing import List, Optional, Tuple
import uuid
from sqlalchemy.orm import Session

from src.domain.entities import StatusIncidente
from src.domain.rules import eh_transicao_valida
from src.infrastructure.models import (
    DependentORM,
    FalsePositiveFeedbackORM,
    GuardianDependentORM,
    GuardianORM,
    IncidentORM,
    IncidentStatusHistoryORM,
)

logger = logging.getLogger(__name__)


class IncidentNotFoundError(LookupError):
    """Exceção quando o incidente não existe ou não está vinculado ao responsável."""


class ForbiddenAccessError(PermissionError):
    """Exceção quando ação exclusiva do primário é tentada por secundário."""


class InvalidTransitionError(ValueError):
    """Exceção quando a transição de status é inválida."""


def _verificar_vinculo_responsavel(
    db: Session, guardian_id: str, dependent_id: str
) -> Tuple[GuardianORM, DependentORM, GuardianDependentORM]:
    guardian = db.query(GuardianORM).filter(GuardianORM.id == guardian_id).first()
    if not guardian:
        raise IncidentNotFoundError(f"Responsável '{guardian_id}' não encontrado.")

    dependent = db.query(DependentORM).filter(DependentORM.id == dependent_id).first()
    if not dependent:
        raise IncidentNotFoundError(f"Dependente '{dependent_id}' não encontrado.")

    link = (
        db.query(GuardianDependentORM)
        .filter(
            GuardianDependentORM.guardian_id == guardian_id,
            GuardianDependentORM.dependent_id == dependent_id,
        )
        .first()
    )
    if not link:
        # Regra 12: Acesso a dependente ou incidente não vinculado -> HTTP 404 (não revelar que existe)
        raise IncidentNotFoundError("Incidente ou dependente não encontrado.")

    return guardian, dependent, link


def marcar_incidente_visualizado(
    db: Session,
    incident_id: str,
    guardian_id: str,
) -> Tuple[IncidentORM, bool]:
    """
    Registra que o responsável abriu o incidente (idempotente).
    Só realiza transição automática se o status atual for DETECTADO -> VISUALIZADO.
    Se já estiver em outro status, mantém o status atual e retorna (incidente, False).
    """
    incidente = db.query(IncidentORM).filter(IncidentORM.id == incident_id).first()
    if not incidente:
        raise IncidentNotFoundError(f"Incidente '{incident_id}' não encontrado.")

    guardian, _, _ = _verificar_vinculo_responsavel(db, guardian_id, incidente.dependent_id)

    if incidente.status != StatusIncidente.DETECTADO.value:
        return incidente, False

    agora = datetime.utcnow()
    status_anterior = incidente.status
    incidente.status = StatusIncidente.VISUALIZADO.value
    incidente.updated_at = agora

    historico = IncidentStatusHistoryORM(
        id=f"hist-{uuid.uuid4().hex[:12]}",
        incident_id=incidente.id,
        from_status=status_anterior,
        to_status=StatusIncidente.VISUALIZADO.value,
        note=None,
        guardian_name=guardian.name,
        changed_at=agora,
    )
    db.add(historico)
    db.add(incidente)
    db.commit()
    db.refresh(incidente)

    return incidente, True


def mudar_status_incidente(
    db: Session,
    incident_id: str,
    novo_status: str,
    guardian_id: str,
    nota: Optional[str] = None,
) -> IncidentORM:
    """
    Muda o status de um incidente validando a máquina de estados (manual=True) e registrando no histórico.
    Qualquer responsável vinculado ao dependente pode alterar o status.
    """
    incidente = db.query(IncidentORM).filter(IncidentORM.id == incident_id).first()
    if not incidente:
        raise IncidentNotFoundError(f"Incidente '{incident_id}' não encontrado.")

    guardian, _, _ = _verificar_vinculo_responsavel(db, guardian_id, incidente.dependent_id)

    status_atual = incidente.status
    if not eh_transicao_valida(status_atual, novo_status, manual=True):
        raise InvalidTransitionError(
            f"Transição inválida de {status_atual} para {novo_status}."
        )

    agora = datetime.utcnow()
    status_anterior = incidente.status
    incidente.status = novo_status
    incidente.updated_at = agora

    historico = IncidentStatusHistoryORM(
        id=f"hist-{uuid.uuid4().hex[:12]}",
        incident_id=incidente.id,
        from_status=status_anterior,
        to_status=novo_status,
        note=nota,
        guardian_name=guardian.name,
        changed_at=agora,
    )
    db.add(historico)

    if novo_status == StatusIncidente.FALSO_POSITIVO.value:
        existing_fb = (
            db.query(FalsePositiveFeedbackORM)
            .filter(FalsePositiveFeedbackORM.incident_id == incidente.id)
            .first()
        )
        if not existing_fb:
            feedback = FalsePositiveFeedbackORM(
                id=f"fp-{uuid.uuid4().hex[:12]}",
                incident_id=incidente.id,
                guardian_id=guardian.id,
                text=incidente.main_message_text,
                confidence=incidente.confidence,
                note=nota,
                created_at=agora,
            )
            db.add(feedback)

    db.add(incidente)
    db.commit()
    db.refresh(incidente)

    logger.info(
        f"Status do incidente {incidente.id} alterado de {status_anterior} para {novo_status} pelo responsável {guardian_id}"
    )

    return incidente


def excluir_incidente(
    db: Session,
    incident_id: str,
    guardian_id: str,
) -> Tuple[str, str]:
    """
    Exclui um incidente definitivamente (LGPD - Direito de Exclusão).
    Apenas o responsável primário vinculado ao dependente pode executar esta ação.
    Retorna (incident_id, dependent_id) do incidente excluído.
    """
    incidente = db.query(IncidentORM).filter(IncidentORM.id == incident_id).first()
    if not incidente:
        raise IncidentNotFoundError(f"Incidente '{incident_id}' não encontrado.")

    _, _, link = _verificar_vinculo_responsavel(db, guardian_id, incidente.dependent_id)

    if not link.is_primary:
        raise ForbiddenAccessError(
            "Apenas o responsável primário tem permissão para excluir registros de incidentes."
        )

    dep_id = incidente.dependent_id
    inc_id = incidente.id

    db.delete(incidente)
    db.commit()

    logger.info(
        f"Incidente {inc_id} excluído definitivamente pelo responsável primário {guardian_id}"
    )

    return inc_id, dep_id


def obter_incidentes_dependente(
    db: Session,
    guardian_id: str,
    dependent_id: Optional[str] = None,
    status: Optional[str] = None,
    categoria: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
) -> List[IncidentORM]:
    """Obtém incidentes vinculados ao responsável, com opções de filtro."""
    guardian = db.query(GuardianORM).filter(GuardianORM.id == guardian_id).first()
    if not guardian:
        raise IncidentNotFoundError(f"Responsável '{guardian_id}' não encontrado.")

    dependent_ids = [link.dependent_id for link in guardian.dependent_links]
    if not dependent_ids:
        return []

    query = db.query(IncidentORM).filter(IncidentORM.dependent_id.in_(dependent_ids))

    if dependent_id:
        if dependent_id not in dependent_ids:
            raise IncidentNotFoundError("Dependente não encontrado.")
        query = query.filter(IncidentORM.dependent_id == dependent_id)

    if status:
        query = query.filter(IncidentORM.status == status)

    if categoria:
        query = query.filter(IncidentORM.category == categoria)

    return (
        query.order_by(IncidentORM.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )


def contar_incidentes_dependente(
    db: Session,
    guardian_id: str,
    dependent_id: Optional[str] = None,
    status: Optional[str] = None,
    categoria: Optional[str] = None,
) -> int:
    """Conta o total de incidentes vinculados ao responsável para paginação."""
    guardian = db.query(GuardianORM).filter(GuardianORM.id == guardian_id).first()
    if not guardian:
        raise IncidentNotFoundError(f"Responsável '{guardian_id}' não encontrado.")

    dependent_ids = [link.dependent_id for link in guardian.dependent_links]
    if not dependent_ids:
        return 0

    query = db.query(IncidentORM).filter(IncidentORM.dependent_id.in_(dependent_ids))

    if dependent_id:
        if dependent_id not in dependent_ids:
            raise IncidentNotFoundError("Dependente não encontrado.")
        query = query.filter(IncidentORM.dependent_id == dependent_id)

    if status:
        query = query.filter(IncidentORM.status == status)

    if categoria:
        query = query.filter(IncidentORM.category == categoria)

    return query.count()