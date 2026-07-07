# Example — Hotfix Chain

This example shows a production defect discovered in TaskFlow v1.3.0, requiring an emergency fix outside the normal release cycle.

Reference: `Core/AGENT_CHAINS.md` — Hotfix Chain, `Workflows/HOTFIX.md`

---

# Trigger

A user reports that `PATCH /tasks/{id}/complete` returns a 500 error when the task ID contains a trailing slash (`/tasks/42/complete/`). This is live in production on `main` (v1.3.0).

---

# Step 1 — Main Agent → Director (Authorization Gate)

> "Production defect found: PATCH /tasks/{id}/complete/ (trailing slash) returns 500 instead of routing correctly. Affects v1.3.0 on `main`. Requesting authorization to hotfix."

**This gate is mandatory before any work begins**, per `Workflows/HOTFIX.md`.

**Director authorizes.**

---

# Step 2 — Engineer

1. Branches from `main` (not `develop` — production reflects `main`, not the latest in-progress work).
2. Branch name: `hotfix/trailing-slash-500`.
3. Fixes the router configuration to normalize trailing slashes.
4. Adds a regression test for the trailing-slash case.
5. Commits: `fix(tasks): handle trailing slash on complete endpoint`

**Output:** Fix implemented, branched from `main`, tested.

---

# Step 3 — Code Reviewer (Expedited Review)

Reviews the fix with the same rigor as a normal PR, but on an expedited timeline given production impact:
- Confirms the fix is scoped only to the trailing-slash handling.
- Confirms no unrelated changes are bundled in.
- Confirms the regression test actually reproduces the original bug before the fix (verified by checking it fails against the pre-fix commit).

**Approved.**

---

# Step 4 — QA Engineer

Validates:
- The original bug is resolved.
- No regression on the non-trailing-slash path.
- No regression on adjacent endpoints.

**Signed off.**

---

# Step 5 — Main Agent → Director (Approval Gate)

> "Hotfix ready: trailing-slash 500 error fixed, reviewed, QA-validated. Requesting approval to merge to `main`."

**Director approves.**

---

# Step 6 — Release Manager

1. Merges `hotfix/trailing-slash-500` → `main`.
2. Tags `v1.3.1`.
3. **Back-merges `main` into `develop`** so the fix is not lost in the next regular release.

**Output:** v1.3.1 live. Fix present in both `main` and `develop`.

---

# What This Example Demonstrates

- Why hotfixes branch from `main`, not `develop` — production state and in-progress development state can diverge.
- Why there are two Director gates in this chain (authorization to start, approval to merge) rather than one — an unauthorized hotfix in progress is as risky as an unapproved merge.
- Why the back-merge to `develop` step exists — without it, the next regular release could silently reintroduce the bug.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Orchestration

Severity: Reference
