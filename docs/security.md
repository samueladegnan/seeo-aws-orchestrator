---
title: Security Report
layout: default
permalink: /security/
---

*Generated automatically by the [ai-cicd-security-guardrail](https://github.com/samueladegnan/ai-cicd-security-guardrail) GitHub Actions workflow.*

*Generated with [ai-cicd-security-guardrail](https://github.com/samueladegnan/ai-cicd-security-guardrail), another project by [Samuel Degnan](https://samueladegnan.github.io/).*

## What This Report Shows

Every push to main is scanned with [Brakeman](https://brakemanscanner.org/), the findings are exported as a SARIF report, and the AI CI/CD Security Guardrail triages them. This page is the raw output of the most recent run, committed automatically by the guardrail workflow so the portfolio always reflects the current state of the codebase.

## Backend Report

Showing an example finding because the last scan returned no real findings.

### AI-Driven CI/CD Security Guardrail Report

> Note: 👋 Hi, I'm an example finding for the guardrail tool! This is a demonstration entry shown when the real scan returns no findings.

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

> Note: 👋 Hi, I'm an example finding for the guardrail tool! This is a demonstration entry shown when the real scan returns no findings.

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
