from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.api.v1.auth.register import _generate_dependent_id
from src.infrastructure.database import get_db
from src.infrastructure.models import (
    DependentORM,
    GuardianDependentORM,
    GuardianORM,
)

router = APIRouter(prefix="/dependents")


class CreateDependentRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Sofia",
                "common_threshold": 0.50,
            }
        }
    )

    name: str = Field(..., min_length=1, description="Nome da criança/dependente")
    common_threshold: float = Field(
        default=0.50, ge=0.50, le=0.84, description="Limiar comum inicial (0.50 a 0.84)"
    )


@router.post("", status_code=status.HTTP_201_CREATED)
@router.post("/", status_code=status.HTTP_201_CREATED, include_in_schema=False)
async def create_dependent(
    payload: CreateDependentRequest,
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Cadastra um novo dependente (filho/a) e vincula ao responsável autenticado como Primário (`is_primary=True`).
    """
    user = db.query(GuardianORM).filter(GuardianORM.id == guardian_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Não foi possível validar as credenciais",
        )

    dep_id = _generate_dependent_id(db)
    new_dep = DependentORM(
        id=dep_id,
        name=payload.name.strip(),
        common_threshold=round(payload.common_threshold, 2),
        safe_messages_count=0,
    )
    db.add(new_dep)
    db.flush()

    link = GuardianDependentORM(
        guardian_id=user.id,
        dependent_id=new_dep.id,
        is_primary=True,
    )
    db.add(link)
    db.commit()
    db.refresh(new_dep)

    return {
        "id": new_dep.id,
        "name": new_dep.name,
        "common_threshold": new_dep.common_threshold,
        "is_primary": True,
        "safe_messages_count": new_dep.safe_messages_count,
    }


@router.get("/simulator")
async def list_dependents_for_simulator(db: Session = Depends(get_db)):
    """
    Retorna todos os dependentes cadastrados no sistema para alimentar dinamicamente
    o seletor de Dependente Monitorado no Simulador de Chat Web.
    """
    deps = db.query(DependentORM).order_by(DependentORM.created_at.asc()).all()
    return [
        {
            "id": d.id,
            "name": d.name,
            "common_threshold": d.common_threshold,
            "safe_messages_count": d.safe_messages_count,
        }
        for d in deps
    ]
