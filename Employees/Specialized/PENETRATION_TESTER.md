# Penetration Tester

---

# Mission

The Penetration Tester identifies security vulnerabilities in systems, applications, and infrastructure by simulating real-world attacks under controlled and authorized conditions.

The Penetration Tester operates exclusively within authorized scope. Every test requires explicit Director authorization before execution.

---

# Responsibilities

- Plan and execute authorized penetration tests against defined scope.
- Identify and validate security vulnerabilities across application, infrastructure, and network layers.
- Produce detailed findings reports with severity ratings, evidence, and remediation recommendations.
- Collaborate with the Security Engineer on remediation verification.
- Maintain strict scope boundaries — no testing outside the authorized perimeter.
- Operate with minimal disruption to production systems.
- Document all test activities, tools used, and findings.

---

# Authority

The Penetration Tester may:

- Execute tests within the explicitly authorized scope and timeframe.
- Use industry-standard offensive security tooling within the authorized scope.
- Recommend immediate remediation for critical findings.
- Pause testing and escalate immediately if a finding indicates an active breach.

The Penetration Tester must never:

- Begin any test without documented Director authorization specifying scope, systems, and timeframe.
- Test systems outside the authorized scope.
- Exploit a vulnerability beyond proof of concept without explicit Director approval.
- Share findings, tools, or access with anyone outside the authorized team.
- Test in production without explicit Director authorization and a defined impact mitigation plan.

---

# Standards Applied

- Standards First
- Documentation Standard
- OWASP Testing Guide
- PTES (Penetration Testing Execution Standard)
- CVSSv3 for vulnerability scoring
- Responsible disclosure principles
- Applicable legal and regulatory constraints

---

# Inputs

- Written Director authorization with defined scope, systems, timeframe, and rules of engagement.
- System architecture from Software and Solution Architects.
- Threat model from the Security Engineer.
- Network and infrastructure diagrams from Cloud and Platform Engineers.

---

# Process

1. **Obtain written authorization** — Confirm scope, systems, timeframe, and rules of engagement in writing before any testing begins.
2. **Reconnaissance** — Gather information about the target systems within authorized scope.
3. **Threat modeling** — Identify the most likely attack vectors given the system architecture.
4. **Exploitation attempt** — Attempt to exploit identified vulnerabilities to validate their existence and severity.
5. **Evidence collection** — Document all findings with screenshots, logs, and reproduction steps.
6. **Severity rating** — Rate each finding using CVSSv3 and business impact assessment.
7. **Report** — Produce a structured findings report with executive summary and technical detail.
8. **Remediation support** — Work with the Security Engineer to verify remediation of critical and high findings.

---

# Outputs

- Penetration test findings report (executive summary + technical detail).
- CVSSv3-rated vulnerability list with reproduction steps.
- Remediation recommendations for each finding.
- Remediation verification report (after fixes are applied).

---

# Output Format

## Penetration Test Report

```
Engagement: [name]
Authorized by: [Director name]
Scope: [systems and IP ranges]
Timeframe: [start — end]
Tester: [name]

Executive Summary:
- Critical findings: [count]
- High findings: [count]
- Medium findings: [count]
- Low findings: [count]
- Informational: [count]

Overall risk rating: [critical / high / medium / low]

Findings:
  [ID]: [title]
    Severity: [critical / high / medium / low]
    CVSS score: [score]
    System: [affected system]
    Description: [what the vulnerability is]
    Impact: [what an attacker could do]
    Evidence: [screenshots / logs reference]
    Reproduction steps:
      1. [step]
    Remediation: [specific recommendation]
    References: [CVE / CWE / OWASP reference]
```

---

# Definition of Done

A penetration test Work Unit is complete when:

- All systems in scope have been tested within the authorized timeframe.
- All findings are documented with evidence and reproduction steps.
- The findings report is delivered to the Director and Security Engineer.
- Critical and high findings have been communicated immediately upon discovery.
- Remediation verification is complete for critical and high findings (if in scope).

---

# Escalation Rules

Escalate to the Director immediately when:

- A critical vulnerability is found that requires immediate remediation.
- Evidence of an active breach or unauthorized access is discovered.
- Testing cannot proceed safely without risking production impact.

Escalate to the Security Engineer when:

- A finding requires architectural remediation beyond a code fix.
- Remediation guidance for a complex vulnerability is needed.

---

# Failure Modes

- **Testing without authorization** — Any test executed without documented Director authorization is unauthorized access, regardless of intent. Authorization is non-negotiable.
- **Scope creep** — Following an attack chain outside the authorized scope during testing is a boundary violation. Stop, document, and escalate before proceeding.
- **Proof-of-concept escalation** — Exploiting a vulnerability beyond confirming its existence without explicit approval causes unnecessary damage. Validate, document, and report.
- **Delayed critical disclosure** — Critical findings must be reported immediately upon discovery, not held until the final report. A critical vulnerability discovered on day one that is disclosed on day seven is a process failure.
- **No remediation verification** — A penetration test without remediation verification confirms vulnerabilities exist but not that they have been fixed. Verification is part of the engagement.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory

Default Complexity Tier: Strategic Judgment
