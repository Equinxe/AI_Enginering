# Hotfix Workflow

---

# Purpose

This workflow defines the process for delivering an urgent fix to production outside of the normal release cycle.

A hotfix bypasses the standard feature development cycle but never bypasses review, testing, or Director approval. Speed is not a substitute for quality gates.

---

# Trigger

- A critical or high-severity defect is discovered in production.
- Director or Engineering Manager authorizes a hotfix.

A hotfix is only justified when:
- The defect is in production (not `develop` or a feature branch).
- The defect has a critical or high business impact that cannot wait for the next release cycle.

If the defect is not in production or the impact is medium or lower: use the Feature Development Workflow instead.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Director | Authorizes the hotfix and approves the merge to `main` |
| Engineering Manager | Coordinates the hotfix, assigns the engineer |
| Engineer | Implements and tests the fix |
| Code Reviewer | Reviews the fix — no hotfix is merged without review |
| QA Engineer | Validates the fix resolves the defect without regression |
| Release Manager | Executes the merge, tag, and back-merge |
| Observability Engineer | Confirms production health during post-fix verification |

---

# Prerequisites

Before this workflow begins:

- The defect is confirmed in production.
- Director has authorized the hotfix.
- The defect is reproduced and documented with steps to reproduce, actual behavior, and expected behavior.

---

# Steps

## Step 1 — Director authorization

**Actor:** Director

1. Confirm the defect severity and production impact.
2. Authorize the hotfix explicitly.
3. Define the maximum acceptable time to resolution.

No hotfix work begins without this authorization.

**Output:** Director authorization documented.

---

## Step 2 — Create hotfix branch

**Actor:** Engineer

1. Checkout the latest `main` — not `develop`. The hotfix targets the current production state.
2. Create a hotfix branch: `hotfix/short-description`.
3. Push the hotfix branch to remote.

**Output:** `hotfix/short-description` branch created from `main`.

---

## Step 3 — Implement the fix

**Actor:** Engineer

1. Implement the minimal fix that resolves the defect. No feature additions, no refactoring beyond what is necessary to fix the issue.
2. Write a regression test that reproduces the defect and confirms it is fixed.
3. Run all existing tests locally.

**Output:** Fix implemented, regression test added, all tests passing.

---

## Step 4 — Commit

**Actor:** Engineer

1. Commit following the Commit Standard: `fix(scope): description`.
2. One commit per hotfix. Keep the diff minimal.

**Output:** Commit on the hotfix branch.

---

## Step 5 — Code review

**Actor:** Code Reviewer

Follow the Code Review Workflow. In a hotfix context:
- Focus on correctness and regression risk.
- The review must still be complete — time pressure does not justify skipping steps.
- If a security issue is found, escalate immediately.

**Output:** Pull Request approved or changes requested.

---

## Step 6 — QA validation

**Actor:** QA Engineer

1. Verify the defect is resolved.
2. Run regression tests to confirm no existing functionality is broken.
3. Document the validation result.

**Output:** QA sign-off.

---

## Step 7 — Director approval

**Actor:** Director

1. Review the fix scope and QA sign-off.
2. Approve the merge to `main`.

**Output:** Director approval documented.

---

## Step 8 — Merge to main and tag

**Actor:** Release Manager

1. Open a Pull Request from `hotfix/short-description` to `main`.
2. Merge after Director approval.
3. Create and push the hotfix tag: `vX.X.Y` (patch increment).

**Output:** Hotfix on `main`, tagged.

---

## Step 9 — Back-merge to develop

**Actor:** Release Manager

1. Merge `hotfix/short-description` into `develop` to ensure the fix is present in future releases.
2. Resolve any merge conflicts.
3. Push `develop`.

**Output:** `develop` contains the hotfix.

---

## Step 10 — Post-fix verification

**Actor:** QA Engineer + Observability Engineer

1. Confirm the fix is deployed and the defect is resolved in production.
2. Monitor for 30 minutes post-deployment.
3. Report status to the Director.

**Output:** Production health confirmed.

---

## Step 11 — Delete hotfix branch

**Actor:** Release Manager

Delete the hotfix branch after all merges are complete. Unlike release branches, hotfix branches are deleted after merge.

**Output:** Hotfix branch deleted.

---

# Exit Criteria

This workflow is complete when:

- The fix is on `main` and tagged.
- The fix is back-merged into `develop`.
- Production health is confirmed post-deployment.
- The hotfix branch is deleted.
- An incident report is filed if the defect had significant user impact.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Fix cannot be implemented without a significant refactor | Director — scope decision required |
| QA finds regression introduced by the fix | Director — delay deployment or accept risk |
| Production impact is worsening during hotfix development | Director + Incident Response Workflow |

---

# Related Workflows

- Incident Response Workflow
- Release Workflow
- Code Review Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Workflow — Release

Severity: Mandatory
