# Code Review Workflow

---

# Purpose

This workflow defines the process for reviewing a Pull Request from assignment to decision.

It ensures every change is reviewed systematically, that feedback is actionable, and that the decision to approve or block is documented and traceable.

---

# Trigger

- A Pull Request is opened and the Code Reviewer is assigned.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Code Reviewer | Executes the review and delivers a decision |
| Engineer (author) | Responds to review comments and makes requested changes |
| Security Engineer | Reviews security findings escalated by the Code Reviewer |
| Software Architect | Reviews architectural concerns escalated by the Code Reviewer |
| Engineering Manager | Resolves blockers when review cycles exceed two rounds |
| QA Engineer | Validates the change after approval when it is security-sensitive or high-risk (see "Security-Sensitive or High-Risk Changes") |

---

# Prerequisites

Before this workflow begins:

- The Pull Request is open with a description that states what changed, why, and how to test it.
- CI/CD checks (lint, tests, build) are passing or failures are explained in the PR description.
- The PR targets `develop`, not `main`.

---

# Steps

## Step 1 — Understand the intent

**Actor:** Code Reviewer

1. Read the PR description completely before opening any file.
2. Identify the linked Work Unit and its Definition of Done.
3. Confirm the PR scope matches the stated intent — nothing more, nothing less.

If the PR description is absent or insufficient: request the author to complete it before proceeding. Do not review an undescribed PR.

**Output:** Reviewer understands what the PR is trying to do.

---

## Step 2 — Review logic and correctness

**Actor:** Code Reviewer

1. Verify the business logic is correct against the acceptance criteria.
2. Identify edge cases not handled.
3. Check error handling — every error path must be handled explicitly.
4. Verify that no existing behavior is broken unintentionally.

**Output:** List of logic issues (if any).

---

## Step 3 — Review tests

**Actor:** Code Reviewer

1. Verify tests exist for the new behavior.
2. Verify tests cover edge cases and failure paths, not just the happy path.
3. Confirm tests are deterministic — no flaky or time-dependent assertions.
4. Verify test coverage does not regress.

If tests are missing or insufficient: this is a blocking issue. Request changes.

**Output:** Test coverage assessment.

---

## Step 4 — Review security

**Actor:** Code Reviewer

1. Check for OWASP Top 10 vulnerabilities in the changed code.
2. Verify no credentials, secrets, or sensitive data are in the diff.
3. Check that user input is validated at system boundaries.
4. Verify authentication and authorization are correctly applied to new endpoints or functions.

If a security issue is found: escalate immediately to the Security Engineer. Do not wait for the full review to complete.

**Output:** Security assessment. Escalation opened if needed.

---

## Step 5 — Review code quality

**Actor:** Code Reviewer

1. Verify naming is clear and consistent with the codebase conventions.
2. Verify the Code Quality Standard is respected.
3. Check that no dead code, commented-out code, or debug statements are included.
4. Verify that complexity is justified — no unnecessary abstractions.

**Output:** Quality assessment.

---

## Step 6 — Review documentation

**Actor:** Code Reviewer

1. Verify public interfaces are documented.
2. Verify complex or non-obvious logic has an explanatory comment.
3. Verify the CHANGELOG or relevant documentation is updated if the PR introduces a user-visible change.

**Output:** Documentation assessment.

---

## Step 7 — Deliver feedback

**Actor:** Code Reviewer

1. Write a comment for each issue found, using the severity format:
   - `[critical]` — must be fixed before approval (defect, security, missing tests)
   - `[major]` — should be fixed before approval (quality, correctness risk)
   - `[minor]` — can be fixed or logged as follow-up (style, minor improvement)
   - `[suggestion]` — optional improvement, does not block approval
2. Be specific: state the issue, why it matters, and a direction for resolution.
3. Never rewrite the author's code in a review comment — give direction, not a replacement.

**Output:** Review comments submitted.

---

## Step 8 — Decision

**Actor:** Code Reviewer

- **Approve** — no critical or major issues, or all have been resolved.
- **Request changes** — one or more critical or major issues remain.
- **Escalate** — security or architecture issue requires specialist review before a decision can be made.

Document the decision with a summary comment stating what was reviewed and what the blocking conditions are (if any).

**Output:** PR approved, changes requested, or escalated.

---

## Step 9 — Author response (if changes requested)

**Actor:** Engineer (author)

1. Address each review comment explicitly — respond to each one, even if the response is "acknowledged, fixed" or "disagree, here's why."
2. Push changes as a new commit — do not force-push unless explicitly requested by the reviewer.
3. Re-request review.

**Output:** PR updated, review re-requested.

**Handoff to:** Step 1 (reviewer re-enters the workflow for the new diff only).

---

# Security-Sensitive or High-Risk Changes

After the Code Reviewer approves a PR, the change is routed to the QA Engineer for validation when it is **security-sensitive or high-risk**. This is not an informal judgment — it is checked against the concrete trigger list below. If a PR touches any of the following, it is security-sensitive or high-risk and QA Engineer validation is required before delivery:

- **Authentication or authorization logic** — login, session handling, or changes to an access-control or permission/role model.
- **Credentials, secrets, or keys** — handling of passwords, API keys, tokens, certificates, or any secret material.
- **Regulated or personal data** — processing, storage, or transmission of PII or other data governed by GDPR, HIPAA, PCI-DSS, SOC 2, or an equivalent framework.
- **Payment or financial transaction processing.**
- **Cryptography usage** — encryption, hashing, signing, or key management.
- **Public-facing API surface** — new or modified externally reachable endpoints, request/response contracts, or API authentication.
- **Untrusted input at a trust boundary** — parsing, deserialization, file upload, or query construction from external input.
- **Infrastructure, deployment, or configuration with production access** — IAM policies, network exposure, or secrets-management configuration.
- **Security architecture changes** — any change that meets the "Security architecture change" ADR trigger in `Workflows/ARCHITECTURE_DECISION.md`.

If the Code Reviewer flags a security concern during the review (Step 4), the Security Engineer is engaged before the QA Engineer, per the Escalation table.

When in doubt: treat the change as security-sensitive and route it through QA Engineer validation. The cost of an unnecessary validation is lower than the cost of shipping an unreviewed security-sensitive change.

---

# Exit Criteria

This workflow is complete when:

- The PR has a documented approval from the Code Reviewer.
- All critical and major issues are resolved.
- Security escalations are resolved or formally accepted by the Security Engineer and Director.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Security vulnerability found | Security Engineer — immediately |
| Architectural issue found | Software Architect |
| Review exceeds two cycles without resolution | Engineering Manager |
| Author is unresponsive for more than one business day | Engineering Manager |

---

# Related Workflows

- Feature Development Workflow
- Hotfix Workflow
- Release Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Workflow — Quality

Severity: Mandatory
