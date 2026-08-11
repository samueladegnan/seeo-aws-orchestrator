# SEEO Demo Deployment Guide

This guide deploys the SEEO multi-cloud mock demo on **Render** for the backend and **Vercel** for the frontend. The public deployment intentionally does not provision real cloud workloads, and no cloud credentials belong in this repository or in the browser bundle.

## What you need

- GitHub repo: `samueladegnan/seeo-aws-orchestrator`
- Runtime model: provider-neutral lifecycle contract for AWS, Azure, Google Cloud, and OCI
- No provider credentials in Git, Vercel, Render source files, or `VITE_*` variables
- Render account
- Vercel account

## Backend (Render)

1. In Render, click **New → Blueprint**.
2. Connect your GitHub repo and select `seeo-aws-orchestrator`.
3. Render will read `render.yaml` and create a Web Service.
   - If you already have a service named `seeo-backend`, either delete it first or rename the `name` field in `render.yaml`.
4. After creation, open the service **Environment** tab and set:
   - `CORS_ALLOW_ORIGINS` to your Vercel URL, not `*` for a shared deployment.
   - `ACTION_CABLE_ALLOWED_ORIGINS` to the same Vercel URL.
   - `SEEO_API_KEY` to a secure random string. Do not use the local template value. This is a public demo credential once passed to Vercel, so keep the backend in multi-cloud mock mode.
   - `SEEO_JWT_SECRET` to a separate secure random string.
   - `SECRET_KEY_BASE` to the generated value from Render.
5. Save and wait for the service to deploy.
6. Copy the generated `SEEO_API_KEY` value from the Render environment tab and paste it into Vercel as `VITE_SEEO_API_KEY` (see below). Vite exposes `VITE_*` values to the browser, so this key must not authorize real multi-cloud lifecycle actions.
7. Copy the service URL (e.g. `https://seeo-backend-xxx.onrender.com`).

## Frontend (Vercel)

1. In Vercel, click **Add New Project** and import `seeo-aws-orchestrator`.
2. Set the **Root Directory** to `frontend`.
3. In **Environment Variables**, add:
   - `VITE_API_BASE=https://seeo-backend-xxx.onrender.com` (your Render URL)
   - `VITE_SEEO_API_KEY` (copy the exact value of `SEEO_API_KEY` from Render)
4. Make sure **Root Directory** is set to `frontend` and **Framework Preset** is `Vite`.
5. Deploy.
6. Copy the Vercel URL.

## Update the docs link

1. Open `docs/demo.md`.
2. Replace `https://seeo-dashboard.vercel.app` with your actual Vercel URL.
3. Commit and push. GitHub Pages will update automatically.

## Local development

```bash
cd backend
cp .env.example .env
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend

cd frontend
cp .env.example .env
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).

## Notes

- The demo backend runs in **multi-cloud mock mode** (`SEEO_MOCK_MODE=true`), so no provider credentials are required and no real resources are created. The application rejects API-key lifecycle access when real mode is enabled. Use JWT tenant authentication and configure the selected provider adapter, Terraform network outputs, and workload identity before sending real traffic.
- Render free tier spins down after inactivity. The frontend shows a "Waking up the server" modal while it starts.
- SQLite is ephemeral in the current Render demo setup. Demo data resets when the container sleeps.
- The Terraform project includes independent AWS, Azure, Google Cloud, and OCI foundation roots. The deployment uses the shared provider-neutral control plane and mock adapters. Real provider operations require a separate adapter runner image with the selected cloud CLI, short-lived credentials or workload identity, network outputs, image configuration, and integration tests. The hosted Render image does not install those CLIs.
