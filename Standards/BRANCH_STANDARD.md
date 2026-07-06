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
```

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
- use inconsistent branch names.

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

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
