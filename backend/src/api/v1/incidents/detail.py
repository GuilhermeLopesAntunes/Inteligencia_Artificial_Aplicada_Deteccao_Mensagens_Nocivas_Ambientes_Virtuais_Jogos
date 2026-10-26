import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.domain.rules import obter_transicoes_permitidas
from src.infrastructure.database import get_db
from src.infrastructure.models import (
    GuardianDependentORM,
    IncidentORM,
    IncidentStatusHistoryORM,
)

router = APIRouter()


def format_incident_detail(db: Session, incidente_db: IncidentORM) -> dict:
    """Formata um IncidentORM no schema IncidentDetail do contrato da API."""
    historico = (
        db.query(IncidentStatusHistoryORM)
        .filter(IncidentStatusHistoryORM.incident_id == incidente_db.id)
        .order_by(IncidentStatusHistoryORM.changed_at.asc())
        .all()
    )

    contexto_antes = []
    contexto_depois = []

    if incidente_db.context_before:
        try:
            contexto_antes = json.loads(incidente_db.context_before)
        except (json.JSONDecodeError, TypeError):
            contexto_antes = []

    if incidente_db.context_after:
        try:
            contexto_depois = json.loads(incidente_db.context_after)
        except (json.JSONDecodeError, TypeError):
            contexto_depois = []

    def format_contexto(mensagens):
        formatted = []
        for msg in mensagens:
            if isinstance(msg, dict):
                formatted.append(
                    {
                        "text": msg.get("text", ""),
                        "sender_id": msg.get("sender_id", ""),
                        "is_from_minor": msg.get("is_from_minor", False),
                        "timestamp": msg.get("timestamp", ""),
                    }
                )
        return formatted

    allowed_transitions = obter_transicoes_permitidas(incidente_db.status)

    historico_formatado = []
    for h in historico:
        changed_iso = None
        if h.changed_at:
            changed_iso = h.changed_at.isoformat()
            if not changed_iso.endswith("Z") and "+" not in changed_iso:
                changed_iso += "Z"
        historico_formatado.append(
            {
                "from_status": h.from_status,
                "to_status": h.to_status,
                "note": h.note,
                "guardian_name": h.guardian_name,
                "changed_at": changed_iso,
            }
        )

    msg_ts = incidente_db.main_message_timestamp.isoformat()
    if not msg_ts.endswith("Z") and "+" not in msg_ts:
        msg_ts += "Z"

    return {
        "id": incidente_db.id,
        "dependent_id": incidente_db.dependent_id,
        "dependent_name": (
            incidente_db.dependent.name if incidente_db.dependent else "Desconhecido"
        ),
        "category": incidente_db.category,
        "severity": incidente_db.severity,
        "confidence": incidente_db.confidence,
        "has_link": incidente_db.has_link,
        "detected_role": incidente_db.detected_role,
        "status": incidente_db.status,
        "integrity_mismatch": not incidente_db.integrity_valid,
        "escalated": incidente_db.escalated,
        "room_type": getattr(incidente_db, "room_type", None) or "conversa",
        "conversation_id": getattr(incidente_db, "conversation_id", None) or "conv-default",
        "message": {
            "text": incidente_db.main_message_text,
            "sender_id": incidente_db.main_message_sender_id,
            "is_from_minor": incidente_db.main_message_is_from_minor,
            "timestamp": msg_ts,
            "message_hash": incidente_db.main_message_hash,
        },
        "context_before": format_contexto(contexto_antes),
        "context_after": format_contexto(contexto_depois),
        "allowed_transitions": allowed_transitions,
        "status_history": historico_formatado,
    }


@router.get("/{incident_id}")
async def get_incident(
    incident_id: str,
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Obtém os detalhes completos de um incidente específico.
    """
    incidente_db = db.query(IncidentORM).filter(IncidentORM.id == incident_id).first()
    if not incidente_db:
        raise HTTPException(status_code=404, detail="Incidente não encontrado")

    link = (
        db.query(GuardianDependentORM)
        .filter(
            GuardianDependentORM.guardian_id == guardian_id,
            GuardianDependentORM.dependent_id == incidente_db.dependent_id,
        )
        .first()
    )
    if not link:
        raise HTTPException(
            status_code=403,
            detail="Responsável não possui acesso a este incidente",
        )

    return format_incident_detail(db, incidente_db)