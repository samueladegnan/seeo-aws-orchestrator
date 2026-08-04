---
title: SEEO | Secure Ephemeral AWS Environments
description: SEEO provisions short-lived AWS environments with Rails, React, Terraform, RBAC, policy checks, live updates, and automatic TTL cleanup.
layout: default
permalink: /
---

<p class="project-badges">
  <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml"><img src="https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml/badge.svg" alt="SEEO CI" /></a>
  <a href="https://www.ruby-lang.org/"><img src="https://img.shields.io/badge/ruby-3.3-cc0000.svg" alt="Ruby 3.3" /></a>
  <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT" /></a>
</p>

<h2>A secure, short-lived environment platform</h2>

<p><strong>SEEO</strong> provisions short-lived AWS EC2 environments through a React dashboard or REST API. It handles authentication, policy checks, audit logging, cost estimates, and automatic cleanup.</p>

<hr>

<h2>What it does</h2>

<ul>
  <li><strong>Multi-tenancy and RBAC:</strong> persists team and owner identifiers so one tenant cannot read or affect another's environments.</li>
  <li><strong>Policy checks:</strong> OPA/Rego validates every provision request, with a built-in Ruby fallback when OPA is not installed.</li>
  <li><strong>Audit logging:</strong> every create/destroy event is recorded with the actor and timestamp.</li>
  <li><strong>Cost estimates:</strong> rough per-environment and per-team cost based on instance type, volume, and TTL.</li>
  <li><strong>Real-time updates:</strong> short-lived signed ActionCable tokens authorize tenant or browser-session streams before state changes reach the React dashboard.</li>
  <li><strong>Observability:</strong> structured JSON logs ready for CloudWatch or a SIEM pipeline.</li>
  <li><strong>Security checks:</strong> Brakeman findings are triaged by Guardrail v1.1.0 in CI, with the source reports preserved as build artifacts.</li>
</ul>

<hr>

<h2>How it works</h2>

<div class="steps" markdown="1">

<div class="step" markdown="1">

<h3>1. Request</h3>

<p>A developer requests an environment through the React dashboard or the Rails API, specifying a project, TTL, and optional idempotency key.</p>

</div>

<div class="step" markdown="1">

<h3>2. Authorize and validate</h3>

<p>SEEO verifies the JWT or scoped API key, checks RBAC and ownership, and runs policy checks.</p>

</div>

<div class="step" markdown="1">

<h3>3. Provision</h3>

<p>SEEO reserves the environment record, launches the EC2 instance, attaches storage, and records the lifecycle event.</p>

</div>

<div class="step" markdown="1">

<h3>4. Observe and expire</h3>

<p>ActionCable streams authorized state changes while the internal TTL job tears down expired environments. Partial provider cleanup is recorded for retry.</p>

</div>

</div>

<hr>

<h2>About the author</h2>

<p>Built by <a href="https://samueladegnan.github.io/">Samuel Degnan</a> as a hands-on portfolio project focused on full-stack engineering, policy-as-code, and secure cloud orchestration.</p>

<p class="ai-disclosure"><strong>How this portfolio piece was made:</strong> I built and reviewed this project with AI assistance. I remain responsible for the architecture, engineering decisions, testing, and final code.</p>
