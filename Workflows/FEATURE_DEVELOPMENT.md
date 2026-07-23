# Feature Development Workflow

---

# Purpose

This workflow defines the end-to-end process for delivering a feature from business requirement to production-ready code.

It governs every engineer involved in feature development and ensures that every change passes through design, implementation, review, and validation before reaching the shared codebase.

---

# Trigger

- Director or Product Manager requests a new feature.
- A Work Unit is created and assigned to the Engineering Manager.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Engineering Manager | Decomposes the feature into Work Units, assigns to engineers |
| Business Analyst | Documents acceptance criteria before the workflow begins |
| Software Architect | Reviews architecture impact, approves ADR if needed |
| Backend / Frontend / iOS / Android / Cross-Platform Engineer | Implements the assigned Work Unit |
| Code Reviewer | Reviews the Pull Request |
| QA Engineer | Validates the implementation against acceptance criteria |
| Technical Lead | Resolves technical blockers, bridges architect and engineers |
| Compliance Engineer | Consulted when the Work Unit's scope involves regulated or sensitive data (PII, payment data, health data) or a named regulatory framework (GDPR, HIPAA, PCI-DSS, SOC 2, ISO 27001) |

---

# Prerequisites

Before this workflow begins:

- The feature has documented acceptance criteria from the Business Analyst or Product Manager.
- The Software Architect has reviewed the feature for architectural impact.
- If the feature introduces architectural changes, an ADR is approved before implementation begins.

---

# Steps

## Step 1 — Work Unit Definition

**Actor:** Engineering Manager

1. Receive the feature request with acceptance criteria.
2. Decompose the feature into atomic Work Units (one independently reviewable engineering task each).
3. For each Work Unit, define:
   - Objective
   - Context
   - Inputs
   - Outputs
   - Definition of Done
   - Standards applicable
   - Expected commit message
4. Assign each Work Unit to the appropriate engineer.

**Output:** Work Units assigned to engineers.

**Handoff to:** Step 2 (each engineer works their assigned Work Unit independently).

---

## Step 2 — Branch Creation

**Actor:** Engineer

1. Checkout the latest `develop` branch.
2. Create a feature branch following the Branch Standard: `feature/short-description`.
3. Confirm the Work Unit objective and acceptance criteria before writing any code.

**Output:** Feature branch ready for development.

**Handoff to:** Step 3.

---

## Step 3 — Implementation

**Actor:** Engineer

1. Implement the Work Unit following the Code Quality Standard.
2. Write tests following the Testing Standard. Tests must be written alongside the code, not after.
3. Verify the implementation meets the Work Unit's Definition of Done.
4. Run existing tests locally to confirm nothing is broken.

**Output:** Implementation complete, tests passing locally.

**Handoff to:** Step 4.

---

## Step 4 — Commit

**Actor:** Engineer

1. Stage only the files relevant to this Work Unit.
2. Write a commit message following the Commit Standard (Conventional Commits).
3. One Work Unit = one commit. Do not bundle unrelated changes.

**Output:** Commit on the feature branch.

**Handoff to:** Step 5.

---

## Step 5 — Pull Request

**Actor:** Engineer

1. Push the feature branch to remote.
2. Open a Pull Request targeting `develop`.
3. Fill in the PR description: what changed, why, how to test, linked Work Unit.
4. Assign the Code Reviewer.

**Output:** Pull Request open and ready for review.

**Handoff to:** Step 6 (Code Review Workflow).

---

## Step 6 — Code Review

**Actor:** Code Reviewer

Follow the **Code Review Workflow**.

**Output:** Pull Request approved or changes requested.

**Handoff to:** Step 7 (if approved) or back to Step 3 (if changes requested).

---

## Step 7 — QA Validation

**Actor:** QA Engineer

1. Pull the feature branch.
2. Validate the implementation against the acceptance criteria defined in the Work Unit.
3. Execute the test plan for the feature.
4. Report findings:
   - If all criteria pass: sign off.
   - If criteria fail: open a defect and return to Step 3.

**Output:** QA sign-off or defect report.

**Handoff to:** Step 8 (if signed off) or Step 3 (if defect found).

---

## Step 8 — Merge

**Actor:** Engineering Manager or Technical Lead

1. Confirm PR is approved by Code Reviewer.
2. Confirm QA sign-off is documented.
3. Merge the Pull Request into `develop`.
4. Delete the feature branch after merge.

**Output:** Feature merged into `develop`.

**Handoff to:** Release Workflow when the sprint or release cycle concludes.

---

# Exit Criteria

This workflow is complete when:

- The Pull Request is merged into `develop`.
- All acceptance criteria are verified by the QA Engineer.
- The feature branch is deleted.
- The Work Unit is marked as complete.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Architectural impact discovered during implementation | Software Architect |
| Work Unit scope is unclear or contradicts acceptance criteria | Engineering Manager → Product Manager |
| Code review cannot reach agreement after two cycles | Engineering Manager |
| QA finds a critical defect that requires rework | Engineering Manager + Director notified |
| Work Unit involves PII, payment data, health data, or a named regulatory framework (GDPR, HIPAA, PCI-DSS, SOC 2, ISO 27001) | Compliance Engineer |

---

# Related Workflows

- Code Review Workflow
- Release Workflow
- Hotfix Workflow (for defects discovered post-merge)
- Architecture Decision Workflow (when an ADR is required)

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Workflow — Development

Severity: Mandatory
