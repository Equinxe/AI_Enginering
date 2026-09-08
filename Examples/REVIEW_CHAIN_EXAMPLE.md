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

The decision states its **denominator**, which `Workflows/CODE_REVIEW.md` Step 8 requires — a review that reports only its findings hides how much it did not look at:

```markdown
Decision: changes requested

Read: routers/tasks.py, services/tasks.py, tests/test_tasks.py, docs/api/tasks.md (4 files, the whole diff).
Lenses applied: correctness, tests, security and compliance, quality, documentation (Steps 2-6).
Claims verified against the repository: the PR says "tests cover all cases" — re-ran the suite,
  12 passed, and read the test names to confirm which cases exist. The malformed-ID case does not.
Risk: RISK: endpoint reachable without an ownership check | tier=Medium | mitigation=asserted in the
  404 test | decided_by=self — Medium, so it proceeds with the mitigation recorded, not escalated.
```

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

Every open finding is **re-anchored** to the new diff or closed with an explicit disposition — `Workflows/CODE_REVIEW.md` Step 9. A finding is never dropped because its line moved: a deleted line is not a fixed defect.

- `[major]` malformed-ID test — **resolved by `a1b2c3d`**. The test exists and fails when the validation is removed.
- `[minor]` API documentation — **resolved by `a1b2c3d`**. `docs/api/tasks.md` now describes the endpoint.
- `[suggestion]` shared validator — **withdrawn: out of scope for this Work Unit**, filed as Issue #57 so it survives the session (`Core/MAIN_AGENT_CONDUCT.md`, Durable Tracking of Findings).

Only the new diff is re-read; the rest of the PR is not reviewed again.

**Approved**, with the denominator restated for the second pass: 2 files re-read, correctness and tests lenses re-applied, the fix verified by removing the validation and watching the new test fail.

---

# Step 5 — Handoff

**Output:** PR #42 approved.

**Handoff to:** QA Engineer (Feature Chain Step 7 — QA Validation).

---

# What This Example Demonstrates

- How the Code Review Workflow's steps map to concrete findings with severity labels.
- How "changes requested" loops back into the same Work Unit rather than creating a new one.
- How a non-blocking suggestion is acknowledged and deferred without blocking the chain — not every finding must be resolved immediately, only [critical] and [major] ones. Deferred does not mean forgotten: it becomes an Issue.
- How a decision **states its denominator** — which files were read, which lenses applied, which of the PR's own claims were verified against the repository. A review that reports only findings hides how much it did not look at.
- How the second pass **re-anchors** every open finding instead of re-reading the whole PR, and gives each one a disposition rather than letting it lapse when its line moves.
- How a `Medium` risk is recorded and proceeds, where a `High` one would have stopped the chain for a Director decision.
- How the Review Chain hands off cleanly back into the parent Feature Chain.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Orchestration

Severity: Reference
