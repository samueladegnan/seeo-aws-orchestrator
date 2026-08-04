# SEEO Backend (Ruby on Rails)

This is the Rails API that orchestrates secure, TTL-bound ephemeral AWS environments for SEEO.

## Requirements

- Ruby 3.3+
- Bundler
- Docker, or Ruby and the project dependencies installed locally
- AWS credentials only when running with `SEEO_MOCK_AWS=false`

## Setup

```bash
cd backend
cp .env.example .env
# Edit .env with local settings and strong development secrets
bundle install
bin/rails db:create db:migrate
bin/rails db:seed   # optional: creates a default team, project, and admin user
bin/rails server
```

## Configuration

| Variable | Description | Default |
|---|---|---|
| `SEEO_API_KEY` | API key for local/mock service-account requests | local development only |
| `SEEO_JWT_SECRET` | Secret used to sign/verify JWT tenant tokens | local development only |
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_PROFILE` | AWS CLI profile | none |
| `SEEO_EC2_KEY_PAIR` | EC2 key pair name | none |
| `SEEO_EC2_AMI_ID` | AMI to launch (falls back to the latest Amazon Linux 2023 image) | none |
| `SEEO_EC2_INSTANCE_TYPE` | Default EC2 instance type | `t3.micro` |
| `SEEO_EC2_SUBNET_ID` | Subnet for new instances | none |
| `SEEO_EC2_SECURITY_GROUP_ID` | Security group for new instances | none |
| `SEEO_IAM_INSTANCE_PROFILE` | IAM instance profile for new instances | none |
| `SEEO_ENVIRONMENTS_TABLE` | DynamoDB environments table | `seeo-environments` |
| `SEEO_AUDIT_LOG_TABLE` | DynamoDB audit log table | `seeo-audit-logs` |
| `SEEO_SECRETS_SECRET_NAME` | Secrets Manager secret name | `seeo/runtime/credentials` |
| `SEEO_TTL_CHECK_INTERVAL_SECONDS` | TTL scan interval (used by the monitor job) | `60` |
| `SEEO_MOCK_AWS` | Use the in-memory provider instead of real AWS APIs | `true` in development |
| `CORS_ALLOW_ORIGINS` | Comma-separated allowed origins | `*` |
| `CORS_ALLOW_CREDENTIALS` | Whether CORS allows credentials | `false` |

## Authentication

The API supports two authentication methods:

- **JWT tenant token**: `Authorization: Bearer <jwt>`
  - Used by users who belong to a team/project.
  - Tokens are issued by `AuthorizationService.issue_token(user)` and expire after 24 hours.
- **API key**: `X-API-Key: <key>`
  - Used for local service-account and public mock-demo requests.
  - In real AWS mode, API-key lifecycle access is rejected. Use a JWT tenant token for real tenant operations.
  - Demo records remain scoped to the server-issued browser session. Internal TTL cleanup uses a separate job context and is not exposed through this key.

Mock clients first call `GET /session-token` with the API key, then send the returned `X-Session-Token` on later requests. ActionCable clients call `GET /cable-token` next. The backend returns a short-lived signed token, and the channel derives the authorized team or session stream instead of trusting a client-selected stream.

## Running locally

```bash
bundle exec rails server
```

For TTL monitoring in development, enqueue the monitor job manually or start the Solid Queue worker:

```bash
bundle exec rake solid_queue:start
```

## Running with Docker

```bash
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

Or use Docker Compose:

```bash
docker compose up --build
```

## Running tests

```bash
bundle exec rspec
```

Inside Docker:

```bash
docker run --rm -e RAILS_ENV=test -e SEEO_JWT_SECRET=test-secret seeo-backend sh -c "bundle exec rails db:create db:migrate && bundle exec rspec"
```

## Linting

```bash
bundle exec rubocop
```

## Background jobs

TTL monitoring is handled by `TtlMonitorJob`, scheduled via Solid Queue recurring tasks or your scheduler of choice. The job sets an internal cleanup context, scans expired records across tenants, attempts each provider cleanup independently, and preserves failed records for a later retry.
