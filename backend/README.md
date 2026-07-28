# SEEO Backend (Ruby on Rails)

This is the Rails API that orchestrates secure, TTL-bound ephemeral AWS environments for SEEO.

## Requirements

- Ruby 3.3+
- Bundler
- AWS credentials configured through environment variables or an IAM role

## Setup

```bash
cd backend
cp .env.example .env
# Edit .env with your AWS settings and a strong SEEO_API_KEY + SEEO_JWT_SECRET
bundle install
bin/rails db:create db:migrate
bin/rails db:seed   # optional: creates a default team, project, and admin user
bin/rails server
```

## Configuration

| Variable | Description | Default |
|---|---|---|
| `SEEO_API_KEY` | Legacy API key for service accounts | `dev-change-me-in-production` |
| `SEEO_JWT_SECRET` | Secret used to sign/verify JWT tenant tokens | `dev-change-me-in-production` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_PROFILE` | AWS CLI profile | none |
| `SEEO_EC2_KEY_PAIR` | EC2 key pair name | none |
| `SEEO_EC2_AMI_ID` | AMI to launch (falls back to latest Amazon Linux 2) | none |
| `SEEO_EC2_INSTANCE_TYPE` | Default EC2 instance type | `t3.micro` |
| `SEEO_EC2_SUBNET_ID` | Subnet for new instances | none |
| `SEEO_EC2_SECURITY_GROUP_ID` | Security group for new instances | none |
| `SEEO_IAM_INSTANCE_PROFILE` | IAM instance profile for new instances | none |
| `SEEO_ENVIRONMENTS_TABLE` | DynamoDB environments table | `seeo-environments` |
| `SEEO_AUDIT_LOG_TABLE` | DynamoDB audit log table | `seeo-audit-logs` |
| `SEEO_SECRETS_SECRET_NAME` | Secrets Manager secret name | `seeo/runtime/credentials` |
| `SEEO_TTL_CHECK_INTERVAL_SECONDS` | TTL scan interval (used by the monitor job) | `60` |
| `SEEO_MOCK_AWS` | Use in-memory mock AWS instead of real APIs | `true` in development |
| `CORS_ALLOW_ORIGINS` | Comma-separated allowed origins | `*` |
| `CORS_ALLOW_CREDENTIALS` | Whether CORS allows credentials | `false` |

## Authentication

The API accepts two authentication methods:

- **JWT tenant token**: `Authorization: Bearer <jwt>`
  - Used by users who belong to a team/project.
  - Tokens are issued by `AuthorizationService.issue_token(user)` and expire after 24 hours.
- **Legacy API key**: `X-API-Key: <key>`
  - Used by service accounts.
  - Authenticates as a transient admin user with no team.

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

TTL monitoring is handled by `TtlMonitorJob`, scheduled via Solid Queue recurring tasks or your scheduler of choice.
