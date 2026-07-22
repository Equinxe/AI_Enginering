# Release Workflow

---

# Purpose

This workflow defines the process for creating a production release from a stable `develop` branch.

It governs every step from release branch creation to tagging and post-release verification, ensuring that every release is traceable, tested, and approved by the Director before reaching `main`.

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
- CHANGELOG.md and VERSION.md are up to date with the planned release version.
- Director has approved the release scope.

---

# Steps

## Step 1 — Release readiness review

**Actor:** Release Manager + Engineering Manager

1. Confirm all planned Work Units are merged into `develop`.
2. Confirm CI/CD is green on `develop`.
3. Confirm no open critical or high defects remain.
4. Review CHANGELOG.md — every significant change must be documented.
5. Confirm VERSION.md reflects the new version number and codename.

If any condition is not met: block the release. Do not proceed until `develop` is ready.

**Output:** Release readiness confirmation.

---

## Step 2 — Create release branch

**Actor:** Release Manager

1. Checkout the latest `develop`.
2. Create a release branch: `release/vX.X.X`.
3. Push the release branch to remote.

Only bug fixes and release-specific changes (version bump, changelog) are allowed on this branch. No new features.

**Output:** `release/vX.X.X` branch created and pushed.

---

## Step 3 — Release acceptance testing

**Actor:** QA Engineer

1. Pull the release branch.
2. Execute the release acceptance test plan covering all features in this release.
3. Verify critical user flows end-to-end.
4. Document results: pass/fail for each test case.

If a defect is found:
- Minor defect: fix on the release branch, commit following the Commit Standard.
- Critical or high defect: escalate to the Director. The release may be blocked or the defect deferred.

**Output:** Release acceptance test report.

---

## Step 4 — Director approval

**Actor:** Director

1. Review the release scope (CHANGELOG.md).
2. Review the QA acceptance test report.
3. Approve or block the release.

No merge to `main` happens without explicit Director approval.

**Output:** Director approval documented.

---

## Step 5 — Merge to main

**Actor:** Release Manager

1. Open a Pull Request from `release/vX.X.X` to `main`.
2. PR description includes: version, release scope summary, QA sign-off reference, Director approval reference.
3. Director or designated approver merges the PR.

**Output:** Release merged into `main`.

---

## Step 6 — Tag

**Actor:** Release Manager

1. Pull the latest `main`.
2. Create a tag: `git tag vX.X.X`.
3. Push the tag: `git push origin vX.X.X`.

**Output:** Release tagged on `main`.

---

## Step 7 — Back-merge to develop

**Actor:** Release Manager

The `pre-push` hook (`Adapters/git-hooks/pre-push`) blocks direct pushes to `develop`, so the back-merge goes through a Pull Request like any other change.

1. Open a Pull Request from `main` to `develop` to capture any release-branch fixes.
2. Merge the PR once CI passes. The content already went through review on its way into `main`, so no new conflicts are expected.

**Output:** `develop` is in sync with `main`.

---

## Step 8 — Post-release verification

**Actor:** QA Engineer + Observability Engineer

1. Verify the production deployment is healthy (if automated deployment is configured).
2. Confirm no critical errors in logs or monitoring dashboards within 30 minutes of release.
3. Report status to the Director.

**Output:** Post-release health confirmation.

---

## Step 9 — Preserve the release branch

**Actor:** Release Manager

The release branch `release/vX.X.X` is **never deleted**. It serves as a permanent snapshot of the exact state released to production.

**Output:** Release branch preserved on remote.

---

# Exit Criteria

This workflow is complete when:

- `release/vX.X.X` is merged into `main`.
- Tag `vX.X.X` is on `main`.
- `release/vX.X.X` is merged back into `develop`.
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

Version: 0.0.4

Status: Draft

Category: Workflow — Release

Severity: Mandatory
