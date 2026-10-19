from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.infrastructure.database import get_db
from src.services.gestao_incidente_service import (
    ForbiddenAccessError,
    IncidentNotFoundError,
    contar_incidentes_dependente,
    obter_incidentes_dependente,
)

router = APIRouter(prefix="/incidents")


@router.get("")
@router.get("/", include_in_schema=False)
def list_incidents(
    dependent_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    limit: int = Query(50, le=200, ge=1),
    offset: int = Query(0, ge=0),
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Lista incidentes vinculados ao responsável autenticado, com filtros e paginação.
    """
    try:
        incidentes = obter_incidentes_dependente(
            db=db,
            guardian_id=guardian_id,
            dependent_id=dependent_id,
            status=status,
            categoria=category,
            limit=limit,
            offset=offset,
        )
        total = contar_incidentes_dependente(
            db=db,
            guardian_id=guardian_id,
            dependent_id=dependent_id,
            status=status,
            categoria=category,
        )
    except IncidentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ForbiddenAccessError as exc:
        raise HTTPException(status_code=403, detail=str(exc))

    items = []
    for inc in incidentes:
        preview = (
            (inc.main_message_text[:60] + "...")
            if len(inc.main_message_text) > 60
            else inc.main_message_text
        )
        created_iso = inc.created_at.isoformat()
        if not created_iso.endswith("Z") and "+" not in created_iso:
            created_iso += "Z"
        items.append(
            {
                "id": inc.id,
                "dependent_id": inc.dependent_id,
                "dependent_name": inc.dependent.name if inc.dependent else "Desconhecido",
                "category": inc.category,
                "severity": inc.severity,
                "confidence": inc.confidence,
                "has_link": inc.has_link,
                "detected_role": inc.detected_role,
                "status": inc.status,
                "integrity_mismatch": not inc.integrity_valid,
                "escalated": inc.escalated,
                "preview": preview,
                "created_at": created_iso,
            }
        )

    return {"items": items, "total": total}