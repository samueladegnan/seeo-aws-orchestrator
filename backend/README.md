# SEEO Backend (Ruby on Rails)

The SEEO backend is a Ruby on Rails API that orchestrates secure, TTL-bound ephemeral AWS environments.

## Requirements

- Ruby 3.3+
- Bundler
- AWS credentials configured via environment variables or IAM role

## Setup

```bash
cd backend
bundle install
bin/rails solid_queue:install:migrations
bin/rails db:create db:migrate
```

## Configuration

Set these environment variables:

| Variable | Description | Default |
|---|---|---|
| `SEEO_API_KEY` | API key for authentication | `dev-change-me-in-production` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_PROFILE` | AWS CLI profile | none |
| `SEEO_ENVIRONMENTS_TABLE` | DynamoDB table name | `seeo-environments` |
| `SEEO_SECRETS_SECRET_NAME` | Secrets Manager secret name | `seeo/runtime/credentials` |
| `SEEO_EC2_INSTANCE_TYPE` | Default EC2 instance type | `t3.micro` |
| `SEEO_TTL_CHECK_INTERVAL_SECONDS` | TTL scan interval | `60` |

## Running locally

```bash
bundle exec rails server
```

For TTL monitoring in development, enqueue the monitor job manually or start the
Solid Queue worker:

```bash
bundle exec rake solid_queue:start
```

## Running tests

```bash
bundle exec rspec
```

## Linting

```bash
bundle exec rubocop
```

## Background jobs

TTL monitoring is handled by `TtlMonitorJob` scheduled via Solid Queue recurring tasks or your scheduler of choice.
