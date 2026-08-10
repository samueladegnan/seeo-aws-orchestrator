#!/usr/bin/env bash
set -euo pipefail

# Provider-neutral host bootstrap reference for a SEEO environment.
# The cloud adapter supplies the provider-specific image and identity mechanism.

exec > >(tee /var/log/seeo-bootstrap.log) 2>&1

echo "=== SEEO environment bootstrap starting ==="
mkdir -p /etc/seeo
cat > /etc/seeo/environment.json <<JSON
{
  "environment_id": "${SEEO_ENVIRONMENT_ID:-unknown}",
  "provider": "${SEEO_PROVIDER:-unknown}",
  "region": "${SEEO_REGION:-unknown}"
}
JSON
chmod 600 /etc/seeo/environment.json
echo "=== SEEO environment bootstrap complete ==="
