---
title: Demo | SEEO Environment Dashboard
description: Try the SEEO multi-cloud environment dashboard in safe mock mode, or run the Rails and React demo locally without cloud credentials.
keywords:
  - multi-cloud dashboard demo
  - ephemeral environments demo
  - Rails React demo
  - cloud orchestration demo
last_modified_at: 2026-08-13
og_type: website
layout: demo
permalink: /demo/
---

<h1>Dashboard demo</h1>

<div class="demo-cta">
  <div>
    <p class="demo-cta__eyebrow">Hosted mock demo</p>
    <p class="demo-cta__copy">Choose a provider, create a short-lived environment, inspect its normalized state, and terminate it. The hosted dashboard uses mock adapters and cannot create cloud resources.</p>
  </div>
  <a class="btn" href="https://seeo-dashboard.vercel.app/" target="_blank" rel="noopener noreferrer">Open the dashboard</a>
</div>

<p><strong>Mock boundary:</strong> provider IDs are synthetic, IP addresses are illustrative, and every lifecycle operation stays in process memory. The demo does not call a cloud API or create billable resources.</p>

> **Wake-up time:** the free Render backend may need **30 to 50 seconds** after a quiet period. The dashboard shows a wake-up state while it retries the health check.

> **If it looks stuck:** ad blockers and privacy extensions can block `.onrender.com` requests or WebSocket connections. Try a private window or temporarily disable the extension.

<h2>What to look for</h2>

<ol>
  <li>Choose AWS, Azure, Google Cloud, or OCI and select a provider-specific region.</li>
  <li>Set a project name and create a short-lived environment.</li>
  <li>Open <strong>Details</strong> to inspect normalized fields and provider resource metadata.</li>
  <li>Open <strong>Show advanced</strong> to inspect TTL, storage, tags, SSH key, and note handling.</li>
  <li>Terminate the environment and watch the browser-scoped list update.</li>
</ol>

<h2>Run the mock demo locally</h2>

<p>The local path does not need provider credentials or cloud access. It is useful when you want fast feedback or want to read the API and frontend while using the same lifecycle. It has the same mock boundary as the hosted demo and does not persist records across process restarts.</p>

<pre><code>cd backend
cp .env.example .env
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend</code></pre>

<p>In a second terminal:</p>

<pre><code>cd frontend
cp .env.example .env
npm ci
npm run dev</code></pre>

<p>Open <a href="http://localhost:5173">http://localhost:5173</a>. The API listens on <a href="http://localhost:3000/health">http://localhost:3000/health</a>.</p>

<h2>Run the checks</h2>

<pre><code>cd frontend
npm ci
npm run lint
npm run build</code></pre>

<p>Backend, Terraform, and security workflow commands are listed in the <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/CONTRIBUTING.md">contribution guide</a>.</p>

<h2>Source and architecture</h2>

<p>Read the <a href="{{ '/architecture/' | relative_url }}">architecture notes</a>, inspect the <a href="https://github.com/samueladegnan/seeo-aws-orchestrator">source repository</a>, or return to the <a href="{{ '/' | relative_url }}">project overview</a>.</p>
