# Employee Brief Template

---

# Usage

An Employee Brief is the context package the Main Agent delivers to an employee when assigning a Work Unit.

It gives the employee exactly the context they need — nothing more. The employee does not read the entire repository. They receive this brief and the relevant standards, then execute.

This is the Context Engine in practice: the Main Agent filters, structures, and delivers only the information the employee needs to complete their Work Unit independently.

---

# Template

```markdown
## Employee Brief — [WU-ID]

**To:** [Employee name — e.g., Backend Engineer]
**Selected by:** "[the rule this dispatch relies on, quoted verbatim, with its source: a `Core/EMPLOYEE_SELECTION.md` trigger line, or the `Core/AGENT_CHAINS.md` or Workflow step that names this Employee]"
**Rejected:** [the closest Miscasting Risks pair considered — e.g., Code Reviewer vs. Technical Lead — and in one clause why the other Employee does not fit; if no pair names this Employee, the nearest Employee considered and why. Never "none".]
**From:** Main Agent
**Work Unit:** [WU-ID]
**Date:** [YYYY-MM-DD]
**Execution tier:** [Lightweight | Standard | Strategic | Frontier] (default: <Employee tier>)
**Tier reason:** [required only when the Execution tier differs from the default — see `Core/CAPABILITY_TIERS.md`, Tier Override; for Frontier, quote the Director's approval]

---

### Your Assignment

[One sentence: what you must deliver by the end of this Work Unit.]

---

### Why This Matters

[Why this Work Unit exists in the project context. What business or technical problem it solves. Enough context to make good decisions — not the entire project history.]

---

### What You Need to Know

**Project:** [project name and one-line description]
**Stack:** [relevant technology — only what applies to this Work Unit]
**Current state:** [what exists today that this Work Unit builds on or changes]

**Relevant decisions:**
- [ADR-ID]: [brief description of the architectural decision that governs your work]

**Related Work Units:**
- [WU-ID]: [what it did — relevant because it is a dependency or context]

---

### Your Inputs

Everything you need before starting:

- [ ] [Input 1 — e.g., "API contract at docs/api/auth.yaml"]
- [ ] [Input 2 — e.g., "Database schema — see migrations/0012_add_users_table.sql"]
- [ ] [Input 3 — e.g., "WU-XX is merged and the auth middleware is available"]

---

### Your Outputs

What you must deliver:

- [ ] [Output 1 — e.g., "POST /auth/login endpoint"]
- [ ] [Output 2 — e.g., "Unit tests covering success and failure paths"]
- [ ] [Output 3 — e.g., "OpenAPI spec updated for the new endpoint"]

---

### Your Definition of Done

You are done when ALL of the following are true:

- [ ] [Criterion 1 — fails if: ___ | not falsifiable: <reason>]
- [ ] [Criterion 2 — fails if: ___ | not falsifiable: <reason>]
- [ ] Tests are written and passing, and each was seen red where `Standards/TESTING_STANDARD.md` (Falsifiability) requires it.
- [ ] Pull Request is open and assigned to the Code Reviewer.
- [ ] Your commit follows the Commit Standard: `[type](scope): description`
- [ ] Your Work Unit Report is written — see below. Without it this Work Unit is not done.

---

### Your Report

Write it as your final action, in the form of `Templates/WORK_UNIT_REPORT.md`:

**Destination:** [the Pull Request description, or a file path — say which. `Core/AGENT_CONDUCT.md`'s Reporting Contract requires a durable location; a message in a conversation is not one.]

It carries a one-word verdict, what was done, **what was not done**, the gate evidence pasted rather than described, any deviation from this brief, your risk records, and this brief's Definition of Done item by item. A bare "Done" is a failed Work Unit: the Main Agent has nothing to verify against, and Step 5 of `Core/ORCHESTRATION.md` will return it.

---

### Standards You Must Follow

Read and apply these before writing any code:

- [Standard 1 — e.g., Code Quality Standard — `Standards/CODE_QUALITY_STANDARD.md`]
- [Standard 2 — e.g., Testing Standard — `Standards/TESTING_STANDARD.md`]
- [Standard 3 — e.g., OWASP API Security Top 10]

These three bind you whether or not this brief lists them, because their Scope says so (`Core/AGENT_CONDUCT.md`, What an Employee's Own List Does Not Limit):

- `Standards/STANDARDS_FIRST.md` — the official standard first, project convention second.
- `Standards/RISK_STANDARD.md` — classify a risk-bearing action **before** performing, planning, or delegating it. `High` and `Critical` stop and wait for a confirmation that names the action; every `Medium`-or-higher decision is recorded in your report.
- `Standards/DATA_PROTECTION_STANDARD.md` — real data, secrets, and operational state stay out of version control.

---

### Constraints and Boundaries

[Explicit constraints the employee must not cross:]
- [e.g., Do not modify the authentication middleware — that is WU-XX scope]
- [e.g., Do not add new dependencies without Engineering Manager approval]
- [e.g., The response schema must match the approved contract exactly — no additions]

Whatever this brief adds, these bind every Work Unit that runs tests:

- Run first the tests that cover what you changed: the test file, or the section of the suite, that exercises it, where the suite can run one.
- Run at most one full test suite at a time. A second suite starts only after the first has exited: never beside it in the background (`&`, a runtime's background command), never fanned out (`xargs -P`, `parallel`).
- Bound every full-suite run with a timeout. A run the timeout ended is not evaluated, never passed.
- The required CI checks on the Pull Request run every suite. Your report pastes their result as the gate evidence for the suites you did not run.

---

### Escalation

If you encounter a blocker, escalate immediately — do not guess:

| Blocker type | Escalate to |
|---|---|
| Unclear requirement or acceptance criteria | Engineering Manager |
| Architectural decision needed | Software Architect |
| Security concern | Security Engineer |
| Input dependency not ready | Engineering Manager |
| An action you classify `High` or `Critical` | Director, through the Main Agent — with the escalation block from `Standards/RISK_STANDARD.md`, then **wait**. Silence, "looks fine", or a go-ahead given earlier for something else is not confirmation. |

---

### Expected Commit

```
[type](scope): [description]
```

Example: `feat(auth): add POST /auth/login with JWT response`
```

