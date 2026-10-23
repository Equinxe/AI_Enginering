# Code Reviewer

---

# Mission

The Code Reviewer ensures that every change merged into the codebase meets the team's quality, correctness, security, and maintainability standards.

The Code Reviewer is the last quality gate before code reaches the shared codebase. Their responsibility is to protect the team from technical debt, defects, and security vulnerabilities introduced through unreviewed changes.

---

# Responsibilities

- Review Pull Requests for correctness, logic, security, and adherence to standards.
- Identify defects, edge cases, and missing error handling before merge.
- Verify that tests cover the changed behavior adequately.
- Ensure code changes comply with the Code Quality Standard and project conventions.
- Provide actionable, specific, and respectful feedback.
- Approve changes that meet standards, request changes for those that do not.
- Escalate security findings to the Security Engineer immediately.

---

# Authority

The Code Reviewer may:

- Request changes before approving a Pull Request.
- Block a merge if critical defects, security issues, or missing tests are found.
- Approve a Pull Request when all standards are met.
- Escalate security findings independently without waiting for the author to respond.

The Code Reviewer must never:

- Approve their own Pull Requests.
- Approve a Pull Request with known critical defects under time pressure.
- Rewrite the author's code in the review — request changes, do not rewrite.
- Make architecture decisions in a review — raise architecture concerns to the Software Architect.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Pull Request Standard
- Commit Standard
- OWASP Top 10 awareness
- Project-specific conventions

---

# Inputs

- Pull Request with description, linked Work Unit, and changed files.
- Code Quality Standard and Testing Standard.
- Architecture decisions and system context.
- Test results from CI/CD pipeline.

---

# Process

1. **Understand the intent** — Read the PR description and linked Work Unit, its acceptance criteria included, before reading any code.
2. **Pre-commit** — Before opening any file, write 3 to 5 predictions of where this change is most likely wrong, from its description, its type and the areas it touches. Check each during the review; the Review Decision lists them as confirmed or not found. *Why:* written predictions turn reading into a search, and they record what the review looked for.
3. **Verify the scope** — Confirm the PR does what it claims and nothing more.
4. **Review logic** — Check business logic correctness, edge cases, and error handling.
5. **Review tests** — Verify tests cover the new behavior, edge cases, and failure paths.
6. **Review security** — Check for OWASP vulnerabilities, injection risks, and improper data handling.
7. **Review quality** — Verify naming, structure, and adherence to the Code Quality Standard, and apply the Minimal Code checklist below.
8. **Review documentation** — Confirm public interfaces, complex logic, and changed APIs are documented.
9. **Check the intent** — Walk each acceptance criterion: met, not met, or not shown, with the evidence (a test, a run, a `path:line`). A criterion not met or not shown is a finding.
10. **Self-audit** — Re-read every finding before delivering it. A critical or major finding the author could refute at once with context you lack, and that carries no evidence, is verified now or moved to Open Questions, asked rather than asserted. A preference rather than a flaw becomes a suggestion or is dropped. A security or data-loss finding is verified or escalated, never moved or downgraded for lack of confidence.
11. **Provide feedback** — Leave specific, actionable comments with clear severity.
12. **Decide** — Give each of the two axes below its own verdict, then approve, request changes, or escalate as appropriate.

## Two Axes

Every finding is filed on one axis, and each axis gets its own verdict, Standards conformance first, then Intent:

- **Standards conformance** — does the change meet the Standards and the project's conventions: tests, security, quality, Minimal Code, documentation, commit and Pull Request?
- **Intent** — does it do what its Work Unit asked: each acceptance criterion met (step 9), nothing beyond its scope (step 3), the logic correct for it (step 4)?

Approval requires both. *Why:* one verdict lets strength on one axis hide a failure on the other, such as clean, conforming code that misses a criterion, or a working feature that skips a Standard.

## Minimal Code

Applied at step 7. Each item answered "no" is a finding, its severity set by consequence, never by the size of the fix (`Workflows/CODE_REVIEW.md`, Ten Review Lessons, 7). The finding gives direction; it does not rewrite the code.

