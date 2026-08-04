---
title: API Documentation | SEEO Environment Lifecycle
description: Reference the SEEO Rails REST API, JWT and API-key authentication, RBAC, environment lifecycle endpoints, and ActionCable WebSockets.
layout: default
permalink: /api/
---

# SEEO API Documentation

The SEEO backend exposes a REST API built with Ruby on Rails.

## Authentication

The API accepts a JWT tenant token or an API key in local/mock mode. The public mock demo uses the API key to obtain a signed browser session token. Real AWS lifecycle actions require JWT tenant authentication.

### JWT tenant token

```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/environments
```

JWT tokens are issued by `AuthorizationService.issue_token(user)` and expire after 24 hours. They are associated with a user, team, and role.

### API key for service accounts

```bash
curl -H "X-API-Key: your-api-key" http://localhost:3000/session-token
```

API-key requests authenticate as a transient service account in local/mock mode. The public frontend uses this route to obtain a signed browser session token. Environment records created without a team are scoped to that verified session, and the key alone does not grant access to another session. API-key lifecycle access is rejected when real AWS mode is enabled.

### Mock demo session token

The public mock demo first requests `GET /session-token` with the API key. The backend returns a signed session token and opaque session identifier. Subsequent mock requests send `X-Session-Token: <token>`. A client-chosen `X-Session-ID` is not accepted as identity.

### Ownership and idempotency

Tenant-backed records persist `team_id` and `owner_user_id`. Team requests are filtered by `team_id`. Mock/demo records are filtered by their session scope. Clients should send `X-Idempotency-Key` on create requests. Repeating a request with the same key returns the existing active environment instead of provisioning another one.

## Authorization

Endpoints require one of the following roles:

| Role | Permissions |
|---|---|
| `viewer` | List and show environments |
| `operator` | Create and destroy environments (also includes viewer) |
| `admin` | Full access (also includes operator and viewer) |

## Endpoints

### Health check

```text
GET /health
```

Response:

```json
{
  "status": "ok",
  "version": "0.1.0",
  "mock_mode": true
}
```

### Create environment

```text
POST /environments
```

Request body:

```json
{
  "project_name": "my-api",
  "ttl_minutes": 60,
  "instance_type": "t3.micro"
}
```

- `project_name` is required.
- `ttl_minutes` is required and must not exceed the policy maximum (default 24 hours).
- `instance_type` is optional and defaults to the configured default (e.g., `t3.micro`).
- Optional fields: `region`, `volume_size`, `volume_type`, `ssh_key_name`, `tags`, `notes`.

Response: `201 Created`

```json
{
  "id": "my-api-abc123",
  "project_name": "my-api",
  "status": "provisioning",
  "ttl_minutes": 60,
  "instance_type": "t3.micro",
  "instance_id": "i-0123456789abcdef0",
  "public_ip": null,
  "created_at": "2026-07-27T00:00:00Z",
  "expires_at": "2026-07-27T01:00:00Z"
}
```

Policy checks run before provisioning. If a rule is violated, the response is `422 Unprocessable Content`.

### List environments

```text
GET /environments
```

Optional query parameter: `status` (e.g., `ready`, `provisioning`, `terminated`).

Response:

```json
{
  "environments": [...],
  "cost": {
    "total": 0.42,
    "environments_count": 3
  }
}
```

### Get environment

```text
GET /environments/{environment_id}
```

Refreshes state from AWS and returns the full environment record.

### Refresh environment state

```text
POST /environments/{environment_id}/refresh
```

Polls AWS and updates the stored environment state.

### Delete environment

```text
DELETE /environments/{environment_id}
```

Terminates the EC2 instance, detaches/deletes the EBS volume, marks the environment as terminated, and writes an audit record.

## Real-time updates

The Rails server mounts a WebSocket endpoint at `/cable`. Request `GET /cable-token` with normal API authentication and, in mock mode, the verified `X-Session-Token`. The response is a short-lived signed token. Pass its `token` value to ActionCable as the `token` query parameter and subscribe with `stream_key`. The server rejects arbitrary stream keys and derives the authorized stream from the signed team or session context.
