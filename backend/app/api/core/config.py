from pathlib import Path
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parents[4]


class Settings(BaseSettings):
    hf_model_repo_id: str = "GuilhermeLA/modelo-tcc-final"
    model_local_dir: Path = BASE_DIR / "scripts" / "datasets" / "modelo_tcc_final"

    class Config:
        env_prefix = "APP_"


settings = Settings()
