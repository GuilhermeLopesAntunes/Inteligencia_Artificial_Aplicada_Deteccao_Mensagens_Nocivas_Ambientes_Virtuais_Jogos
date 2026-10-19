from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.infrastructure.database import get_db
from src.infrastructure.models import GuardianORM

router = APIRouter(prefix="/dependents")


@router.get("")
@router.get("/", include_in_schema=False)
def list_dependents(
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Lista os dependentes vinculados ao responsável autenticado.
    """
    user = db.query(GuardianORM).filter(GuardianORM.id == guardian_id).first()
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Não foi possível validar as credenciais",
            headers={"WWW-Authenticate": "Bearer"},
        )

    dependents = []
    for link in user.dependent_links:
        if link.dependent:
            dep = link.dependent
            dependents.append(
                {
                    "id": dep.id,
                    "name": dep.name,
                    "common_threshold": dep.common_threshold,
                    "is_primary": link.is_primary,
                    "safe_messages_count": dep.safe_messages_count,
                }
            )

    return dependents