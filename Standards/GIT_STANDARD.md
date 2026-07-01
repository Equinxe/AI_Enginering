# Git Standard

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory

---

# Purpose

This standard defines how Git must be used within IA Engineering.

Git is an engineering communication tool. A clean Git history improves collaboration, reviewability, traceability, and long-term maintainability.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Rules

## One Work Unit, One Commit

Each completed Work Unit should produce one logical commit.

A commit represents a completed engineering milestone, not a backup.

---

## Atomic Changes

Each commit must address a single objective.

Do not combine unrelated changes.

---

## Small Commits

Commits should remain small enough to be reviewed comfortably.

When a commit becomes difficult to review, split the work into multiple Work Units.

---

## Incremental Development

Features should be developed incrementally.

Partial but functional progress is encouraged.

Avoid implementing large features in a single commit.

---

## Traceability

Every commit should clearly explain the evolution of the project.

Future contributors should understand what changed and why.

---

## Commit Before Context Switch

Before switching to another engineering task, commit the current Work Unit if it is complete.

Avoid mixing unrelated modifications.

---

# Forbidden Practices

The following practices are prohibited:

- Huge commits containing multiple unrelated changes.
- Mixing refactoring with feature development.
- Committing unfinished unrelated work.
- Using Git only as a backup solution.
- Skipping logical commit history.

---

# Engineering Principle

Git history is part of the engineering documentation.

A well-structured history is as valuable as clean source code.

---

# Rationale

Following this standard provides:

- Easier code reviews
- Better collaboration
- Simpler debugging
- Clear project history
- Reduced regression risk

---

# References

- Work Unit
- Commit Standard
- Pull Request Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
