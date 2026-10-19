"""
Script para popular o banco de dados com dados de demonstração.
Execute com: python -m src.seed
"""

from typing import Optional
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from sqlalchemy.orm import Session

from src.infrastructure.database import create_tables, engine
from src.infrastructure.models import (
    DependentORM,
    GuardianDependentORM,
    GuardianORM,
)

_ph = PasswordHasher()


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return _ph.verify(hashed_password, plain_password)
    except (VerifyMismatchError, Exception):
        return False


def seed_session(session: Session) -> None:
    """Popula uma sessão do banco de dados com os dados canônicos de seed (idempotente)."""
    existing_guardian = session.query(GuardianORM).filter(GuardianORM.id == "resp-001").first()
    if existing_guardian:
        return

    guardian1 = GuardianORM(
        id="resp-001",
        name="Maria",
        email="responsavel@exemplo.com",
        hashed_password=hash_password("senha123"),
        is_active=True,
    )

    guardian2 = GuardianORM(
        id="resp-002",
        name="João",
        email="joao@exemplo.com",
        hashed_password=hash_password("senha456"),
        is_active=True,
    )

    dependent1 = DependentORM(
        id="dep-001",
        name="Lucas",
        common_threshold=0.50,
        safe_messages_count=0,
    )

    dependent2 = DependentORM(
        id="dep-002",
        name="Ana",
        common_threshold=0.50,
        safe_messages_count=0,
    )

    session.add_all([guardian1, guardian2, dependent1, dependent2])
    session.flush()

    links = [
        GuardianDependentORM(
            guardian_id="resp-001", dependent_id="dep-001", is_primary=True
        ),
        GuardianDependentORM(
            guardian_id="resp-001", dependent_id="dep-002", is_primary=True
        ),
        GuardianDependentORM(
            guardian_id="resp-002", dependent_id="dep-001", is_primary=False
        ),
    ]
    session.add_all(links)
    session.commit()


def seed_data(session: Optional[Session] = None) -> None:
    """Popula o banco com dados de demonstração."""
    if session is not None:
        seed_session(session)
        return

    create_tables()
    with Session(engine) as db_session:
        seed_session(db_session)
        print("Dados de demonstração garantidos com sucesso!")
        print("Credenciais:")
        print("  - Maria (Primário): responsavel@exemplo.com / senha123")
        print("  - João (Secundário): joao@exemplo.com / senha456")


if __name__ == "__main__":
    seed_data()