# Example — Architecture Chain

This example shows an architectural decision on TaskFlow, distinct from the previous examples: the outcome is a decision, not a shipped feature.

Reference: `Core/AGENT_CHAINS.md` — Architecture Chain, `Workflows/ARCHITECTURE_DECISION.md`

---

# Trigger

Director requests: "TaskFlow needs to support recurring tasks (e.g., 'every Monday'). Figure out the best way to model this."

This is an architectural question, not a Work Unit — the data model does not yet support recurrence, and the choice will affect the schema long-term.

---

# Step 1 — Business Analyst

Clarifies the requirement:
- Recurrence patterns needed: daily, weekly, monthly, custom interval.
- A recurring task generates new task instances; it is not a single mutable task.
- Users must be able to edit a single instance without affecting the whole series.

**Output:** Functional requirements documented.

---

# Step 2 — Software Architect

Evaluates options and drafts an ADR (`Templates/ADR.md`):

```markdown
## ADR-TASKFLOW-005 — Recurring Task Modeling

**Status:** Proposed

**Context:** TaskFlow needs recurring tasks. The current schema models one row per task with no concept of a series.

**Options considered:**
1. Store a recurrence rule on the task; generate instances on read (computed, not persisted).
2. Store a recurrence rule on a parent "series" record; generate and persist child task rows on a schedule.
3. Require the client to create each occurrence manually (no server-side recurrence).

**Decision:** We will implement Option 2 — persisted child rows.
**Rationale:** Option 1 breaks per-instance editing (nothing to attach the edit to). Option 3 pushes complexity to every client. Option 2 supports per-instance edits and keeps query performance predictable at TaskFlow's expected scale.

**Consequences:**
- New `task_series` table.
- A background job to generate future instances is required — new operational dependency.
- Existing task queries must exclude series metadata rows.
```

**Output:** ADR-TASKFLOW-005 drafted, status Proposed.

---

# Step 3 — Solution Architect (Cross-System Impact)

Reviews whether this affects other systems consuming TaskFlow's task data (e.g., a notifications service that reads task rows directly).

**Finding:** The notifications service filters on `status`, not on row type — it would incorrectly pick up series metadata rows unless explicitly excluded.

**Added to ADR:** Consequence — notifications service query must be updated in a coordinated Work Unit before this ships.

---

# Step 4 — Technical Lead (Feasibility)

Confirms the background job infrastructure needed for Option 2 already exists in TaskFlow's stack (a cron-based job runner is already used for other periodic tasks) — no new infrastructure dependency.

**Output:** Feasibility confirmed, no new infrastructure risk.

---

# Step 5 — Main Agent → Director (Decision Gate)

> "ADR-TASKFLOW-005 recommends modeling recurring tasks as a parent series with persisted child instances. This requires a new background job and a coordinated update to the notifications service. Requesting decision: Accept, Reject, or request changes."

**Director accepts.** ADR status: **Accepted**.

---

# Step 6 — Handoff to Feature Chain

**Engineering Manager** decomposes the accepted ADR into Work Units:
- WU-TASKFLOW-020: Add `task_series` table and model.
- WU-TASKFLOW-021: Add background job to generate instances.
- WU-TASKFLOW-022: Update notifications service query to exclude series metadata.

Each proceeds through the **Feature Chain** independently.

---

# What This Example Demonstrates

- Why an architectural question is routed through the Architecture Chain rather than jumping straight to a Work Unit — the decision must exist and be approved before implementation is scoped.
- Why the Solution Architect step exists separately from the Software Architect step — cross-system impact (the notifications service) would have been missed otherwise.
- How an Accepted ADR becomes multiple Work Units that then each run through the Feature Chain — the Architecture Chain produces decisions; the Feature Chain produces code.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Orchestration

Severity: Reference
