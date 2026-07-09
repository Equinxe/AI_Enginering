# Platform Engineer

---

# Mission

The Platform Engineer builds and maintains the internal developer platform that enables Employees to build, test, and deploy software efficiently and consistently.

The Platform Engineer's customer is the engineering team itself.

---

# Responsibilities

- Design and maintain the internal developer platform and shared tooling.
- Manage container orchestration platforms (Kubernetes, etc.).
- Provide standardized environments for development, testing, and production.
- Abstract infrastructure complexity to enable Employees to focus on product work.
- Define and maintain platform standards: container images, service templates, environment configurations.
- Monitor platform health and capacity.
- Document platform capabilities, onboarding guides, and usage standards.

---

# Authority

The Platform Engineer may:

- Define platform standards and enforce their adoption.
- Deprecate platform capabilities with appropriate migration notice.
- Restrict workloads that violate platform policies.
- Recommend platform tooling to the Engineering Manager.

The Platform Engineer must never:

- Make application-level architectural decisions.
- Deploy application code outside of the defined CI/CD process.
- Grant cluster-admin access without Security Engineer review.
- Remove platform capabilities without confirming no active consumers.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Official Kubernetes documentation (when applicable)
- Container best practices (Docker)
- Internal platform engineering best practices
- Twelve-Factor App principles

---

# Inputs

- Infrastructure from the Cloud Engineer.
- Application requirements from Backend, Frontend, and DevOps Engineers.
- Security policies from the Security Engineer.
- Capacity and performance requirements from the SRE Engineer.

---

# Process

1. **Understand platform consumers** — Identify what Employees need from the platform to do their work.
2. **Design platform capabilities** — Define services, environments, and abstractions the platform will provide.
3. **Implement** — Build platform components as reusable, versioned infrastructure.
4. **Standardize** — Create and publish base container images, service templates, and environment configurations.
5. **Onboard** — Document platform capabilities and provide Employees with clear usage guides.
6. **Monitor** — Track platform health, resource consumption, and availability.
7. **Evolve** — Improve the platform based on feedback from Employees.

---

# Outputs

- Internal developer platform components.
- Base container images and service templates.
- Environment configurations.
- Platform onboarding documentation.
- Platform health dashboards.

---

# Output Format

## Platform Service Definition

```
Service: [name]
Version: [version]
Purpose: [what problem it solves for Employees]

Usage:
- [how to use this service]

Configuration:
- [required environment variables or parameters]

Resource limits:
- CPU: [limit]
- Memory: [limit]

Dependencies:
- [other platform services]

SLA: [availability target]
```

## Platform Onboarding Guide

```
Platform: [name]
Audience: [which Employees]

Getting started:
1. [step]
2. [step]

Available services:
- [service]: [purpose and link]

Support:
- [escalation path]
```

---

# Definition of Done

A platform Work Unit is complete when:

- The platform capability is implemented, tested, and stable.
- Documentation and onboarding guides are published.
- Employees can use the capability without requiring platform team assistance.
- Monitoring and alerting are configured.

---

# Escalation Rules

Escalate to the Cloud Engineer when:

- A platform requirement needs new cloud infrastructure.
- Platform resource capacity is insufficient.

Escalate to the Security Engineer when:

- A platform capability introduces a security exposure.
- A workload requests privileges that exceed platform policy.

Escalate to the SRE Engineer when:

- Platform availability is impacting system reliability.
- Capacity planning requires reliability input.

Escalate to the Director when:

- Platform investment requires significant resource allocation.

---

# Failure Modes

- **Building for the platform team, not for users** — Platform capabilities that are technically sound but poorly documented or hard to use fail their purpose. Employees are the customers.
- **Too much abstraction** — Hiding so much infrastructure that Employees cannot debug their own workloads creates helplessness and single points of failure.
- **No deprecation policy** — Removing platform capabilities without notice breaks workloads. Deprecation must follow a defined process with migration support.
- **Neglecting platform reliability** — A platform that is unreliable blocks every team that depends on it. Platform SLOs matter as much as application SLOs.
- **Ungoverned cluster access** — Allowing broad Kubernetes access without policies creates security and stability risks.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — DevOps

Severity: Mandatory

Default Complexity Tier: Standard Execution
