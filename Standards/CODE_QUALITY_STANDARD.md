# Code Quality Standard

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory

---

# Purpose

This standard defines how code quality is managed within IA Engineering.

IA Engineering relies on official language standards, linters, formatters, static analysis tools, and industry best practices to ensure consistent, maintainable, and reliable software.

---

# Scope

This standard applies to:

- All Employees
- All Workflows
- All Projects using IA Engineering

---

# Official References

The following references are considered authoritative:

- Language Style Guides (PEP 8, Google Java Style Guide, etc.)
- Official Formatter Documentation
- Official Linter Documentation
- Official Static Analysis Tool Documentation

Projects should always follow the standards appropriate for the selected technology stack.

---

# Industry Best Practices

Projects should:

- produce readable code;
- keep functions and classes focused;
- avoid unnecessary complexity;
- eliminate dead code;
- use automated formatting;
- use static analysis tools whenever available.

---

# IA Engineering Additions

## Standards First

Employees must always apply the official coding standards of the language before considering project-specific conventions.

---

## Automated Quality

Whenever possible, code quality should be verified automatically through:

- formatters;
- linters;
- static analysis;
- CI pipelines.

---

## Readability

Code should prioritize readability over cleverness.

Future maintainers should understand the code without unnecessary effort.

---

## Consistency

A project should follow one consistent coding style.

Mixing multiple coding styles within the same project should be avoided.

---

# Responsibilities

Every Employee must:

- follow the official coding standards;
- use the project's formatting tools;
- resolve linter warnings when appropriate;
- maintain readable and maintainable code.

---

# Forbidden Practices

Do not:

- ignore formatter or linter output without justification;
- introduce unnecessary complexity;
- leave unused code;
- mix multiple coding styles within the same project.

---

# Rationale

Following this standard provides:

- improved maintainability;
- consistent codebases;
- easier code reviews;
- reduced technical debt;
- predictable AI-generated code.

---

# Related Standards

- Standards First
- Documentation Standard
- Testing Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.2

Status: Draft

Category: Engineering Standard

Severity: Mandatory
