from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.infrastructure.database import get_db
from src.infrastructure.models import GuardianORM

router = APIRouter()


@router.get("/me")
def read_guardian_me(
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
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
            dependents.append(
                {
                    "id": link.dependent.id,
                    "name": link.dependent.name,
                    "is_primary": link.is_primary,
                }
            )

    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "dependents": dependents,
    }