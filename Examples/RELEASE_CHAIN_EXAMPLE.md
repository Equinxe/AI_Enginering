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
3. Runs `./ia-engineering/Adapters/scripts/release.sh publish v1.3.0 --confirm`, which creates the annotated tag, pushes it, **and creates the GitHub Release with notes extracted from this version's `CHANGELOG.md` section**.
4. **Does not delete `release/v1.3.0`** — release branches are permanent.

**A bare tag is not a release.** `Workflows/RELEASE.md` Step 7 requires the full Release, with notes derived from the CHANGELOG entry, because a tag alone produces no description on the Releases page. That gap had to be patched after the fact for two consecutive releases before it became a rule, and a third shipped with no tag at all — which is why `validate-framework.sh` section 16 now checks that every CHANGELOG version has one.

Without `--confirm` the script prints its plan and stops, changing nothing. Publishing is externally visible and effectively irreversible, so it is never the default.

**Output:** v1.3.0 live on `main`, tagged, GitHub Release published from the CHANGELOG, release branch preserved.

---

# Step 6 — Release Manager (back-merge check)

**The back-merge is performed, not skipped.** An earlier version of this example reasoned that the release branch was an exact snapshot of `develop`, so `main` and `develop` already held the same release *content* and there was nothing to carry back. The content claim is true. The conclusion is wrong, and the difference is history rather than content.

Merging the release branch into `main` in Step 5 creates a **merge commit on `main`**. That commit exists on `main` and nowhere else — nothing merges `main` anywhere, so `develop` never receives it. Every release therefore leaves `main` one commit ahead, carrying no content, and the gap accumulates one commit per release. It is invisible until `main` requires branches to be up to date, and from then on it blocks the *next* release: that Pull Request's head does not contain `main`'s tip and cannot be made to without performing the back-merge that was skipped.

So:

1. **Branch from `develop`** (for example `chore/back-merge-main`) and merge `main` into it: `git merge --no-ff origin/main`. Push that branch.
2. Open the Pull Request from **that branch** to `develop`, not from `main` itself.
3. Merge once CI passes.

**Do not open it with `main` as the head.** That is the obvious shape and it cannot work: "up to date" compares the *head* against the *base*, so a head of `main` would have to contain `develop`'s tip — the opposite of a back-merge, and it would put unreleased work on `main` outside this workflow.

In the normal case that Pull Request **changes no files**: it carries only the merge commit from Step 5. That is expected. The `PR Size` and `Data Policy` checks recognise a range whose commits are all merges and pass it with a notice; a range with no commits at all, or one holding a non-merge commit that changed nothing, still fails.

Had a defect been found during Step 3 acceptance testing, branch protection would have blocked a direct push to `release/v1.3.0`. Instead, a fix branch (for example `fix/release-v1.3.0-short-description`) would branch from `release/v1.3.0`, commit the fix, open a Pull Request targeting `release/v1.3.0` (not `develop`), wait for CI to pass, get reviewed by the Code Reviewer, and merge into the release branch. Those fixes then have real content to carry back, on top of the merge commit that always does.

**Output:** `develop` contains `main`'s tip, so the next release can satisfy "require branches to be up to date".

---

# What This Example Demonstrates

- Why the version bump happens on `develop` before the release branch is cut — the release branch is a pure, traceable snapshot with no separate bump commit of its own.
- Why the Director approval gate exists between QA sign-off and the merge to `main` — it is mandatory and cannot be inferred from a passing test suite alone.
- Why release branches are never deleted — `release/v1.3.0` remains as a permanent historical record.
- Why the back-merge to `develop` is required on *every* release, not only when a defect fix diverged the release branch — the Step 5 merge always leaves a content-free merge commit on `main` that `develop` would otherwise never receive, and skipping it blocks the next release.
- How Work Unit traceability survives all the way to the changelog (WU-TASKFLOW-014 is visible from commit to release note).

---

# Metadata

Owner: IA Engineering

Version: 0.0.9

Status: Draft

Category: Example — Orchestration

Severity: Reference
