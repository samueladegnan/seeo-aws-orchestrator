#!/bin/bash
# Example user-data script for a SEEO-provisioned EC2 instance.
# The production script is generated dynamically by the backend in aws_service.py.
# This file can be used as a reference for building hardened custom AMIs.

set -euo pipefail
exec > >(tee /var/log/seeo-bootstrap.log) 2>&1

echo "=== SEEO Bootstrap Starting ==="

# Update and install required tooling (Amazon Linux 2023 example)
dnf update -y
dnf install -y amazon-cloudwatch-agent aws-cli

# Hardening example: enforce least-privilege, enable automatic security updates, etc.
# In a real custom AMI, these steps are baked into the AMI rather than run at launch.

# Fetch runtime credentials from Secrets Manager using the attached IAM role.
# SECRET=$(aws secretsmanager get-secret-value \\
#   --region "${AWS_REGION:-us-east-1}" \\
#   --secret-id "seeo/runtime/credentials" \\
#   --query SecretString --output text)

# The application on this host can read /etc/seeo-config.json at runtime.

echo "=== SEEO Bootstrap Complete ==="
