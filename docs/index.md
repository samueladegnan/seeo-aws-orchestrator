---
title: SEEO | Secure Ephemeral Environment Orchestrator
description: Samuel Degnan's SEEO project: a multi-cloud control plane for requesting, observing, and expiring short-lived environments.
layout: default
permalink: /
---

<p class="project-badges">
  <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml"><img src="https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml/badge.svg" alt="SEEO CI" /></a>
  <a href="https://www.ruby-lang.org/"><img src="https://img.shields.io/badge/ruby-3.3-cc0000.svg" alt="Ruby 3.3" /></a>
  <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT" /></a>
</p>

<h2>A practical multi-cloud platform for short-lived environments</h2>

<p><strong>SEEO</strong> is my dashboard and API for requesting temporary environments across AWS, Azure, Google Cloud, and OCI. A provider-neutral adapter contract keeps the lifecycle consistent while each cloud maps the request to its own region, compute shape, storage class, and resource identifiers.</p>

<hr>

<h2>What it does</h2>

<ul>
  <li><strong>Multi-cloud lifecycle:</strong> the same create, refresh, terminate, and expiry flow accepts AWS, Azure, Google Cloud, and OCI as first-class providers.</li>
  <li><strong>Provider-neutral state:</strong> the control plane stores the selected provider, region, normalized tiers, ownership, expiry, and provider resource IDs without using one cloud as the system of record.</li>
  <li><strong>Multi-tenancy and RBAC:</strong> team and owner identifiers keep one tenant from reading or changing another tenant's environments.</li>
  <li><strong>Policy checks:</strong> OPA/Rego validates provider, region, TTL, resource tiers, storage, and capacity, with a built-in Ruby fallback.</li>
  <li><strong>Cost estimates:</strong> the dashboard estimates compute and storage cost with provider-specific rates.</li>
  <li><strong>Real-time updates:</strong> signed ActionCable tokens authorize the right team or browser-session stream.</li>
  <li><strong>Safe demos:</strong> hosted and local mock mode supports all four providers without creating cloud resources.</li>
  <li><strong>Infrastructure foundations:</strong> independent Terraform roots establish the network and identity boundary for every supported cloud.</li>
  <li><strong>Security checks:</strong> Brakeman output is triaged by Guardrail in CI, with source reports preserved as build artifacts.</li>
</ul>

<hr>

<h2>How it works</h2>

<div class="steps" markdown="1">
<div class="step" markdown="1">
<h3>1. Request</h3>
<p>A developer requests an environment through the React dashboard or Rails API, specifying a cloud provider, region, compute tier, storage tier, TTL, and optional idempotency key.</p>
</div>
<div class="step" markdown="1">
<h3>2. Authorize and validate</h3>
<p>SEEO verifies the JWT or scoped demo key, checks RBAC and ownership, validates the selected provider's region, and runs policy rules before any cloud call.</p>
</div>
<div class="step" markdown="1">
<h3>3. Provision</h3>
<p>The adapter factory selects the provider implementation. Each adapter maps normalized tiers to native VM and storage resources, then records the resulting provider IDs in the shared Rails control plane.</p>
</div>
<div class="step" markdown="1">
<h3>4. Observe and expire</h3>
<p>ActionCable streams authorized state changes while the TTL job scans every enabled provider and retries cleanup for expired environments.</p>
</div>
</div>

<hr>

<h2>Engineering focus</h2>

<ul>
  <li><strong>One lifecycle, four clouds:</strong> provider differences stay inside adapters rather than leaking into controllers, policies, or the dashboard.</li>
  <li><strong>Failure-aware cleanup:</strong> provider resource identifiers are persisted as they are acquired so partial operations can be recovered.</li>
  <li><strong>Provider-aware policy:</strong> regions and resource classes are validated against the selected cloud, not one global AWS-shaped list.</li>
  <li><strong>Production discipline:</strong> the repository includes tenant-scoped WebSockets, policy enforcement, structured logs, Docker support, automated tests, and CI security review.</li>
</ul>

<h2>About the build</h2>

<p>I built and reviewed SEEO with AI assistance. I remain responsible for the architecture, engineering decisions, testing, security model, and final code.</p>

<h2>Why this is a useful engineering sample</h2>

<ul>
  <li><strong>It is operable:</strong> lifecycle state is persisted, resources expire, cleanup retries, and health is visible.</li>
  <li><strong>It is safe to evaluate:</strong> the public demo uses no provider credentials and cannot create billable resources.</li>
  <li><strong>It is honest about scope:</strong> mock lifecycle behavior, adapter contracts, and Terraform foundations are demonstrated; credentialed cloud integration remains an explicit next step.</li>
</ul>


<h2>About the author</h2>

<p>Built by <a href="https://samueladegnan.github.io/">Samuel Degnan</a> as a hands-on portfolio project focused on full-stack engineering, policy-as-code, and reliable multi-cloud orchestration.</p>
