import asyncio
import anyio
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.api.v1.websocket.handler import send_incident_deleted_notification
from src.infrastructure.database import get_db
from src.services.gestao_incidente_service import (
    ForbiddenAccessError,
    IncidentNotFoundError,
    excluir_incidente,
)

router = APIRouter()


def _notify_deleted(inc_id: str, dep_id: str) -> None:
    try:
        anyio.from_thread.run(send_incident_deleted_notification, inc_id, dep_id)
    except RuntimeError:
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(send_incident_deleted_notification(inc_id, dep_id))
        except RuntimeError:
            asyncio.run(send_incident_deleted_notification(inc_id, dep_id))


@router.delete("/{incident_id}", status_code=status.HTTP_204_NO_CONTENT)
def excluir_incidente_endpoint(
    incident_id: str,
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Exclui um incidente definitivamente (LGPD - Direito de Exclusão).
    Apenas o responsável primário pode executar esta ação.
    """
    try:
        inc_id, dep_id = excluir_incidente(
            db=db,
            incident_id=incident_id,
            guardian_id=guardian_id,
        )
        _notify_deleted(inc_id, dep_id)
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except IncidentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ForbiddenAccessError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))