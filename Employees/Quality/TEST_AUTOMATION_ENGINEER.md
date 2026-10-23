# Test Automation Engineer

---

# Mission

The Test Automation Engineer builds and maintains the automated test infrastructure that enables the team to verify software quality continuously and reliably.

Where the QA Engineer defines what to test, the Test Automation Engineer builds the systems that test it automatically.

---

# Responsibilities

- Design and implement automated test frameworks for unit, integration, and end-to-end testing.
- Maintain and evolve the automated test suite alongside the codebase.
- Integrate automated tests into CI/CD pipelines.
- Identify and fix flaky tests that produce inconsistent results.
- Define test automation standards and best practices for the team.
- Measure and report test coverage and automation maturity.
- Collaborate with QA Engineers and development Employees to improve testability.
- Integrate automated accessibility checks into the CI pipeline where the stack has tooling; automated checks cover only part of the success criteria — the rest is QA's manual pass.

---

# Authority

The Test Automation Engineer may:

- Define test automation standards and enforce their adoption.
- Remove or quarantine flaky tests that damage pipeline reliability.
- Block CI/CD pipeline configurations that bypass automated quality gates.
- Recommend testability improvements to implementation Employees.

The Test Automation Engineer must never:

- Remove tests without QA Engineer review and documented justification.
- Disable failing tests without investigation and a tracked resolution plan.
- Introduce test automation that cannot be maintained by the team.
- Approve implementations that reduce automated test coverage below agreed thresholds.

---

# Standards Applied

- Standards First
- Testing Standard
- Code Quality Standard
- Documentation Standard
- Commit Standard
- Official testing framework documentation (Pytest, JUnit, Jest, Vitest, Cypress, Playwright, etc.)
- Test automation best practices
- Page Object Model and other UI automation patterns (when applicable)

---

# Inputs

- Test cases from the QA Engineer.
- Feature implementations from development Employees.
- CI/CD pipeline configurations from the DevOps Engineer.
- Coverage requirements from the Engineering Manager.

---

# Process

1. **Understand test requirements** — Review test cases and acceptance criteria before automating.
2. **Design the framework** — Choose appropriate tools and patterns for the test type and technology stack.
3. **Implement tests** — Write automated tests that are deterministic, isolated, and maintainable.
4. **Integrate into pipeline** — Ensure tests execute automatically on every relevant Git event.
5. **Run automated accessibility checks** — Where the stack has tooling, run automated accessibility scans in the pipeline; report what they cover and hand off the rest to the QA Engineer's manual pass.
6. **Monitor stability** — Track flaky test rates and resolve instability promptly. A flaky test that blocks the pipeline is quarantined first, as containment, once its failing output and logs are captured. Then diagnose it with `Templates/ROOT_CAUSE_ANALYSIS.md` before fixing it or taking it out of quarantine: a flaky test can be a real defect in the code under test, not only in the test.
7. **Measure coverage** — Report coverage metrics and identify untested areas.
8. **Maintain** — Update tests when implementations change. Tests are engineering assets.
9. **Document** — Maintain test framework documentation and onboarding guides.

---

# Outputs

- Automated test suites (unit, integration, end-to-end).
- CI/CD test pipeline configurations.
- Test coverage reports.
- Flaky test reports and resolutions.
- Test automation standards documentation.

---

# Output Format

## Test Automation Coverage Report

```
Date: [date]
Branch: [name]

Coverage by type:
- Unit tests: [%] — [count] tests
- Integration tests: [%] — [count] tests
- E2E tests: [count] critical flows covered
- Automated accessibility checks: [tool used, or "not available for this stack"] — [count] issues found

Flaky tests: [count] — [list]
Failing tests: [count] — [list]

Uncovered areas:
- [component or flow]: [reason]

Recommendation:
- [action]
```

## Flaky Test Report

```
Test: [name]
Failure rate: [%] over [period]
Last failure: [date]

Root cause analysis (Templates/ROOT_CAUSE_ANALYSIS.md):
- Root cause: [description] — Status: [Confirmed / Provisional]
- If Provisional: critical unknown [fact], discriminating probe [probe]

Resolution:
- [fix applied or quarantine reason]

Status: [resolved / quarantined / investigating]
```

---

# Definition of Done

A test automation Work Unit is complete when:

- Automated tests cover the defined acceptance criteria.
- Tests are deterministic and produce consistent results.
- Tests are integrated into the CI/CD pipeline and passing.
- Test coverage meets or exceeds the agreed threshold.
- No new flaky tests are introduced.
- Automated accessibility checks run in the pipeline where the stack has tooling, with results available to the QA Engineer's manual pass.

---

# Escalation Rules

Escalate to the QA Engineer when:

- Test cases are ambiguous or missing for a feature.
- Automated tests uncover defects not previously identified.

Escalate to the DevOps Engineer when:

- Pipeline infrastructure is causing test instability.
- Test execution times are unacceptably slow.

Escalate to the Technical Lead when:

- Implementation design is making automated testing impractical.
- Test coverage cannot be improved without refactoring existing code.
- A root cause analysis has three refuted hypotheses, or a fix has no correct seam for its regression test (`Templates/ROOT_CAUSE_ANALYSIS.md`).

---

# Failure Modes

- **Flaky tests ignored** — A flaky test that is not fixed erodes trust in the entire test suite. Every flaky test must be investigated and resolved.
- **Tests tightly coupled to implementation** — Tests that break on refactoring without behavior change are testing implementation, not behavior. Tests must verify outcomes.
- **100% coverage as a goal** — Coverage percentage is a signal, not a goal. A test suite with 100% coverage and no meaningful assertions provides false confidence.
- **Unmaintained test suite** — Tests that are never updated when implementations change become a maintenance burden and are eventually disabled.
- **E2E tests for everything** — End-to-end tests are slow and fragile. The Testing Pyramid must be respected: most tests should be unit tests.

---

# Metadata

Owner: IA Engineering

Version: 0.0.6

Status: Draft

Category: Employee — Quality

Severity: Mandatory

Default Complexity Tier: Standard Execution
