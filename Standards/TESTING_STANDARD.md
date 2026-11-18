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

1. **Every acceptance criterion states its failure condition**: "This fails if ___", naming an observable behaviour of the system under test (an output, an exit code, a refusal reason, a state), never the test itself. It makes explicit the criterion's pass/fail criteria (ISO/IEC/IEEE 29119-1) and the expected result of each test case that guards it (ISO/IEC/IEEE 29119-3). A criterion that cannot be written this way is declared as a gap in the Work Unit ("not falsifiable: <reason>"), never silently kept.
2. **Every new or changed test that guards a criterion or a fix is seen red once**, by one of, in order of preference: (a) running it against the pre-fix code (the base commit), for a defect fix; (b) a hand mutant, the smallest change to the code under test that realises the "fails if" condition; (c) the stack's mutation-testing tool. A test that stays green proves nothing: it is strengthened or removed.
3. **The red run is caused by the condition the test guards.** The failing assertion checks the behaviour the "fails if" names (the refusal reason, the message, the state), not only an outcome another cause would also produce, such as a non-zero exit code. A test that is already red against the base because another rule rejects its input is over-determined: it proves nothing about the change and does not satisfy item 2.
4. **Mutants live in a disposable copy** (a separate worktree or a temporary copy), never in the working tree and never via `git stash` (Git Standard). A mutant is never committed.
5. **Evidence is pasted**: the mutant (one line or a diff) or the base commit, the command, the failing line, then the green run on the real code. It goes in the Work Unit Report, under Gate Evidence.
6. **Runs are bounded.** A mutant run has a time limit. A run stopped by the limit is inconclusive, not red, unless the "fails if" names termination or time (a hang, a missed deadline); then it counts as red only if a rerun reproduces it. An equivalent mutant (no observable change) is declared and is not a red run: another mutant is written, or, when every mutant that realises the condition is equivalent, the criterion is declared "not falsifiable: <reason>" (item 1).
7. **Scope.** The rule applies to Work Units opened after WU-IAENG-354 is merged. Item 1 applies to every such Work Unit. Items 2 to 6 apply when its change alters executable behaviour, as `Workflows/FEATURE_DEVELOPMENT.md` Step 7 defines it. The rule is not retroactive on existing tests and sets no mutation-score threshold.

## Independent Oracle — The Expected Value Comes From Outside the Code

A test oracle is the source of a test's expected result (ISO/IEC/IEEE 29119-1; ISTQB Glossary). Falsifiability shows that a test can fail; this section ensures that a passing test passes against the right value. A test whose expected value was copied from the code's own output also fails on a mutant, so its red run proves nothing about correctness: it pins whatever the code did, defect included.

1. **The expected value comes from a source independent of the code under test**: the acceptance criterion or specification, a worked example computed by hand or by a reference implementation, a published standard, or vendor documentation. The test, or the Work Unit Report, names the source.
2. **The code under test is never its own oracle.** A value obtained by running it, or recomputed in the test by the same logic, is not an expected value until a person has checked it against the specification and named that check. A baseline recorded before the change shows only that behaviour did not change: it is an oracle for a change that must preserve behaviour, never for a fix or a new behaviour.
3. **A missing seam is a finding.** When the behaviour cannot be observed or controlled at the interface where it is specified (no injection point for a clock, a network call, or a file; no observable output), the Employee does not assert on whatever internal state is reachable instead. It files an Issue and declares "Falsifiability item 2 not met: no seam (#n)" under Deviations in the Work Unit Report, as `Templates/ROOT_CAUSE_ANALYSIS.md` does.
4. **Scope.** As Falsifiability item 7, for Work Units opened after the Work Unit that adds this section is merged, when the change alters executable behaviour. Not retroactive.

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
- merge a test that was never seen to fail, where Falsifiability requires it;
- take a test's expected value from the code under test, where Independent Oracle applies.

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

Version: 0.0.4

Status: Draft

Category: Engineering Standard

Severity: Mandatory
