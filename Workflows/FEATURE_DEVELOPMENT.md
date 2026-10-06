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
| Security Engineer | Consulted when the Work Unit's scope involves authentication or authorisation, secrets or credentials, a trust boundary between systems, cryptography, or user-supplied input reaching a query, a filesystem path or a command |

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
2. Create a feature branch following the Branch Standard: `feature/short-description`. For a documentation-only Work Unit, use `docs/short-description` instead (`Standards/BRANCH_STANDARD.md`).
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
2. If the Work Unit is not already registered, add it to `Registry/work-units.yml` (id, employee, title, milestone, delivers) in this same commit. In a project that imported the framework this is the PROJECT's own registry (the bootstrap writes an empty starter; the check never reads the framework's). The required `Work Unit Exists` CI check resolves every commit's `Work Unit:` trailer against that file and fails the Pull Request if the ID is not registered there — see `Registry/README.md`. For the `milestone` value: the current in-progress milestone is declared in `VERSION.md` ("Next Milestone") — a new Work Unit's `milestone:` uses that name.
3. Write a commit message following the Commit Standard (Conventional Commits).
4. One Work Unit = one commit. Do not bundle unrelated changes.

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

**Actor:** Engineering Manager or Technical Lead — or the Main Agent itself, under the Director's standing exception and only on its conditions, which add the approvals items 1–2 do not list (`Core/MAIN_AGENT_CONDUCT.md`, Git Execution via Named Employee)

1. Confirm PR is approved by Code Reviewer.
2. Confirm QA sign-off is documented.
3. Merge the Pull Request into `develop`.
4. Delete the feature branch after merge.

**Output:** Feature merged into `develop`.

**Handoff to:** Release Workflow when the sprint or release cycle concludes.

---

# Trivial / Mechanical Changes (Express Path)

For a typo, a one-line fix, or a doc tweak, this workflow does not change. Every participant and every gate above still applies: Business Analyst (Prerequisites), Architect impact review (Prerequisites), Code Reviewer (Step 6), QA Validation (Step 7), and the Director delivery gate at the end of the Feature Chain (`Core/AGENT_CHAINS.md`). No participant is dropped, no gate is skipped, and no step here is made conditional by this section.

What changes is execution capability, not workflow shape. A Work Unit that is genuinely mechanical — bounded, unambiguous, with no tradeoff to weigh — is dispatched at the **Lightweight Execution** tier (`Core/CAPABILITY_TIERS.md`, Tier Override) for its entire path through this workflow, rather than the Standard Execution tier most Work Units default to. Each step becomes a fast confirmation instead of a full pass: the Architect's impact review is a quick triviality check rather than a design review; Code Review is a quick correctness pass; QA Validation (Step 7) is a quick pass/fail of the change against its acceptance criteria rather than a full test-plan execution. The genuinely conditional steps already in this workflow — Compliance Engineer and Security Engineer (Actors, above) and the ADR (Prerequisites, above) — are untouched by this section and still trigger only against their own existing criteria.

Code Review and QA Validation are not on `Core/CAPABILITY_TIERS.md`'s sign-off/gate floor (a Director delivery gate, a release approval, a merge approval to main), so the Director's 23 Sep decision runs them at Lightweight here — except that guardrail 1 still applies in full: a change in a Sensitive change zone or carrying a Medium-or-higher RISK runs Code Review and QA at Standard Execution.

It is still a Work Unit in the full sense: the Commit Standard, Work Unit registration (`Registry/work-units.yml`, Step 4), and every required CI check still apply, and Exit Criteria below still governs completion. **Less load, not fewer controls: this is lighter execution of every step, not fewer steps.**

`Governance/CONTRIBUTING.md` §1 (Change Tiers) is where this same mechanical/non-mechanical distinction is framed for changes to the framework repository itself, rather than to a project built on it.

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
| Work Unit involves authentication or authorisation, secrets or credentials, a trust boundary, cryptography, or user input reaching a query, path or command | Security Engineer |


Both of those trigger a **consultation during implementation**, not a second review. `Workflows/CODE_REVIEW.md` already escalates a security finding to the Security Engineer and a compliance-relevant one to the Compliance Engineer, and that stays true — but a review can only find what the design already committed to. An authentication scheme, where a secret lives, or which side of a trust boundary a component sits on are decided while the Work Unit is being built; by review time the cost of changing them is the cost of rebuilding it. The same reasoning put Compliance Engineer here rather than leaving it to review, and it applies to security without modification.

The two entries are deliberately parallel. `Workflows/CODE_REVIEW.md` treats the two Employees identically, and an asymmetry here would read as a claim that security matters later than compliance does, which nothing in the Standards supports — `Standards/RISK_STANDARD.md` and `Standards/DATA_PROTECTION_STANDARD.md` bind every Employee from the first commit.
---

# Related Workflows

- Code Review Workflow
- Release Workflow
- Hotfix Workflow (for defects discovered post-merge)
- Architecture Decision Workflow (when an ADR is required)

---

# Metadata

Owner: IA Engineering

Version: 0.0.10

Status: Draft

Category: Workflow — Development

Severity: Mandatory
