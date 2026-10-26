import os
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Garante que backend/ está no PYTHONPATH e APP_ENV=testing por padrão nos testes
BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

os.environ["APP_ENV"] = "testing"

from src.infrastructure.database import Base, get_db
from src.infrastructure.in_memory_buffer import buffer_contexto
from src.main import app
from src.seed import seed_data
import src.services.analise_service as analise_service_module


@pytest.fixture()
def db_session():
    """Cria um banco SQLite em memória isolado por teste."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    db = TestingSessionLocal()
    try:
        seed_data(db)
        buffer_contexto.clear()
        analise_service_module._classificador_override = None
        yield db
    finally:
        buffer_contexto.clear()
        analise_service_module._classificador_override = None
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client(db_session):
    """TestClient FastAPI injetando a sessão SQLite em memória."""
    async def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
