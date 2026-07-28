---
title: API
layout: default
permalink: /api/
---

# SEEO API Documentation

The SEEO backend exposes a REST API built with Ruby on Rails.

## Authentication

The API accepts either a JWT tenant token or a legacy API key.

### JWT tenant token

```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/environments
```

JWT tokens are issued by `AuthorizationService.issue_token(user)` and expire after 24 hours. They are associated with a user, team, and role.

### Legacy API key

```bash
curl -H "X-API-Key: your-api-key" http://localhost:3000/environments
```

API-key requests authenticate as a transient admin service account with no team.

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
  "version": "0.1.0"
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
- `ttl_minutes` is required.
- `instance_type` is optional and defaults to `SEEO_EC2_INSTANCE_TYPE` (`t3.micro`).

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

Terminates the EC2 instance, detaches/deletes the EBS volume, marks the environment as terminated, and writes an DynamoDB audit record.

## Real-time updates

The Rails server mounts an WebSocket endpoint at `/cable`. The React dashboard can subscribe to `EnvironmentChannel` to receive environment state changes.
