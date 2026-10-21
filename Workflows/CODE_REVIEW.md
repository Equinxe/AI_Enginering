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
| Compliance Engineer | Reviews compliance findings escalated by the Code Reviewer (regulated data handling, retention/deletion logic, cross-border data transfer) |
| Prompt Engineer | Approves every change to an Employee definition (`Employees/`) or to any `Core/*.md` document (including a deletion or rename), in addition to the Code Reviewer, and never a change it authored (`Core/EMPLOYEE_SELECTION.md`, Prompt Engineer trigger) |
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
5. Verify the red-run evidence for each test within the scope of `Standards/TESTING_STANDARD.md` (Falsifiability, item 7): its "fails if" names an observable behaviour of the system, and its red run fails on that behaviour. A missing red run, a tautological "fails if" (such as "fails if the test fails"), or an over-determined red run is a blocking finding.

If tests are missing or insufficient: this is a blocking issue. Request changes.

**Output:** Test coverage assessment.

---

## Step 4 — Review security and compliance

**Actor:** Code Reviewer

1. Check for OWASP Top 10 vulnerabilities in the changed code.
2. Verify no credentials, secrets, or sensitive data are in the diff.
3. Check that user input is validated at system boundaries.
4. Verify authentication and authorization are correctly applied to new endpoints or functions.
5. Check for compliance-relevant content: regulated data handling (PII, payment data, health data), retention/deletion logic, or cross-border data transfer.

If a security issue is found: escalate immediately to the Security Engineer. Do not wait for the full review to complete.

If compliance-relevant content is found: escalate immediately to the Compliance Engineer, the same way a security issue escalates to the Security Engineer. Do not wait for the full review to complete.

If the Pull Request makes a change to an Employee definition (`Employees/`) or to any `Core/*.md` document (including a deletion or rename): request the Prompt Engineer's review, whether or not a finding exists. The Prompt Engineer's **approval** is required before merge, in addition to this review, and must cover the `Employees/` and `Core/*.md` text the head carries. A later push that changes that text needs it again; a merge of `develop` into the branch keeps it only as condition 1 of `Core/MAIN_AGENT_CONDUCT.md` (Git Execution via Named Employee) allows. If the Prompt Engineer authored the change, its own review does not count: escalate to the Director, who names the second reviewer (`Core/EMPLOYEE_SELECTION.md`, Prompt Engineer trigger).

**Output:** Security assessment. Escalation opened if needed (Security Engineer and/or Compliance Engineer). Prompt Engineer review requested for a change to `Employees/` or any `Core/*.md` document (including a deletion or rename).

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

Document the decision with a summary comment stating **what was reviewed** — which files, which lenses (Steps 2–6), which claims in the description were verified against the repository — and what the blocking conditions are (if any). A review that found nothing states what it looked at; "LGTM" with no denominator is not a decision, it is an absence of one.

**Output:** PR approved, changes requested, or escalated.

---

## Step 9 — Author response (if changes requested)

**Actor:** Engineer (author)

1. Address each review comment explicitly — respond to each one, even if the response is "acknowledged, fixed" or "disagree, here's why."
2. Push changes as a new commit — do not force-push unless explicitly requested by the reviewer.
3. Re-request review.

**Output:** PR updated, review re-requested.

**Handoff to:** Step 1 (reviewer re-enters the workflow for the new diff only — after re-anchoring, below).

### Line Re-Anchoring

Before re-reviewing, the Code Reviewer **re-anchors every open finding** to the new diff. A finding was made against a line number that the new commit may have moved or removed; each one is either:

- re-anchored to the line that now carries the same code, or
- closed with an explicit disposition — `resolved by <commit>`, or `withdrawn: <reason>`.

A finding is **never dropped because its line disappeared**. A deleted line is not a fixed defect; the defect may have moved. The reviewer's re-review comment lists the re-anchored and closed findings by their original identifiers, so the author and any later reader can see that every finding reached a disposition.

---

# Multi-Lens Review

Steps 2 through 6 are five **lenses** — correctness, tests, security and compliance, quality, documentation. For an ordinary Pull Request one Code Reviewer applies them in sequence. For a Pull Request that is **security-sensitive or high-risk** (the trigger list below), or that carries a `High` or `Critical` `RISK:` record in its Work Unit Report (`Standards/RISK_STANDARD.md`), the lenses are applied by **separate passes**, and where the runtime allows it, by separate Employees:

