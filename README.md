# SEEO — Secure Ephemeral Environment Orchestrator

A production-oriented, full-stack internal tool that lets teams request temporary, secure AWS environments on demand. SEEO automatically provisions hardened EC2 instances, securely injects runtime credentials via AWS Secrets Manager, tracks every environment's TTL in DynamoDB, and tears down resources when they expire.

> **Portfolio purpose:** SEEO demonstrates secure application development in Python with FastAPI, enterprise-grade AWS architecture, infrastructure-as-code with Terraform, secrets lifecycle management, and automated infrastructure lifecycle management.

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
│                         SEEO Backend (FastAPI)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ Environments │  │    Health    │  │      TTL Service         │  │
│  │   Router     │  │    Router    │  │  (background thread)     │  │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘  │
└─────────┼────────────────┼───────────────────────┼──────────────────┘
          │                │                       │
          ▼                ▼                       ▼
     ┌─────────┐     ┌──────────┐         ┌──────────────┐
     │  EC2    │     │ DynamoDB │         │Secrets Manager│
     │ + EBS   │     │ Environments       │ Runtime creds │
     └─────────┘     └──────────         └──────────────┘
```

### Technology Stack

| Layer                | Technology                                   |
|----------------------|----------------------------------------------|
| API / Business Logic | Python 3.11, FastAPI, Pydantic v2            |
| Cloud Orchestration  | boto3 (EC2, EBS, Secrets Manager, DynamoDB) |
| State Store          | DynamoDB                                     |
| Secrets Management   | AWS Secrets Manager                          |
| Infrastructure       | Terraform (AWS provider)                     |
| Dashboard            | Vanilla JS + CSS served by FastAPI/Jinja2    |
| Container            | Docker                                       |

---

## Project Structure

```
.
├── backend/
│   ├── app/
│   │   ├── config.py              # Pydantic settings
│   │   ├── dependencies.py        # FastAPI dependencies
│   │   ├── main.py                # FastAPI entrypoint & lifespan
│   │   ├── models.py              # Pydantic request/response models
│   │   ├── routers/
│   │   │   ├── environments.py    # Environment CRUD endpoints
│   │   │   └── health.py          # Health check
│   │   ├── services/
│   │   │   ├── auth_service.py    # API key validation
│   │   │   ├── aws_service.py     # AWS orchestration logic
│   │   │   └── ttl_service.py     # TTL background monitor
│   │   ├── static/                # Dashboard CSS/JS
│   │   └── templates/
│   │       └── index.html         # Dashboard
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .env.example
├── infrastructure/
│   ├── main.tf                    # VPC, IAM, SG, DynamoDB, Secrets
│   ├── variables.tf
│   └── outputs.tf
├── scripts/
│   └── ec2_user_data.sh           # Bootstrap reference
├── README.md
└── .gitignore
```

---

## Prerequisites

- **Python 3.11+**
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
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Open [http://localhost:8000](http://localhost:8000) for the dashboard and [http://localhost:8000/docs](http://localhost:8000/docs) for the OpenAPI docs.

### 4. Request an Environment

```bash
curl -X POST "http://localhost:8000/environments" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{"project_name": "my-api", "ttl_minutes": 60}'
```

---

## Environment Variables

| Variable                  | Description                                       | Default                  |
|---------------------------|---------------------------------------------------|--------------------------|
| `API_KEY`                 | API key for all protected endpoints               | `dev-change-me...`       |
| `AWS_REGION`              | AWS region                                        | `us-east-1`              |
| `AWS_PROFILE`             | AWS CLI profile name (optional)                   | —                        |
| `EC2_KEY_PAIR`            | EC2 key pair name for SSH access                  | —                        |
| `EC2_AMI_ID`              | AMI ID to launch (optional; latest AL2023 used)   | —                        |
| `EC2_INSTANCE_TYPE`       | Default EC2 instance type                         | `t3.micro`               |
| `EC2_SUBNET_ID`           | Subnet ID for launched instances                  | —                        |
| `EC2_SECURITY_GROUP_ID`   | Security group ID for launched instances          | —                        |
| `IAM_INSTANCE_PROFILE`    | IAM instance profile attached to EC2 instances    | —                        |
| `ENVIRONMENTS_TABLE`      | DynamoDB table name                               | `seeo-environments`      |
| `SECRETS_SECRET_NAME`     | Secrets Manager secret name                       | `seeo/runtime/credentials` |
| `TTL_CHECK_INTERVAL_SECONDS` | TTL scan interval in seconds                   | `60`                     |
| `CORS_ALLOW_ORIGINS`      | Comma-separated list of allowed CORS origins   | `*`                      |
| `CORS_ALLOW_CREDENTIALS`  | Allow CORS requests with credentials           | `false`                  |

---

## Security Highlights

- **No hardcoded secrets** in source code or user-data.
- **IAM least privilege** — EC2 instance role can only read its assigned secret and update its own DynamoDB record.
- **API key authentication** on all sensitive endpoints.
- **Non-root container** in the provided Dockerfile.
- **Encrypted secrets at rest** via AWS Secrets Manager and DynamoDB.

---

## Testing

Run syntax/type checks with:

```bash
cd backend
python -m compileall app/
```

For unit tests (pytest suite can be added):

```bash
pytest
```

---

## Roadmap / Next Steps

- Add CI/CD pipeline for automated tests and Docker builds.
- Implement a custom AMI build with Packer.
- Add email/Slack notifications on environment lifecycle events.
- Introduce cost allocation tags and daily budget reporting.
- Add full unit/integration test coverage.

---

## License

MIT © 2026 [samueladegnan](https://github.com/samueladegnan)
