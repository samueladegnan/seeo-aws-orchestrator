# SEEO — Secure Ephemeral Environment Orchestrator

SEEO is a multi-tenant internal developer platform for provisioning secure, short-lived AWS environments on demand. I built it to show what it takes to go from a simple provisioning API to something a real engineering team could adopt: secure by default, observable, and cost-conscious.

> **Why I built it:** I kept seeing side projects and intern sandboxes left running for weeks, racking up bills and exposing unused services. SEEO is my take on fixing that with role-based access, policy checks, and automatic cleanup.

> **Project site:** [samueladegnan.github.io/seeo-aws-orchestrator](https://samueladegnan.github.io/seeo-aws-orchestrator/)

---

## Features

- **Multi-tenancy & RBAC**: Teams, users, and projects with admin, operator, and viewer roles.
- **Policy-as-code**: OPA/Rego rules enforce TTLs, allowed instance types, and team limits before provisioning.
- **Audit logging**: Every create/destroy event is written to DynamoDB with actor, team, and timestamp.
- **Cost tracking**: Estimated spend per environment and per team based on instance type and TTL.
- **Real-time dashboard**: ActionCable broadcasts environment state changes to the React dashboard.
- **Structured logging**: JSON logs ready for CloudWatch and SIEM pipelines.
- **React frontend**: A modern Vite 8 + React 18 dashboard alongside the Rails API.
- **Security-first CI**: RuboCop, RSpec, Terraform `fmt`/`validate`, Checkov scans, and AI Guardrail triage in GitHub Actions.

---

## Architecture

```
─────────────────────────────────────────────────────────────────────────┐
│                        React Dashboard (Vite)                           │
│                     Lists envs, shows cost, real-time updates           │
└─────────────────────────────┬───────────────────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────────────┐
│                        Rails 7 API                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐        │
│  │ Environments │  │   Health     │  │      TTL Service         │        │
│  │  Controller  │  │  Controller  │  │    (Solid Queue job)     │        │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘        │
│  ┌──────▼─────────────────┼───────────────────────┼──────┐               │
│  │  AuthService           │                     │      │               │
│  │  AuditLogService       │                     │      │               │
│  │  PolicyService         │                     │      │               │
│  │  CostTrackingService   │                     │      │               │
│  └─────────────────────────┘                     │      │               │
└───────────────────────────┼───────────────────────┼──────┼──────────────┘
                            │                       │      │
                                                   ▼      ▼
┌─────────────┐    ┌─────────────────    ┌─────────────────┐
│  EC2 + EBS  │    │    DynamoDB     │    │ Secrets Manager │
│             │    │ Environments    │    │                 │
│             │    │ Audit Logs      │    │                 │
│             │    │                 │    │                 │
└─────────────┘    └─────────────────┘    └─────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| API / Business Logic | Ruby 3.3, Ruby on Rails 7, Active Model |
| Frontend | React 18, Vite 8, Tailwind CSS, ESLint 9 |
| Real-time | ActionCable / WebSockets |
| Cloud Orchestration | aws-sdk-ruby (EC2, EBS, DynamoDB, Secrets Manager, Cost Explorer) |
| State Store | DynamoDB |
| Auth | JWT tenant tokens + legacy API key |
| Policy Engine | OPA/Rego (with Ruby fallback) |
| Infrastructure | Terraform, AWS |
| CI/CD | GitHub Actions, RuboCop, RSpec, Checkov |

---

## Quick Start

The fastest way to run SEEO is with Docker. You can also run the backend and frontend directly if you have Ruby 3.3+ and Node.js installed.

### Option A: Docker (recommended)

From the project root:

```bash
# macOS / Linux
cp backend/.env.example backend/.env
# Edit backend/.env with your AWS credentials and secrets
cd backend
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

On Windows Command Prompt:

```cmd
cd C:\Users\sammd\Documents\GitProjects\seeo-aws-orchestrator\backend
copy .env.example .env
:: Edit .env with your AWS credentials and secrets
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

> **Note:** If you change `SEEO_API_KEY` in `backend/.env`, make sure the frontend uses the same key via `VITE_SEEO_API_KEY` (set in `frontend/.env` or the default in `frontend/src/App.jsx`).
>
> By default, the backend runs in **Mock AWS Mode** (`SEEO_MOCK_AWS=true`) so it works without real AWS credentials. Set `SEEO_MOCK_AWS=false` to call real AWS APIs. In mock mode, audit logs are written to the Rails log instead of DynamoDB.

### Option B: Direct local install

Backend:

```bash
cd backend
cp .env.example .env
# Edit .env
bundle install
bin/rails db:create db:migrate
bin/rails server
```

Frontend:

```bash
cd frontend
cp .env.example .env  # optional: copy local environment template
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) for the dashboard.

## Live demo

A fully deployed demo is available at [https://seeo-dashboard.vercel.app/](https://seeo-dashboard.vercel.app/). It runs the backend in **Mock AWS Mode**, so no AWS credentials are required. Each visitor gets their own isolated session via a browser-generated session id stored in local storage.

> **Note:** Because the backend is hosted on Render's free tier, it may take **30–50 seconds** to wake up after a period of inactivity. The dashboard will show a loading message while the server starts. Some ad blockers may block requests to `.onrender.com`; if the dashboard seems stuck, try disabling your ad blocker or use an incognito/private window.

## Docs / portfolio site (optional)

The Jekyll site in `docs/` is the project portfolio. Run it via Docker (Ruby/Bundler not required):

```bash
cd docs
docker compose up --build
```

Open [http://localhost:4000](http://localhost:4000).

---

## Testing

Backend tests and linting run inside the Docker image or locally:

```bash
cd backend
bundle exec rubocop
bundle exec rspec
```

With Docker:

```bash
docker run --rm -e RAILS_ENV=test -e SEEO_JWT_SECRET=test-secret seeo-backend sh -c "bundle exec rails db:create db:migrate && bundle exec rspec"
```

---

## Roadmap

- [ ] Email/Slack notifications on lifecycle events.
- [ ] Daily/weekly cost reports by team.
- [ ] GitOps-style infrastructure requests via PR.
- [ ] Deploy backend to ECS/App Runner with the included Terraform.
- [x] Integrate the AI Guardrail for policy/security scanning.

---

## License

MIT © 2026 [samueladegnan](https://github.com/samueladegnan)