| Lens | Applied by | Why separate |
|---|---|---|
| Correctness, quality, documentation (Steps 2, 5, 6) | Code Reviewer | The baseline pass |
| Tests (Step 3) | QA Engineer | Whether the tests *can fail* is a question the author of the review checklist tends to answer optimistically |
| Security and compliance (Step 4) | Security Engineer; Compliance Engineer when regulated data is in scope; Prompt Engineer for a change to `Employees/` or any `Core/*.md` document (including a deletion or rename) | Already the Escalation rule when a finding exists; for high-risk changes the pass runs whether or not the baseline reviewer noticed anything. The Prompt Engineer's approval is required on every such change, whatever its risk |

Three rules make separate passes worth more than one long one:

1. **Independence first.** Each pass records its findings *before* reading the others'. A lens that reads the baseline review first inherits its blind spots.
2. **Cross-debate, decided by evidence.** The passes then read each other's findings. Where two disagree — one calls a path unreachable, another calls it exploitable — the disagreement is resolved by a reproduction, a test, or a trace through the code, and the resolution is written down. It is never resolved by which Employee is senior, and never left as "both noted".
3. **One decision.** The Code Reviewer consolidates the findings, re-labels severity where the debate changed it, and delivers the single Step 8 decision. Three reviews with three verdicts is not a review; it is three opinions.

---

# Ten Review Lessons

Recorded because each was learned by getting it wrong at least once, in this framework's own reviews or in the sibling corpora it draws on. They bind the Code Reviewer alongside the Steps.

1. **Read the description before any file.** The review is of the change against its stated intent; without the intent there is nothing to review against.
2. **Verify claims against the repository, not against the description.** "Tests pass" is checked by the CI log or by running them. "No trailers on these commits" was once reported on four commits that each carried one.
3. **A test that cannot fail is not a test.** For every new test, ask what change to the code would make it red. If nothing would, it is a fixture. The evidence this requires is set by `Standards/TESTING_STANDARD.md` (Falsifiability) and checked at Step 3, item 5.
4. **Review what is absent.** The file that should have changed and did not; the test that should exist; the migration without a rollback; the documentation the change made stale. Diffs show additions; defects hide in omissions.
5. **Count the things prose counts.** "Six checks", "three rules", "42 Employees" — every literal count in the changed documents is checked against the set it counts. They drift every time the set grows.
6. **Run the falsifier.** When the author claims a mechanism behaves a certain way, enumerate what else it could do, then test the alternative. A claim that "splitting the trailers buys nothing" was accepted until the measurement showed 28 of 30 commits parsed only when split. For a test, the falsifier is the red run `Standards/TESTING_STANDARD.md` (Falsifiability) requires.
7. **Severity follows consequence, not effort.** A one-character fix to an authorization check is `[critical]`; a two-hundred-line renaming is `[minor]`. Never let the size of the fix set the label.
8. **Give direction, not a replacement.** A review comment that rewrites the author's code has stopped reviewing and started implementing — and the rewrite is now unreviewed.
9. **Re-review only the new diff, but re-anchor every old finding.** Re-reading the whole PR each round is waste; losing a finding because its line moved is a defect shipped.
10. **State the denominator.** What was read, which lenses ran, which claims were verified. A review that reports only its findings hides how much it did not look at — the same defect as a check that reports success without evaluating (`Adapters/README.md`, the Check Convention).

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
- **User-facing UI changes that affect accessibility** — new or modified interactive components, focus order, contrast, or ARIA / platform accessibility attributes.

If the Code Reviewer flags a security concern during the review (Step 4), the Security Engineer is engaged before the QA Engineer, per the Escalation table.

When in doubt: treat the change as security-sensitive and route it through QA Engineer validation. The cost of an unnecessary validation is lower than the cost of shipping an unreviewed security-sensitive change.

---

# Exit Criteria

This workflow is complete when:

- The PR has a documented approval from the Code Reviewer.
- All critical and major issues are resolved.
- Security escalations are resolved or formally accepted by the Security Engineer and Director.
- A change to `Employees/` or any `Core/*.md` document (including a deletion or rename) has the Prompt Engineer's approval on the `Employees/` and `Core/*.md` text the head carries, or, when the Prompt Engineer authored it, the approval of the reviewer the Director named (Step 4). A later push that changes that text needs it again; a merge of `develop` into the branch keeps it only as condition 1 of `Core/MAIN_AGENT_CONDUCT.md` (Git Execution via Named Employee) allows.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Security vulnerability found | Security Engineer — immediately |
| Compliance-relevant content found (regulated data handling, retention/deletion logic, cross-border data transfer) | Compliance Engineer — immediately |
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

Version: 0.0.9

Status: Draft

Category: Workflow — Quality

Severity: Mandatory
