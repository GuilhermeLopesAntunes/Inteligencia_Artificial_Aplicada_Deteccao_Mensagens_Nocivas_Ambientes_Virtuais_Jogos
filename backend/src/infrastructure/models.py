from datetime import datetime
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from src.infrastructure.database import Base


class GuardianDependentORM(Base):
    """Tabela associativa N:N entre responsáveis e dependentes com flag `is_primary` por dependente."""

    __tablename__ = "guardian_dependents"

    guardian_id = Column(
        String, ForeignKey("guardians.id", ondelete="CASCADE"), primary_key=True
    )
    dependent_id = Column(
        String, ForeignKey("dependents.id", ondelete="CASCADE"), primary_key=True
    )
    is_primary = Column(Boolean, nullable=False, default=False)

    guardian = relationship("GuardianORM", back_populates="dependent_links")
    dependent = relationship("DependentORM", back_populates="guardian_links")


class GuardianORM(Base):
    __tablename__ = "guardians"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    dependent_links = relationship(
        "GuardianDependentORM",
        back_populates="guardian",
        cascade="all, delete-orphan",
    )

    @property
    def guardian_links(self):
        return self.dependent_links


class DependentORM(Base):
    __tablename__ = "dependents"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    common_threshold = Column(Float, nullable=False, default=0.50)  # 0.50 a 0.84
    safe_messages_count = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

    guardian_links = relationship(
        "GuardianDependentORM",
        back_populates="dependent",
        cascade="all, delete-orphan",
    )
    incidents = relationship(
        "IncidentORM",
        back_populates="dependent",
        cascade="all, delete-orphan",
    )


class IncidentORM(Base):
    __tablename__ = "incidents"

    id = Column(String, primary_key=True, index=True)
    dependent_id = Column(
        String, ForeignKey("dependents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    room_type = Column(String, nullable=False, default="conversa")
    conversation_id = Column(String, nullable=False, default="conv-default")

    # Mensagem principal
    main_message_text = Column(Text, nullable=False)
    main_message_sender_id = Column(String, nullable=False)
    main_message_is_from_minor = Column(Boolean, nullable=False)
    main_message_timestamp = Column(DateTime, nullable=False)
    main_message_hash = Column(String, nullable=False)

    # Classificação
    category = Column(String, nullable=False)  # SEGURO, CIBERBULLYING, LINK_SUSPEITO
    severity = Column(String, nullable=False)  # CRITICO ou COMUM
    confidence = Column(Float, nullable=False)  # P(nocivo)
    has_link = Column(Boolean, nullable=False)
    detected_role = Column(String, nullable=False)  # VITIMA, EMISSOR, ESPECTADOR
    action_required = Column(
        String, nullable=False
    )  # NONE, LOG_INCIDENT, ALERT_PARENT_CRITICAL
    integrity_valid = Column(
        Boolean, nullable=False, default=True
    )  # Resultado da verificação SHA-256

    # Contexto (armazenado como JSON texto)
    context_before = Column(Text, nullable=True)
    context_after = Column(Text, nullable=True)

    # Controle de status
    status = Column(String, nullable=False, default="DETECTADO")
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    escalated = Column(Boolean, nullable=False, default=False)

    dependent = relationship("DependentORM", back_populates="incidents")
    status_history = relationship(
        "IncidentStatusHistoryORM",
        back_populates="incident",
        cascade="all, delete-orphan",
    )
    false_positive_feedbacks = relationship(
        "FalsePositiveFeedbackORM",
        back_populates="incident",
        cascade="all, delete-orphan",
    )


class IncidentStatusHistoryORM(Base):
    __tablename__ = "incident_status_history"

    id = Column(String, primary_key=True, index=True)
    incident_id = Column(
        String, ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    from_status = Column(String, nullable=False)
    to_status = Column(String, nullable=False)
    note = Column(Text, nullable=True)
    guardian_name = Column(String, nullable=False)
    changed_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    incident = relationship("IncidentORM", back_populates="status_history")


class FalsePositiveFeedbackORM(Base):
    __tablename__ = "false_positive_feedbacks"

    id = Column(String, primary_key=True, index=True)
    incident_id = Column(
        String, ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    guardian_id = Column(String, nullable=True)
    text = Column(Text, nullable=True)
    confidence = Column(Float, nullable=True)
    note = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    incident = relationship("IncidentORM", back_populates="false_positive_feedbacks")


class CoParentingInviteORM(Base):
    __tablename__ = "coparenting_invites"

    code = Column(String, primary_key=True, index=True)
    dependent_id = Column(
        String, ForeignKey("dependents.id", ondelete="CASCADE"), nullable=False
    )
    created_by = Column(
        String, ForeignKey("guardians.id", ondelete="CASCADE"), nullable=False
    )
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)