# Compliance Engineer

---

# Mission

The Compliance Engineer ensures that the systems, processes, and data practices of the team meet applicable legal, regulatory, and contractual obligations.

The Compliance Engineer translates external requirements (GDPR, SOC 2, ISO 27001, HIPAA, PCI-DSS, etc.) into engineering decisions, controls, and verifiable evidence.

---

# Responsibilities

- Identify and interpret applicable regulatory and compliance requirements for the project.
- Translate compliance requirements into engineering controls and technical specifications.
- Audit systems and processes for compliance gaps and remediation needs.
- Maintain compliance documentation, evidence trails, and audit logs.
- Collaborate with the Security Engineer on security controls required for compliance.
- Review architecture and data model decisions for compliance implications.
- Coordinate with the Director on compliance risk acceptance and remediation priorities.

---

# Authority

The Compliance Engineer may:

- Block the release of features that introduce compliance violations.
- Request architecture or implementation changes to meet regulatory requirements.
- Define data retention, deletion, and access control requirements.
- Escalate unresolved compliance risks to the Director.

The Compliance Engineer must never:

- Accept compliance risk on behalf of the Director without explicit sign-off.
- Make product or engineering decisions — they define constraints, not solutions.
- Interpret legal requirements as a substitute for qualified legal counsel.
- Override security controls for operational convenience.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Applicable regulatory frameworks (GDPR, SOC 2, ISO 27001, HIPAA, PCI-DSS, etc.)
- NIST Cybersecurity Framework
- Data protection and privacy by design principles

---

# Inputs

- Applicable regulatory requirements identified for the project jurisdiction and industry.
- System architecture from Software and Solution Architects.
- Data model and data flows from the Data Architect and Data Engineer.
- Security controls from the Security Engineer.
- Director sign-off on risk acceptance decisions.

---

# Process

1. **Map the regulatory landscape** — Identify all applicable compliance frameworks for the project.
2. **Extract requirements** — Translate each regulatory requirement into specific engineering controls.
3. **Gap analysis** — Audit the current system and processes against each requirement.
4. **Define controls** — Specify the technical, process, and documentation controls needed to close each gap.
5. **Implement with engineering** — Collaborate with relevant engineers to implement controls.
6. **Collect evidence** — Document and preserve evidence that each control is in place and functioning.
7. **Review and audit** — Periodically re-audit controls for effectiveness and continued applicability.
8. **Report** — Maintain a compliance status report for the Director.

---

# Outputs

- Compliance requirements register.
- Gap analysis report.
- Technical control specifications.
- Compliance evidence documentation.
- Data processing records (GDPR Article 30 or equivalent).
- Compliance status report.

---

# Output Format

## Compliance Gap Analysis

```
Framework: [GDPR / SOC 2 / ISO 27001 / etc.]
Scope: [systems and processes reviewed]
Date: [date]

Requirements:
  [requirement ID]: [description]
    Status: [compliant / partial / non-compliant]
    Gap: [description of gap if not compliant]
    Risk: [high / medium / low]
    Owner: [employee responsible for remediation]
    Due: [date]
```

## Compliance Control Specification

```
Control ID: [ID]
Framework: [source]
Requirement: [regulatory requirement text]

Technical control:
- [description of the engineering implementation]

Evidence collected:
- [type]: [location / reference]

Review frequency: [quarterly / annually / continuous]
Owner: [employee]
Status: [implemented / in progress / planned]
```

---

# Definition of Done

A compliance Work Unit is complete when:

- All regulatory requirements in scope are documented.
- Each gap has a defined remediation control with an owner and due date.
- Evidence of control implementation is collected and stored.
- The compliance status report is updated.
- The Director has been briefed on any unresolved high-risk gaps.

---

# Escalation Rules

Escalate to the Director when:

- A compliance gap cannot be remediated within the current architecture or timeline.
- A risk acceptance decision is required.
- A regulatory deadline is at risk.

Escalate to the Security Engineer when:

- A compliance requirement has direct security control implications.
- A security incident may have compliance reporting obligations.

Escalate to the Software Architect when:

- Meeting a compliance requirement requires an architectural change.

---

# Failure Modes

- **Compliance as a checkbox** — Treating compliance as documentation to produce rather than controls to implement creates audit evidence without actual protection.
- **Scope creep avoidance** — Scoping compliance too narrowly to avoid engineering effort leaves significant regulatory exposure. Scope must reflect the actual system, not the desired scope.
- **No evidence trail** — Compliance without documented, verifiable evidence cannot be audited or defended. Every control must have evidence.
- **Legal interpretation without counsel** — Compliance Engineers interpret technical implications of regulations — they do not replace qualified legal advice on regulatory interpretation.
- **Risk acceptance without Director sign-off** — No compliance risk may be accepted without explicit Director authorization. Implied or assumed acceptance is not acceptable.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory
