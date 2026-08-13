---
title: Architecture | Rails, React, Terraform, and Multi-cloud Adapters
description: Explore SEEO's Rails control plane, provider adapters, policy checks, lifecycle state, ActionCable updates, and Terraform foundations.
keywords:
  - cloud control plane architecture
  - provider adapter pattern
  - Rails ActionCable
  - Terraform multi-cloud
  - OPA policy
last_modified_at: 2026-08-13
og_type: article
mermaid: true
layout: default
permalink: /architecture/
---

# SEEO Architecture

SEEO gives AWS, Azure, Google Cloud, and OCI one lifecycle contract. Rails owns authentication, authorization, policy, environment state, audit events, cost estimates, live updates, and TTL cleanup. Provider adapters own the cloud-specific resource calls.

## High-level flow

1. The React dashboard or Rails API receives a request with a provider, region, compute tier, storage tier, TTL, and project.
2. Rails authenticates the requester, resolves the team and role, and establishes the ownership context.
3. Policy validates the provider allow-list, provider-specific region, resource tiers, TTL, storage size, and team capacity.
4. `CloudAdapter.for` selects the adapter for AWS, Azure, Google Cloud, OCI, or mock mode.
5. The adapter creates the provider resources and writes normalized identifiers to the Rails control-plane database after each successful operation.
6. ActionCable broadcasts state changes to the authorized team or browser-session stream.
7. `TtlMonitorJob` scans every enabled provider and invokes the same cleanup contract for expired records.
8. Terraform roots provide the provider network and identity foundations consumed by the matching adapter.

## Lifecycle state and request pipeline

The lifecycle diagram distinguishes request pipeline stages from persisted records. `active` maps to `ready` in the Rails model and `failed` maps to `error`.

```mermaid
flowchart LR
  requested[requested] --> authorized[authorized]
  authorized --> validated[validated]
  validated --> provisioning[provisioning]
  provisioning --> active[active<br/>ready]
  provisioning --> failed[failed<br/>error]
  active --> expired[expired]
  expired --> cleanup[cleanup]
  cleanup --> terminated[terminated]
  cleanup --> retrying[retrying]
  retrying --> cleanup
  failed --> retrying
```

## Provider adapter architecture

```mermaid
flowchart TB
  api[Rails API] --> control[Auth, ownership, policy, state]
  control --> contract[CloudAdapter contract]
  contract --> aws[AwsService]
  contract --> azure[AzureService]
  contract --> gcp[GcpService]
  contract --> oci[OciService]
  contract --> mock[MockCloudService]
  aws --> awscli[AWS CLI argv]
  azure --> azcli[Azure CLI argv]
  gcp --> gcloud[Google Cloud CLI argv]
  oci --> ocicli[OCI CLI argv]
  mock --> memory[(In-memory mock store)]
  awscli --> records[(EnvironmentRecord)]
  azcli --> records
  gcloud --> records
  ocicli --> records
  terraform[Terraform foundations] -. network and identity outputs .-> aws
  terraform -. network and identity outputs .-> azure
  terraform -. network and identity outputs .-> gcp
  terraform -. network and identity outputs .-> oci
```

## Tenant and authorization model

```mermaid
flowchart LR
  tenant[Tenant] --> team[Team]
  team --> user[User and role]
  user --> rbac[RBAC]
  jwt[JWT tenant token] --> user
  demo[Demo API key] --> session[Signed browser session]
  session --> ownership[Session ownership]
  user --> cable[Signed ActionCable token]
  session --> cable
  cable --> stream[Derived team or session stream]
  team --> resource[EnvironmentRecord]
  user --> resource
  ownership --> resource
  rbac --> resource
```

## Component diagram

The diagram below follows the request from the browser to the provider boundary. Each lane is intentionally readable on its own: on smaller screens the lanes stack instead of shrinking a large SVG until its labels become unreadable.

<section class="architecture-diagram" aria-labelledby="architecture-diagram-title">
  <div class="architecture-diagram__header">
    <div>
      <span class="architecture-diagram__eyebrow">Request path</span>
      <h3 id="architecture-diagram-title">One control plane, four provider boundaries</h3>
    </div>
    <p>Solid arrows show lifecycle flow. Dashed links represent Terraform outputs supplied to the matching adapter.</p>
  </div>

  <div class="architecture-lane architecture-lane--request">
    <div class="architecture-lane__label">1. Request</div>
    <div class="architecture-flow">
      <div class="architecture-node architecture-node--external"><strong>Developer or service account</strong><span>Chooses provider, region, tier, storage, and TTL</span></div>
      <span class="architecture-arrow" aria-hidden="true">→</span>
      <div class="architecture-node architecture-node--external"><strong>React dashboard</strong><span>Creates and observes environments</span></div>
      <span class="architecture-arrow" aria-hidden="true">→</span>
      <div class="architecture-node architecture-node--primary"><strong>Rails API</strong><span>Single lifecycle entry point</span></div>
    </div>
  </div>

  <div class="architecture-lane architecture-lane--control">
    <div class="architecture-lane__label">2. Control plane</div>
    <div class="architecture-node-grid">
      <div class="architecture-node"><strong>Auth &amp; ownership</strong><span>JWT, demo sessions, RBAC, tenant scope</span></div>
      <div class="architecture-node"><strong>Policy gate</strong><span>Provider, region, TTL, tiers, storage, capacity</span></div>
      <div class="architecture-node"><strong>Adapter factory</strong><span><code>CloudAdapter.for</code> selects the boundary</span></div>
      <div class="architecture-node"><strong>Rails state</strong><span>Lifecycle, IDs, audit events, cost estimates</span></div>
      <div class="architecture-node"><strong>Live updates &amp; cleanup</strong><span>ActionCable streams and <code>TtlMonitorJob</code></span></div>
    </div>
  </div>

  <div class="architecture-lane architecture-lane--providers">
    <div class="architecture-lane__label">3. Provider boundary</div>
    <div class="architecture-provider-grid">
      <div class="architecture-node architecture-node--provider"><strong>AWS</strong><span>VM and storage</span></div>
      <div class="architecture-node architecture-node--provider"><strong>Azure</strong><span>VM and disk</span></div>
      <div class="architecture-node architecture-node--provider"><strong>Google Cloud</strong><span>GCE VM and persistent disk</span></div>
      <div class="architecture-node architecture-node--provider"><strong>OCI</strong><span>Compute and block volume</span></div>
      <div class="architecture-node architecture-node--mock"><strong>Mock adapter</strong><span>Safe browser-visible demo path</span></div>
    </div>
  </div>

  <div class="architecture-lane architecture-lane--terraform">
    <div class="architecture-lane__label">4. Terraform inputs</div>
    <div class="architecture-flow architecture-flow--terraform">
      <div class="architecture-node architecture-node--terraform"><strong>Independent provider roots</strong><span>AWS · Azure · Google Cloud · OCI</span></div>
      <span class="architecture-arrow architecture-arrow--dashed" aria-hidden="true">⇢</span>
      <div class="architecture-node architecture-node--terraform"><strong>Network &amp; identity outputs</strong><span>Consumed by the matching runtime adapter</span></div>
    </div>
  </div>