**Selected by** and **Rejected** make the choice of Employee reviewable before any work starts. A quoted rule that describes another Employee's work, or a pair rejected for convenience rather than fit, is role absorption (`Core/MAIN_AGENT_CONDUCT.md`, Employee Selection) — visible in the brief instead of discovered in the commit.

A brief never prescribes which model authors the commit. If the runtime adds an optional attribution trailer, it names whichever model actually ran — see `Standards/COMMIT_STANDARD.md`, Runtime attribution trailer.

The test-run limits exist because every Employee shares one machine: on 28 Oct 2026, about ten agents running test suites at once ran the editor out of memory, and a peer framework lost its environment on 26 Oct to three parallel flows running six suites. The required CI checks, not a local full run, are the evidence that every suite passes (`Workflows/FEATURE_DEVELOPMENT.md`, Step 3).

---

# When to Use This Template

The Main Agent creates an Employee Brief every time a Work Unit is delegated to an employee. The brief is the single document the employee reads before starting. All other context is contained within it or referenced from it.

An employee who cannot complete their Work Unit from this brief alone has received an incomplete brief — the Main Agent must improve it, not the employee.

---

# Context Engine Principle

The Employee Brief implements the Context Engine:

> Employees receive only the context they need, never the whole repository.

**What to include:**
- The specific files, schemas, or contracts the employee will touch.
- The ADRs that govern their decisions.
- The Work Units they depend on.
- The constraints they must not cross.

**What to exclude:**
- Project history not relevant to this Work Unit.
- Standards the employee does not need for this specific task.
- Other teams' context, unrelated architecture, future plans.

A brief that is too long is as harmful as one that is too short. The Main Agent's job is precision.

---

# Metadata

Owner: IA Engineering

Version: 0.0.10

Status: Draft

Category: Template — Orchestration

Severity: Mandatory
