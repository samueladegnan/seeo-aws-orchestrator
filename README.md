# SEEO: Secure Ephemeral Environment Orchestrator

SEEO is a full-stack multi-cloud control plane for requesting short-lived environments, watching their lifecycle, and cleaning them up before they become forgotten infrastructure. It is designed to make the safe path easy: every demo request has an expiry, an owner, a policy decision, and a cleanup path. The project combines a Rails API, tenant-aware authorization, provider-aware policy checks, a React dashboard, live updates, cost estimates, and Terraform foundations for AWS, Azure, Google Cloud, and OCI.

> **Project site:** [samueladegnan.github.io/seeo-aws-orchestrator](https://samueladegnan.github.io/seeo-aws-orchestrator/) · [Launch the live mock demo](https://seeo-dashboard.vercel.app/)

[![CI](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml) [![Security workflow](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/guardrail.yml/badge.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/guardrail.yml)

## Why it exists

Temporary environments are useful for previews, debugging, and integration work. They are also easy to leave running. SEEO treats an environment as a lifecycle: authenticate the requester, select a cloud, validate the request, record ownership, provision through a common adapter contract, stream state to the dashboard, estimate cost, and remove expired resources.

## Features

- **Multi-cloud lifecycle contract:** AWS, Azure, Google Cloud, and OCI share the same create, refresh, terminate, and cleanup interface.
- **Provider-neutral records:** environments store the selected cloud, region, normalized compute/storage tiers, and provider resource identifiers without tying the control plane to one vendor.
- **Multi-tenancy and RBAC:** teams, users, and projects with admin, operator, and viewer roles.
- **Provider-aware policy:** OPA/Rego and a Ruby fallback enforce provider allow-lists, valid regions, TTLs, resource tiers, volume limits, and capacity.
- **Cost estimates:** the dashboard estimates compute and storage cost using provider-specific tier rates.
- **Live updates:** signed ActionCable tokens keep tenant and browser-session streams scoped to the right audience.
- **Safe demo mode:** the hosted and local demos use an in-memory adapter for every provider, so no cloud resources are created.
- **Terraform foundations:** independent stacks establish the network and identity boundary for all four clouds, with provider state kept separate from Rails lifecycle state.
- **Operational health:** a public health endpoint reports version, mock mode, and the enabled provider catalog without exposing credentials.
- **Security workflow:** Brakeman output is triaged by Guardrail in CI, with source reports preserved as artifacts.

## Five-minute tour

1. Open the [live mock demo](https://seeo-dashboard.vercel.app/) and choose any provider.
2. Create a short-lived environment, open **Details**, and inspect normalized provider/resource fields.
3. Terminate it and observe that the record disappears from the browser-scoped session.
4. Read [Architecture](https://samueladegnan.github.io/seeo-aws-orchestrator/architecture/), [API documentation](https://samueladegnan.github.io/seeo-aws-orchestrator/api/), and the [Security Report](https://samueladegnan.github.io/seeo-aws-orchestrator/security/) to see the design, lifecycle contract, and security boundaries.
5. Run `npm run lint`, `npm run build`, and the Terraform validation commands locally; GitHub Actions runs the backend tests/lint, the separate Guardrail security workflow runs Brakeman, and the provider-runner job builds the credential-free CLI image.

## Architecture

See the [Architecture page](https://samueladegnan.github.io/seeo-aws-orchestrator/architecture/) for the adapter contract, request flow, provider mapping, security controls, and Terraform layout.

## Tech stack

| Layer | Technology |
| --- | --- |
| API and business logic | Ruby 3.3, Ruby on Rails 7, Active Model and Active Record |
| Frontend | React 18, Vite, Tailwind CSS, ESLint |
| Real-time | ActionCable and WebSockets |
| Cloud adapters | Provider-neutral contract with AWS, Azure, Google Cloud, OCI, and mock implementations |
| Infrastructure | Terraform with independent AWS, Azure, Google Cloud, and OCI stacks |
| Control-plane state | Rails database with SQLite for local development |
| Authentication | JWT tenant tokens plus a scoped mock-demo API key |
| Policy engine | OPA/Rego with a built-in Ruby fallback |
| CI/CD | GitHub Actions, RuboCop, RSpec, Terraform, Checkov, and Guardrail |

## Quick start

Docker is the shortest path.

```bash
cp backend/.env.example backend/.env
cd backend
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

In another terminal:

```bash
cd frontend
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).

The default backend configuration enables `SEEO_MOCK_MODE=true` and allows all four providers. Select AWS, Azure, Google Cloud, or OCI in the dashboard and the mock adapter will simulate that provider's resource shapes and regions without credentials.

For a real provider deployment, run the backend with the selected cloud CLI (`aws`, `az`, `gcloud`, or `oci`), configure credentials through workload identity or a secret manager, wire Terraform network outputs and image settings, and then set `SEEO_MOCK_MODE=false`. The hosted Render demo intentionally stays in mock mode; its browser-visible key can never authorize real cloud lifecycle actions.

## Demo

The [Demo page](https://samueladegnan.github.io/seeo-aws-orchestrator/demo/) puts the hosted dashboard first and keeps local instructions below it. The live dashboard runs in multi-cloud mock mode. Every visitor receives a browser-scoped session and no real cloud resources are created.

## Terraform

The `infrastructure/` directory contains four independent roots:

- `infrastructure/` for AWS
- `infrastructure/stacks/azure/` for Azure
- `infrastructure/stacks/gcp/` for Google Cloud
- `infrastructure/stacks/oci/` for OCI

Each stack exports network identifiers consumed by the matching adapter. Provider state remains separate; Rails stores environment lifecycle state in its own database.

```bash
terraform -chdir=infrastructure fmt -check -recursive
terraform -chdir=infrastructure init
terraform -chdir=infrastructure validate
```

Repeat validation in each provider stack directory.

## Documentation site

The Jekyll site in `docs/` is the project portfolio:

```bash
cd docs
docker compose up --build
```

Open [http://localhost:4000](http://localhost:4000).

## Engineering boundaries

The control plane is provider-neutral, but provider APIs are not interchangeable. Networking, identity, native VM/storage shapes, CLI output parsing, and lifecycle-state normalization remain behind adapters. That is deliberate: it keeps controllers, policy, persistence, and the UI stable while each cloud evolves independently.

The current repository provides a safe, fully demonstrable multi-cloud mock lifecycle, checked-in provider response contract fixtures for all four CLIs, a credential-free `backend/Dockerfile.runner`, and validated Terraform foundations for all four providers. Real provider execution remains credential-gated because creating VMs, disks, networks, and identities is inherently a cloud API operation; no credentials are stored in this repository.

## Testing

Backend:

```bash
cd backend
bundle exec rubocop
bundle exec rspec
```

Frontend:

```bash
cd frontend
npm run lint
npm run build
```

Terraform:

```bash
for stack in infrastructure infrastructure/stacks/azure infrastructure/stacks/gcp infrastructure/stacks/oci; do
  terraform -chdir="$stack" init
  terraform -chdir="$stack" validate
done
```

## Roadmap

- Replace CLI runner boundaries with direct SDK workers where operationally justified.
- Run credentialed provider integration tests in disposable, budget-capped accounts.
- Add provider-specific image catalogs and asynchronous operation polling.
- Add cost reports by team, project, and provider.
- Add notifications for lifecycle events.
- Deploy the Rails control plane and worker with provider-neutral secrets and workload identity.

## Portfolio talking points

- **Ownership:** built the Rails control plane, React dashboard, provider adapters, Terraform roots, policy layer, security workflow, and deployment path.
- **Technical depth:** normalized four provider lifecycles while preserving provider-specific networking, identity, resource shapes, and state parsing behind adapters.
- **Reliability:** added idempotency, persisted provider IDs, TTL cleanup, retry-aware demo behavior, ActionCable authorization, and provider contract fixtures.
- **Engineering judgment:** kept the public demo credential-free and mock-backed instead of claiming unverified or potentially billable cloud execution.

## About this project

I built and reviewed SEEO with AI assistance. The tools helped with exploration, implementation, documentation, and testing. I remain responsible for the architecture, engineering decisions, and final review.

## License

MIT (c) 2026 [samueladegnan](https://github.com/samueladegnan)
