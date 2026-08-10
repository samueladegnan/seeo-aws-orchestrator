# Contributing to SEEO

SEEO is a portfolio project, but it follows the same quality gates expected of a production service: small changes, automated checks, explicit security boundaries, and documentation that matches the code.

## Development setup

### Backend

Requirements: Ruby 3.3+, Bundler, and either SQLite locally or Docker.

```bash
cd backend
cp .env.example .env
bundle install
bin/rails db:prepare
bundle exec rails server
```

The default configuration uses the in-memory multi-cloud adapter. It does not require provider credentials or create cloud resources.

### Frontend

```bash
cd frontend
npm ci
npm run dev
```

Set `VITE_API_BASE` if the Rails API is not running at `http://localhost:3000`.

## Quality gates

Run the relevant checks before opening a pull request:

```bash
# Backend
cd backend
bundle exec rubocop
bundle exec rspec

# Frontend
cd frontend
npm ci
npm audit --omit=optional
npm run lint
npm run build

# Terraform
for stack in infrastructure infrastructure/stacks/azure infrastructure/stacks/gcp infrastructure/stacks/oci; do
  terraform -chdir="$stack" fmt -check -recursive
  terraform -chdir="$stack" init -input=false
  terraform -chdir="$stack" validate
done
```

Provider adapter contract tests use checked-in JSON fixtures and stubbed subprocess calls. They prove command construction and response normalization without credentials or cloud spend.

## Change guidelines

- Keep provider-specific behavior inside an adapter; do not add cloud branching to controllers or the React dashboard.
- Never commit `.env`, credentials, private keys, Terraform state, or provider configuration files.
- Update the relevant README or documentation page when behavior or deployment assumptions change.
- Add a regression test for lifecycle, authorization, policy, idempotency, or cleanup changes.
- Keep demo mode safe by default. A browser-visible `VITE_*` value must never authorize real cloud operations.

## Pull requests

A useful pull request description includes:

1. The problem and user/operator impact.
2. The design or trade-off chosen.
3. Tests and checks run.
4. Any remaining limitation or follow-up work.
