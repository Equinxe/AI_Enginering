# Example — Feature Chain

This example walks through the Feature Chain end-to-end on a fictional project, **TaskFlow** (a task management API), to show how the Orchestration Protocol, Agent Chains, and Templates work together in practice.

Reference: `Core/AGENT_CHAINS.md` — Feature Chain, `Workflows/FEATURE_DEVELOPMENT.md`

---

# Director Request

> "Users need to be able to mark a task as complete. Add that."

---

# Step 1 — Receive (Main Agent)

Extracted:

- **Objective:** Users can mark a task as complete via the API.
- **Scope:** New endpoint, no changes to task creation or listing.
- **Constraints:** Must follow existing REST conventions in TaskFlow.
- **Missing information:** None — request is clear enough to proceed.

---

# Step 2 — Analyze (Main Agent)

- **Chain selected:** Feature Chain
- **Employees required:** Business Analyst → Software Architect → Backend Engineer → Code Reviewer → QA Engineer. The chain's decomposition step is the Main Agent's own Step 3, below — not a dispatch (`Core/AGENT_CHAINS.md`, Work Unit Decomposition).
- **Workflow:** `Workflows/FEATURE_DEVELOPMENT.md`
- **ADR required?** No — no architectural change, existing REST pattern applies.
- **Director pre-approval required?** Only for the Work Unit plan (Step 3).

---

# Step 3 — Plan (Main Agent)

## Work Unit — WU-TASKFLOW-014

```markdown
**Objective:** Add an endpoint to mark a task as complete.

**Context:** TaskFlow tasks currently support create, read, update, delete. There is no dedicated way to mark completion without a full update call.

**Inputs:**

- Existing task schema: `models/task.py`
- Existing router pattern: `routes/tasks.py`

**Outputs:**

- `PATCH /tasks/{id}/complete` endpoint
- Unit tests for success and not-found cases

**Definition of Done:**

- Endpoint returns 200 with the updated task on success.
- Endpoint returns 404 if the task does not exist.
- Endpoint returns 409 if the task is already complete.
- Tests written and passing.
- PR opened, Code Reviewer assigned.

**Standards:** Code Quality Standard, Testing Standard, REST conventions already used in TaskFlow.

**Expected Commit:** `feat(tasks): add PATCH /tasks/{id}/complete endpoint`
```

**Presented to Director → Approved.**

---

# Step 4 — Dispatch (Main Agent)

Sequential dispatch (each output feeds the next):

```
Business Analyst → Software Architect → Backend Engineer → Code Reviewer → QA Engineer
```

## Employee Brief — WU-TASKFLOW-014 (excerpt, sent to Backend Engineer)

```markdown
**To:** Backend Engineer
**Work Unit:** WU-TASKFLOW-014

**Your Assignment:** Implement PATCH /tasks/{id}/complete.

**Why This Matters:** Users have no way to mark a task done without overwriting the whole record. This closes that gap.

**What You Need to Know:**
**Stack:** Python / FastAPI
**Current state:** `routes/tasks.py` has create/read/update/delete. `models/task.py` has a `status` field with values `open`, `complete`.

**Your Inputs:**

- [x] `models/task.py` — status field already exists
- [x] `routes/tasks.py` — existing router pattern to follow

**Your Outputs:**

- [ ] PATCH /tasks/{id}/complete endpoint
- [ ] Unit tests: success, not-found, already-complete

**Constraints:**

- Do not modify the update (PUT) endpoint — that is out of scope.
- Do not add new dependencies.

**Expected Commit:** `feat(tasks): add PATCH /tasks/{id}/complete endpoint`
```

---

# Step 5 — Collect (Main Agent)

Each Employee returns a **Work Unit Report** (`Templates/WORK_UNIT_REPORT.md`), and the Main Agent verifies its claims against the repository rather than accepting them — `Core/ORCHESTRATION.md` Step 5:

| Employee | Report verdict | What the Main Agent re-verified, and how |
|---|---|---|
| Business Analyst | COMPLETE | Acceptance criteria (200/404/409) present in the Work Unit; read them. |
| Software Architect | COMPLETE | "No architectural impact" checked against the ADR trigger list in `Workflows/ARCHITECTURE_DECISION.md`, not taken on trust. |
| Backend Engineer | COMPLETE | Test output pasted in the report re-run: `12 passed`. `git log` shows one commit with both trailers. |
| Code Reviewer | COMPLETE | The `Decision: approved` block is on the PR, and it states its denominator (which files, which lenses). |
| QA Engineer | COMPLETE | All three cases exercised against the acceptance criteria; the run is quoted. |

Risk records collected from the reports (`Standards/RISK_STANDARD.md`):

```
RISK: new endpoint reachable without an ownership check | tier=Medium | mitigation=authorization asserted in the 404 test | decided_by=self
```

`Medium` with a stated mitigation, so it proceeded and was recorded. Nothing reached `High`, so nothing stopped for a Director decision inside this chain.

All reports received and verified. No remediation Work Unit needed. A bare "Done" from any of these Employees would have been a **failed** Work Unit, not a completed one.

---

# Step 6 — Review (Main Agent)

Chain-level check:

- All Work Units complete and DoDs met.
- Outputs coherent — endpoint matches existing REST conventions.
- No gaps or unresolved blockers.
- Result matches the original Director request.

---

# Step 7 — Deliver (Main Agent → Director)

> "Delivered: `PATCH /tasks/{id}/complete`. Handles success, not-found, and already-complete cases. Reviewed by Code Reviewer, validated by QA. Merged to `develop`, ready for the next release. No open items."

**Director reviews → approves. Chain complete.**

---

# What This Example Demonstrates

- How a one-line Director request becomes a fully scoped Work Unit.
- How the Employee Brief gives the Backend Engineer everything needed without reading the whole repository (Context Engine in practice).
- How sequential dispatch works when each employee's output feeds the next.
- How the Main Agent validates against Definition of Done before moving to the next step — never passing through a failed output.
- How Step 5 reads a **Work Unit Report** and then re-verifies its claims against the repository, rather than accepting them. A bare "Done" is a failed Work Unit; a report is evidence to check, not proof to trust.
- How a `Medium` risk is recorded with its mitigation and proceeds, so that the decision survives the session.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Orchestration

Severity: Reference
