# SEEO: Secure Ephemeral Environment Orchestrator

SEEO is a full-stack platform for requesting secure, short-lived AWS environments on demand. It brings together a Rails API, tenant-aware authorization, policy-as-code, a React dashboard with live updates, Terraform infrastructure, and CI security checks in one focused system.

> **Project site:** [samueladegnan.github.io/seeo-aws-orchestrator](https://samueladegnan.github.io/seeo-aws-orchestrator/)

---

## Why it exists

Temporary environments are useful for previews, debugging, and short-lived integration work, but they are easy to forget. SEEO treats an environment as a lifecycle. It authenticates the requester, checks policy, provisions with least privilege, streams tenant-scoped state, estimates cost, records an audit event, and cleans up when the TTL expires.

## Features

- **Multi-tenancy & RBAC**: Teams, users, and projects with admin, operator, and viewer roles.
- **Policy engine**: OPA/Rego rules (with a built-in Ruby fallback) enforce TTLs, allowed instance types, and team limits before provisioning.
- **Audit logging**: Every create/destroy event is recorded with actor, team, and timestamp.
- **Cost estimates**: Rough per-environment and per-team spend based on instance type, volume, and TTL.
- **Real-time dashboard**: short-lived signed ActionCable tokens authorize tenant or browser-session streams before state changes reach the React dashboard.
- **Structured logging**: JSON logs ready for CloudWatch or a SIEM pipeline.
- **React frontend**: Vite + React 18 dashboard that talks directly to the Rails API.
- **CI checks**: RuboCop, RSpec, Terraform `fmt`/`validate`, Checkov, and Guardrail v1.1.0 for Brakeman triage on every push.

---

## Architecture

See the [Architecture page](https://samueladegnan.github.io/seeo-aws-orchestrator/architecture/) for a component diagram and detailed flow.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| API / Business Logic | Ruby 3.3, Ruby on Rails 7, Active Model |
| Frontend | React 18, Vite, Tailwind CSS, ESLint |
| Real-time | ActionCable / WebSockets |
| Cloud Orchestration | aws-sdk-ruby (EC2, DynamoDB, Secrets Manager) |
| State Store | DynamoDB |
| Auth | JWT tenant tokens + scoped local/demo API key |
| Policy Engine | OPA/Rego with a built-in Ruby fallback |
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

On Windows Command Prompt, run the same commands after changing into the `backend` directory:

```cmd
cd backend
copy .env.example .env
:: Edit .env with your local settings
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

> **Note:** If you change `SEEO_API_KEY` in `backend/.env`, the local frontend must use the same value through `VITE_SEEO_API_KEY`. Vite embeds `VITE_*` values in the browser bundle, so this key is appropriate for the mock demo only. Do not use a browser-exposed API key to authorize real AWS operations.
>
> By default, the backend runs in **Mock AWS Mode** (`SEEO_MOCK_AWS=true`) and needs no AWS credentials. Set `SEEO_MOCK_AWS=false` only after configuring AWS, DynamoDB, EC2 networking, IAM, and Secrets Manager. Mock provider state is in memory and audit logs go to the Rails log. Real mode persists ownership in DynamoDB, reserves idempotency keys, and records failed cleanup for retry.

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

A deployed demo is available at [https://seeo-dashboard.vercel.app/](https://seeo-dashboard.vercel.app/). It runs the backend in **Mock AWS Mode**, so no AWS credentials are required and no real AWS resources are created. Each visitor receives a browser-scoped sandbox through a server-issued signed session token. ActionCable uses a separate short-lived token for that same session. Clearing local storage starts a fresh demo session.

> **Note:** The backend runs on Render's free tier. It may take **30–50 seconds** to wake up after a period of inactivity. The dashboard shows a loading message while the server starts. Some ad blockers may block requests to `.onrender.com`. If the dashboard seems stuck, try disabling your ad blocker or use an incognito/private window.

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

## How this portfolio project was made

I built and reviewed this project with AI assistance. AI tools helped with exploration, implementation, documentation, and testing. I remain responsible for the architecture, engineering decisions, testing, and final code.

## License

MIT (c) 2026 [samueladegnan](https://github.com/samueladegnan)
