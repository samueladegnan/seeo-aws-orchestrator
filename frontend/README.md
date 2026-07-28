# SEEO Dashboard (React)

A modern React dashboard for the SEEO ephemeral environment platform.

## Quick Start

```bash
cd frontend
npm install
npm run dev
```

The dev server runs on `http://localhost:5173` and proxies API requests to the Rails backend on `http://localhost:3000`.

> **Note:** If the page looks unstyled, make sure `tailwind.config.js` and `postcss.config.js` exist and that you ran `npm install` after any dependency changes.

## Environment Variables

Create a `.env` file in `frontend/` if you want to override defaults:

| Variable | Description | Default |
|---|---|---|
| `VITE_SEEO_API_KEY` | API key used for local development | `dev-change-me-in-production` |

The dashboard uses `X-API-Key` authentication against the local Rails backend. Make sure this key matches the `SEEO_API_KEY` value in `backend/.env`.

## Vite proxy

`vite.config.js` proxies the following paths to the Rails API:

- `/environments` → `http://localhost:3000`
- `/cable` → `ws://localhost:3000` (ActionCable WebSocket)

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
