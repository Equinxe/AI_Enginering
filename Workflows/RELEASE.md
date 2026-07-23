# Release Workflow

---

# Purpose

This workflow defines the process for creating a production release from a stable `develop` branch.

It governs every step from the version bump through release branch creation, tagging, and post-release verification, ensuring that every release is traceable, tested, and approved by the Director before reaching `main`.

---

# Trigger

- Director or Engineering Manager initiates a release cycle.
- `develop` contains a set of features and fixes that are ready for production.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Release Manager | Orchestrates the release, owns the release branch |
| Engineering Manager | Confirms `develop` is in a releasable state |
| QA Engineer | Executes release acceptance testing |
| Director | Final approval to merge release into `main` |
| Technical Lead | Resolves last-minute technical issues found during release testing |
| Observability Engineer | Confirms production health during post-release verification |

---

# Prerequisites

Before this workflow begins:

- All features and fixes intended for this release are merged into `develop`.
- No open critical or high defects on `develop`.
- The release version number and codename have been decided. (The version bump itself is performed inside this workflow, in Step 2, not before it.)
- Director has approved the release scope.

---

# Steps

## Step 1 — Release readiness review

**Actor:** Release Manager + Engineering Manager

1. Confirm all planned Work Units are merged into `develop`.
2. Confirm CI/CD is green on `develop`.
3. Confirm no open critical or high defects remain.
4. Confirm the release version number and codename are agreed.
5. Review the pending CHANGELOG.md entries — every significant change since the last release must be accounted for so the version bump in Step 2 is complete.

If any condition is not met: block the release. Do not proceed until `develop` is ready.

**Output:** Release readiness confirmation.

---

## Step 2 — Bump version on `develop`

**Actor:** Release Manager

The version bump is a normal Work Unit merged into `develop` through the standard branch → commit → PR → merge cycle, subject to the same CI and hooks as any other change. It happens **before** the release branch is created, so that `develop` already carries the final `VERSION.md` and CHANGELOG.md for this release.

1. Branch from the latest `develop` (for example `chore/release-vX.X.X-bump`).
2. Update VERSION.md to the new version number and codename.
3. Update CHANGELOG.md to finalize the entries for this release.
4. Commit following the Commit Standard.
5. Open a Pull Request to `develop`.
6. Merge the PR once CI passes.

This is why the release branch created in Step 3 needs no separate version-bump commit: the bump already lives on `develop`.

**Output:** `develop` carries the final VERSION.md and CHANGELOG.md for this release.

---

## Step 3 — Create release branch

**Actor:** Release Manager

1. Checkout the latest `develop` (now including the version bump from Step 2).
2. Create a release branch: `release/vX.X.X`.
3. Push the release branch to remote.

At creation the release branch is an exact snapshot of `develop`, version bump included. No separate version-bump or changelog commit happens on this branch. Only bug fixes found during release acceptance testing (Step 4) are allowed here. No new features.

**Output:** `release/vX.X.X` branch created and pushed.

---

## Step 4 — Release acceptance testing

**Actor:** QA Engineer

1. Pull the release branch.
2. Execute the release acceptance test plan covering all features in this release.
3. Verify critical user flows end-to-end.
4. Document results: pass/fail for each test case.

If a defect is found:
- Minor defect: fix on the release branch, commit following the Commit Standard. Note that this causes the release branch to diverge from `develop`, which makes the back-merge in Step 8 necessary.
- Critical or high defect: escalate to the Director. The release may be blocked or the defect deferred.

**Output:** Release acceptance test report.

---

## Step 5 — Director approval

**Actor:** Director

1. Review the release scope (CHANGELOG.md).
2. Review the QA acceptance test report.
3. Approve or block the release.

No merge to `main` happens without explicit Director approval.

**Output:** Director approval documented.

---

## Step 6 — Merge to main

**Actor:** Release Manager

1. Open a Pull Request from `release/vX.X.X` to `main`.
2. PR description includes: version, release scope summary, QA sign-off reference, Director approval reference.
3. Director or designated approver merges the PR.

**Output:** Release merged into `main`.

---

## Step 7 — Tag

**Actor:** Release Manager

1. Pull the latest `main`.
2. Create a tag: `git tag vX.X.X`.
3. Push the tag: `git push origin vX.X.X`.

**Output:** Release tagged on `main`.

---

## Step 8 — Back-merge to develop

**Actor:** Release Manager

Because the release branch was created as an exact snapshot of `develop` (the version bump already happened on `develop` in Step 2), this step is **normally unnecessary**: `main` and `develop` hold the same release content, so there is nothing to carry back.

This step is **still required** whenever a defect fix was applied directly to the release branch during Step 4 acceptance testing. In that case the release branch diverged from `develop` by those fix commits, and they must be brought back.

When required:

1. The `pre-push` hook (`Adapters/git-hooks/pre-push`) blocks direct pushes to `develop`, so the back-merge goes through a Pull Request like any other change.
2. Open a Pull Request from `main` to `develop` to capture the release-branch fixes.
3. Merge the PR once CI passes. The content already went through review on its way into `main`, so no new conflicts are expected.

**Output:** `develop` is in sync with `main`.

---

## Step 9 — Post-release verification

**Actor:** QA Engineer + Observability Engineer

1. Verify the production deployment is healthy (if automated deployment is configured).
2. Confirm no critical errors in logs or monitoring dashboards within 30 minutes of release.
3. Report status to the Director.

**Output:** Post-release health confirmation.

---

## Step 10 — Preserve the release branch

**Actor:** Release Manager

The release branch `release/vX.X.X` is **never deleted**. It serves as a permanent snapshot of the exact state released to production.

**Output:** Release branch preserved on remote.

---

# Exit Criteria

This workflow is complete when:

- The version bump is merged into `develop` (Step 2).
- `release/vX.X.X` is merged into `main`.
- Tag `vX.X.X` is on `main`.
- `develop` is in sync with `main` — either automatically (release branch never diverged) or via the back-merge PR when a defect fix was applied directly to the release branch.
- `release/vX.X.X` branch is preserved on remote.
- Post-release health is confirmed.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Critical defect found during release testing | Director — release decision required |
| Director approval is delayed and blocking the release | Engineering Manager → Director |
| Post-release critical failure | Director + full incident response via Incident Response Workflow |

---

# Related Workflows

- Feature Development Workflow
- Hotfix Workflow
- Incident Response Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.9.3

Status: Draft

Category: Workflow — Release

Severity: Mandatory
