# Example — Review Chain

This example continues the TaskFlow scenario from `FEATURE_CHAIN_EXAMPLE.md`, focusing on the Code Review step in detail.

Reference: `Core/AGENT_CHAINS.md` — Review Chain, `Workflows/CODE_REVIEW.md`

---

# Trigger

Backend Engineer opens Pull Request #42: `feat(tasks): add PATCH /tasks/{id}/complete endpoint`, targeting `develop`.

---

# Step 1 — Code Reviewer Receives the PR

The Code Reviewer follows `Workflows/CODE_REVIEW.md`:

1. **Understand intent** — reads the linked Work Unit WU-TASKFLOW-014, confirms the PR matches the stated objective.
2. **Logic** — verifies the 200/404/409 branches are all handled and no edge case (e.g., malformed ID) is missed.
3. **Tests** — confirms tests cover success, not-found, already-complete. Notes: no test for malformed ID format.
4. **Security** — confirms no injection risk, no missing authorization check on the endpoint.
5. **Quality** — checks naming, consistency with existing router style.
6. **Documentation** — checks whether the API reference needs updating. It does — no update included.

---

# Review Findings

```markdown
[major] Missing test for malformed task ID (non-numeric). Add a 422 case.
[minor] API documentation not updated for the new endpoint — add to docs/api/tasks.md.
[suggestion] Consider extracting the "already complete" check into a shared validator — not blocking.
```

---

# Step 2 — Decision

**Changes requested.** PR returned to Backend Engineer with the findings above.

**Handoff:** Back to Feature Chain Step 3 (Implementation) — not a new Work Unit, same WU-TASKFLOW-014.

---

# Step 3 — Author Response

Backend Engineer:
- Adds the 422 test case for malformed ID.
- Updates `docs/api/tasks.md`.
- Leaves the shared-validator suggestion for a future Work Unit (not blocking, out of scope for this one).
- Pushes a new commit to the same PR.

---

# Step 4 — Second Review Pass

Code Reviewer confirms:
- [major] resolved — test added.
- [minor] resolved — documentation updated.
- [suggestion] acknowledged, deferred — acceptable.

**Approved.**

---

# Step 5 — Handoff

**Output:** PR #42 approved.

**Handoff to:** QA Engineer (Feature Chain Step 7 — QA Validation).

---

# What This Example Demonstrates

- How the Code Review Workflow's steps map to concrete findings with severity labels.
- How "changes requested" loops back into the same Work Unit rather than creating a new one.
- How a non-blocking suggestion is acknowledged and deferred without blocking the chain — not every finding must be resolved immediately, only [critical] and [major] ones.
- How the Review Chain hands off cleanly back into the parent Feature Chain.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Orchestration

Severity: Reference
