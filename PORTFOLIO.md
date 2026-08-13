# SEEO portfolio notes

These notes summarize the shipped behavior and engineering boundaries of SEEO without claiming live cloud spend, production scale, or unrun benchmarks.

## Short description

SEEO, a multi-cloud control-plane prototype for short-lived environments across AWS, Azure, Google Cloud, and OCI. It keeps lifecycle state in one place, checks requests with policy-as-code, pushes tenant-scoped updates, expires old environments, estimates cost, and ships with a credential-free mock demo.

## Main portfolio description card

**SEEO Multi-Cloud Orchestrator**

A multi-cloud control-plane prototype for short-lived environments across AWS, Azure, Google Cloud, and OCI. Rails owns authentication, tenant scope, lifecycle state, TTL cleanup, and audit events while provider adapters keep cloud-specific resource calls behind one contract.

**Evidence:** Terraform foundations for four clouds, OPA/Rego policy checks, persisted provider IDs, recurring cleanup scans, tenant-scoped live updates, and a public mock demo that cannot create cloud resources.

**Scope:** The hosted demo runs entirely in mock mode. Credentialed provider execution is intentionally separate and requires a disposable, budget-capped cloud environment.

## Selected engineering work

- Designed a provider-neutral Rails lifecycle contract for AWS, Azure, Google Cloud, OCI, and mock adapters, keeping provider-specific networking, identity, resource shapes, and CLI response parsing behind isolated boundaries. Credentialed provider execution remains unverified.
- Built a React/Vite dashboard with provider-aware regions, normalized lifecycle state, cost estimates, ActionCable updates, retry behavior, keyboard-accessible controls, and responsive mobile layouts.
- Implemented tenant-aware JWT/RBAC authorization, signed browser sessions, idempotent create requests, persisted provider IDs, audit events, policy validation, and recurring TTL cleanup.
- Added Terraform roots for four cloud providers, a credential-free provider runner image, provider response fixtures, subprocess contract tests, RuboCop/RSpec/Brakeman/Checkov CI, and a public mock deployment that cannot create billable resources.

## The scope

The public demo exercises the control-plane lifecycle in multi-cloud mock mode. Provider adapters and contract tests cover command construction and response normalization without credentials. Credentialed provider integration requires a disposable, budget-capped cloud environment and remains separate from the public demo.

The hosted demo does not provision real VMs or create billable cloud resources. The repository does not claim production infrastructure across four clouds or load testing at a specific scale.
