import os
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker
from sqlalchemy.pool import StaticPool

from src.api.core.config import settings

db_url = settings.database_url
if db_url.startswith("sqlite:///") and ":memory:" not in db_url:
    db_file_path = db_url.replace("sqlite:///", "", 1)
    if db_file_path.startswith("/") and os.name == "nt" and not os.path.exists("/app"):
        from src.api.core.config import BACKEND_DIR
        local_db = BACKEND_DIR / "data" / "artemis.db"
        os.makedirs(local_db.parent, exist_ok=True)
        db_url = f"sqlite:///{local_db.as_posix()}"
    else:
        db_dir = os.path.dirname(db_file_path)
        if db_dir:
            os.makedirs(db_dir, exist_ok=True)

connect_args = {"check_same_thread": False} if db_url.startswith("sqlite") else {}
engine_kwargs = {"connect_args": connect_args, "echo": False}
if ":memory:" in db_url or db_url == "sqlite://":
    engine_kwargs["poolclass"] = StaticPool

engine = create_engine(db_url, **engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Dependency para obter uma sessão do banco de dados."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    """Cria todas as tabelas no banco de dados."""
    import src.infrastructure.models  # noqa: F401
    Base.metadata.create_all(bind=engine)


init_db = create_tables

from src.infrastructure.models import (  # noqa: E402, F401
    CoParentingInviteORM,
    DependentORM,
    FalsePositiveFeedbackORM,
    GuardianDependentORM,
    GuardianORM,
    IncidentORM,
    IncidentStatusHistoryORM,
)