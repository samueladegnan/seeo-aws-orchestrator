---
title: API
layout: default
permalink: /api/
---

# SEEO API Documentation

The SEEO backend exposes a REST API built with Ruby on Rails.

## Authentication

All protected endpoints require an `X-API-Key` header.

```bash
curl -H "X-API-Key: your-api-key" http://localhost:3000/environments
```

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

Response: `201 Created`

### List environments

```text
GET /environments
```

Optional query parameter: `status_filter` (e.g., `ready`, `provisioning`).

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

Terminates the EC2 instance, detaches/deletes the EBS volume, and marks the environment as terminated.

## Dashboard

A web dashboard can be served from the Rails backend or run as a static GitHub Pages demo.
