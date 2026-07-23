# Project Charter Template

---

# Usage

A Project Charter is the durable, reviewable record of the business and project answers gathered before any tech-stack discussion begins.

It captures Phase A of the Project Bootstrap Workflow: the business goal, users, scope, success criteria, constraints, compliance, data sensitivity, scale, lifecycle, and stakeholders for a new project — before any technology is chosen.

The Project Charter does not contain technology decisions. The tech-stack decision (Phase B of the Project Bootstrap Workflow) is captured separately as an Architecture Decision Record. Do not add a stack or technical section to this document.

Complete this template with the Director before starting implementation. An implementation that begins without an approved Project Charter has skipped a mandatory step.

The frameworks named in Section 6 (GDPR, HIPAA, PCI, SOC 2, ISO 27001, etc.) are engineering-discovery prompts meant to surface what needs architectural and control attention — they are not a statement of legal completeness, and compliance-engineering interpretation of them is not a substitute for qualified legal counsel. See the Compliance Engineer's Failure Modes for the same caveat applied to that Employee's own output.

---

# Template

```markdown
## Project Charter — [PROJECT-NAME]

**Date:** [YYYY-MM-DD]
**Status:** [Draft | Approved]
**Author:** [Employee name — e.g., Product Manager, Software Architect]
**Approved by:** [Director]

---

### 1. Business Goal

[The problem this project solves, in plain language. One-sentence value proposition: what value exists after this project ships that does not exist today.]

---

### 2. Target Users / Consumers

[Who uses or consumes this system: end users, internal teams, other systems/APIs. Be specific — not "everyone."]

---

### 3. Scope & Non-Goals

**In scope for v1:**
- [Capability 1]
- [Capability 2]

**Explicitly out of scope:**
- [Non-goal 1 — and why it is excluded]
- [Non-goal 2]

---

### 4. Success Criteria

[How "working" is measured. The launch definition of done.]

- [ ] [Measurable criterion 1 — e.g., "95% of requests complete under 200ms"]
- [ ] [Measurable criterion 2]
- [ ] [Launch definition of done]

---

### 5. Constraints

**Deadline:** [date or "none"]
**Budget:** [amount or "none"]
**Team size:** [number of engineers/employees available]
**Existing systems to integrate with:** [system 1, system 2, or "none"]

---

### 6. Compliance / Regulatory

[Applicable regulatory or legal requirements. This list is an engineering-discovery prompt, not a statement of legal completeness — it is not a substitute for qualified legal counsel:]

- **Jurisdictions of operation / data-subject residency:** [whose laws apply — not just where data physically sits, e.g. "none"]
- **GDPR:** [applies / does not apply — details]
- **HIPAA:** [applies / does not apply — details]
- **PCI:** [applies / does not apply — details]
- **Other applicable frameworks (SOC 2, ISO 27001, …):** [applies / does not apply — details]
- **Data residency:** [requirement or "none"]
- **Licensing:** [constraints on dependencies/licenses, or "none"]

---

### 7. Data Sensitivity

[What data this system will hold and how sensitive it is:]

- **PII:** [yes/no — what fields]
- **Special-category data:** [yes/no — which, e.g. health, biometric, or other GDPR Art. 9 categories]
- **Secrets:** [what secrets/credentials the system will manage]
- **Retention:** [how long data must be kept, and how it must be deleted]

---

### 8. Scale Expectations

| Dimension | At launch | At horizon ([timeframe]) |
|---|---|---|
| Users | [estimate] | [estimate] |
| Requests | [estimate] | [estimate] |
| Data volume | [estimate] | [estimate] |

---

### 9. Lifecycle

[Is this a prototype, a product, or a long-lived system?]

**Classification:** [Prototype | Product | Long-lived system]
**Maintenance expectations:** [who maintains it after launch, and for how long]

---

### 10. Stakeholders & Decision Authority

**Director:** [name — final decision authority]
**Other approvers:** [name and role — e.g., Compliance Engineer and Security Engineer for compliance sign-off on Sections 6-7]
**Escalation path:** [who to escalate to if the Director is unavailable]
```

---

# Field Reference

| Field | Purpose | Common mistakes |
|---|---|---|
| Business Goal | States the "why" this project exists at all | Describing a feature instead of the underlying problem |
| Target Users | Defines who the system serves | "Everyone" — too vague to design for |
| Scope & Non-Goals | Bounds v1 — what is deliberately excluded | No non-goals listed, leading to scope creep |
| Success Criteria | Defines what "done" and "working" mean | Subjective criteria that cannot be measured |
| Constraints | Real-world limits on delivery | Omitting team size or existing systems |
| Compliance / Regulatory | Legal and regulatory obligations | Assuming "not applicable" without verifying |
| Data Sensitivity | What data the system must protect | Missing PII or secrets that exist implicitly |
| Scale Expectations | Sizes the system correctly from the start | No horizon estimate — only launch-day numbers |
| Lifecycle | Sets maintenance and investment expectations | Treating every project as a permanent product |
| Stakeholders & Decision Authority | Establishes who approves what | No named Director or escalation path |

---

# Relationship to Other Documents

The Project Charter is Phase A of the Project Bootstrap Workflow — the business and project questions asked before any technology is discussed.

Phase B — the tech-stack decision — is recorded separately using the ADR Template (`Templates/ADR.md`). The Project Charter does not duplicate that content.

---

# Storage Convention

Project Charters are stored in: `Governance/charters/` within the project repository.

File naming: `PROJECT_CHARTER-[kebab-case-project-name].md`

Example: `PROJECT_CHARTER-shop-checkout-service.md`

---

# Metadata

Owner: IA Engineering

Version: 0.0.10

Status: Draft

Category: Template — Product

Severity: Mandatory
