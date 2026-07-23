"""Application configuration."""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Settings loaded from environment variables."""

    app_name: str = "SEEO - Secure Ephemeral Environment Orchestrator"
    debug: bool = False

    # API Security
    api_key: str = "dev-change-me-in-production"

    # AWS
    aws_region: str = "us-east-1"
    aws_profile: str | None = None

    # Infrastructure
    ec2_key_pair: str | None = None
    ec2_ami_id: str | None = None
    ec2_instance_type: str = "t3.micro"
    ec2_subnet_id: str | None = None
    ec2_security_group_id: str | None = None
    iam_instance_profile: str | None = None

    # DynamoDB table for environment tracking
    environments_table: str = "seeo-environments"

    # Secrets Manager secret name for runtime credentials
    secrets_secret_name: str = "seeo/runtime/credentials"

    # TTL checker interval in seconds
    ttl_check_interval_seconds: int = 60

    # CORS: comma-separated list of allowed origins. "*" allows all.
    cors_allow_origins: str = "*"
    cors_allow_credentials: bool = False

    model_config = SettingsConfigDict(env_file=".env")


@lru_cache()
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()
