import os
import warnings
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

warnings.filterwarnings("ignore", message=".*The HMAC key is.*")

from src.api.core.config import settings
from src.api.core.model_loader import classify_text, is_model_loaded
from src.api.v1 import auth, dependents, incidents, predict, websocket
from src.infrastructure.database import SessionLocal, init_db
from src.seed import seed_data


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    current_env = os.getenv("APP_ENV", settings.app_env)
    if current_env != "testing":
        db = SessionLocal()
        try:
            seed_data(db)
        finally:
            db.close()
        # Pré-aquece o modelo BERTimbau na Main Thread durante o startup do servidor
        # para evitar Cold Start na primeira mensagem e garantir afinidade de thread do PyTorch
        try:
            classify_text("inicializacao")
        except Exception:
            pass
    yield


app = FastAPI(
    title="Project Artemis - API de Controle Parental Inteligente",
    description="Backend FastAPI para detecção de ciberbullying via BERTimbau e DetectorDeLinks",
    version="1.0.0",
    lifespan=lifespan,
)

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["Health Check"])
async def read_root():
    return {"status": "online", "model_loaded": is_model_loaded()}


app.include_router(predict.router, prefix="/api/v1", tags=["Inference"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(dependents.router, prefix="/api/v1", tags=["Dependents"])
app.include_router(incidents.router, prefix="/api/v1", tags=["Incidents"])
app.include_router(websocket.router, tags=["WebSocket"])
app.include_router(websocket.router, prefix="/api/v1/ws", include_in_schema=False)
