---
title: Demo
layout: demo
permalink: /demo/
---

## SEEO Dashboard

The SEEO Dashboard is a React + Vite application that lets teams request, monitor, and terminate secure, short-lived AWS environments.

### Live Demo

The live demo runs the full stack in **Mock AWS Mode**, so no AWS credentials are required. Because it is hosted on free tiers, the backend may take **30–50 seconds to wake up** after a period of inactivity. The dashboard will show a loading message while the server starts.

> **Note:** Some ad blockers and privacy extensions block requests to `.onrender.com` domains, which can prevent the dashboard from waking the backend or connecting to the real-time WebSocket updates. If the dashboard seems stuck or shows **Live updates: disconnected**, try disabling your ad blocker or opening the demo in an incognito/private window.

> **Is it shared?** No — the deployed demo gives each visitor their own sandbox. Your browser generates a session id that is stored locally and sent with every request, so the environments you create are only visible in your browser. If you open the demo in a different browser or clear local storage, you'll get a fresh, empty session.

### Run it locally

If the live backend is down or you want to explore the source, you can run the demo locally. Make sure the backend is running on [http://localhost:3000](http://localhost:3000), then:

<p class="local-demo-cta">
  <a class="btn" href="http://localhost:5173" target="_blank" rel="noopener noreferrer">Open Local Demo</a>
</p>

#### 1. Start the backend

```bash
cd backend
cp .env.example .env
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

The backend runs in **Mock AWS Mode** by default, so no AWS credentials are required.

#### 2. Start the frontend

In a second terminal:

```bash
cd frontend
cp .env.example .env
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) to use the dashboard.

## What to try

- Create an environment for a project and TTL.
- Watch the estimated cost update in real time.
- Terminate an environment and see it reflected in the table.
- Open two browser windows to see ActionCable WebSocket updates.

## Source code

The dashboard source is in the [`frontend/`](https://github.com/samueladegnan/seeo-aws-orchestrator/tree/main/frontend) directory of the repository.
