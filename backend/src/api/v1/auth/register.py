from datetime import datetime, timedelta
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from src.api.core.config import settings
from src.api.core.security import create_access_token
from src.api.v1.auth.login import TokenResponse
from src.infrastructure.database import get_db
from src.infrastructure.models import (
    CoParentingInviteORM,
    DependentORM,
    GuardianDependentORM,
    GuardianORM,
)
from src.seed import hash_password

router = APIRouter()


def _generate_dependent_id(db: Session) -> str:
    """Gera um ID legível sequencial (ex.: dep-003) ou com sufixo único."""
    count = db.query(DependentORM).count()
    candidate = f"dep-{count + 1:03d}"
    existing = db.query(DependentORM).filter(DependentORM.id == candidate).first()
    if not existing:
        return candidate
    return f"dep-{uuid.uuid4().hex[:6]}"


class RegisterRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Carlos Silva",
                "email": "carlos@exemplo.com",
                "password": "senha123",
                "dependent_name": "Gabriel",
                "invite_code": None,
            }
        }
    )

    name: str = Field(..., min_length=1, description="Nome completo do responsável")
    email: str = Field(..., min_length=1, description="E-mail ou usuário do responsável")
    password: str = Field(..., min_length=1, description="Senha de acesso")
    dependent_name: Optional[str] = Field(
        default=None,
        description="Nome da criança/dependente a ser cadastrado (Responsável Primário)",
    )
    invite_code: Optional[str] = Field(
        default=None,
        description="Código de convite ou ID do dependente para co-parentalidade (Responsável Secundário)",
    )


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register_guardian(payload: RegisterRequest, db: Session = Depends(get_db)):
    """
    Cria uma nova conta de responsável e já realiza o vínculo com a criança:
    - Se `dependent_name` for informado: cria a criança em `dependents` e vincula como Responsável Primário (`is_primary=True`).
    - Se `invite_code` for informado: vincula a uma criança existente como Responsável Secundário (`is_primary=False`).
    """
    email_clean = payload.email.strip().lower()
    existing_user = db.query(GuardianORM).filter(GuardianORM.email == email_clean).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este e-mail já está cadastrado.",
        )

    dep_name_clean = (payload.dependent_name or "").strip()
    invite_clean = (payload.invite_code or "").strip()

    if not dep_name_clean and not invite_clean:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Informe o nome do filho(a)/dependente ou um código de convite.",
        )

    guardian_id = f"resp-{uuid.uuid4().hex[:8]}"
    new_guardian = GuardianORM(
        id=guardian_id,
        name=payload.name.strip(),
        email=email_clean,
        hashed_password=hash_password(payload.password),
        is_active=True,
    )
    db.add(new_guardian)
    db.flush()

    created_dependents = []

    if dep_name_clean:
        dep_id = _generate_dependent_id(db)
        new_dep = DependentORM(
            id=dep_id,
            name=dep_name_clean,
            common_threshold=0.50,
            safe_messages_count=0,
        )
        db.add(new_dep)
        db.flush()

        link = GuardianDependentORM(
            guardian_id=new_guardian.id,
            dependent_id=new_dep.id,
            is_primary=True,
        )
        db.add(link)
        created_dependents.append(
            {
                "id": new_dep.id,
                "name": new_dep.name,
                "common_threshold": new_dep.common_threshold,
                "is_primary": True,
                "safe_messages_count": 0,
            }
        )

    if invite_clean:
        invite = (
            db.query(CoParentingInviteORM)
            .filter(CoParentingInviteORM.code == invite_clean)
            .first()
        )
        target_dependent = None
        if invite:
            if invite.used or invite.expires_at < datetime.utcnow():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Código de convite expirado ou já utilizado.",
                )
            target_dependent = (
                db.query(DependentORM)
                .filter(DependentORM.id == invite.dependent_id)
                .first()
            )
            invite.used = True
        else:
            # Permite também vincular diretamente pelo ID do dependente em ambiente de demonstração
            target_dependent = (
                db.query(DependentORM).filter(DependentORM.id == invite_clean).first()
            )

        if not target_dependent:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Código de convite ou dependente não encontrado.",
            )

        link = GuardianDependentORM(
            guardian_id=new_guardian.id,
            dependent_id=target_dependent.id,
            is_primary=False,
        )
        db.add(link)
        created_dependents.append(
            {
                "id": target_dependent.id,
                "name": target_dependent.name,
                "common_threshold": target_dependent.common_threshold,
                "is_primary": False,
                "safe_messages_count": target_dependent.safe_messages_count,
            }
        )

    db.commit()
    db.refresh(new_guardian)

    access_token_expires = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": new_guardian.id}, expires_delta=access_token_expires
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": int(access_token_expires.total_seconds()),
        "guardian": {
            "id": new_guardian.id,
            "name": new_guardian.name,
            "email": new_guardian.email,
            "dependents": created_dependents,
        },
    }
