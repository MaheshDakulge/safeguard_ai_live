import os
from pydantic_settings import BaseSettings, SettingsConfigDict

# Walk up from this file (app/core/config.py) to find .env at project root
_env_file = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    ".env"
)


class Settings(BaseSettings):
    supabase_url: str = ""
    supabase_service_key: str = ""
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    # FIX: .env key is ACCESS_TOKEN_EXPIRE_MINUTES — was mismatched (hours vs minutes)
    access_token_expire_minutes: int = 1440

    google_doc_ai_project_id: str = ""
    google_doc_ai_processor_id: str = ""
    google_doc_ai_location: str = "us"
    google_application_credentials: str = ""

    model_config = SettingsConfigDict(env_file=_env_file, extra="ignore")


settings = Settings()
