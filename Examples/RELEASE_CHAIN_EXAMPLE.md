# Example — Release Chain

This example continues the TaskFlow scenario, showing how WU-TASKFLOW-014 (and other merged Work Units) reach production.

Reference: `Core/AGENT_CHAINS.md` — Release Chain, `Workflows/RELEASE.md`

---

# Trigger

Sprint 6 is complete. `develop` contains three merged features, including the `PATCH /tasks/{id}/complete` endpoint (WU-TASKFLOW-014). Director requests a release.

---

# Step 1 — Release Manager (bump version on `develop`)

The version bump happens **before** the release branch exists, as its own Work Unit on `develop`.

1. Branches from `develop`: `chore/release-v1.3.0-bump`.
2. Updates `CHANGELOG.md`:

```markdown
## [1.3.0]

### Added
- PATCH /tasks/{id}/complete — mark a task as complete (WU-TASKFLOW-014)
- [other Sprint 6 features]
```

3. Bumps version in `VERSION.md` to `1.3.0`.
4. Commits: `docs(release): bump version to v1.3.0 and update changelog`
5. Opens a Pull Request to `develop`; merges once CI passes.

**Output:** `develop` carries the final `VERSION.md` and `CHANGELOG.md` for v1.3.0.

---

# Step 2 — Release Manager (create release branch)

1. Checks out the latest `develop` (now including the version bump from Step 1).
2. Creates `release/v1.3.0` — an exact snapshot of `develop`, version bump included. No separate version-bump commit happens on this branch.
3. Pushes `release/v1.3.0` to remote.

**Output:** `release/v1.3.0` branch created and pushed.

---

# Step 3 — QA Engineer

Executes the release-level Test Plan (`Templates/TEST_PLAN.md`), covering:
- Regression tests for all existing endpoints.
- New feature validation: the three Sprint 6 features, including WU-TASKFLOW-014.

```markdown
| Test case | Area | Status |
|---|---|---|
| TC-TASKFLOW-041 | PATCH /tasks/{id}/complete — success | Pass |
| TC-TASKFLOW-042 | PATCH /tasks/{id}/complete — not found | Pass |
| TC-TASKFLOW-043 | PATCH /tasks/{id}/complete — already complete | Pass |
| TC-TASKFLOW-044 | Regression — existing task CRUD | Pass |
```

**Result:** Pass — ready for release. No defect fixes needed on the release branch, so it has not diverged from `develop`.

---

# Step 4 — Main Agent → Director (Mandatory Gate)

> "Release v1.3.0 is ready: 3 features, all regression and acceptance tests passing, changelog updated. Requesting approval to merge to `main`."

**This gate cannot be skipped.** No merge to `main` proceeds without explicit Director approval, per `Workflows/RELEASE.md` and `CLAUDE.md`.

**Director approves.**

---

# Step 5 — Release Manager (merge to main and tag)

1. Opens PR: `release/v1.3.0` → `main`.
2. Merges after Director confirms.
3. Tags `v1.3.0` on `main`.
4. **Does not delete `release/v1.3.0`** — release branches are permanent.

**Output:** v1.3.0 live on `main`, tagged, release branch preserved.

---

# Step 6 — Release Manager (back-merge check)

Because the release branch was an exact snapshot of `develop` (the version bump already happened in Step 1), and no defect fixes were applied to the release branch during Step 3, `main` and `develop` already hold the same release content. The back-merge PR from `main` to `develop` (`Workflows/RELEASE.md` Step 8) is a no-op here and is skipped.

Had a defect fix been committed directly to `release/v1.3.0` during acceptance testing, this step would instead open a Pull Request from `main` to `develop` and merge it once CI passes, per the `pre-push` hook that blocks direct pushes to `develop`.

**Output:** `develop` confirmed in sync with `main`.

---

# What This Example Demonstrates

- Why the version bump happens on `develop` before the release branch is cut — the release branch is a pure, traceable snapshot with no separate bump commit of its own.
- Why the Director approval gate exists between QA sign-off and the merge to `main` — it is mandatory and cannot be inferred from a passing test suite alone.
- Why release branches are never deleted — `release/v1.3.0` remains as a permanent historical record.
- Why the back-merge to `develop` is normally a no-op — it only carries real content when a defect fix was applied directly to the release branch during acceptance testing.
- How Work Unit traceability survives all the way to the changelog (WU-TASKFLOW-014 is visible from commit to release note).

---

# Metadata

Owner: IA Engineering

Version: 0.0.8

Status: Draft

Category: Example — Orchestration

Severity: Reference
