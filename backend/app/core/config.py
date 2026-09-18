import os
from pathlib import Path
from pydantic import ConfigDict
from pydantic_settings import BaseSettings

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
DEFAULT_DB_PATH = (BACKEND_DIR / "resqnet_server.db").as_posix()

class Settings(BaseSettings):
    PROJECT_NAME: str = "ResQNet Backend"
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str = os.getenv("SECRET_KEY", "resqnet_super_secret_jwt_key_2026_offline_first")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # SQLite default fallback if PostgreSQL is not active locally during testing
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", 
        f"sqlite+aiosqlite:///{DEFAULT_DB_PATH}"
    )

    model_config = ConfigDict(case_sensitive=True)

settings = Settings()
