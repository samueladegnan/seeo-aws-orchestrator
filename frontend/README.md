# SEEO Dashboard (React)

A React dashboard for requesting, monitoring, and expiring short-lived environments through the SEEO API.

## Quick Start

```bash
cd frontend
copy .env.example .env
npm install
npm run dev
```

The dev server runs on `http://localhost:5173` and talks directly to the Rails backend on `http://localhost:3000` via the `VITE_API_BASE` environment variable. The dashboard defaults to mock AWS mode when used with the included local backend, so exploring the lifecycle does not create real cloud resources.

> **Note:** If the page looks unstyled, make sure `tailwind.config.js` and `postcss.config.js` exist and that you ran `npm install` after any dependency changes.

## Environment Variables

Copy `.env.example` to `.env` and adjust as needed:

| Variable | Description | Default |
|---|---|---|
| `VITE_API_BASE` | Backend base URL | `http://localhost:3000` |
| `VITE_SEEO_API_KEY` | API key used for local development | `local-development-only` |

The dashboard uses the API key for the local/mock demo. Make sure it matches `SEEO_API_KEY` in `backend/.env`. Because Vite embeds `VITE_*` values in the browser bundle, treat this as a public demo credential. Real AWS deployments should use JWT tenant authentication rather than exposing an API key in the frontend.

## Build

```bash
npm run lint
npm run build
```

I built and reviewed this dashboard with AI assistance. AI tools helped with exploration, implementation, documentation, and testing. I remain responsible for the architecture and final code.

## Windows quick start

In Command Prompt:

```cmd
cd C:\Users\sammd\Documents\GitProjects\seeo-aws-orchestrator\frontend
npm install
npm run dev
```
