---
title: API Documentation | SEEO Multi-cloud Environment Lifecycle
description: Reference for the SEEO Rails API, authentication, tenant authorization, provider selection, lifecycle state, policy, and ActionCable updates.
keywords:
  - Rails API documentation
  - multi-cloud lifecycle API
  - tenant authorization
  - ActionCable WebSocket API
  - cloud environment API
last_modified_at: 2026-08-13
og_type: article
layout: default
permalink: /api/
---

# SEEO API Documentation

The Rails backend exposes one lifecycle API for AWS, Azure, Google Cloud, OCI, and the safe mock mode used by the public demo. The examples below show the normalized request and response shapes.

## Authentication

The API accepts a JWT tenant token or an API key in mock mode. The public demo uses the API key to obtain a signed browser session token. Real provider operations require JWT tenant authentication and configured provider credentials.

```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/environments
```

Mock clients first request `GET /session-token` with `X-API-Key`, then send `X-Session-Token` on later requests. The server owns the session identity.

## Authorization

| Role | Permissions |
|---|---|
| `viewer` | List and show environments |
| `operator` | Create and terminate environments |
| `admin` | Full access |

## Create an environment

```text
POST /environments
```

```json
{
  "project_name": "preview-api",
  "provider": "gcp",
  "region": "us-central1",
  "compute_tier": "small",
  "storage_tier": "balanced",
  "volume_size": 10,
  "ttl_minutes": 60,
  "tags": { "purpose": "preview" },
  "notes": "Integration test environment"
}
```

Required fields are `project_name` and `ttl_minutes`. The `provider` defaults to `SEEO_DEFAULT_PROVIDER`. The `compute_tier` defaults to `small`. The `storage_tier` defaults to `balanced`. The provider catalog supplies the default region.

Supported providers:

- `aws`
- `azure`
- `gcp`
- `oci`

The selected region must belong to the selected provider. Policy checks the provider allow-list, compute/storage tiers, TTL, volume size, and capacity before any provider call. Invalid requests fail early rather than creating infrastructure that must be rolled back. OPA/Rego is supported with a Ruby fallback when OPA is unavailable. Provider catalogs and policy definitions must remain synchronized.

Clients should send `X-Idempotency-Key` on create requests. Repeating an active request with the same key and provider returns the existing environment.

## Response

```json
{
  "id": "preview-api-20260809000000-abc123",
  "project_name": "preview-api",
  "provider": "gcp",
  "provider_label": "Google Cloud",
  "provider_resource_id": "gcp-vm-a1b2c3d4",
  "provider_resource_type": "virtual_machine",
  "status": "provisioning",
  "region": "us-central1",
  "compute_tier": "small",
  "instance_type": "e2-micro",
  "storage_tier": "balanced",
  "volume_type": "pd-balanced",
  "volume_size": 10,
  "ttl_minutes": 60,
  "public_ip": null,
  "created_at": "2026-08-09T00:00:00Z",
  "expires_at": "2026-08-09T01:00:00Z"
}
```

## List environments

```text
GET /environments
GET /environments?status=ready
```

The response contains normalized environments and provider-specific cost estimates:

```json
{
  "environments": [],
  "cost": {
    "total": 0.0123,
    "currency": "USD",
    "environments_count": 1
  }
}
```

## Refresh an environment

```text
GET /environments/{environment_id}
POST /environments/{environment_id}/refresh
```

The selected adapter refreshes the provider resource and updates the normalized state.

## Terminate an environment

```text
DELETE /environments/{environment_id}
```

The selected adapter terminates the VM and attached storage using provider-specific cleanup, then marks the control-plane record as terminated. The action is recorded in the audit log.

## Health check

```text
GET /health
```

The response identifies the configured multi-cloud catalog without exposing credentials:

```json
{
  "status": "ok",
  "version": "0.3.0",
  "mock_mode": true,
  "default_provider": "aws",
  "providers": [
    { "id": "aws", "label": "Amazon Web Services" },
    { "id": "azure", "label": "Microsoft Azure" },
    { "id": "gcp", "label": "Google Cloud" },
    { "id": "oci", "label": "Oracle Cloud Infrastructure" }
  ]
}
```

## Real-time updates

The Rails server mounts a WebSocket endpoint at `/cable`. Request `GET /cable-token` with normal authentication and the verified mock session token when using mock mode. ActionCable rejects arbitrary stream keys and derives the authorized team or session stream on the server.
