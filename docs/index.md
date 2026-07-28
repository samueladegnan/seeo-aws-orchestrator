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

<p class="hero__lead">SEEO provisions secure, short-lived AWS environments on demand through a React dashboard or API. I built it after too many side-project sandboxes stuck around too long and cost too much.</p>

</div>

## What it does

- **Multi-tenancy & RBAC**: keeps teams, projects, and permissions separate so one team cannot accidentally blow up another's sandbox.
- **Policy-as-code**: OPA/Rego checks every provision request before any AWS call is made.
- **Audit logging**: every create/destroy event is recorded with who did it and when.
- **Cost tracking**: rough cost estimates per environment and team, because free-tier surprises are real.
- **Real-time updates**: ActionCable WebSocket broadcasts state changes to the React dashboard.
- **Observability**: structured JSON logs ready for CloudWatch or a SIEM pipeline.
- **AI Guardrail**: every CI run triages Brakeman findings with an AI guardrail and produces a report.

## How It Works

<div class="steps" markdown="1">

<div class="step" markdown="1">

### 1. Request

Developers request an environment through the React dashboard or Rails API with a project and TTL.

</div>

<div class="step" markdown="1">

### 2. Authorize & Validate

SEEO verifies the JWT or API key, checks RBAC, and runs OPA policy checks.

</div>

<div class="step" markdown="1">

### 3. Provision

Metadata is stored, an audit record is written, and a hardened EC2 instance is spun up.

</div>

<div class="step" markdown="1">

### 4. Observe & Expire

ActionCable streams state changes while the TTL service tears down expired environments automatically.

</div>

</div>

## About the Author

I am [Sam Degnan](https://samueladegnan.github.io/), a software engineer focused on platform engineering, secure cloud automation, and infrastructure-as-code. SEEO is one of my portfolio projects; I built it end-to-end to show how a small team could safely self-service cloud environments.
