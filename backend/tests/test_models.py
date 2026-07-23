"""Tests for Pydantic request/response models."""

import pytest
from pydantic import ValidationError

from app.models import CreateEnvironmentRequest, EnvironmentStatus


def test_create_environment_request_valid():
    req = CreateEnvironmentRequest(project_name="my-api", ttl_minutes=60)
    assert req.project_name == "my-api"
    assert req.ttl_minutes == 60


def test_create_environment_request_ttl_too_low():
    with pytest.raises(ValidationError):
        CreateEnvironmentRequest(project_name="my-api", ttl_minutes=10)


def test_create_environment_request_ttl_too_high():
    with pytest.raises(ValidationError):
        CreateEnvironmentRequest(project_name="my-api", ttl_minutes=2000)


def test_create_environment_request_empty_project():
    with pytest.raises(ValidationError):
        CreateEnvironmentRequest(project_name="", ttl_minutes=60)


def test_environment_status_enum():
    assert EnvironmentStatus.READY == "ready"
    assert EnvironmentStatus.PROVISIONING.value == "provisioning"
