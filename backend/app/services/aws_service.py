"""AWS orchestration helpers for SEEO."""

import base64
import datetime
import hashlib
import json
import os
import time
import uuid
from typing import Sequence

import boto3
from boto3.dynamodb.conditions import Attr, Key
from botocore.exceptions import ClientError

from ..config import Settings
from ..models import Environment, EnvironmentStatus


class AWSService:
    """Coordinates AWS resources for ephemeral environments."""

    def __init__(self, settings: Settings):
        self.settings = settings
        session_kwargs: dict = {"region_name": settings.aws_region}
        if settings.aws_profile:
            session_kwargs["profile_name"] = settings.aws_profile
        session = boto3.Session(**session_kwargs)
        self.ec2 = session.client("ec2")
        self.dynamodb = session.resource("dynamodb")
        self.table = self.dynamodb.Table(settings.environments_table)
        self.secretsmanager = session.client("secretsmanager")

    def _generate_id(self, project_name: str) -> str:
        """Generate a deterministic, URL-safe environment ID."""
        timestamp = datetime.datetime.utcnow().strftime("%Y%m%d%H%M%S")
        unique = uuid.uuid4().hex[:8]
        return f"{project_name}-{timestamp}-{unique}"

    def _encode_user_data(self, environment_id: str, secret_name: str) -> str:
        """Build and base64-encode a hardened EC2 bootstrap script.

        The script fetches runtime credentials from Secrets Manager using the
        attached IAM role and writes them to a protected config file. It does
        not write secrets to logs or environment variables.
        """
        bootstrap = f"""#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/seeo-bootstrap.log) 2>&1

REGION="{self.settings.aws_region}"
SECRET_NAME="{secret_name}"
CONFIG_FILE="/etc/seeo-config.json"
SECRET_FILE="/etc/seeo-secret.json"

# Fetch runtime credentials from Secrets Manager at startup using IAM role.
aws secretsmanager get-secret-value \\
  --region "$REGION" \\
  --secret-id "$SECRET_NAME" \\
  --query SecretString --output text > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"

# Persist non-secret environment metadata in a separate config file.
printf '%s' "{{\\"environment_id\\": \\"{environment_id}\\"}}" > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

echo "SEEO bootstrap complete for {environment_id}"
"""
        return base64.b64encode(bootstrap.encode("utf-8")).decode("utf-8")

    def create_environment(self, project_name: str, ttl_minutes: int, instance_type: str | None = None) -> Environment:
        """Provision a hardened ephemeral environment in AWS.

        Args:
            project_name: Identifier for the requesting project.
            ttl_minutes: Time-to-live in minutes.
            instance_type: Optional EC2 instance type override.

        Returns:
            Environment model representing the new environment.
        """
        environment_id = self._generate_id(project_name)
        created_at = datetime.datetime.utcnow()
        expires_at = created_at + datetime.timedelta(minutes=ttl_minutes)

        # Use provided AMI or fall back to the latest Amazon Linux 2023 AMI
        ami_id = self.settings.ec2_ami_id or self._latest_amazon_linux_ami()
        selected_instance_type = instance_type or self.settings.ec2_instance_type

        # Build bootstrap script that fetches credentials from Secrets Manager
        user_data = self._encode_user_data(environment_id, self.settings.secrets_secret_name)

        run_args: dict = {
            "ImageId": ami_id,
            "InstanceType": selected_instance_type,
            "MinCount": 1,
            "MaxCount": 1,
            "UserData": user_data,
            "TagSpecifications": [
                {
                    "ResourceType": "instance",
                    "Tags": [
                        {"Key": "Name", "Value": f"seeo-{environment_id}"},
                        {"Key": "Project", "Value": project_name},
                        {"Key": "seeo:environment_id", "Value": environment_id},
                        {"Key": "seeo:ttl_minutes", "Value": str(ttl_minutes)},
                        {"Key": "seeo:managed_by", "Value": "seeo"},
                    ],
                }
            ],
        }

        if self.settings.iam_instance_profile:
            run_args["IamInstanceProfile"] = {"Name": self.settings.iam_instance_profile}

        if self.settings.ec2_key_pair:
            run_args["KeyName"] = self.settings.ec2_key_pair

        if self.settings.ec2_security_group_id:
            run_args["SecurityGroupIds"] = [self.settings.ec2_security_group_id]

        if self.settings.ec2_subnet_id:
            run_args["SubnetId"] = self.settings.ec2_subnet_id

        try:
            response = self.ec2.run_instances(**run_args)
        except ClientError as exc:
            raise RuntimeError(f"Failed to launch EC2 instance: {exc}") from exc

        instance_id = response["Instances"][0]["InstanceId"]

        # Attach a small EBS volume for local data processing
        volume_id: str | None = None
        try:
            vol_resp = self.ec2.create_volume(
                Size=10,
                VolumeType="gp3",
                AvailabilityZone=self._availability_zone_for_subnet(),
                TagSpecifications=[
                    {
                        "ResourceType": "volume",
                        "Tags": [
                            {"Key": "Name", "Value": f"seeo-{environment_id}"},
                            {"Key": "seeo:environment_id", "Value": environment_id},
                            {"Key": "seeo:managed_by", "Value": "seeo"},
                        ],
                    }
                ],
            )
            volume_id = vol_resp["VolumeId"]
            self.ec2.attach_volume(
                InstanceId=instance_id,
                VolumeId=volume_id,
                Device="/dev/sdf",
            )
        except ClientError as exc:
            # Don't fail the whole request if volume creation fails, but surface it
            volume_id = None
            print(f"WARN: EBS volume creation/attachment failed: {exc}")

        environment = Environment(
            id=environment_id,
            project_name=project_name,
            status=EnvironmentStatus.PROVISIONING,
            created_at=created_at,
            expires_at=expires_at,
            instance_id=instance_id,
            volume_id=volume_id,
            ttl_minutes=ttl_minutes,
        )

        self._persist_environment(environment)
        return environment

    def _latest_amazon_linux_ami(self) -> str:
        """Find the latest Amazon Linux 2023 AMI owned by Amazon."""
        try:
            response = self.ec2.describe_images(
                Owners=["amazon"],
                Filters=[
                    {"Name": "name", "Values": ["al2023-ami-*"]},
                    {"Name": "virtualization-type", "Values": ["hvm"]},
                    {"Name": "architecture", "Values": ["x86_64"]},
                ],
            )
            images = sorted(response["Images"], key=lambda i: i["CreationDate"], reverse=True)
            if not images:
                raise RuntimeError("No Amazon Linux 2023 AMI found")
            return images[0]["ImageId"]
        except ClientError as exc:
            raise RuntimeError(f"Unable to resolve latest AMI: {exc}") from exc

    def _availability_zone_for_subnet(self) -> str:
        """Return the AZ for the configured subnet, or default to a region AZ."""
        if self.settings.ec2_subnet_id:
            try:
                response = self.ec2.describe_subnets(SubnetIds=[self.settings.ec2_subnet_id])
                return response["Subnets"][0]["AvailabilityZone"]
            except ClientError:
                pass
        # Fallback: use the first AZ in the region
        response = self.ec2.describe_availability_zones()
        return response["AvailabilityZones"][0]["ZoneName"]

    def _persist_environment(self, environment: Environment) -> None:
        """Store or update an environment record in DynamoDB."""
        item = environment.model_dump()
        # Convert datetimes to ISO strings for DynamoDB
        item["created_at"] = environment.created_at.isoformat()
        item["expires_at"] = environment.expires_at.isoformat()
        self.table.put_item(Item=item)

    def get_environment(self, environment_id: str) -> Environment | None:
        """Fetch a single environment by ID."""
        try:
            response = self.table.get_item(Key={"id": environment_id})
            item = response.get("Item")
            if not item:
                return None
            return self._item_to_environment(item)
        except ClientError as exc:
            raise RuntimeError(f"Failed to read environment: {exc}") from exc

    def list_environments(self, status_filter: EnvironmentStatus | None = None) -> Sequence[Environment]:
        """List all tracked environments, optionally filtered by status."""
        try:
            if status_filter:
                # Note: in production, use a GSI on status for this query
                response = self.table.scan(
                    FilterExpression=Attr("status").eq(status_filter.value)
                )
            else:
                response = self.table.scan()
            items = response.get("Items", [])
            return [self._item_to_environment(item) for item in items]
        except ClientError as exc:
            raise RuntimeError(f"Failed to list environments: {exc}") from exc

    def list_expired_environments(self) -> Sequence[Environment]:
        """Return environments whose TTL has expired and are still active."""
        now = datetime.datetime.utcnow().isoformat()
        try:
            response = self.table.scan(
                FilterExpression=Attr("expires_at").lt(now) & Attr("status").is_in(
                    ["pending", "provisioning", "ready"]
                )
            )
            items = response.get("Items", [])
            return [self._item_to_environment(item) for item in items]
        except ClientError as exc:
            raise RuntimeError(f"Failed to list expired environments: {exc}") from exc

    def _wait_for_instance_termination(self, instance_id: str, timeout: int = 120) -> None:
        """Poll EC2 until the instance reaches the terminated state."""
        start = datetime.datetime.utcnow()
        while (datetime.datetime.utcnow() - start).total_seconds() < timeout:
            try:
                response = self.ec2.describe_instances(InstanceIds=[instance_id])
                state = response["Reservations"][0]["Instances"][0]["State"]["Name"]
                if state in ("terminated", "terminating"):
                    return
            except ClientError:
                # Instance may already be gone
                return
            time.sleep(5)

    def terminate_environment(self, environment_id: str) -> Environment:
        """Tear down an environment and its associated AWS resources."""
        environment = self.get_environment(environment_id)
        if not environment:
            raise ValueError(f"Environment {environment_id} not found")

        environment.status = EnvironmentStatus.TERMINATING
        self._persist_environment(environment)

        if environment.instance_id:
            try:
                self.ec2.terminate_instances(InstanceIds=[environment.instance_id])
            except ClientError as exc:
                error_code = exc.response.get("Error", {}).get("Code", "")
                if error_code != "InvalidInstanceID.NotFound":
                    raise RuntimeError(f"Failed to terminate instance: {exc}") from exc

            self._wait_for_instance_termination(environment.instance_id)

        if environment.volume_id:
            try:
                self.ec2.delete_volume(VolumeId=environment.volume_id)
            except ClientError as exc:
                error_code = exc.response.get("Error", {}).get("Code", "")
                if error_code not in ("InvalidVolume.NotFound", "VolumeInUse"):
                    raise RuntimeError(f"Failed to delete volume: {exc}") from exc

        environment.status = EnvironmentStatus.TERMINATED
        self._persist_environment(environment)
        return environment

    def refresh_environment_state(self, environment_id: str) -> Environment:
        """Refresh the stored state of an environment from AWS.

        Updates public_ip, private_ip and status based on the live EC2 instance.
        When an instance is running and was still provisioning, mark it ready.
        """
        environment = self.get_environment(environment_id)
        if not environment or not environment.instance_id:
            return environment  # type: ignore[return-value]

        try:
            response = self.ec2.describe_instances(InstanceIds=[environment.instance_id])
            instance = response["Reservations"][0]["Instances"][0]
            environment.public_ip = instance.get("PublicIpAddress")
            environment.private_ip = instance.get("PrivateIpAddress")
            state = instance["State"]["Name"]
            if state == "running" and environment.status == EnvironmentStatus.PROVISIONING:
                environment.status = EnvironmentStatus.READY
            elif state == "terminated":
                environment.status = EnvironmentStatus.TERMINATED
        except ClientError:
            # Instance may already be gone
            pass

        self._persist_environment(environment)
        return environment

    @staticmethod
    def _item_to_environment(item: dict) -> Environment:
        """Convert a DynamoDB item into an Environment model."""
        return Environment(
            id=item["id"],
            project_name=item["project_name"],
            status=EnvironmentStatus(item["status"]),
            created_at=datetime.datetime.fromisoformat(item["created_at"]),
            expires_at=datetime.datetime.fromisoformat(item["expires_at"]),
            instance_id=item.get("instance_id"),
            public_ip=item.get("public_ip"),
            private_ip=item.get("private_ip"),
            volume_id=item.get("volume_id"),
            ttl_minutes=int(item["ttl_minutes"]),
            message=item.get("message"),
        )
