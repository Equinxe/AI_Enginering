# Testing Standard

---

# Purpose

This standard defines how testing is approached within IA Engineering.

IA Engineering relies on official testing frameworks, language-specific best practices, and automated validation to ensure software reliability and maintainability.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Official References

The following references are considered authoritative:

- Official testing framework documentation
- Language-specific testing guidelines
- Testing Pyramid
- Test Automation best practices

Projects should always use the testing framework recommended by their technology stack whenever possible.

---

# Industry Best Practices

Projects should:

- automate tests whenever possible;
- execute tests before integration;
- maintain deterministic tests;
- isolate test cases;
- continuously improve test coverage.

---

# IA Engineering Additions

## Standards First

Employees must use the official testing framework of the selected technology whenever possible.

Examples include:

- Pytest
- JUnit
- PHPUnit
- Jest
- Vitest
- Go Testing

---

## Definition of Done

When applicable, a Work Unit is only considered complete when the required tests have been implemented and executed successfully.

---

## Automated Validation

Projects should execute automated tests through the Continuous Integration pipeline whenever available.

---

## Maintainable Tests

Tests are engineering assets.

They should be:

- readable;
- deterministic;
- maintainable;
- kept up to date with software changes.

---

# Responsibilities

Every Employee must:

- create tests appropriate for the implemented changes;
- maintain existing tests;
- investigate failing tests before merging;
- follow the project's testing strategy.

---

# Forbidden Practices

Do not:

- ignore failing tests;
- disable tests without justification;
- merge code that intentionally breaks existing tests;
- write flaky or non-deterministic tests.

---

# Rationale

Following this standard provides:

- improved software reliability;
- safer refactoring;
- earlier defect detection;
- higher confidence during releases;
- predictable AI-assisted development.

---

# Related Standards

- Standards First
- Code Quality Standard
- Pull Request Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
