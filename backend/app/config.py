"""Application configuration from environment."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    mongodb_uri: str = "mongodb://localhost:27017"
    database_name: str = "speech_parallel"
    gridfs_bucket: str = "audio"
    cors_origins: str = "*"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
