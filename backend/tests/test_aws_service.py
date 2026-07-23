"""Integration tests for AWSService using moto to mock AWS."""

import pytest
from moto import mock_aws

from app.config import Settings
from app.models import EnvironmentStatus
from app.services.aws_service import AWSService


@pytest.fixture
def test_settings() -> Settings:
    return Settings(
        aws_region="us-east-1",
        environments_table="seeo-environments-test",
        secrets_secret_name="seeo/runtime/credentials-test",
        ec2_instance_type="t2.micro",
    )


def _create_table(aws_service: AWSService) -> None:
    aws_service.dynamodb.create_table(
        TableName=aws_service.settings.environments_table,
        KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
        BillingMode="PAY_PER_REQUEST",
    )


@mock_aws
def test_create_environment(test_settings: Settings) -> None:
    aws_service = AWSService(test_settings)
    _create_table(aws_service)

    env = aws_service.create_environment("demo", 60)
    assert env.project_name == "demo"
    assert env.status == EnvironmentStatus.PROVISIONING
    assert env.instance_id is not None
    assert env.volume_id is not None

    stored = aws_service.get_environment(env.id)
    assert stored is not None
    assert stored.instance_id == env.instance_id


@mock_aws
def test_list_environments(test_settings: Settings) -> None:
    aws_service = AWSService(test_settings)
    _create_table(aws_service)

    env1 = aws_service.create_environment("demo-1", 60)
    env2 = aws_service.create_environment("demo-2", 60)

    environments = aws_service.list_environments()
    assert len(environments) == 2
    ids = {e.id for e in environments}
    assert {env1.id, env2.id} == ids


@mock_aws
def test_terminate_environment(test_settings: Settings) -> None:
    aws_service = AWSService(test_settings)
    _create_table(aws_service)

    env = aws_service.create_environment("demo", 60)
    terminated = aws_service.terminate_environment(env.id)
    assert terminated.status == EnvironmentStatus.TERMINATED

    # Instance should no longer be listed as active
    active = aws_service.list_environments()
    assert all(e.status != EnvironmentStatus.READY for e in active)


@mock_aws
def test_list_expired_environments(test_settings: Settings) -> None:
    aws_service = AWSService(test_settings)
    _create_table(aws_service)

    env = aws_service.create_environment("expired-demo", ttl_minutes=-1)
    expired = aws_service.list_expired_environments()
    assert any(e.id == env.id for e in expired)
