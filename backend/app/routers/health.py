"""Health check endpoint."""

from fastapi import APIRouter, Depends

from ..config import Settings, get_settings_dependency
from ..models import HealthResponse

router = APIRouter(prefix="/health", tags=["health"])


@router.get("", response_model=HealthResponse)
def health_check(settings: Settings = Depends(get_settings_dependency)) -> HealthResponse:
    """Return a simple health status."""
    return HealthResponse(
        status="ok",
        version="0.1.0",
    )
