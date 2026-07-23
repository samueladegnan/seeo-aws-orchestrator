---
title: SEEO
layout: default
permalink: /
---

# SEEO — Secure Ephemeral Environment Orchestrator

[![SEEO CI](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml)
[![SEEO Pages](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/pages.yml/badge.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/pages.yml)
[![Python 3.11](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/LICENSE)

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
- [Architecture](./architecture)
- [Manual Steps & Deployment Guide](./manual-steps)
- [API Documentation](./api)

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

[Samuel Degnan](https://samueladegnan.github.io/)
