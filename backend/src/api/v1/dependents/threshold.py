from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.domain.rules import validar_calibracao_limiar
from src.infrastructure.database import get_db
from src.infrastructure.models import DependentORM, GuardianDependentORM

router = APIRouter(prefix="/dependents")


class ThresholdUpdate(BaseModel):
    common_threshold: float


@router.patch("/{dependent_id}/threshold")
async def update_dependent_threshold(
    dependent_id: str,
    threshold_update: ThresholdUpdate,
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Atualiza o limiar comum de um dependente (0.50 <= L <= 0.84).
    Apenas o responsável primário vinculado pode executar esta ação.
    """
    try:
        novo_limiar = validar_calibracao_limiar(threshold_update.common_threshold)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )

    dependent = db.query(DependentORM).filter(DependentORM.id == dependent_id).first()
    if not dependent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dependente não encontrado",
        )

    link = (
        db.query(GuardianDependentORM)
        .filter(
            GuardianDependentORM.guardian_id == guardian_id,
            GuardianDependentORM.dependent_id == dependent_id,
        )
        .first()
    )
    if not link:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dependente não encontrado",
        )

    if not link.is_primary:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas o responsável primário pode atualizar o limiar",
        )

    dependent.common_threshold = novo_limiar
    db.add(dependent)
    db.commit()
    db.refresh(dependent)

    return {
        "id": dependent.id,
        "common_threshold": dependent.common_threshold,
        "updated_at": datetime.utcnow().isoformat() + "Z",
    }