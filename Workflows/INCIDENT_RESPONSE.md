# Incident Response Workflow

---

# Purpose

This workflow defines the process for detecting, containing, resolving, and learning from production incidents.

An incident is any unplanned disruption or degradation of a production system that impacts users or business operations. Every incident follows this workflow — no exceptions.

---

# Trigger

- Automated alert from monitoring or observability platform.
- User or stakeholder reports a production issue.
- Engineer detects anomalous behavior in production.

---

# Severity Levels

| Severity | Definition | Response time |
|---|---|---|
| P1 — Critical | Total outage or data loss. All users affected. | Immediate — within 15 minutes |
| P2 — High | Major feature unavailable. Significant user impact. | Within 30 minutes |
| P3 — Medium | Degraded performance or partial feature failure. | Within 2 hours |
| P4 — Low | Minor issue with minimal user impact. | Next business day |

P1 and P2 require Director notification. P3 and P4 are handled by the Engineering Manager.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Incident Commander | Owns the incident from detection to resolution. Coordinates all actors. |
| Director | Notified for P1/P2. Makes business decisions during the incident. |
| Engineering Manager | Assigns Incident Commander, coordinates team resources |
| SRE Engineer | Monitors systems, leads technical diagnosis |
| Observability Engineer | Provides logs, metrics, and traces for diagnosis |
| On-call Engineer | Implements fixes under Incident Commander direction |
| Security Engineer | Engaged if the incident has a security dimension |

The Incident Commander role is assigned at the start of the incident. It does not default to the most senior engineer — it defaults to the first qualified engineer available.

---

# Prerequisites

- Observability platform is configured with alerts and dashboards.
- On-call rotation is defined and current.
- Incident communication channel is available (dedicated channel or thread).

---

# Steps

## Step 1 — Detect and declare

**Actor:** First responder (any engineer or automated alert)

1. Confirm the incident is real — rule out false positives.
2. Declare the incident and assign an initial severity level.
3. Notify the Engineering Manager immediately.
4. Open the incident communication channel.

**Output:** Incident declared, Engineering Manager notified.

---

## Step 2 — Assign Incident Commander

**Actor:** Engineering Manager

1. Assign an Incident Commander for this incident.
2. Notify the Director if severity is P1 or P2.

**Output:** Incident Commander assigned, Director notified if P1/P2.

---

## Step 3 — Assess and communicate

**Actor:** Incident Commander

1. Assess the scope: what is broken, who is affected, what is the business impact.
2. Post an initial status update in the incident channel within 15 minutes of declaration:
   - What is happening
   - Who is affected
   - What the team is doing right now
   - Next update time
3. Update status at regular intervals (every 30 minutes for P1/P2, hourly for P3).

**Output:** Initial status communicated. Regular updates scheduled.

---

## Step 4 — Diagnose

**Actor:** SRE Engineer + Observability Engineer

1. Collect logs, metrics, and traces from the time of incident onset.
2. Identify the timeline of events leading to the incident.
3. Form hypotheses about the root cause.
4. Test hypotheses systematically — do not apply fixes before diagnosis is complete unless the impact is escalating.

**Output:** Root cause hypothesis documented.

---

## Step 5 — Contain

**Actor:** Incident Commander + On-call Engineer

1. Apply the fastest available mitigation to reduce user impact, even if it does not fully resolve the issue:
   - Rollback to the previous stable version.
   - Feature flag disable.
   - Traffic rerouting.
   - Scaling up resources.
2. Confirm containment: user impact is reduced or stopped.
3. Update the incident status channel.

**Output:** Incident contained. User impact reduced.

---

## Step 6 — Resolve

**Actor:** On-call Engineer + Technical Lead

1. Implement the definitive fix based on the diagnosed root cause.
2. If the fix requires a code change: follow the Hotfix Workflow.
3. Verify the fix resolves the incident completely.
4. Confirm production systems are healthy via observability dashboards.

**Output:** Incident resolved. Systems healthy.

---

## Step 7 — Declare resolution

**Actor:** Incident Commander

1. Confirm resolution with the SRE Engineer and Observability Engineer.
2. Post a resolution update in the incident channel:
   - What was resolved
   - When resolution was confirmed
   - Any remaining monitoring or follow-up actions
3. Notify the Director if P1/P2.

**Output:** Incident declared resolved. Director notified.

---

## Step 8 — Post-mortem

**Actor:** Incident Commander + all involved actors

Mandatory for all P1 and P2 incidents. Recommended for P3.

1. Schedule the post-mortem within 48 hours of resolution.
2. Write the post-mortem document:
   - Timeline of events
   - Root cause (confirmed, not hypothesized)
   - Impact summary
   - What went well
   - What went wrong
   - Action items with owners and due dates
3. Present to the Director and Engineering Manager.
4. Track action items to completion.

Post-mortems are blameless. The goal is systemic improvement, not individual accountability.

**Output:** Post-mortem document published. Action items tracked.

---

# Exit Criteria

This workflow is complete when:

- Production systems are confirmed healthy.
- Incident is declared resolved.
- Director is notified (P1/P2).
- Post-mortem is completed and action items are assigned (P1/P2 mandatory).

---

# Escalation

| Situation | Escalate to |
|---|---|
| P1/P2 incident | Director — immediately upon declaration |
| Security dimension detected | Security Engineer — immediately |
| Resolution requires architectural change | Software Architect |
| Incident involves data loss or breach | Director + Compliance Engineer + Security Engineer — immediately |

---

# Related Workflows

- Hotfix Workflow
- Release Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Workflow — Operations

Severity: Mandatory
