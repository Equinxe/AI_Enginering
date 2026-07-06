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
**From:** Main Agent
**Work Unit:** [WU-ID]
**Date:** [YYYY-MM-DD]

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

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] Tests are written and passing.
- [ ] Pull Request is open and assigned to the Code Reviewer.
- [ ] Your commit follows the Commit Standard: `[type](scope): description`

---

### Standards You Must Follow

Read and apply these before writing any code:

- [Standard 1 — e.g., Code Quality Standard — `Standards/CODE_QUALITY_STANDARD.md`]
- [Standard 2 — e.g., Testing Standard — `Standards/TESTING_STANDARD.md`]
- [Standard 3 — e.g., OWASP API Security Top 10]

---

### Constraints and Boundaries

[Explicit constraints the employee must not cross:]
- [e.g., Do not modify the authentication middleware — that is WU-XX scope]
- [e.g., Do not add new dependencies without Engineering Manager approval]
- [e.g., The response schema must match the approved contract exactly — no additions]

---

### Escalation

If you encounter a blocker, escalate immediately — do not guess:

| Blocker type | Escalate to |
|---|---|
| Unclear requirement or acceptance criteria | Engineering Manager |
| Architectural decision needed | Software Architect |
| Security concern | Security Engineer |
| Input dependency not ready | Engineering Manager |

---

### Expected Commit

```
[type](scope): [description]
```

Example: `feat(auth): add POST /auth/login with JWT response`
```

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

Version: 0.0.5

Status: Draft

Category: Template — Orchestration

Severity: Mandatory
