---
title: SEEO
layout: default
permalink: /
---

[![SEEO CI](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml)
[![Ruby 3.3](https://img.shields.io/badge/ruby-3.3-cc0000.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/LICENSE)

<div class="hero" markdown="1">

<p class="hero__title">A platform for secure, short-lived AWS environments</p>

<p class="hero__lead">SEEO is a multi-tenant internal developer platform. Teams request environments through a React dashboard or API, policy-as-code enforces guardrails, and every action is audited and cost-tracked.</p>

</div>

## Features

- **Multi-tenancy & RBAC**: teams, users, projects, and role-based access (admin, operator, viewer).
- **Policy-as-code**: OPA/Rego checks every provision request.
- **Audit logging**: every create/destroy event is recorded in DynamoDB.
- **Cost tracking**: estimated spend per environment and per team.
- **Real-time updates**: ActionCable WebSocket broadcasts to the React dashboard.
- **Structured logging & CloudWatch**: production-ready observability.

## How It Works

<div class="steps" markdown="1">

<div class="step" markdown="1">

### 1. Request

A developer requests an environment through the React dashboard or Rails API, choosing a project and TTL.

</div>

<div class="step" markdown="1">

### 2. Authorize & Validate

SEEO verifies the user's JWT or API key, checks RBAC, and runs OPA policy checks before allowing provisioning.

</div>

<div class="step" markdown="1">

### 3. Provision

SEEO stores environment metadata in DynamoDB, writes an audit record, and spins up a hardened EC2 instance with an attached EBS volume.

</div>

<div class="step" markdown="1">

### 4. Observe & Expire

ActionCable streams state changes, CloudWatch captures structured logs, and the TTL service tears down expired environments automatically.

</div>

</div>

## Explore Further

- [Demo](./demo/) — see the dashboard preview and run it locally.
- [Architecture Deep Dive](./architecture/) — data flow, component diagram, and security highlights.
- [API Documentation](./api/) — authentication, endpoints, and role-based access.
- [Frontend README](https://github.com/samueladegnan/seeo-aws-orchestrator/tree/main/frontend) — how to run the React dashboard.
- [Backend README](https://github.com/samueladegnan/seeo-aws-orchestrator/tree/main/backend) — configuration, setup, and Docker commands.

## Technology Stack

| Layer | Technology |
|-------|------------|
| API / Business Logic | Ruby 3.3, Ruby on Rails 7, Active Model |
| Frontend | React 18, Vite, Tailwind CSS |
| Real-time | ActionCable |
| Cloud Orchestration | aws-sdk-ruby (EC2, EBS, DynamoDB, Secrets Manager, Cost Explorer) |
| State Store | DynamoDB |
| Auth | JWT tenant tokens + legacy API key |
| Policy Engine | OPA/Rego (with Ruby fallback) |
| Infrastructure | Terraform |
| CI/CD | GitHub Actions, RuboCop, RSpec, Checkov |

## About the Author

Built by [Sam Degnan](https://samueladegnan.github.io/) as a portfolio project to demonstrate platform engineering, secure cloud automation, and infrastructure-as-code.
