# Commit Standard

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory

---

# Purpose

This standard defines how commits are created within IA Engineering.

IA Engineering adopts the Conventional Commits specification and extends it with engineering practices that improve traceability, collaboration, and AI-assisted development.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Official References

The following references are considered authoritative:

- Conventional Commits Specification
- Git Documentation

---

# Industry Best Practices

Projects should:

- create small, focused commits;
- write meaningful commit messages;
- keep commits atomic;
- maintain a readable Git history.

---

# IA Engineering Additions

## One Work Unit = One Commit

A completed Work Unit should produce one commit.

A commit represents one engineering objective.

---

## Commit Readiness

Before creating a commit, verify that:

- the Work Unit is complete;
- the project builds (when applicable);
- tests pass (when applicable);
- no temporary or generated files are included;
- documentation has been updated if required.

---

## Engineering Intent

Every commit should clearly answer:

> Why does this change exist?

If the answer cannot be expressed in one sentence, the Work Unit should probably be divided.

---

# Responsibilities

Every Employee must:

- follow the Conventional Commits specification;
- create small and reviewable commits;
- avoid mixing unrelated changes;
- commit only completed Work Units.

---

# Forbidden Practices

Do not:

- create meaningless commit messages;
- commit unfinished work on shared branches;
- mix multiple engineering objectives;
- use commits as temporary backups;
- commit debugging artifacts or temporary files.

---

# Rationale

Following this standard provides:

- better code reviews;
- clearer project history;
- easier debugging;
- improved collaboration;
- predictable AI-generated commits.

---

# Related Standards

- Standards First
- Git Standard
- Branch Standard
- Pull Request Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
