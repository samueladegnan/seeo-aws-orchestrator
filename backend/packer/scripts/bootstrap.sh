#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/seeo-packer-bootstrap.log) 2>&1

echo "=== SEEO AMI Bootstrap Starting ==="

# Update the system
dnf update -y

# Install required tooling
dnf install -y aws-cli amazon-cloudwatch-agent

# Hardening examples (expand as needed)
# - Enable automatic security updates
# - Configure CloudWatch agent
# - Restrict file permissions
# - Disable unnecessary services

echo "=== SEEO AMI Bootstrap Complete ==="
