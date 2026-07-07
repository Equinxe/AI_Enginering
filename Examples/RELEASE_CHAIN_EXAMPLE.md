# Example — Release Chain

This example continues the TaskFlow scenario, showing how WU-TASKFLOW-014 (and other merged Work Units) reach production.

Reference: `Core/AGENT_CHAINS.md` — Release Chain, `Workflows/RELEASE.md`

---

# Trigger

Sprint 6 is complete. `develop` contains three merged features, including the `PATCH /tasks/{id}/complete` endpoint (WU-TASKFLOW-014). Director requests a release.

---

# Step 1 — Release Manager

1. Creates `release/v1.3.0` from `develop`.
2. Updates `CHANGELOG.md`:

```markdown
## [1.3.0]

### Added
- PATCH /tasks/{id}/complete — mark a task as complete (WU-TASKFLOW-014)
- [other Sprint 6 features]
```

3. Bumps version in `VERSION.md` to `1.3.0`.
4. Commits: `docs(release): bump version to v1.3.0 and update changelog`

**Output:** Release branch ready with changelog and version bump.

---

# Step 2 — QA Engineer

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

**Result:** Pass — ready for release.

---

# Step 3 — Main Agent → Director (Mandatory Gate)

> "Release v1.3.0 is ready: 3 features, all regression and acceptance tests passing, changelog updated. Requesting approval to merge to `main`."

**This gate cannot be skipped.** No merge to `main` proceeds without explicit Director approval, per `Workflows/RELEASE.md` and `CLAUDE.md`.

**Director approves.**

---

# Step 4 — Release Manager

1. Opens PR: `release/v1.3.0` → `main`.
2. Merges after Director confirms.
3. Tags `v1.3.0` on `main`.
4. **Does not delete `release/v1.3.0`** — release branches are permanent.
5. Merges `main` back into `develop` to sync the version bump.

**Output:** v1.3.0 live on `main`, tagged, release branch preserved.

---

# What This Example Demonstrates

- Why the Director approval gate exists between QA sign-off and the merge to `main` — it is mandatory and cannot be inferred from a passing test suite alone.
- Why release branches are never deleted — `release/v1.3.0` remains as a permanent historical record.
- How Work Unit traceability survives all the way to the changelog (WU-TASKFLOW-014 is visible from commit to release note).

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Orchestration

Severity: Reference
