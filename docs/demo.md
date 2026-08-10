---
title: Demo | SEEO Environment Dashboard
description: Try the SEEO environment dashboard live, or run the mock demo locally with the Rails API and React frontend.
layout: demo
permalink: /demo/
---

## SEEO Dashboard

SEEO is a React and Vite dashboard for requesting, monitoring, and terminating short-lived environments. This page gives you two ways to try it.

<div class="demo-launch-card">
  <div>
    <span class="demo-eyebrow">Hosted experience</span>
    <h2>Launch the live demo</h2>
    <p>The hosted dashboard uses the multi-cloud mock provider. It lets you select AWS, Azure, Google Cloud, or OCI, creates no real cloud resources, and gives each browser its own signed sandbox session.
</p>
  </div>
  <a class="btn" href="https://seeo-dashboard.vercel.app/" target="_blank" rel="noopener noreferrer">Launch Live Demo</a>
</div>

> **Wake-up time:** the free Render backend may need **30–50 seconds** after a quiet period. The dashboard displays a wake-up state while it retries the health check.

> **If it looks stuck:** ad blockers and privacy extensions sometimes block `.onrender.com` requests or WebSocket connections. Try a private window or temporarily disable the extension.

## Run the mock demo locally

The local path is useful when you want fast feedback or want to read the code while you use it. The backend defaults to multi-cloud mock mode, so no provider credentials or billable resources are required. That safety boundary is deliberate: visitors can exercise the lifecycle and UX without billing risk or secret exposure, while the real provider path remains credential-gated and is not disguised as a live demo.

<p class="local-demo-cta">
  <a class="btn" href="http://localhost:5173" target="_blank" rel="noopener noreferrer">Open Local Demo</a>
</p>

### 1. Start the backend

```bash
cd backend
cp .env.example .env
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

The Rails API will be available at [http://localhost:3000](http://localhost:3000). Multi-cloud mock mode is enabled by default.

### 2. Start the frontend

In a second terminal:

```bash
cd frontend
cp .env.example .env
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) to use the local dashboard.

## What to try

- Create an environment with a project name, provider, region, and short TTL.
- Open **Show advanced** to inspect volume, tag, SSH key, and note handling.
- Watch the mock environment move from provisioning to ready.
- Open the details panel, then terminate the environment.
- Open two browser windows to see that session-scoped updates stay separate.
