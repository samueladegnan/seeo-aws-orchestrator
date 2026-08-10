#!/usr/bin/env bash
set -euo pipefail
exec > >(tee /var/log/seeo-packer-bootstrap.log) 2>&1

echo "=== SEEO provider-neutral image bootstrap starting ==="

# Install only baseline tooling here. Provider CLIs and workload identity are
# supplied by the selected adapter image or deployment environment.
if command -v dnf >/dev/null 2>&1; then
  dnf update -y
  dnf install -y curl jq
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y curl jq
fi

echo "=== SEEO provider-neutral image bootstrap complete ==="
