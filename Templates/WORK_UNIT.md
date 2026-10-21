# Work Unit Template

---

# Usage

A Work Unit is the smallest independently deliverable engineering task.

One Work Unit → One Commit → One engineering objective.

Copy this template for every task before assigning it to an engineer. All fields are mandatory. A Work Unit with incomplete fields is not ready for assignment.

---

# Template

```markdown
## Work Unit — [WU-ID]

**Title:** [short, action-oriented title — e.g., "Add user authentication endpoint"]

---

### Objective

[One sentence: what must exist or work after this Work Unit is complete that does not exist or work today.]

---

### Context

[Why this Work Unit exists. Link to the feature, ADR, or business requirement it serves.
What the engineer needs to understand before starting — without reading the entire codebase.]

---

### Inputs

[What the engineer needs before starting:]
- [ ] [Input 1 — e.g., "API contract approved by Software Architect"]
- [ ] [Input 2 — e.g., "Database schema migration WU-XX is merged"]
- [ ] [Standard — e.g., "OWASP API Security Top 10"]

---

### Outputs

[What the engineer must deliver:]
- [ ] [Output 1 — e.g., "POST /auth/login endpoint implemented"]
- [ ] [Output 2 — e.g., "Unit and integration tests passing"]
- [ ] [Output 3 — e.g., "OpenAPI spec updated"]

---

### Definition of Done

The Work Unit is complete when ALL of the following are true:

- [ ] [Criterion 1 — measurable; fails if: ___ | not falsifiable: <reason> (`Standards/TESTING_STANDARD.md`, Falsifiability)]
- [ ] [Criterion 2 — fails if: ___ | not falsifiable: <reason>]
- [ ] [Criterion 3 — fails if: ___ | not falsifiable: <reason>]
- [ ] Tests are written and passing.
- [ ] Code has passed review by the Code Reviewer.
- [ ] The Work Unit Report is written (`Templates/WORK_UNIT_REPORT.md`), with the gate evidence pasted and any omission stated. A bare "Done" is a failed Work Unit.
- [ ] Pull Request is merged into `develop`.

---

### Standards

[List the specific standards that apply to this Work Unit:]
- [e.g., Code Quality Standard]
- [e.g., Testing Standard]
- [e.g., OWASP Top 10]
- [e.g., OpenAPI Specification]

---

### Expected Commit

```
[type](scope): [description]

[optional body]
```

Example: `feat(auth): add POST /auth/login endpoint with JWT response`

---

### Assigned To

**Employee:** [Employee name — e.g., Backend Engineer]
**Assigned by:** [Main Agent — or Engineering Manager, for multi-pole work]
**Assigned on:** [date]
**Due:** [date or sprint]

---

### Status

- [ ] Not started
- [ ] In progress
- [ ] In review
- [ ] Complete
```

---

# Field Reference

| Field | Purpose | Common mistakes |
|---|---|---|
| Objective | States the "what" — one sentence, measurable | Too vague ("improve auth"), too broad (multiple objectives) |
| Context | States the "why" — links to requirements | Missing links, assumes knowledge the engineer does not have |
| Inputs | Prerequisites — what must be true before starting | Listing tools instead of dependencies, incomplete checklist |
| Outputs | Deliverables — what the engineer must produce | Missing tests or documentation outputs |
| Definition of Done | Verifiable completion criteria | A criterion with no "fails if", or one that names the test instead of the system's behaviour (`Standards/TESTING_STANDARD.md`, Falsifiability); subjective criteria ("code is clean"), missing review step, missing the Work Unit Report — every item here becomes a row in that report, so an item nobody can verify produces a row nobody can fill |
| Standards | Applicable standards for this task | Empty or generic — list only the standards that actually apply |
| Expected Commit | The commit message format for this Work Unit | Missing scope, not following Conventional Commits format |

---

# Work Unit ID Convention

Format: `WU-[project]-[sequential number]`

Example: `WU-SHOP-042`

IDs are assigned by whoever decomposes the work — the Main Agent (`Core/ORCHESTRATION.md` Step 3), or the Engineering Manager for multi-pole work (`Core/AGENT_CHAINS.md`, Work Unit Decomposition) — and are unique per project. A project that imported the framework keeps its own registry and its own prefix: the `Work Unit Exists` check reads the project's `Registry/work-units.yml` and never the framework's. In this framework's own repository, the project prefix is `IAENG` (e.g., `WU-IAENG-042`); the next free number is the highest `id:` entry already present in `Registry/work-units.yml` plus one. Assigning an ID is not enough — the Work Unit must also be added to that file (id, employee, title, milestone, delivers) in the commit that performs the work, per `Workflows/FEATURE_DEVELOPMENT.md` Step 4, because the required `Work Unit Exists` CI check validates every commit's `Work Unit:` trailer against `Registry/work-units.yml` (see `Registry/README.md`).

The `milestone` field of a registry entry names the release or iteration the Work Unit belongs to. In a project that imported the framework it is **the project's own label**, not a framework version (a consuming project has no `VERSION.md`): the adoption Work Unit uses `Bootstrap`, and later ones use whatever the project calls its release or iteration, such as `v1.0` or `Sprint 3`. No required check reads it; only `Adapters/scripts/release.sh` does, and there it must equal a section name in the project's `CHANGELOG.md` (`Registry/README.md`, Work Unit `milestone` in a consuming project).

---

# Metadata

Owner: IA Engineering

Version: 0.0.8

Status: Draft

Category: Template — Engineering

Severity: Mandatory
