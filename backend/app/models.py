"""Pydantic models for request/response payloads."""

from datetime import datetime
from enum import Enum
from pydantic import BaseModel, ConfigDict, Field


class EnvironmentStatus(str, Enum):
    """Lifecycle status of an ephemeral environment."""

    PENDING = "pending"
    PROVISIONING = "provisioning"
    READY = "ready"
    EXPIRED = "expired"
    TERMINATING = "terminating"
    TERMINATED = "terminated"
    ERROR = "error"


class CreateEnvironmentRequest(BaseModel):
    """Payload to request a new ephemeral environment."""

    project_name: str = Field(..., min_length=1, max_length=64, examples=["my-api"])
    ttl_minutes: int = Field(..., ge=15, le=1440, examples=["60"])
    instance_type: str | None = Field(
        default=None,
        description="Override default EC2 instance type.",
        examples=["t3.micro"],
    )


class Environment(BaseModel):
    """Representation of an ephemeral environment."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    project_name: str
    status: EnvironmentStatus
    created_at: datetime
    expires_at: datetime
    instance_id: str | None = None
    public_ip: str | None = None
    private_ip: str | None = None
    volume_id: str | None = None
    ttl_minutes: int
    message: str | None = None


class EnvironmentSummary(BaseModel):
    """Summary of an environment for listing."""

    id: str
    project_name: str
    status: EnvironmentStatus
    created_at: datetime
    expires_at: datetime
    instance_id: str | None = None
    public_ip: str | None = None
    ttl_minutes: int


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    version: str = "0.1.0"
