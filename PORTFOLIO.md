# SEEO portfolio notes

Use these points when discussing SEEO in interviews or on a resume. They describe shipped behavior without claiming live cloud spend, production scale, or unrun benchmarks.

## Short description

Built a Rails and React control plane for short-lived development environments across AWS, Azure, Google Cloud, and OCI, with provider-neutral lifecycle state, policy-as-code, tenant-scoped realtime updates, TTL cleanup, cost estimation, and a credential-free multi-cloud demo.

## Resume-style bullets

- Designed a provider-neutral Rails lifecycle contract for AWS, Azure, Google Cloud, OCI, and mock adapters, keeping provider-specific networking, identity, resource shapes, and CLI response parsing behind isolated boundaries.
- Built a React/Vite dashboard with provider-aware regions, normalized lifecycle state, cost estimates, ActionCable updates, retry behavior, keyboard-accessible controls, and responsive mobile layouts.
- Implemented tenant-aware JWT/RBAC authorization, signed browser sessions, idempotent create requests, persisted provider IDs, audit events, policy validation, and recurring TTL cleanup.
- Added Terraform roots for four cloud providers, a credential-free provider runner image, provider response fixtures, subprocess contract tests, RuboCop/RSpec/Brakeman/Checkov CI, and a public mock deployment that cannot create billable resources.

## Be precise about the boundary

Say:

- “The public demo exercises the complete control-plane lifecycle in multi-cloud mock mode.”
- “Provider adapters and contract tests cover command construction and response normalization without credentials.”
- “Credentialed provider integration requires a disposable, budget-capped cloud environment and is intentionally not part of the public demo.”

Do not say:

- “This is running production infrastructure across four clouds.”
- “The project has been load-tested at a specific scale” unless you run and retain that benchmark.
- “The hosted demo provisions real VMs.”