</section>

<details>
<summary>Accessible text version</summary>
<p>A developer or service account sends a provider, region, tier, storage, and TTL to the React dashboard or Rails API. Rails authenticates the requester, applies ownership and policy checks, then selects one provider adapter. The adapter creates or removes provider resources and writes normalized lifecycle state to Rails. ActionCable sends authorized updates to the owning team or browser session. Terraform roots provide network and identity outputs to the matching adapter.</p>
</details>

<pre><code>Developer or service account
        |
        v
React dashboard or Rails API
        |
        v
Auth, ownership, policy, adapter factory, Rails state
        |
        +--> AWS
        +--> Azure
        +--> Google Cloud
        +--> OCI
        +--> Mock adapter
        ^
        |
Terraform network and identity outputs</code></pre>

## Provider contract

The controller does not call EC2, Azure Compute, Compute Engine, or OCI directly. It calls the shared lifecycle methods:

- `create_environment(project, ttl_minutes, compute_tier, options)`
- `list_environments(status_filter)`
- `refresh_environment_state(environment_id)`
- `terminate_environment(environment_id)`
- `list_expired_environments`
- `force_terminate_environment(environment_id)`

Every adapter returns the same `Environment` shape. Provider-specific details remain in `provider_resource_id`, `provider_resource_type`, `instance_type`, and `volume_type` for operational visibility, while `provider`, `compute_tier`, `storage_tier`, `region`, and `ttl_minutes` remain normalized.

## Control-plane state

Rails stores environment lifecycle state in its own database. This keeps tenant ownership, idempotency, auditability, and TTL recovery independent from any provider's data store. Terraform state remains provider-specific and is never used as the request-time environment database.

This separation is deliberate: a provider outage must not erase the control plane's knowledge of what should be cleaned up. The trade-off is that cleanup must tolerate partial operations, stale provider IDs, and asynchronous provider failures.

## Why the adapters stay separate

The lifecycle is normalized, not the cloud APIs. Each adapter owns its provider's networking, identity, resource shapes, CLI commands, and response parsing. That keeps controllers, policy, persistence, and the dashboard provider-neutral. The cost is some intentional duplication between adapters rather than leaking four clouds into every layer.

The real adapters currently use CLI boundaries because argv construction and JSON normalization are easy to inspect with checked-in fixtures and subprocess contract tests. A credential-free runner image packages the four CLIs, while direct SDK workers remain a future option if richer typed APIs or higher execution volume justify the added coupling.

## Infrastructure

Each Terraform root can be initialized and validated without unrelated provider credentials. Real adapter runners additionally need the selected cloud CLI, image settings, short-lived workload identity, and provider integration tests:

- AWS: VPC, subnets, security group, IAM, state-supporting services, logs, and registry
- Azure: resource group, virtual network, and subnet
- Google Cloud: VPC network and subnetwork
- OCI: VCN and subnet

The roots export network identifiers for the matching runtime adapter. AWS, Azure, Google Cloud, and OCI runners normalize their native CLI responses before writing control-plane state. `backend/Dockerfile.runner` packages the four CLIs without credentials. Authentication is supplied at runtime through workload identity or standard environment configuration and is never committed.

## Expiry and recovery

Every environment has an expiry time. `TtlMonitorJob` scans enabled providers and retries cleanup using the persisted provider IDs, making temporary infrastructure harder to forget than to delete. Cleanup is asynchronous by design and must tolerate provider failures.

## Built-in security controls

- JWT tenant authentication and signed mock browser sessions
- RBAC for viewer, operator, and administrator roles
- Provider-aware OPA/Rego policy with a Ruby fallback
- Team and browser-session ownership filtering
- Signed ActionCable tokens with server-derived stream authorization
- Audit events in the shared Rails control plane
- Explicit provider resource IDs for partial cleanup and retry
- No committed provider credentials, Terraform secret values, or browser-authorized real cloud credentials
