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

<p class="hero__lead">SEEO provisions secure, short-lived AWS EC2 environments on demand through a React dashboard or a REST API. It handles authentication, policy checks, audit logging, and automatic cleanup.</p>

</div>

## What it does

- **Multi-tenancy & RBAC**: keeps teams, projects, and permissions separate so one team cannot affect another's environments.
- **Policy checks**: OPA/Rego validates every provision request, with a built-in Ruby fallback when OPA is not installed.
- **Audit logging**: every create/destroy event is recorded with the actor and timestamp.
- **Cost estimates**: rough per-environment and per-team cost based on instance type, volume, and TTL.
- **Real-time updates**: ActionCable WebSocket broadcasts state changes to the React dashboard.
- **Observability**: structured JSON logs ready for CloudWatch or a SIEM pipeline.
- **AI Guardrail**: every CI run triages Brakeman findings with an AI guardrail and produces a report.

## How It Works

<div class="steps" markdown="1">

<div class="step" markdown="1">

### 1. Request

A developer requests an environment through the React dashboard or the Rails API, specifying a project and TTL.

</div>

<div class="step" markdown="1">

### 2. Authorize & Validate

SEEO verifies the JWT or API key, checks RBAC, and runs policy checks.

</div>

<div class="step" markdown="1">

### 3. Provision

Metadata is stored, an audit record is written, and an EC2 instance is launched.

</div>

<div class="step" markdown="1">

### 4. Observe & Expire

ActionCable streams state changes while the TTL service tears down expired environments automatically.

</div>

</div>

## About the Author

Built by [Samuel Degnan](https://samueladegnan.github.io/) as a portfolio project demonstrating full-stack engineering, policy-as-code, and secure cloud orchestration.
