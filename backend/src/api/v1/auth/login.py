from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from src.api.core.config import settings
from src.api.core.security import create_access_token
from src.infrastructure.database import get_db
from src.infrastructure.models import GuardianORM
from src.seed import verify_password

router = APIRouter()


class LoginRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "responsavel@exemplo.com",
                "password": "senha123",
            }
        }
    )

    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int
    guardian: dict


def authenticate_user(db: Session, email: str, password: str):
    user = db.query(GuardianORM).filter(GuardianORM.email == email).first()
    if not user:
        return False
    if not verify_password(password, user.hashed_password):
        return False
    return user


@router.post("/login", response_model=TokenResponse)
def login_for_access_token(form_data: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, form_data.email, form_data.password)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="E-mail ou senha incorretos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": user.id}, expires_delta=access_token_expires
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
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": int(access_token_expires.total_seconds()),
        "guardian": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "dependents": dependents,
        },
    }