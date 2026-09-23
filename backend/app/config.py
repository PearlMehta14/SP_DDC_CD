import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    database_url: Optional[str] = None
    secret_key: Optional[str] = None
    supabase_url: Optional[str] = None
    supabase_publishable_key: Optional[str] = None
    supabase_secret_key: Optional[str] = None
    cors_origins: Optional[str] = None
    api_base_url: Optional[str] = None
    initial_admin_email: str = "dilpesh@ddcdiamonds.com"

    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env"),
        env_file_encoding="utf-8"
    )

settings = Settings()
