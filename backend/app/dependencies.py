"""FastAPI dependencies."""

from fastapi import Header, HTTPException, status

from .config import Settings, get_settings
from .services.auth_service import verify_api_key


def get_settings_dependency() -> Settings:
    """Inject settings into routes."""
    return get_settings()


def require_api_key(api_key: str = Header(..., alias="X-API-Key", description="API key for authentication")) -> str:
    """Validate the X-API-Key header.

    Raises:
        HTTPException: If the API key is missing or invalid.
    """
    if not verify_api_key(api_key):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )
    return api_key
