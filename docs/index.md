---
title: SEEO | Multi-cloud Control-plane Prototype
description: SEEO, a multi-cloud control-plane prototype for short-lived environments across AWS, Azure, Google Cloud, and OCI.
last_modified_at: 2026-08-13
og_type: website
layout: default
permalink: /
---

<p class="project-badges">
  <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml"><img src="https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml/badge.svg" alt="CI workflow status" /></a>
  <a href="https://www.ruby-lang.org/"><img src="https://img.shields.io/badge/ruby-3.3-cc0000.svg" alt="Ruby 3.3" /></a>
  <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT license" /></a>
</p>

<h1>SEEO, a multi-cloud control-plane prototype for short-lived environments</h1>

<p><strong>SEEO</strong> brings a Rails control plane, React dashboard, provider adapters, policy checks, lifecycle state, live updates, and cleanup into one focused system for temporary environments across AWS, Azure, Google Cloud, and OCI.</p>

<div class="demo-cta">
  <div>
    <p class="demo-cta__eyebrow">Safe hosted demo</p>
    <p class="demo-cta__copy">The public dashboard runs in mock mode. It does not require provider credentials or create cloud resources.</p>
  </div>
  <a class="btn" href="https://seeo-dashboard.vercel.app/" target="_blank" rel="noopener noreferrer">Open the dashboard</a>
</div>

<h2>Implementation</h2>

<ul>
  <li>A provider-neutral lifecycle contract keeps cloud-specific behavior behind separate adapters.</li>
  <li>Rails owns authentication, tenant scope, policy checks, normalized state, cost estimates, and TTL cleanup.</li>
  <li>The React dashboard shows provider-aware environment requests, lifecycle state, costs, and authorized updates.</li>
</ul>

<h2>Engineering approach</h2>

<p>I kept the control plane independent from provider infrastructure state, made ownership part of every request path, and used the same adapter boundary for the hosted mock experience and the unverified credentialed CLI paths. That makes the public demo safe to evaluate while keeping the engineering boundary visible in the source.</p>

<h2>The scope</h2>

<p>The hosted demo exercises the control-plane lifecycle without cloud credentials or billable resources. Provider adapters, response fixtures, Terraform foundations, policy checks, and cleanup behavior are implemented and tested. Credentialed AWS, Azure, Google Cloud, and OCI provisioning remains unverified and is not presented as a live feature.</p>

<h2>Explore the project</h2>

<p><a class="btn" href="https://seeo-dashboard.vercel.app/" target="_blank" rel="noopener noreferrer">Open the live demo</a> <a class="btn" href="{{ '/architecture/' | relative_url }}">Read the architecture</a></p>

<p>Run the <a href="{{ '/demo/' | relative_url }}">test instructions</a> or inspect the <a href="https://github.com/samueladegnan/seeo-aws-orchestrator">source repository</a>.</p>

<p class="ai-disclosure"><strong>Ownership:</strong> I own the architecture, implementation, testing, security model, documentation, and final review. AI tools supported parts of the build as a secondary development aid.</p>
