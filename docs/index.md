# SEEO — Secure Ephemeral Environment Orchestrator

A production-oriented, full-stack internal tool that lets teams request temporary, secure AWS environments on demand.

## What it does

- **Self-service ephemeral environments** via REST API and web dashboard.
- **Hardened EC2 + EBS** provisioned automatically for each request.
- **Secure credential handling** with AWS Secrets Manager and IAM roles.
- **TTL lifecycle automation** — expired environments are torn down automatically.
- **Infrastructure as Code** with Terraform.
- **Containerized FastAPI backend** with a responsive dashboard.

## Live Demo

The dashboard is served by the FastAPI backend. See the [README](https://github.com/samueladegnan/seeo-aws-orchestrator#readme) for setup instructions.

## Quick Links

- [Source Code](https://github.com/samueladegnan/seeo-aws-orchestrator)
- [Architecture & Setup](https://github.com/samueladegnan/seeo-aws-orchestrator#readme)
- [Manual Steps & Deployment Guide](./manual-steps)
- [API Documentation](https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/README.md)

## Technology Stack

| Layer                | Technology                                   |
|----------------------|----------------------------------------------|
| API / Business Logic | Python 3.11, FastAPI, Pydantic v2            |
| Cloud Orchestration  | boto3 (EC2, EBS, Secrets Manager, DynamoDB) |
| State Store          | DynamoDB                                     |
| Secrets Management   | AWS Secrets Manager                          |
| Infrastructure       | Terraform (AWS provider)                     |
| Dashboard            | Vanilla JS + CSS served by FastAPI/Jinja2    |
| Container            | Docker                                       |

## Author

[Samuel Adegnan](https://samueladegnan.github.io/)
