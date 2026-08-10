#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper for older AWS image workflows.
# New environments use the provider-neutral bootstrap contract.

SEEO_PROVIDER="aws" SEEO_REGION="${AWS_REGION:-us-east-1}" \
  SEEO_ENVIRONMENT_ID="${SEEO_ENVIRONMENT_ID:-unknown}" \
  "$(dirname "$0")/bootstrap_environment.sh"