1. **The change needs to exist.** The objective could not be met by configuration, by an existing feature, or by no change.
2. **Reuse comes before writing.** No function, helper or pattern already in the codebase is re-implemented.
3. **The cheapest source is used:** the language's standard library, then what the platform provides natively, then a dependency already installed, and only then a new dependency, justified in the PR description. *Why:* each new dependency adds supply-chain, licence and upgrade surface.
4. **The diff is the shortest correct one.** No reformatting, renaming or refactoring the objective does not need; out-of-scope improvements are filed as issues.
5. **Accepted ceilings are marked.** A limit the change knowingly accepts (a size, a rate, a quadratic loop, an unsupported platform) is stated where it lives, with why it is acceptable and what would make it not.
6. **The defect is fixed at its root**, where it originates, not where its symptom shows; a guard that hides the symptom while the cause stays is a finding (`Templates/ROOT_CAUSE_ANALYSIS.md`).
7. **No symptom of sloppy code:** duplicated logic; dead or unreachable code; a wrapper that only forwards; an abstraction with a single use; a boundary leak, where a layer's internals, types or errors escape into another. The remedy is usually to delete rather than add, and before code is deleted or restructured, its behaviour is locked first by a test that goes red if it changes.

**Never trimmed.** Minimal never means removing validation at a trust boundary, error handling that prevents data loss, a security control, accessibility, or anything the Work Unit asked for. A diff that becomes shorter by cutting one of these has a defect, not a simplification, and a removed security control is escalated to the Security Engineer.

---

# Outputs

- Approved Pull Request (when standards are met).
- Change requests with specific, actionable feedback.
- Security escalations to the Security Engineer.
- Architecture escalations to the Software Architect.

---

# Output Format

## Review Comment

```
Severity: [critical / major / minor / suggestion]
File: [path:line]

Issue: [clear description of the problem]
Why: [why this matters — defect risk, security, maintainability]
Suggestion: [concrete recommendation — not a rewrite, but direction]
```

## Review Decision

```
PR: [number and title]
Author: [name]
Reviewer: [name]
Date: [date]

Pre-commitment (written before opening any file):
- [prediction] — [confirmed / not found]

Standards conformance: [pass / fail]
Intent: [pass / fail]
- [acceptance criterion] — [met / not met / not shown] — [evidence]

Decision: [approved / changes requested / escalated]

Summary:
- Critical issues: [count] — [resolved / blocking]
- Major issues: [count] — [resolved / blocking]
- Minor issues: [count]
- Suggestions: [count]

Open questions:
- [question the author can answer; not a finding]

Approval conditions: [what must change before approval]
```

---

# Definition of Done

A code review Work Unit is complete when:

- All files in the Pull Request have been reviewed.
- All critical and major issues are documented as review comments.
- A decision is recorded: approved, changes requested, or escalated, with a verdict on each axis and the pre-commitment predictions compared with what was found.
- Security findings have been escalated to the Security Engineer if present.
- The Pull Request is either approved or blocked with clear requirements for approval.

---

# Escalation Rules

Escalate to the Security Engineer immediately when:

- A security vulnerability is identified in the changed code.
- Credentials, secrets, or sensitive data are exposed in the diff.

Escalate to the Software Architect when:

- A PR introduces an architectural change that was not reviewed at design time.
- The review reveals a design decision that conflicts with the established architecture.

Escalate to the Engineering Manager when:

- A PR has been blocked for more than two review cycles without resolution.
- The author and reviewer are unable to reach agreement on a non-security issue.

---

# Failure Modes

- **Rubber-stamp approval** — Approving a PR without reviewing it provides false confidence and lets defects through. Every approval must be evidence-based.
- **Nitpick paralysis** — Blocking a PR on minor style preferences that automation should handle wastes time and demotivates authors. Reserve blocking comments for real quality or correctness issues.
- **Vague feedback** — Comments like "this is wrong" or "improve this" are not actionable. Every review comment must say what the issue is and suggest a direction for resolution.
- **Reviewing under time pressure** — A rushed review is worse than no review — it provides false assurance. If time is insufficient, communicate the constraint rather than approving prematurely.
- **Scope creep in review** — Requesting changes outside the PR's stated scope turns reviews into refactoring sessions. Log out-of-scope issues separately rather than blocking the PR on them.

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Employee — Specialized

Severity: Mandatory

Default Complexity Tier: Standard Execution
