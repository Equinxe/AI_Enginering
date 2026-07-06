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

1. **Understand the intent** — Read the PR description and linked Work Unit before reading any code.
2. **Verify the scope** — Confirm the PR does what it claims and nothing more.
3. **Review logic** — Check business logic correctness, edge cases, and error handling.
4. **Review tests** — Verify tests cover the new behavior, edge cases, and failure paths.
5. **Review security** — Check for OWASP vulnerabilities, injection risks, and improper data handling.
6. **Review quality** — Verify naming, structure, and adherence to the Code Quality Standard.
7. **Review documentation** — Confirm public interfaces, complex logic, and changed APIs are documented.
8. **Provide feedback** — Leave specific, actionable comments with clear severity.
9. **Decide** — Approve, request changes, or escalate as appropriate.

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

Decision: [approved / changes requested / escalated]

Summary:
- Critical issues: [count] — [resolved / blocking]
- Major issues: [count] — [resolved / blocking]
- Minor issues: [count]
- Suggestions: [count]

Approval conditions: [what must change before approval]
```

---

# Definition of Done

A code review Work Unit is complete when:

- All files in the Pull Request have been reviewed.
- All critical and major issues are documented as review comments.
- A decision is recorded: approved, changes requested, or escalated.
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

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory
