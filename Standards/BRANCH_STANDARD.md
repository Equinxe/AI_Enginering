# Branch Standard

---

# Purpose

This standard defines how Git branches are managed within IA Engineering.

IA Engineering does not enforce a specific branching strategy. Instead, it adopts the branching workflow selected by the project and ensures that every Employee follows it consistently.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Official References

The following references are considered authoritative:

- Git Documentation
- GitHub Flow
- Git Flow
- Trunk-Based Development

---

# Industry Best Practices

Projects should:

- document their branching strategy;
- use meaningful branch names;
- isolate work in dedicated branches;
- keep branches focused on a single objective;
- regularly synchronize with the integration branch.

---

# IA Engineering Additions

## Project Branch Strategy

Every project must define its branching strategy during initialization.

All Employees must follow this strategy consistently.

---

## Branch Naming

Branch names should follow the project's documented convention.

Examples include:

```
feature/project-crud
feature/user-authentication

fix/login-timeout

hotfix/security-patch

release/v1.2.0

docs/short-description

spike/short-question
```

`docs/` — documentation-only changes, no source or configuration touched (this repository's own history: `docs/express-path-trivial-changes`, `docs/entry-point-clarity`).

`spike/` — a throwaway prototype that answers one question and is never merged (Throwaway Prototype Branches, below).

The naming convention must remain consistent throughout the project.

---

## Single Objective

A branch should contain one engineering objective.

Avoid mixing unrelated work within the same branch.

---

## Branch Lifecycle

Branches should be:

- created for a defined purpose;
- merged once completed;
- deleted when no longer needed.

**Protected-branch exception:** `main`, `develop`, and `release/*` are protected and are never deleted — release branches in particular are preserved indefinitely. `Standards/GIT_STANDARD.md` is the controlling rule for branch protection; this lifecycle applies to feature, fix, and hotfix branches, not to protected ones.

## Throwaway Prototype Branches

A `spike/*` branch answers one question by building something to throw away: a prototype, a measurement, a proof that an approach works or does not. Its code is never merged; its answer is.

- **Who creates it:** the Employee dispatched on a Work Unit whose objective is the question, under an Employee Brief that names the branch and the ADR the answer feeds (`Workflows/ARCHITECTURE_DECISION.md`).
- **What it holds:** commits that follow `Standards/COMMIT_STANDARD.md` and `Standards/DATA_PROTECTION_STANDARD.md` like any other. Nothing in it is reviewed as deliverable code.
- **How it ends:** the ADR's Options Considered records the question, the answer, the evidence (what was tried, what was measured, what failed), and the branch's last commit. The decision lives in the ADR, never only in the branch. Code the decision keeps is rewritten on a `feature/*` branch, under its own Work Unit and the normal review.
- **Never merged:** a Pull Request from a `spike/*` branch is closed unmerged.
- **Lifetime:** it ends when its ADR is merged, and at the latest at the end of the Milestone in which it was opened. Past that, the Main Agent reports it to the Director as obsolete.
- **Deletion:** its commits are never merged, so deleting it discards work. That is a High action (`Standards/RISK_STANDARD.md`, Operational catalog), taken on the Director's instruction once the ADR is merged.

---

# Responsibilities

Every Employee must:

- create branches according to the project workflow;
- respect the naming convention;
- keep branches focused;
- synchronize with the project workflow.

---

# Forbidden Practices

Do not:

- develop directly on protected branches;
- create branches without a clear objective;
- keep obsolete branches indefinitely;
- use inconsistent branch names;
- merge a spike/* branch, or keep its decision only in the branch.

---

# Rationale

Following a consistent branching strategy provides:

- better collaboration;
- easier reviews;
- safer integrations;
- cleaner project history;
- predictable AI workflows.

---

# Related Standards

- Standards First
- Git Standard
- Commit Standard
- Pull Request Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Engineering Standard

Severity: Mandatory
