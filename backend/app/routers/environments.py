"""Environment lifecycle endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Request, status

from ..dependencies import get_settings_dependency
from ..dependencies import require_api_key
from ..models import (
    CreateEnvironmentRequest,
    Environment,
    EnvironmentStatus,
    EnvironmentSummary,
)
from ..services.aws_service import AWSService
from ..services.ttl_service import TTLService

router = APIRouter(prefix="/environments", tags=["environments"])


def get_aws_service(request: Request) -> AWSService:
    """Return the application-scoped AWS service singleton."""
    return request.app.state.aws_service


@router.post("", response_model=Environment, status_code=status.HTTP_201_CREATED)
def create_environment(
    request: CreateEnvironmentRequest,
    aws_service: AWSService = Depends(get_aws_service),
    _: str = Depends(require_api_key),
) -> Environment:
    """Request a new ephemeral environment.

    The environment will be provisioned asynchronously and will be torn down
    automatically when its TTL expires.
    """
    try:
        environment = aws_service.create_environment(
            project_name=request.project_name,
            ttl_minutes=request.ttl_minutes,
            instance_type=request.instance_type,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create environment: {exc}",
        ) from exc

    return environment


@router.get("", response_model=list[EnvironmentSummary])
def list_environments(
    status_filter: EnvironmentStatus | None = None,
    aws_service: AWSService = Depends(get_aws_service),
    _: str = Depends(require_api_key),
) -> list[EnvironmentSummary]:
    """List all tracked environments."""
    environments = aws_service.list_environments(status_filter=status_filter)
    return [
        EnvironmentSummary(
            id=env.id,
            project_name=env.project_name,
            status=env.status,
            created_at=env.created_at,
            expires_at=env.expires_at,
            instance_id=env.instance_id,
            public_ip=env.public_ip,
            ttl_minutes=env.ttl_minutes,
        )
        for env in environments
    ]


@router.get("/{environment_id}", response_model=Environment)
def get_environment(
    environment_id: str,
    aws_service: AWSService = Depends(get_aws_service),
    _: str = Depends(require_api_key),
) -> Environment:
    """Get details for a specific environment, refreshing state from AWS."""
    environment = aws_service.refresh_environment_state(environment_id)
    if not environment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Environment {environment_id} not found",
        )
    return environment


@router.delete("/{environment_id}", response_model=Environment)
def delete_environment(
    environment_id: str,
    aws_service: AWSService = Depends(get_aws_service),
    _: str = Depends(require_api_key),
) -> Environment:
    """Manually tear down an environment."""
    try:
        return aws_service.terminate_environment(environment_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to terminate environment: {exc}",
        ) from exc


@router.post("/{environment_id}/refresh", response_model=Environment)
def refresh_environment(
    environment_id: str,
    aws_service: AWSService = Depends(get_aws_service),
    _: str = Depends(require_api_key),
) -> Environment:
    """Refresh environment state from AWS."""
    environment = aws_service.refresh_environment_state(environment_id)
    if not environment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Environment {environment_id} not found",
        )
    return environment
