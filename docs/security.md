---
title: Security Report | Brakeman and Guardrail v1.1.0
description: Learn how SEEO uses Brakeman and AI CI/CD Security Guardrail v1.1.0 to review Rails security findings with clearly labeled example data.
layout: default
permalink: /security/
security_report: true
---

<div class="security-report-page">
  <section class="security-report-header" aria-labelledby="security-report-title">
    <div class="report-status-label"><span class="status-dot status-dot--example" aria-hidden="true"></span> Example report. Live scan unavailable</div>
    <h1 id="security-report-title">Security Report</h1>
    <p class="security-report-lead">This page shows the report format used by SEEO's security workflow. CI runs Brakeman against the Rails backend, then passes the SARIF output to AI CI/CD Security Guardrail v1.1.0 for triage. The workflow preserves the reports as build artifacts for engineering review.</p>
    <dl class="security-report-details">
      <div>
        <dt>Source scan</dt>
        <dd>Brakeman SARIF from <code>backend/</code><br><a href="https://github.com/samueladegnan/ai-cicd-security-guardrail/releases/tag/v1.1.0">AI Guardrail v1.1.0</a></dd>
      </div>
      <div>
        <dt>Triage provider</dt>
        <dd>Deterministic mock provider. Source stays in CI.</dd>
      </div>
      <div>
        <dt>Report scope</dt>
        <dd>SEEO <code>backend/</code> tree</dd>
      </div>
    </dl>
    <p class="security-report-meta security-report-timestamp">Guardrail v1.1.0 is pinned in the GitHub Actions workflow. This page is a portfolio presentation of the workflow, not a live scan result.</p>
  </section>

  <div class="report-disclaimer" role="note">
    <strong>How to read this report:</strong> these are automated triage results, not a guarantee that the repository is vulnerability-free. Findings should be verified by an engineer before they are accepted or dismissed.
  </div>

  <div class="empty-state" role="status">
    <span class="empty-icon" aria-hidden="true">&#8987;</span>
    <h2>Live report pending</h2>
    <p>The latest CI artifact is not embedded in this Pages build. The report below uses clearly labeled sample data so the page remains useful. The source SARIF and Guardrail outputs remain available from the GitHub Actions run artifacts.</p>
  </div>

  <div class="example-report-notice" role="status">
    <span class="example-report-notice__label">Example report</span>
    <h2>Illustrative findings are shown below</h2>
    <p>The latest CI artifact is not embedded in this page. The findings below are sample data used to demonstrate the report interface. They are not issues found in the SEEO repository.</p>
  </div>

  <section class="summary-card" aria-labelledby="summary-title">
    <div class="summary-header">
      <div>
        <h2 id="summary-title" class="summary-title">Example triage summary</h2>
        <p class="summary-subtitle">Sample values only. Check the CI artifact for a specific run.</p>
      </div>
      <span class="example-badge">Example data</span>
    </div>
    <div class="summary-metrics">
      <div class="metric-card metric-total"><span class="metric-value">2</span><span class="metric-label">Total examples</span></div>
      <div class="metric-card metric-high"><span class="metric-value">0</span><span class="metric-label">High priority</span></div>
      <div class="metric-card metric-fp"><span class="metric-value">0</span><span class="metric-label">False positives</span></div>
      <div class="metric-card metric-unclear"><span class="metric-value">2</span><span class="metric-label">Review needed</span></div>
    </div>
  </section>

  <section class="results-card" aria-labelledby="results-title">
    <div class="summary-header">
      <div>
        <h2 id="results-title" class="summary-title">Example findings</h2>
        <p class="summary-subtitle">Each result is clearly marked as sample data.</p>
      </div>
      <span class="example-badge">Not a live scan</span>
    </div>

    <div class="results-table-wrap">
      <table class="guardrail-table">
        <thead>
          <tr>
            <th scope="col">Finding</th>
            <th scope="col">Location</th>
            <th scope="col">Category</th>
            <th scope="col">Severity</th>
            <th scope="col">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>Audit log metadata exposure</strong><br><small>Example finding</small></td>
            <td class="finding-loc"><code>backend/app/services/audit_log_service.rb</code><br><small>Example line 42</small></td>
            <td>Information disclosure</td>
            <td><span class="guardrail-badge verdict-unclear">Low</span></td>
            <td><span class="guardrail-badge verdict-unclear">Review</span></td>
          </tr>
          <tr>
            <td><strong>WebSocket subscription identity</strong><br><small>Example finding</small></td>
            <td class="finding-loc"><code>frontend/src/App.jsx</code><br><small>Example line 365</small></td>
            <td>Authentication</td>
            <td><span class="guardrail-badge verdict-unclear">Low</span></td>
            <td><span class="guardrail-badge verdict-unclear">Review</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <hr>

  <h2>Example finding details</h2>

  <section class="detail-block" aria-labelledby="finding-one-title">
    <h3 id="finding-one-title">Example 1. Audit log metadata exposure</h3>
    <p><strong>Risk:</strong> a hypothetical serializer that records an entire environment object could expose infrastructure metadata that operators do not need for forensics.</p>
    <p><strong>Recommendation:</strong> keep the audit schema explicit. Log the environment ID, project, actor, action, and timestamp. Redact provider-specific identifiers unless an operational use case requires them.</p>
    <p class="muted"><strong>Example finding.</strong> This is not a Brakeman result from the current repository.</p>
  </section>

  <section class="detail-block" aria-labelledby="finding-two-title">
    <h3 id="finding-two-title">Example 2. WebSocket subscription identity</h3>
    <p><strong>Risk:</strong> a hypothetical client subscription without server-side identity checks could expose environment updates to an unauthorized connection.</p>
    <p><strong>Recommendation:</strong> authenticate the ActionCable connection and authorize the requested tenant before subscribing. SEEO now uses a short-lived signed connection token and a server-issued signed demo-session token instead of treating client-provided identifiers as proof of identity.</p>
    <p class="muted"><strong>Example finding.</strong> This is not a confirmed issue in the current repository.</p>
  </section>

  <hr>

  <h2>Verification workflow</h2>

  <ol>
    <li>Static analysis produces a machine-readable SARIF report.</li>
    <li>Guardrail v1.1.0 adds repository context and maps relevant controls.</li>
    <li>Triage classifies each result as high priority, review, or false positive.</li>
    <li>Engineering review confirms exploitability and updates the code or report disposition.</li>
    <li>CI artifacts preserve the source SARIF and Guardrail output for auditability.</li>
  </ol>

  <p><a href="https://github.com/samueladegnan/ai-cicd-security-guardrail">Read the Guardrail project</a> or <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/.github/workflows/guardrail.yml">view the workflow</a>.</p>

  <p class="ai-disclosure">I built and reviewed this portfolio project with AI assistance. AI tools helped with exploration, implementation, documentation, and testing. I remain responsible for the architecture, engineering decisions, testing, and final code.</p>
</div>
