from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.api.v1.incidents.detail import format_incident_detail
from src.api.v1.websocket.handler import manager as ws_manager
from src.infrastructure.database import get_db
from src.services.gestao_incidente_service import (
    ForbiddenAccessError,
    IncidentNotFoundError,
    marcar_incidente_visualizado,
)

router = APIRouter()


def _notify_updated(incidente) -> None:
    payload = {
        "id": incidente.id,
        "dependent_id": incidente.dependent_id,
        "dependent_name": incidente.dependent.name if incidente.dependent else "Desconhecido",
        "category": incidente.category,
        "severity": incidente.severity,
        "confidence": incidente.confidence,
        "has_link": incidente.has_link,
        "detected_role": incidente.detected_role,
        "status": incidente.status,
        "integrity_mismatch": not incidente.integrity_valid,
        "escalated": incidente.escalated,
        "preview": incidente.main_message_text[:60],
        "created_at": incidente.created_at.isoformat() + "Z",
    }
    ws_manager.notify_event_sync("incident.updated", payload)


@router.post("/{incident_id}/view")
async def marcar_como_visualizado(
    incident_id: str,
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Registra que o responsável abriu o incidente (idempotente).
    Só realiza transição automática se o status atual for DETECTADO -> VISUALIZADO.
    """
    try:
        incidente, mudou = marcar_incidente_visualizado(
            db=db,
            incident_id=incident_id,
            guardian_id=guardian_id,
        )
        if mudou:
            _notify_updated(incidente)
        return format_incident_detail(db, incidente)
    except IncidentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ForbiddenAccessError as exc:
        raise HTTPException(status_code=403, detail=str(exc))