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
- ISO/IEC/IEEE 29119-1:2022, Software testing — General concepts (test oracle, pass/fail criteria)
- ISO/IEC/IEEE 29119-3:2021, Software testing — Test documentation (the expected result of each test case)
- ISTQB Glossary (mutation testing, test oracle, regression testing)
- DeMillo, Lipton and Sayward, "Hints on Test Data Selection: Help for the Practicing Programmer", IEEE Computer, 1978; Jia and Harman, "An Analysis and Survey of the Development of Mutation Testing", IEEE Transactions on Software Engineering 37(5), 2011

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

## Falsifiability — Every Test Is Seen to Fail

A test is trusted only once it has been seen to fail when the behaviour it guards is wrong. The terms below are used as the references above define them; this section adds when the evidence is required and what it must show, not new definitions.

1. **Every acceptance criterion states its failure condition**: "This fails if ___", naming an observable behaviour of the system under test (an output, an exit code, a refusal reason, a state), never the test itself. It is the criterion's pass/fail criterion made explicit (ISO/IEC/IEEE 29119-1). A criterion that cannot be written this way is declared as a gap in the Work Unit ("not falsifiable: <reason>"), never silently kept.
2. **Every new or changed test that guards a criterion or a fix is seen red once**, by one of, in order of preference: (a) running it against the pre-fix code (the base commit), for a defect fix; (b) a hand mutant, the smallest change to the code under test that realises the "fails if" condition; (c) the stack's mutation-testing tool. A test that stays green is a fixture: it is strengthened or removed.
3. **The red run is caused by the condition the test guards.** The failing assertion checks the behaviour the "fails if" names (the refusal reason, the message, the state), not only an outcome another cause would also produce, such as a non-zero exit code. A test that is already red against the base because another rule rejects its input is over-determined: it proves nothing about the change and does not satisfy item 2.
4. **Mutants live in a disposable copy** (a separate worktree or a temporary copy), never in the working tree and never via `git stash` (Git Standard). A mutant is never committed.
5. **Evidence is pasted**: the mutant (one line or a diff) or the base commit, the command, the failing line, then the green run on the real code. It goes in the Work Unit Report, under Gate Evidence.
6. **Runs are bounded.** A mutant run has a time limit. A run stopped by the limit counts as red only if a rerun reproduces it. An equivalent mutant (no observable change) is declared, not counted.
7. **Scope.** Item 1 applies to every Work Unit. Items 2 to 6 apply when the change alters executable behaviour, as `Workflows/FEATURE_DEVELOPMENT.md` Step 7 defines it. The rule applies to tests added or changed from v0.0.15 on, is not retroactive on existing tests, and sets no mutation-score threshold.

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
- write flaky or non-deterministic tests;
- merge a test that was never seen to fail, where Falsifiability requires it.

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
- Git Standard

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Engineering Standard

Severity: Mandatory
