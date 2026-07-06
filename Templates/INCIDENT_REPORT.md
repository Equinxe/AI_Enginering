# Incident Report Template

---

# Usage

An Incident Report (post-mortem) is mandatory for all P1 and P2 incidents and recommended for P3.

It must be completed within 48 hours of incident resolution.

Post-mortems are blameless. The goal is systemic improvement, not individual accountability.

Follow the Incident Response Workflow when responding to a production incident.

---

# Template

```markdown
## Incident Report — [INC-ID]

**Date of incident:** [YYYY-MM-DD]
**Date of report:** [YYYY-MM-DD]
**Severity:** [P1 | P2 | P3 | P4]
**Status:** [Resolved]
**Incident Commander:** [name]
**Author:** [name]
**Reviewed by:** [Director / Engineering Manager]

---

### Summary

[One paragraph: what happened, what was the user impact, how long did it last, and how was it resolved. Written for a non-technical reader.]

---

### Impact

**Duration:** [start time] → [resolution time] — Total: [X hours Y minutes]

**Users affected:** [count or percentage]

**Systems affected:**
- [system name]: [description of impact]

**Business impact:**
- [revenue, SLA breach, data loss, reputation — quantify where possible]

---

### Timeline

[Chronological sequence of events. Use UTC timestamps. Be specific.]

| Time (UTC) | Event |
|---|---|
| [HH:MM] | [What happened — detection, escalation, diagnosis, containment, resolution steps] |
| [HH:MM] | [...] |

---

### Root Cause

[The confirmed root cause of the incident. Not a hypothesis — this is written after investigation is complete.

Use the "5 Whys" format if helpful:
- Why did X fail? Because Y.
- Why did Y occur? Because Z.
- ...]

---

### Contributing Factors

[Conditions that made the incident worse or allowed it to happen, even if they were not the direct cause:]
- [Factor 1]
- [Factor 2]

---

### What Went Well

[Things that worked during the incident response:]
- [e.g., Monitoring alert fired within 2 minutes of onset]
- [e.g., Rollback procedure was documented and executed successfully]

---

### What Went Wrong

[Things that did not work or could have been better:]
- [e.g., Alert threshold was too high — 8 minutes elapsed before detection]
- [e.g., Runbook for this service was outdated]

---

### Action Items

[Concrete improvements to prevent recurrence or improve response. Each item must have an owner and a due date.]

| Action | Owner | Due date | Status |
|---|---|---|---|
| [description] | [employee] | [YYYY-MM-DD] | [open / in progress / complete] |

---

### Lessons Learned

[Key insights from this incident that should inform how the team builds and operates systems going forward.]

---

### Detection and Response Metrics

| Metric | Value | Target |
|---|---|---|
| Time to detection | [duration] | [SLO target] |
| Time to acknowledgment | [duration] | [SLO target] |
| Time to containment | [duration] | [SLO target] |
| Time to resolution | [duration] | [SLO target] |
```

---

# Incident ID Convention

Format: `INC-[project]-[sequential number]`

Example: `INC-SHOP-014`

IDs are assigned by the Incident Commander and are unique per project.

---

# Storage Convention

Incident reports are stored in: `docs/incidents/` or `Governance/incidents/` within the project repository.

File naming: `INC-[ID]-[YYYY-MM-DD]-[kebab-case-title].md`

Example: `INC-SHOP-014-2026-07-06-database-connection-pool-exhaustion.md`

---

# Metadata

Owner: IA Engineering

Version: 0.0.5

Status: Draft

Category: Template — Operations

Severity: Mandatory
