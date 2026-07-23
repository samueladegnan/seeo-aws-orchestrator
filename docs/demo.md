---
title: Demo
layout: default
permalink: /demo/
---

# SEEO Demo

## Request an environment

```bash
curl -X POST "http://localhost:8000/environments" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{"project_name": "my-api", "ttl_minutes": 60}'
```

## List active environments

```bash
curl -H "X-API-Key: your-api-key" \
  "http://localhost:8000/environments"
```

## Tear down an environment

```bash
curl -X DELETE "http://localhost:8000/environments/{environment_id}" \
  -H "X-API-Key: your-api-key"
```

## Dashboard

Open `http://localhost:8000` after starting the backend to use the web dashboard.

## Running locally

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
