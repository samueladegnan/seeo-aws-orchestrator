# SEEO Dashboard (React)

A modern React dashboard for the SEEO ephemeral environment platform.

## Quick Start

```bash
cd frontend
copy .env.example .env
npm install
npm run dev
```

The dev server runs on `http://localhost:5173` and talks directly to the Rails backend on `http://localhost:3000` via the `VITE_API_BASE` environment variable.


> **Note:** If the page looks unstyled, make sure `tailwind.config.js` and `postcss.config.js` exist and that you ran `npm install` after any dependency changes.

## Environment Variables

Copy `.env.example` to `.env` and adjust as needed:

| Variable | Description | Default |
|---|---|---|
| `VITE_API_BASE` | Backend base URL | `http://localhost:3000` |
| `VITE_SEEO_API_KEY` | API key used for local development | `dev-change-me-in-production` |

The dashboard uses `X-API-Key` authentication against the local Rails backend. Make sure this key matches the `SEEO_API_KEY` value in `backend/.env`.

## Build

```bash
npm run build
```

## Windows quick start

In Command Prompt:

```cmd
cd C:\Users\sammd\Documents\GitProjects\seeo-aws-orchestrator\frontend
npm install
npm run dev
```
