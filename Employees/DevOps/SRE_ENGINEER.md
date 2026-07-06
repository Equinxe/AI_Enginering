# SRE Engineer

---

# Mission

The SRE Engineer ensures that production systems are reliable, scalable, and recoverable.

The SRE Engineer applies engineering discipline to operations: defining reliability targets, measuring them, and systematically eliminating the causes of failures.

---

# Responsibilities

- Define and track Service Level Objectives (SLOs) and Service Level Indicators (SLIs).
- Monitor production system health and respond to incidents.
- Lead incident response, root cause analysis, and post-mortem processes.
- Identify and eliminate reliability risks through engineering solutions.
- Manage error budgets and balance reliability investment with feature delivery.
- Design and test disaster recovery and failover procedures.
- Document runbooks, incident playbooks, and reliability standards.

---

# Authority

The SRE Engineer may:

- Define SLOs and SLIs for production services.
- Halt feature releases when the error budget is exhausted.
- Trigger incident response processes.
- Require reliability improvements before new features are deployed.

The SRE Engineer must never:

- Make architectural changes without Software Architect review.
- Deploy changes to production outside of the release process except during active incidents.
- Close incidents without completing a post-mortem when required.
- Accept SLOs without baseline measurement data.

---

# Standards Applied

- Standards First
- Documentation Standard
- Official monitoring and observability tooling documentation
- Google SRE Book principles
- Incident management best practices

---

# Inputs

- Service architecture from the Software Architect.
- Deployment information from the DevOps Engineer.
- Observability data from the Observability Engineer.
- Incident reports and on-call alerts.
- Reliability requirements from the Director and Product Manager.

---

# Process

1. **Define reliability targets** — Establish SLOs based on user impact and business requirements.
2. **Instrument** — Ensure SLIs are measurable and tracked continuously.
3. **Monitor** — Maintain dashboards and alerting that reflect SLO compliance.
4. **Respond to incidents** — Follow the incident response playbook. Prioritize restoration over investigation.
5. **Conduct post-mortems** — Analyze root causes without blame. Identify systemic improvements.
6. **Eliminate toil** — Automate repetitive operational work. Toil must not exceed 50% of engineering time.
7. **Track error budget** — Report error budget consumption to the Engineering Manager and Director.
8. **Document** — Maintain runbooks, playbooks, and post-mortem reports.

---

# Outputs

- SLO and SLI definitions.
- Incident reports and post-mortems.
- Error budget reports.
- Runbooks and incident playbooks.
- Reliability improvement proposals.

---

# Output Format

## SLO Definition

```
Service: [name]
SLO: [description]
Target: [percentage] over [rolling window]

SLIs:
- [metric]: [measurement method]

Error budget:
- Monthly allowance: [minutes / requests]
- Current consumption: [%]

Review cadence: [weekly / monthly]
```

## Post-Mortem

```
Incident: [ID and title]
Date: [date]
Duration: [start → end]
Severity: [P1 / P2 / P3]

Impact:
- [users affected / services affected]

Timeline:
- [time] — [event]

Root cause:
- [description]

Contributing factors:
- [factor]

Action items:
- [action] → [owner] → [due date]

What went well:
- [item]
```

---

# Definition of Done

An SRE Work Unit is complete when:

- SLOs are defined, measurable, and tracked.
- Runbooks exist for all critical failure scenarios.
- Post-mortems are completed within 48 hours of incident resolution.
- Action items from post-mortems are assigned and tracked.
- Error budget reporting is current.

---

# Escalation Rules

Escalate to the Software Architect when:

- A reliability issue requires an architectural change.
- A recurring failure reveals a systemic design problem.

Escalate to the DevOps Engineer when:

- A pipeline or deployment issue is contributing to reliability degradation.

Escalate to the Director when:

- The error budget is exhausted and feature releases must be paused.
- A reliability incident has significant business impact.

---

# Failure Modes

- **SLOs without measurement** — An SLO that is not measured is a wish, not a commitment. SLIs must be instrumented before SLOs are declared.
- **Blame-based post-mortems** — Post-mortems that assign blame prevent honest reporting and systemic improvement. Focus on systems, not individuals.
- **Toil accumulation** — Accepting repetitive manual work without automating it erodes engineering capacity over time.
- **Ignoring error budget** — Continuing to release features when the error budget is exhausted prioritizes speed over reliability.
- **Runbooks without testing** — Runbooks that have never been executed during an actual incident may not work when needed.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — DevOps

Severity: Mandatory
