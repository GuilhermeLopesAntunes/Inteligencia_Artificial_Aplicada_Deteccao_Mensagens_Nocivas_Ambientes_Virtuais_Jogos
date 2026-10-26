from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

# Raiz do repositório quando rodando fora do Docker (backend/src/api/core/config.py)
REPO_ROOT = Path(__file__).resolve().parents[4]
BACKEND_DIR = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "production"
    model_dir: Path = REPO_ROOT / "models" / "modelo_tcc_final"
    model_version: str = "GuilhermeLA/modelo-tcc-final"
    database_url: str = f"sqlite:///{(BACKEND_DIR / 'data' / 'artemis.db').as_posix()}"
    jwt_secret: str = "artemis-default-secret-key-2026-tcc"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 365 * 24 * 60
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"

    @property
    def jwt_secret_key(self) -> str:
        return self.jwt_secret


settings = Settings()
