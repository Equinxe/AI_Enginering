# Test Plan Template

---

# Usage

A Test Plan defines what will be tested, how, by whom, and what constitutes a pass or fail for a feature or release.

Test Plans are created by the QA Engineer before testing begins — not after. Testing without a plan is manual exploration, not validation.

A Test Plan is required for:
- Every feature with a QA validation step in the Feature Development Workflow.
- Every release acceptance test in the Release Workflow.
- Every hotfix validation in the Hotfix Workflow.

---

# Template

```markdown
## Test Plan — [TP-ID]

**Feature / Release:** [name and version]
**Work Unit(s):** [WU-ID list]
**Author:** [QA Engineer]
**Date:** [YYYY-MM-DD]
**Status:** [Draft | Approved | In Progress | Complete]

---

### Scope

**In scope:**
- [What will be tested]

**Out of scope:**
- [What will NOT be tested and why]

---

### Test Environment

**Environment:** [staging / production / local]
**Branch / version:** [branch name or version tag]
**Dependencies:** [external services, databases, or configurations required]
**Test data:** [how test data will be set up and cleaned up]

---

### Acceptance Criteria Reference

[List the acceptance criteria from the Work Unit or feature specification that this test plan validates:]

- AC-001: [criterion]
- AC-002: [criterion]

---

### Test Cases

#### [TC-001] — [Test case title]

**Type:** [unit | integration | e2e | manual | regression | performance | security]
**Priority:** [critical | high | medium | low]
**Related AC:** [AC-ID]

**Preconditions:**
- [State that must be true before executing this test case]

**Steps:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected result:**
[What should happen — specific and verifiable]

**Actual result:**
[Filled in during test execution]

**Status:** [Pass | Fail | Blocked | Not run]

---

#### [TC-002] — [Test case title]

[...]

---

### Regression Tests

[List existing test cases from previous releases that must pass to confirm no regression:]

| Test case | Area | Status |
|---|---|---|
| [TC-ID or description] | [area] | [Pass | Fail | Not run] |

---

### Test Execution Summary

[Filled in after testing is complete.]

| Metric | Value |
|---|---|
| Total test cases | [count] |
| Passed | [count] |
| Failed | [count] |
| Blocked | [count] |
| Not run | [count] |

**Open defects:**
- [DEF-ID]: [description] — Severity: [critical | high | medium | low]

---

### Sign-off

**QA Engineer:** [name] — [date]
**Result:** [Pass — ready for release | Fail — blocked by [DEF-ID list]]
```

---

# Test Case ID Convention

Format: `TC-[project]-[sequential number]`

Example: `TC-SHOP-042`

---

# Defect ID Convention

Format: `DEF-[project]-[sequential number]`

Example: `DEF-SHOP-007`

Defects are tracked in the project issue tracker and referenced in the Test Plan.

---

# Test Types Reference

| Type | Purpose | When required |
|---|---|---|
| Unit | Validates isolated logic | All new business logic |
| Integration | Validates component interactions | API endpoints, service calls |
| End-to-end | Validates full user flows | Critical user journeys |
| Manual | Human verification of UX or complex flows | UI changes, edge cases not automatable |
| Regression | Confirms existing behavior is unbroken | Every PR, every release |
| Performance | Validates response time and load behavior | Performance-sensitive paths |
| Security | Validates against security requirements | Authentication, authorization, data handling |

---

# Metadata

Owner: IA Engineering

Version: 0.0.5

Status: Draft

Category: Template — Quality

Severity: Mandatory
