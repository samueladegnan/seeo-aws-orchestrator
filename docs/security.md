---
title: Security Report
layout: default
permalink: /security/
---

# Security Report

Generated automatically by the [ai-cicd-security-guardrail](https://github.com/samueladegnan/ai-cicd-security-guardrail) GitHub Actions workflow.

## What This Report Shows

Every push to main is scanned with [Brakeman](https://brakemanscanner.org/), the findings are exported as a SARIF report, and the AI CI/CD Security Guardrail triages them. This page is the raw output of the most recent run, committed automatically by the guardrail workflow so the portfolio always reflects the current state of the codebase.

## Backend Report

Showing an example finding because the last scan returned no real findings.

### AI-Driven CI/CD Security Guardrail Report

> 👋 Hi, I'm an example finding for the guardrail tool! This is a demonstration entry shown when the real scan returns no findings.

#### Summary

- Total findings triaged: 1
- High-priority security risks: 0
- False positives: 0
- Unclear: 1

#### Findings

##### 1. Audit log may include internal environment metadata

- **Severity:** Low
- **Category:** Information disclosure
- **Location:** `backend/app/services/audit_log_service.rb`
- **Risk:** Serializing the full environment object into the audit log can leak internal metadata such as instance IDs, volume IDs, and IP addresses.
- **Recommendation:** Log only the fields required for forensics (for example, environment ID, project name, and actor) and redact sensitive metadata.
- **Status:** Example finding for demonstration purposes.

## Frontend Report

Showing an example finding because the last scan returned no real findings.

### AI-Driven CI/CD Security Guardrail Report

> 👋 Hi, I'm an example finding for the guardrail tool! This is a demonstration entry shown when the real scan returns no findings.

#### Summary

- Total findings triaged: 1
- High-priority security risks: 0
- False positives: 0
- Unclear: 1

#### Findings

##### 1. WebSocket subscription does not verify identity

- **Severity:** Low
- **Category:** Authentication
- **Location:** `frontend/src/App.jsx`
- **Risk:** The ActionCable subscription is opened without validating the user's identity, which could allow unauthorized clients to receive environment state updates.
- **Recommendation:** Authenticate the WebSocket connection on the server and reject subscriptions from unauthenticated clients.
- **Status:** Example finding for demonstration purposes.

## Built-in security controls

SEEO also enforces security through design:

- **Authentication**: every sensitive endpoint requires a JWT tenant token or API key.
- **RBAC**: admin, operator, and viewer roles restrict what each user can do.
- **Policy-as-code**: OPA/Rego enforces TTLs, allowed instance types, and team limits before provisioning.
- **Audit logging**: every create/destroy event is recorded with actor, team, and timestamp.
- **No hardcoded secrets**: runtime credentials are fetched from AWS Secrets Manager.
- **IAM least privilege**: the EC2 instance role can only read its assigned secret.
- **Encrypted data at rest**: DynamoDB and Secrets Manager encrypt data.
- **Non-root container**: the backend Dockerfile runs as an unprivileged user.

## CI/CD configuration

The guardrail workflow is defined in `.github/workflows/guardrail.yml`. On every push and pull request it:

1. Runs Brakeman to generate a SARIF report of the Rails backend.
2. Feeds that report to the AI Guardrail, which triages each finding with an LLM.
3. Produces a Markdown summary and a JSON report that can be downloaded from the workflow run.

The guardrail uses a mock provider by default so the pipeline runs without paid API keys. To use a real LLM, set these repository secrets:

- `GUARDRAIL_LLM_PROVIDER` — `openai`, `anthropic`, `gemini`, or `mock`
- `GUARDRAIL_LLM_API_KEY` — your provider API key
- `GUARDRAIL_LLM_MODEL` — model name (optional, e.g., `gpt-4o-mini`)

## Reporting issues

If you spot a security issue, please open a private issue or email me directly. I take disclosures seriously and will respond as quickly as possible.
