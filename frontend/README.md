# SEEO Dashboard (React)

This React dashboard is the browser frontend for SEEO, a multi-cloud control-plane prototype for short-lived environments across AWS, Azure, Google Cloud, and OCI. It requests, monitors, and terminates environments through the Rails API.

## Quick start

```bash
cd frontend
cp .env.example .env
npm ci
npm run dev
```

The dev server runs on `http://localhost:5173` and talks to the Rails backend on `http://localhost:3000` via `VITE_API_BASE`. The included backend defaults to multi-cloud mock mode, so selecting any supported provider does not create real cloud resources.

## Environment variables

| Variable | Description | Default |
|---|---|---|
| `VITE_API_BASE` | Backend base URL | `http://localhost:3000` |
| `VITE_SEEO_API_KEY` | Public mock-demo API key | `local-development-only` |

Because Vite embeds `VITE_*` values in the browser bundle, the API key is public and only appropriate for mock mode. The frontend stores the short-lived demo session in `sessionStorage`, while real provider lifecycle access uses JWT tenant authentication on the backend. Never place cloud credentials in frontend variables.

## Build

```bash
npm run lint
npm run build
```
