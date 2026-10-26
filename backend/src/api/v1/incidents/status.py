from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.api.v1.incidents.detail import format_incident_detail
from src.api.v1.incidents.view import _notify_updated
from src.infrastructure.database import get_db
from src.services.gestao_incidente_service import (
    ForbiddenAccessError,
    IncidentNotFoundError,
    InvalidTransitionError,
    mudar_status_incidente,
)

router = APIRouter()


class StatusUpdate(BaseModel):
    status: str
    note: Optional[str] = None


@router.patch("/{incident_id}/status")
async def atualizar_status_incidente(
    incident_id: str,
    status_update: StatusUpdate,
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Atualiza o status de um incidente conforme a máquina de estados permitida.
    """
    try:
        incidente = mudar_status_incidente(
            db=db,
            incident_id=incident_id,
            novo_status=status_update.status,
            guardian_id=guardian_id,
            nota=status_update.note,
        )
        _notify_updated(incidente)
        return format_incident_detail(db, incidente)
    except IncidentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ForbiddenAccessError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except InvalidTransitionError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))