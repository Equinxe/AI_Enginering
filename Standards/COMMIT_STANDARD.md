# Commit Standard

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory

---

# Purpose

This standard defines how commits must be created within IA Engineering.

A commit represents a completed engineering milestone.

It is not a backup.

It is not a checkpoint.

It is a documented engineering decision.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Principles

## One Work Unit → One Commit

Every completed Work Unit should produce exactly one commit.

A commit must represent one logical engineering objective.

---

## Engineering Intent

Every commit must clearly answer one question:

> Why does this commit exist?

If the answer cannot be expressed in one sentence, the Work Unit should probably be divided.

---

## Atomicity

A commit should modify one logical concern.

Unrelated work must never be committed together.

---

## Reviewability

Every commit should be small enough to review comfortably.

If reviewing a commit becomes difficult, the Work Unit is too large.

---

## Independence

A commit should remain understandable on its own.

A reviewer should not need future commits to understand its purpose.

---

# Commit Readiness

Before creating a commit, verify that:

- the assigned Work Unit is complete;
- the project builds (when applicable);
- no temporary files are included;
- unrelated modifications have been removed;
- documentation has been updated if required;
- the commit satisfies this standard.

Only then should the commit be created.

---

# Commit Message Format

IA Engineering adopts the Conventional Commits specification.

```
<type>(<scope>): <description>
```

Examples:

```
feat(auth): implement JWT authentication

fix(api): validate missing project identifier

docs(standards): add commit standard

refactor(database): simplify repository layer

test(auth): add login integration tests
```

---

# Approved Types

The following commit types are approved:

- feat
- fix
- docs
- refactor
- test
- perf
- build
- ci
- chore

Additional types may be introduced through future standards.

---

# Commit Scope

A single commit should contain only one of the following:

- one feature;
- one bug fix;
- one documentation update;
- one refactoring;
- one engineering improvement.

Mixing multiple engineering objectives is discouraged.

---

# Commit Frequency

Create a commit immediately after completing a Work Unit.

Avoid accumulating unrelated changes before committing.

Frequent, meaningful commits are preferred over large, infrequent commits.

---

# Forbidden Practices

Do not:

- create meaningless commit messages;
- commit unfinished unrelated work;
- mix features and refactoring;
- commit debugging artifacts;
- create "WIP" commits on shared branches;
- use commits as temporary backups.

---

# Good Examples

```
feat(project): create project entity

fix(auth): validate expired JWT tokens

docs(readme): explain project installation

refactor(api): simplify dependency injection

test(project): add CRUD integration tests
```

---

# Bad Examples

```
update

fix

changes

misc

test

final

wip

new code
```

---

# Rationale

Following this standard provides:

- Better code reviews
- Clear engineering history
- Faster collaboration
- Easier debugging
- Smaller Pull Requests
- Better AI task decomposition

---

# References

- Git Standard
- Branch Standard
- Pull Request Standard
- Work Unit Specification _(future)_

---

# Metadata

Owner: IA Engineering

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
