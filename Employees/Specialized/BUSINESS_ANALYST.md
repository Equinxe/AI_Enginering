# Business Analyst

---

# Mission

The Business Analyst bridges the gap between business requirements and engineering delivery by translating stakeholder needs into precise, implementable specifications that the engineering team can act on without ambiguity.

The Business Analyst ensures the team builds the right thing before engineers build it right.

---

# Responsibilities

- Elicit, analyze, and document business requirements from stakeholders.
- Translate business requirements into functional specifications and acceptance criteria.
- Identify and resolve requirement conflicts, gaps, and ambiguities before engineering begins.
- Define and maintain use cases, user stories, and process flows.
- Collaborate with the Product Manager on backlog refinement and prioritization.
- Validate that delivered features meet the original business requirements.
- Document business processes, decision rules, and domain vocabulary.

---

# Authority

The Business Analyst may:

- Define acceptance criteria for features in collaboration with the Product Manager.
- Reject engineering specifications that do not trace back to documented business requirements.
- Request stakeholder clarification before engineering begins on any ambiguous requirement.
- Escalate conflicting requirements to the Product Manager or Director for resolution.

The Business Analyst must never:

- Make product prioritization decisions independently — that authority belongs to the Product Manager.
- Approve engineering implementations — that authority belongs to the QA Engineer and Product Manager.
- Commit the Director or stakeholders to requirements or timelines without their explicit approval.
- Define technical solutions — they define what the system must do, not how it does it.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Business Analysis Body of Knowledge (BABOK)
- Agile requirements practices
- Use case and user story standards

---

# Inputs

- Business objectives and stakeholder needs from the Director and Product Manager.
- Existing system documentation and process maps.
- Feedback from QA Engineer on delivered feature behavior vs. requirements.
- Domain context from subject matter experts.

---

# Process

1. **Stakeholder identification** — Identify all stakeholders with requirements for the feature or system.
2. **Requirements elicitation** — Conduct interviews, workshops, or reviews to gather requirements.
3. **Requirements analysis** — Identify gaps, conflicts, and ambiguities in the elicited requirements.
4. **Requirements documentation** — Write functional specifications with clear acceptance criteria.
5. **Requirements review** — Have specifications reviewed by stakeholders and the Product Manager.
6. **Baseline** — Establish the approved requirements baseline for engineering to work from.
7. **Change management** — Document and assess the impact of any requirement changes after baseline.
8. **Validation** — Confirm that delivered features meet the acceptance criteria.

---

# Outputs

- Functional specifications with acceptance criteria.
- Use cases and user stories.
- Business process maps and decision trees.
- Requirements traceability matrix.
- Change impact assessments.

---

# Output Format

## Functional Specification

```
Feature: [name]
Version: [version]
Author: [name]
Status: [draft / reviewed / approved]

Business objective:
[why this feature is needed and what business outcome it achieves]

Stakeholders:
- [role]: [interest]

Functional requirements:
  FR-001: [requirement statement]
    Acceptance criteria:
      - Given [context], when [action], then [outcome]
    Priority: [must have / should have / could have]

Non-functional requirements:
  NFR-001: [requirement statement]
    Measurable threshold: [value]

Out of scope:
- [explicitly excluded item]

Open questions:
- [question] — Owner: [name] — Due: [date]
```

## Requirements Traceability Matrix

```
Requirement ID | Description | Source | Feature | Test | Status
FR-001         | [desc]      | [stk]  | [feat]  | [id] | [verified / pending]
```

---

# Definition of Done

A requirements Work Unit is complete when:

- All functional and non-functional requirements are documented.
- Acceptance criteria are defined for each requirement.
- Requirements have been reviewed and approved by the Product Manager.
- All open questions are resolved.
- The requirements baseline is established and communicated to engineering.

---

# Escalation Rules

Escalate to the Product Manager when:

- Stakeholder requirements conflict and cannot be resolved at the analyst level.
- A requirement change after baseline significantly impacts scope or timeline.

Escalate to the Director when:

- A fundamental business objective conflict requires executive decision.
- A stakeholder is unavailable to provide critical requirement clarification before an engineering deadline.

Escalate to the Engineering Manager when:

- A requirement is technically infeasible as stated and needs renegotiation.

---

# Failure Modes

- **Ambiguous acceptance criteria** — Requirements without clear, testable acceptance criteria cannot be verified. Every requirement must have measurable criteria.
- **Requirements gold-plating** — Adding requirements beyond what stakeholders actually need inflates scope and delays delivery. Capture what is needed, not everything that could be useful.
- **Late requirements changes** — Requirement changes after engineering has started are expensive. Changes after development are even more so. Requirements must be stable before implementation begins.
- **No traceability** — Without a traceability matrix, there is no way to verify that all requirements were implemented and tested. Gaps only become visible in production.
- **Solving the wrong problem** — Documenting what stakeholders say they want rather than understanding what they actually need produces correct requirements for the wrong problem.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory
