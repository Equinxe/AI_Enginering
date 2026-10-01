# Code Quality Standard

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

## No Inline Suppression

A linter, a type checker, or a test runner that reports a problem is a control. The instruction that makes it stop reporting *this one line* — `# noqa`, `# type: ignore`, `// eslint-disable-next-line`, `@ts-ignore`, `@SuppressWarnings`, `#pragma warning disable`, `# pylint: disable` — is an escape hatch in the sense `Standards/GIT_STANDARD.md` defines: it makes the control stop applying with nothing recording why, and it scales. One suppression is a judgment; fifty are a linter that no longer runs.

The rule:

- **Suppression is configuration, not code.** A rule that is wrong for the project is disabled or tuned in the linter's configuration file, where the change is a reviewed diff with a commit message, and applies uniformly.
- **Inline suppression is never written to silence a true finding.** Not with a justification comment, not "temporarily". If a single site genuinely needs an exception, the site is restructured so the rule is satisfied, or the rule is reconsidered for the project in its configuration.
- **The one admissible inline case is a tool false positive that configuration cannot scope** — the tool misreads code that is correct, and disabling the rule project-wide would lose it everywhere else. The directive then names, on the preceding line, the interface or constraint that forces it, so a reviewer can check the claim rather than trust it.
- **The same holds for the other silent disables:** a bare `except:` / `catch (e) {}` that swallows a failure; `test.skip`, `.only`, `xit`, `@pytest.mark.skip` left in a commit; a coverage threshold lowered to make a build pass; a type widened to `any` / `Object` to satisfy a checker; a failing test deleted rather than fixed. Each converts a red signal into a green one without changing what the signal measured.
- **Generated code is the one exception**, and it is declared in `.gitattributes` as `linguist-generated`, so the exception is itself reviewable — never asserted inline.

A control that is in the way is escalated (`Standards/RISK_STANDARD.md`), with the linter's output quoted. The `Shellcheck Adapters` check on this framework's own scripts is held to exactly this rule, and the count has gone **down**, to zero. The last `# shellcheck disable` directive sat in `Adapters/git-hooks/pre-push`, where git's four-field hook interface forces an unused variable; WU-IAENG-315 read that field into `_`, which shellcheck does not report, and the directive became unnecessary.

The second one is worth recording because of how it went. `validate-framework.sh` suppressed SC2016 for a grep pattern whose backticks were deliberately unexpanded — a genuine false positive, correctly documented. But a suppression has to sit immediately before the command it covers, and inserting code above it silently detached it, so the finding returned. Holding the backtick in a variable let the pattern be double-quoted, and the directive became unnecessary. That is the order this section asks for: restructure so the rule is satisfied, and reach for a directive only when configuration genuinely cannot scope the exception.

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
- mix multiple coding styles within the same project;
- suppress a linter, type checker, or test inline — configure the rule for the project, or satisfy it;
- swallow a failure, skip or focus a test, lower a coverage threshold, or widen a type to make a check pass.

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

Version: 0.0.3

Status: Draft

Category: Engineering Standard

Severity: Mandatory
