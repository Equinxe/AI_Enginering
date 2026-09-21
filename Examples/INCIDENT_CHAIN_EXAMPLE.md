# Example — Incident Chain

This example shows a production incident on TaskFlow, distinct from the Hotfix Chain example: here the service is degraded for all users, not a single reproducible defect.

Reference: `Core/AGENT_CHAINS.md` — Incident Chain, `Workflows/INCIDENT_RESPONSE.md`

---

# Trigger

TaskFlow's database connection pool is exhausted. All API requests are timing out. SRE Engineer detects the alert.

---

# Step 1 — SRE Engineer: Detection and Severity

- Confirms: 100% of requests timing out, all users affected.
- Classifies: **P1** — critical, full outage.

---

# Step 2 — Engineering Manager: Assign Incident Commander

Engineering Manager assigns the SRE Engineer as Incident Commander for this incident — the first qualified engineer available, per `Workflows/INCIDENT_RESPONSE.md`. The Incident Commander owns the incident end-to-end and coordinates every actor below.

---

# Step 3 — Main Agent → Director (Mandatory Notification)

> "P1 incident declared: TaskFlow API fully down, database connection pool exhausted. Incident Commander is containing now. Will update within 15 minutes."

**P1/P2 notification to Director is mandatory and immediate** — not after resolution.

This is the one gate in the framework that does **not** pause the chain (`Registry/workflows.yml` records it as `notification_only`). Containment proceeds while the Director is informed, because withholding mitigation to wait for an approval would worsen the incident. The containment action here lands at the `Critical` tier — a source of truth is unavailable and every user is affected — and `Standards/RISK_STANDARD.md`'s *Relationship to Incident Response* clause governs the interaction exactly: during a declared P1/P2 incident a **reversible** containment action MAY proceed on the Incident Commander's judgment without the Critical tier's pre-action stop, on three conditions — **(a)** it is genuinely reversible, **(b)** the mandatory P1/P2 notification has been made (Step 3 above), and **(c)** the independent verification pass Critical requires is still performed, moved to immediately after containment (Step 4) rather than waived. All three hold here, so the action is recorded as it happens rather than escalated before it:

```
RISK: raising the connection-pool ceiling on a live production database |
      tier=Critical | mitigation=reversible by reverting the config; P1 notification made (Step 3);
      independent post-hoc verification by the Observability Engineer (Step 4) |
      decided_by=Director (notified Step 3, confirmation quoted in the post-mortem)
```

An irreversible containment action — dropping connections, truncating a table — would **not** qualify under that clause: it fails condition (a), so it stops for an explicit Director decision naming the action even mid-incident, `Critical` requiring a named Director decision *and* an independent verification pass. Speed never converts an irreversible Critical action into a proceed-on-judgment one.

---

# Step 4 — Containment

**Incident Commander (SRE Engineer) + Engineering Manager:**
- Incident Commander restarts the connection pool and applies a temporary connection limit increase to stop the immediate bleeding.
- Engineering Manager coordinates — confirms no other team is mid-deploy, ensures single point of action.

**Post-hoc independent verification (Critical tier, condition (c) from Step 3):**
- **Observability Engineer** — *not* the Incident Commander who applied the change — independently confirms from the dashboards, immediately after containment, that the raised connection-pool ceiling took effect, that request success rate has recovered, and that the higher ceiling has introduced no new failure mode (no database CPU or memory pressure from the added connections). This is the independent verification pass Critical requires, performed *after* containment rather than before it, per `Standards/RISK_STANDARD.md`'s *Relationship to Incident Response* clause. Its result is recorded for the post-mortem.

**Result:** Service restored within 12 minutes, containment independently verified. Root cause not yet fixed — this is mitigation, not resolution.

---

# Step 5 — Root Cause Fix

Investigation finds a recent Work Unit (WU-TASKFLOW-011, merged two days prior) introduced a query that does not release its connection on a specific error path.

Since this requires a code change to production:

**Handoff to Hotfix Chain** (see `Examples/HOTFIX_CHAIN_EXAMPLE.md` for that chain's mechanics) — Director authorizes, Engineer fixes the connection leak, Code Reviewer + QA Engineer validate, Director approves, Release Manager merges as `v1.3.2`.

---

# Step 6 — Recovery Confirmation

**SRE Engineer:**
- Confirms connection pool metrics are stable for 30 minutes post-deploy.
- Removes the temporary connection limit workaround now that the real fix is live.

---

# Step 7 — Post-Mortem

**Engineering Manager**, using `Templates/INCIDENT_REPORT.md`:

```markdown
**Incident:** INC-TASKFLOW-003
**Severity:** P1
**Duration:** 12 minutes to mitigation, 3 hours to full resolution

**5 Whys:**
1. Why did the API go down? — Connection pool exhausted.
2. Why was it exhausted? — Connections were not released on one error path.
3. Why weren't they released? — WU-TASKFLOW-011 added a new query without a `finally` block for cleanup.
4. Why wasn't this caught in review? — The error path was not covered by a test case.
5. Why was there no test for that path? — Test Plan for WU-TASKFLOW-011 covered the success path only.

**Root cause:** Missing connection cleanup on an untested error path.

**Corrective actions:**
- [DEF-TASKFLOW-019] Add connection-pool exhaustion alert threshold (owner: SRE Engineer)
- [DEF-TASKFLOW-020] Add error-path test requirement to Code Review checklist (owner: Code Reviewer)
```

**Blameless** — the report identifies the missing test coverage as a process gap, not an individual's fault.

---

# Step 8 — Deliver (Main Agent → Director)

> "Incident INC-TASKFLOW-003 resolved. Root cause: unreleased DB connection on an untested error path. Fixed via hotfix v1.3.2. Two corrective actions opened to prevent recurrence. Full report attached."

---

# What This Example Demonstrates

- The difference between the Incident Chain (service-level degradation, unknown cause) and the Hotfix Chain (known code defect) — and how an incident hands off into a hotfix once the root cause is identified.
- Why mitigation and resolution are tracked as separate steps — restoring service is not the same as fixing the cause.
- Why the post-mortem is blameless and produces process corrective actions, not individual blame.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Orchestration

Severity: Reference
