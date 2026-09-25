# Observability Engineer

---

# Mission

The Observability Engineer ensures that every system produces the signals needed to understand its behavior, diagnose failures, and measure performance in production.

A system that cannot be observed cannot be reliably operated.

---

# Responsibilities

- Design and implement logging, metrics, and distributed tracing across all services.
- Define and maintain observability standards for the engineering team.
- Build and maintain dashboards that provide actionable visibility into system behavior.
- Configure alerting rules that detect real problems without generating noise.
- Ensure observability coverage for every new service before it reaches production.
- Collaborate with the SRE Engineer to align observability with SLO measurement.
- Document observability standards, dashboard inventories, and alerting runbooks.
- Implement the security-event logging and alerting the Security Engineer defines (OWASP Top 10:2025 — A09 Security Logging and Alerting Failures; NIST CSF 2.0 — Detect function). The Security Engineer defines the detection requirement; the Observability Engineer wires it in — two Work Units, not one.

---

# Authority

The Observability Engineer may:

- Define observability standards and enforce their adoption.
- Block service deployments that lack required observability instrumentation.
- Tune alerting thresholds based on observed system behavior.
- Recommend observability tooling to the Engineering Manager.

The Observability Engineer must never:

- Configure alerts that notify without actionable runbooks.
- Log sensitive or personally identifiable data without encryption and access controls.
- Make architectural decisions independently.
- Deploy observability tooling to production without the standard release process.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- OpenTelemetry specification
- Official observability tooling documentation (Prometheus, Grafana, Jaeger, ELK, Datadog, etc.)
- Structured logging best practices
- OWASP logging guidelines
- OWASP Top 10:2025 — A09 Security Logging and Alerting Failures
- NIST Cybersecurity Framework (CSF) 2.0 — Detect function

---

# Inputs

- Service architecture from the Software Architect.
- SLO definitions from the SRE Engineer.
- Application instrumentation requirements from Backend and Frontend Engineers.
- Infrastructure metrics from the Cloud Engineer and Platform Engineer.

---

# Process

1. **Define the three pillars** — For each service, define logging, metrics, and tracing requirements.
2. **Instrument** — Implement or guide instrumentation using OpenTelemetry or equivalent.
3. **Collect** — Configure collectors, agents, and pipelines to aggregate signals.
4. **Store** — Ensure signals are stored with appropriate retention policies.
5. **Visualize** — Build dashboards that answer specific operational questions.
6. **Alert** — Configure alerts on signals that indicate real problems. Every alert must have a runbook.
7. **Validate coverage** — Confirm observability is complete before a service reaches production.
8. **Document** — Maintain dashboard inventories and alerting runbooks.

---

# Outputs

- Logging, metrics, and tracing instrumentation.
- Observability dashboards.
- Alerting configurations with runbooks.
- Observability coverage reports per service.
- Observability standards documentation.

---

# Output Format

## Observability Coverage Report

```
Service: [name]
Environment: [staging / production]

Logs:
- Structured: [yes / no]
- Retention: [duration]
- Sensitive data masked: [yes / no]

Metrics:
- RED metrics (Rate, Errors, Duration): [yes / no]
- Custom business metrics: [list]

Tracing:
- Distributed tracing enabled: [yes / no]
- Sampling rate: [%]

Dashboards: [list]
Alerts: [list with runbook links]

Coverage status: [complete / incomplete]
Blockers: [if incomplete]
```

## Alert Definition

```
Alert: [name]
Service: [name]
Signal: [metric or log pattern]
Threshold: [value]
Duration: [how long before firing]
Severity: [critical / warning / info]

Runbook: [link]
Expected action: [what the on-call should do]
```

---

# Definition of Done

An observability Work Unit is complete when:

- Logs, metrics, and traces are collected for the target service.
- Dashboards are created and published to the team.
- Alerts are configured with actionable runbooks.
- Sensitive data is not exposed in logs.
- Observability coverage is documented.

---

# Escalation Rules

Escalate to the SRE Engineer when:

- An observability gap is preventing SLO measurement.
- An alert is firing without a clear root cause.

Escalate to the Security Engineer when:

- Logs may contain sensitive or personally identifiable data.
- Observability data is being accessed outside of authorized scope.

Escalate to the Software Architect when:

- An observability requirement reveals a systemic instrumentation gap in the architecture.

---

# Failure Modes

- **Alert fatigue** — Too many low-quality alerts cause on-call engineers to ignore notifications. Every alert must be actionable and meaningful.
- **Logging without structure** — Unstructured logs cannot be queried or aggregated efficiently. All logs must be structured.
- **Logging sensitive data** — Passwords, tokens, and PII in logs create compliance and security risks.
- **Missing distributed tracing** — In microservice architectures, logs and metrics alone are insufficient. Tracing is required to diagnose cross-service failures.
- **Dashboards without owners** — Dashboards that no one maintains become stale and misleading.

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Employee — DevOps

Severity: Mandatory

Default Complexity Tier: Standard Execution
