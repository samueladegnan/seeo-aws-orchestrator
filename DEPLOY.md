# SEEO Demo Deployment Guide

This guide deploys the SEEO demo on **Render** (backend) and **Vercel** (frontend).

## What you need

- GitHub repo: `samueladegnan/seeo-aws-orchestrator`
- Render account
- Vercel account

## Backend (Render)

1. In Render, click **New → Blueprint**.
2. Connect your GitHub repo and select `seeo-aws-orchestrator`.
3. Render will read `render.yaml` and create a Web Service.
   - If you already have a service named `seeo-backend`, either delete it first or rename the `name` field in `render.yaml`.
4. After creation, open the service **Environment** tab and set:
   - `CORS_ALLOW_ORIGINS` to your Vercel URL (e.g. `https://seeo-dashboard.vercel.app`) or `*` for testing.
   - `SEEO_API_KEY` to a secure random string (copy this value for Vercel).
5. Save and wait for the service to deploy.
6. Copy the generated `SEEO_API_KEY` value from the Render environment tab and paste it into Vercel as `VITE_SEEO_API_KEY` (see below).
6. Copy the service URL (e.g. `https://seeo-backend-xxx.onrender.com`).

## Frontend (Vercel)

1. In Vercel, click **Add New Project** and import `seeo-aws-orchestrator`.
2. Set the **Root Directory** to `frontend`.
3. In **Environment Variables**, add:
   - `VITE_API_BASE=https://seeo-backend-xxx.onrender.com` (your Render URL)
   - `VITE_SEEO_API_KEY` (copy the exact value of `SEEO_API_KEY` from Render)
4. Make sure **Root Directory** is set to `frontend` and **Framework Preset** is `Vite`.
4. Deploy.
5. Copy the Vercel URL.

## Update the docs link

1. Open `docs/demo.md`.
2. Replace `https://seeo-dashboard.vercel.app` with your actual Vercel URL.
3. Commit and push; GitHub Pages will update automatically.

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

- The backend runs in **Mock AWS Mode** (`SEEO_MOCK_AWS=true`), so no AWS credentials are required.
- Render free tier spins down after inactivity; the frontend shows a "Waking up the server" modal while it starts.
- SQLite is ephemeral; demo data resets when the container sleeps.
