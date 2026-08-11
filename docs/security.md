---
title: Security Report | SEEO
description: Samuel Degnan's security report for the SEEO Rails backend, with Brakeman and Guardrail review notes.
layout: default
permalink: /security/
security_report: true
---

<div class="security-report-page">
  <div class="report-status-label"><span class="status-dot status-dot--example" aria-hidden="true"></span> Pending <code>backend/</code> self-assessment</div>
  <h1>Security report</h1>
  <p class="security-report-intro">This is the security report for SEEO, a project built and maintained by Samuel Degnan. It covers the Rails backend and records the scan scope and review notes alongside the rest of this case study.</p>

  <dl class="security-report-details">
    <div>
      <dt>Source scan</dt>        <dd>Brakeman SARIF from <code>backend/</code> · triaged by <a href="https://github.com/samueladegnan/ai-cicd-security-guardrail/releases/tag/v1.1.0">AI Guardrail v1.1.0</a></dd>
    </div>
    <div>
      <dt>Triage provider</dt>
      <dd>Deterministic mock provider. Source stays in CI.</dd>
    </div>
    <div>
      <dt>Report scope</dt>
      <dd>SEEO <code>backend/</code> tree</dd>
    </div>
    <div>
      <dt>Project owner</dt>
      <dd>Samuel Degnan</dd>
    </div>
  </dl>

  <p class="security-report-meta security-report-timestamp">Published with the Pages build. The workflow runs in CI; this page does not embed its generated artifact.</p>

  <div class="report-disclaimer" role="note">
    <strong>How to read this report:</strong> these are automated triage results, not a guarantee that the repository is vulnerability-free. Verify findings with an engineer before accepting or dismissing them.
  </div>

  <h2>Scoped scan findings</h2>
  <p class="security-report-lead">Findings from the SEEO backend self-assessment.</p>

  <div class="live-scan-pending" role="status">
    <span class="live-scan-pending__icon" aria-hidden="true">⌛</span>
    <div>
      <span class="live-scan-pending__label">Live report pending</span>
      <h3>The latest CI report is not embedded here yet</h3>
      <p>The generated report remains in the CI artifact for each workflow run. Until a Pages build embeds that artifact, the dashboard below uses clearly labeled example data so the review format remains inspectable. <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/guardrail.yml">Open the Guardrail workflow and choose a run</a>.</p>
    </div>
  </div>

  <div class="example-report-notice" role="status">
    <span class="example-report-notice__label">Illustrative findings are shown below</span>
    <p>These committed examples are not issues in this repository. They demonstrate how Brakeman and Guardrail results are presented and reviewed.</p>
  </div>

  <section class="summary-card" aria-labelledby="summary-title">
    <div class="summary-header">
      <div>
        <h2 id="summary-title" class="summary-title">Illustrative triage summary</h2>
        <p class="summary-subtitle">Example values only. Check the CI artifact for a specific run.</p>
      </div>
      <span class="example-badge">Example data</span>
    </div>
    <div class="summary-metrics">
      <div class="metric-card metric-total"><span class="metric-value">2</span><span class="metric-label">Example items</span></div>
      <div class="metric-card metric-high"><span class="metric-value">0</span><span class="metric-label">High priority</span></div>
      <div class="metric-card metric-fp"><span class="metric-value">0</span><span class="metric-label">False positives</span></div>
      <div class="metric-card metric-unclear"><span class="metric-value">2</span><span class="metric-label">Review examples</span></div>
    </div>
  </section>

  <section class="results-card" aria-labelledby="results-title">
    <div class="summary-header">
      <div>
        <h2 id="results-title" class="summary-title">Illustrative findings</h2>
        <p class="summary-subtitle">Each result is sample data, not a live scan result.</p>
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
            <td><strong>Audit log metadata exposure</strong><br><small>Illustrative finding</small></td>
            <td class="finding-loc"><code>backend/app/services/audit_log_service.rb</code><br><small>Example line 42</small></td>
            <td>Information disclosure</td>
            <td><span class="guardrail-badge verdict-unclear">Low</span></td>
            <td><span class="guardrail-badge verdict-unclear">Review</span></td>
          </tr>
          <tr>
            <td><strong>Provider command boundary</strong><br><small>Illustrative finding</small></td>
            <td class="finding-loc"><code>backend/app/services/cli_cloud_service.rb</code><br><small>Example line 118</small></td>
            <td>Command execution</td>
            <td><span class="guardrail-badge verdict-unclear">Low</span></td>
            <td><span class="guardrail-badge verdict-unclear">Review</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <hr>

  <h2>Illustrative finding details</h2>

  <section class="detail-block" aria-labelledby="finding-one-title">
    <h3 id="finding-one-title">Example 1. Audit log metadata exposure</h3>
    <p><strong>Risk:</strong> a hypothetical serializer that records an entire environment object could expose infrastructure metadata that operators do not need for forensics.</p>
    <p><strong>Recommendation:</strong> keep the audit schema explicit. Log the environment ID, project, actor, action, and timestamp. Redact provider-specific identifiers unless an operational use case requires them.</p>
    <p class="muted"><strong>Illustrative example.</strong> This is not a Brakeman result from the current repository.</p>
  </section>

  <section class="detail-block" aria-labelledby="finding-two-title">
    <h3 id="finding-two-title">Example 2. Provider command boundary</h3>
    <p><strong>Risk:</strong> a hypothetical command runner that interpolates untrusted request data into a shell string could allow argument injection across a provider boundary.</p>
    <p><strong>Recommendation:</strong> pass provider commands as argv arrays, validate policy before execution, and keep credentials outside request data. SEEO's adapters use structured subprocess arguments and contract fixtures.</p>
    <p class="muted"><strong>Illustrative example.</strong> This is not a confirmed issue in the current repository.</p>
  </section>

  <hr>

  <h2>Verification workflow</h2>

  <ol>
    <li>Brakeman produces a machine-readable SARIF report for the Rails backend.</li>
    <li>Guardrail v1.1.0 adds repository context and maps relevant controls.</li>
    <li>Triage classifies each result as high priority, review, or false positive.</li>
    <li>Engineering review confirms exploitability and updates the code or report disposition.</li>
    <li>CI artifacts preserve the source SARIF and Guardrail output for auditability.</li>
  </ol>

  <p><a href="https://github.com/samueladegnan/ai-cicd-security-guardrail">Read the Guardrail project</a> or <a href="https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/.github/workflows/guardrail.yml">view the workflow</a>.</p>
</div>
