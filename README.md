# SEEO — Secure Ephemeral Environment Orchestrator

A production-oriented, full-stack internal tool that lets teams request temporary, secure AWS environments on demand. SEEO automatically provisions hardened EC2 instances, securely injects runtime credentials via AWS Secrets Manager, tracks every environment's TTL in DynamoDB, and tears down resources when they expire.

> **Portfolio purpose:** SEEO demonstrates secure application development with Ruby on Rails, enterprise-grade AWS architecture, infrastructure-as-code with Terraform, secrets lifecycle management, and automated infrastructure lifecycle management.

> **Project site:** [samueladegnan.github.io/seeo-aws-orchestrator](https://samueladegnan.github.io/seeo-aws-orchestrator/)

---

## Features

- **Self-service ephemeral environments** — Request environments via REST API or web dashboard.
- **Secure credential handling** — EC2 instances use IAM roles to fetch runtime secrets from AWS Secrets Manager; no hardcoded credentials in code or user-data.
- **TTL lifecycle automation** — Background service scans for expired environments and terminates them automatically.
- **Infrastructure as Code** — Terraform provisions the VPC, subnets, security groups, IAM roles, DynamoDB table, and Secrets Manager secret.
- **Audit trail & state tracking** — DynamoDB records every environment's lifecycle and metadata.
- **Containerized backend** — Dockerfile included for consistent local or container deployment.
- **Web dashboard** — Clean, responsive UI to request, monitor, and tear down environments.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SEEO Backend (Ruby on Rails)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │ Environments │  │    Health    │  │      TTL Service         │   │
│  │  Controller  │  │  Controller  │  │    (Solid Queue job)     │   │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘   │
└─────────┼─────────────────┼───────────────────────┼─────────────────┘
          │                 │                       │
          ▼                 ▼                       ▼
     ┌─────────┐     ┌──────────────┐         ┌───────────────┐
     │  EC2    │     │ DynamoDB     │         │Secrets Manager│
     │ + EBS   │     │ Environments │         │ Runtime creds │
     └─────────┘     └──────────────┘         └───────────────┘
```

### Technology Stack

| Layer                | Technology                                         |
|----------------------|----------------------------------------------------|
| API / Business Logic | Ruby 3.3, Ruby on Rails 7, Active Model              |
| Cloud Orchestration  | aws-sdk-ruby (EC2, EBS, Secrets Manager, DynamoDB) |
| State Store          | DynamoDB                                           |
| Secrets Management   | AWS Secrets Manager                                |
| Infrastructure       | Terraform (AWS provider)                           |
| Dashboard            | Vanilla JS + CSS served by Rails API               |
| Container            | Docker                                             |

---

## Project Structure

```
.
├── backend/
│   ├── app/
│   │   ├── controllers/           # Rails controllers
│   │   ├── models/                # ActiveModel objects
│   │   ├── services/              # AWS and auth services
│   │   └── jobs/                  # Solid Queue background jobs
│   ├── config/                    # Rails configuration
│   ├── db/                        # Migrations (Solid Queue, etc.)
│   ├── spec/                      # RSpec tests
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── Gemfile
├── infrastructure/
│   ├── main.tf                    # VPC, IAM, SG, DynamoDB, Secrets
│   ├── variables.tf
│   └── outputs.tf
├── scripts/
│   └── ec2_user_data.sh           # Bootstrap reference
├── docs/                          # GitHub Pages site
├── README.md
└── .gitignore
```

---

## Prerequisites

- **Ruby 3.3+**
- **AWS CLI** configured with appropriate credentials
- **Terraform 1.5+**
- (Optional) **Docker**

---

## Quick Start

### 1. Clone & Configure

```bash
cp backend/.env.example backend/.env
# Edit backend/.env with your AWS settings and a strong API_KEY
```

### 2. Deploy the Infrastructure

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

Note the outputs (VPC ID, subnet IDs, security group ID, instance profile name).

### 3. Run the Backend Locally

```bash
cd backend
bundle install
bin/rails solid_queue:install:migrations
bin/rails db:create db:migrate
bin/rails server
```

Open [http://localhost:3000](http://localhost:3000) for the dashboard and [http://localhost:3000/environments](http://localhost:3000/environments) for the API.

### 4. Request an Environment

```bash
curl -X POST "http://localhost:3000/environments" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{"project_name": "my-api", "ttl_minutes": 60}'
```

---

## Environment Variables

| Variable                       | Description                                    | Default                    |
|--------------------------------|------------------------------------------------|----------------------------|
| `SEEO_API_KEY`                 | API key for all protected endpoints            | `dev-change-me...`       |
| `AWS_REGION`                   | AWS region                                     | `us-east-1`                |
| `AWS_PROFILE`                  | AWS CLI profile name (optional)                | —                          |
| `SEEO_EC2_KEY_PAIR`            | EC2 key pair name for SSH access               | —                          |
| `SEEO_EC2_AMI_ID`              | AMI ID to launch (optional; latest AL2023 used) | —                         |
| `SEEO_EC2_INSTANCE_TYPE`       | Default EC2 instance type                      | `t3.micro`                 |
| `SEEO_EC2_SUBNET_ID`           | Subnet ID for launched instances               | —                          |
| `SEEO_EC2_SECURITY_GROUP_ID` | Security group ID for launched instances       | —                          |
| `SEEO_IAM_INSTANCE_PROFILE`    | IAM instance profile attached to EC2 instances | —                          |
| `SEEO_ENVIRONMENTS_TABLE`      | DynamoDB table name                            | `seeo-environments`        |
| `SEEO_SECRETS_SECRET_NAME`     | Secrets Manager secret name                    | `seeo/runtime/credentials` |
| `SEEO_TTL_CHECK_INTERVAL_SECONDS` | TTL scan interval in seconds                | `60`                       |
| `CORS_ALLOW_ORIGINS`           | Comma-separated list of allowed CORS origins     | `*`                        |
| `CORS_ALLOW_CREDENTIALS`       | Allow CORS requests with credentials             | `false`                    |

---

## Security Highlights

- **No hardcoded secrets** in source code or user-data.
- **IAM least privilege** — EC2 instance role can only read its assigned secret.
- **API key authentication** on all sensitive endpoints.
- **Non-root container** in the provided Dockerfile.
- **Encrypted secrets at rest** via AWS Secrets Manager and DynamoDB.

---

## Testing

Run the test suite with:

```bash
cd backend
bundle exec rspec
```

For linting:

```bash
cd backend
bundle exec rubocop
```

---

## Roadmap / Next Steps

- Add email/Slack notifications on environment lifecycle events.
- Introduce cost allocation tags and daily budget reporting.
- Expand unit/integration test coverage beyond the core orchestration flows.

---

## License

MIT © 2026 [samueladegnan](https://github.com/samueladegnan)
