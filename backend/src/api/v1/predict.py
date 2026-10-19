from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from src.api.core.config import settings
from src.infrastructure.database import get_db
from src.services.analise_service import (
    DependentNotFoundError,
    analisar_mensagem_completa,
)

router = APIRouter()


class ContextMetadata(BaseModel):
    conversation_id: str
    room_type: str  # "jogo" ou "conversa"
    sender_id: str
    is_from_minor: bool
    is_direct: bool
    timestamp: str  # ISO-8601 UTC


class PredictPayload(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "text": "Você é um inútil, ninguém gosta de você",
                "message_hash": "fd4fb587eb5d6eb02581ffab2d7df17f9e0f5b5d83b8ca16ef3f6f7d22a92fb3",
                "dependent_id": "dep-001",
                "context_metadata": {
                    "conversation_id": "conv-demo-01",
                    "room_type": "jogo",
                    "sender_id": "user-adversario-09",
                    "is_from_minor": False,
                    "is_direct": True,
                    "timestamp": "2026-10-19T18:30:00Z",
                },
            }
        }
    )

    text: str
    message_hash: str
    dependent_id: str
    context_metadata: ContextMetadata


class PredictionResponse(BaseModel):
    label: str  # "normal" ou "nocivo"
    category: str  # "SEGURO", "CIBERBULLYING", "LINK_SUSPEITO"
    confidence: float  # P(nocivo)
    has_link: bool
    action_required: str  # "NONE", "LOG_INCIDENT", "ALERT_PARENT_CRITICAL"
    detected_role: str  # "VITIMA", "EMISSOR", "ESPECTADOR"
    sha256_match: bool
    incident_id: Optional[str]  # ID do incidente criado, ou null se ação for NONE
    model_version: str
    inference_time_ms: float


@router.post("/predict", response_model=PredictionResponse)
def predict_message(payload: PredictPayload, db: Session = Depends(get_db)):
    """
    Endpoint que recebe uma mensagem do simulador, processa através do serviço de análise
    (inferência BERTimbau única, DetectorDeLinks, buffer de contexto e regras de limiar)
    e retorna a classificação completa conforme o contrato da API.
    """
    if not payload.text or not payload.text.strip():
        raise HTTPException(status_code=400, detail="O texto não pode estar vazio.")

    if payload.context_metadata.room_type not in ["jogo", "conversa"]:
        raise HTTPException(
            status_code=422, detail="room_type deve ser 'jogo' ou 'conversa'"
        )

    try:
        timestamp = datetime.fromisoformat(
            payload.context_metadata.timestamp.replace("Z", "+00:00")
        )
    except ValueError:
        raise HTTPException(
            status_code=422, detail="timestamp deve estar no formato ISO-8601 UTC"
        )

    try:
        resultado = analisar_mensagem_completa(
            db=db,
            texto=payload.text,
            message_hash=payload.message_hash,
            dependent_id=payload.dependent_id,
            conversation_id=payload.context_metadata.conversation_id,
            room_type=payload.context_metadata.room_type,
            sender_id=payload.context_metadata.sender_id,
            is_from_minor=payload.context_metadata.is_from_minor,
            is_direct=payload.context_metadata.is_direct,
            timestamp=timestamp,
        )
    except DependentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    return {
        "label": resultado.label,
        "category": resultado.category,
        "confidence": resultado.confidence,
        "has_link": resultado.has_link,
        "action_required": resultado.action_required,
        "detected_role": resultado.detected_role,
        "sha256_match": resultado.sha256_match,
        "incident_id": resultado.incident_id,
        "model_version": settings.model_version,
        "inference_time_ms": resultado.inference_time_ms,
    }