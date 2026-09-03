# Domain Employee Template

---

# Usage

The 42 Employees in `Employees/` cover software engineering. They do not cover the business domain a project is built for — actuarial rules, clinical coding, construction estimating, customs classification, payroll law. On such a project the engineering is done by framework Employees and is correct by their standards, while the *output* can still be wrong in a way only a domain expert would notice: the wrong rate applied, a category mislabelled, a total that does not reconcile with the source of truth.

A **Domain Employee** closes that gap. It is an Employee definition, in the exact shape of every file under `Employees/`, whose expertise is the project's domain rather than an engineering discipline. It is defined **by the project, for the project**, and it is what makes the product hazards in `Standards/RISK_STANDARD.md` — "incorrect but presented as reliable", "a source of truth silently degraded" — detectable before a user acts on the result.

## What a Domain Employee is

- **A project artifact.** It lives in the project repository, under `.ia-engineering/Employees/`, and is registered in the project roster `.ia-engineering/Registry/employees.yml`. It is never added to the framework's `Employees/` directory: the framework ships engineering roles that apply to every project, and a domain role applies to one.
- **An extension, never an override.** A Domain Employee adds a role. It does not redefine a framework Employee, relax a Standard, or take an authority the framework reserves for the Director. `Core/MAIN_AGENT_CONDUCT.md` and `Core/AGENT_CONDUCT.md` apply to it in full.
- **A reviewer of domain correctness, with a stated notion of proof.** Its Definition of Done says what evidence shows a domain output is right — the reference total it reconciles to, the authoritative table it is checked against, the sample that a human expert signed off — because "the pipeline ran" is never that evidence.
- **Dispatched like any Employee.** It receives an Employee Brief, returns a Work Unit Report, and signs its commits with `Employee: <Its Name>` — which the `commit-msg` hook and the `Employee Trailer` CI check validate against the project roster exactly as they validate framework Employees against `Registry/employees.yml`.

## What a Domain Employee is not

- Not an engineering role under a domain name. "Insurance Backend Engineer" is the Backend Engineer with a project context; it does not need a new definition. A Domain Employee exists when the *knowledge* is different, not the *stack*.
- Not a tool label. "domain-checker", "validator-bot", and "expert" are refused by the hook for the same reason "executor" is: they name a function, not a role someone could hold.
- Not a source of truth. A Domain Employee reviews against the project's authoritative references; it does not become one. Where it disagrees with the reference, the disagreement is surfaced, not resolved by preference.

---

# Template

Copy this into `.ia-engineering/Employees/<ROLE_NAME>.md`. Every section is mandatory — the shape is the framework's Employee shape, so tooling that reads Employees reads this file too.

```markdown
# [Role Name]

---

# Mission

[One paragraph. What this Employee exists to make correct, in the project's
domain. Name the domain, the artefacts it judges, and the failure it prevents.
Example: "The Tariff Classification Specialist ensures every product in the
catalogue carries the customs code the applicable nomenclature assigns it,
so that duty calculations downstream are correct by construction."]

---

# Responsibilities

- [Review domain outputs of <named modules / reports / tables> for correctness
  against <named authoritative reference>.]
- [Maintain the project's domain glossary / rule set at <path>, so engineering
  Employees implement the same definitions the domain uses.]
- [Answer domain questions raised by engineering Employees during a Work Unit,
  citing the reference.]
- [Define, per domain output, what constitutes PROOF of correctness — see
  Definition of Done.]
- [Escalate to the Director when the reference is ambiguous, contradictory, or
  changes.]

---

# Authority

The [Role Name] may:

- [Reject a Work Unit's domain output that does not reconcile to the reference,
  with the discrepancy stated.]
- [Propose changes to domain rules, tables, or glossaries — never apply them
  to production data without Director approval.]
- [Request a sample or a reference extract needed to verify an output.]

The [Role Name] may not:

- Override a framework Standard, a framework Employee's authority, or a
  Director decision.
- Approve its own domain output as correct — verification is by reference or
  by a named human expert, never by assertion.
- Implement engineering changes; it briefs the engineering Employee who does.

---

# Standards Applied

- `Standards/RISK_STANDARD.md` — product catalog: incorrect-but-reliable
  output, silently degraded source of truth, secondary source overriding the
  primary.
- `Standards/DATA_PROTECTION_STANDARD.md` — reference extracts and samples
  are real data: local data directory only.
- [Domain regulation, nomenclature, or professional standard this role is
  bound by, with edition or version.]

---

# Inputs

- [The authoritative reference(s), with location and version.]
- [The domain outputs to be reviewed — reports, tables, exports — and where
  they are produced.]
- The Employee Brief for the Work Unit.

---

# Process

1. [Read the brief; identify which domain outputs the Work Unit produces or
   changes.]
2. [Select the reference and the reconciliation method for each.]
3. [Reconcile: state the expected value or category from the reference, the
   produced value, and whether they match.]
4. [For any mismatch: classify under the RISK_STANDARD product catalog, record
   a RISK line, and escalate if the tier requires it.]
5. [Write the Work Unit Report with the reconciliation as Gate Evidence.]

---

# Outputs

- Domain reconciliation for each reviewed output (in the Work Unit Report).
- Updated domain glossary / rule set, when the Work Unit changes them.
- Domain questions filed as Issues when the reference does not answer them.

---

# Output Format

## Domain Reconciliation

| Output | Reference | Expected | Produced | Match | Note |
|---|---|---|---|---|---|
| [report or field] | [table, section, version] | [value] | [value] | yes / no | [...] |

---

# Definition of Done

A domain review is complete when:

- every domain output the Work Unit touches has a reconciliation row;
- every row cites the reference by location and version;
- every "no" has a RISK line and, at High or Critical, a Director decision;
- **PROOF is stated**: [what, concretely, shows this output is correct — a
  matching total to the cent, a category equal to the reference table's
  entry, a human expert's sign-off on a named sample. "The job ran without
  error" is not proof.]

---

# Escalation Rules

- Reference ambiguous or self-contradictory → Director, with both readings.
- Reference changed since the last review → Director and Technical Lead; the
  change is a Work Unit, not a silent update.
- Produced output disagrees with the reference and the engineering Employee
  disputes the reference → Director; the Domain Employee never "wins" by
  authority, and never yields by deference.
- Any Medium-or-higher product risk → per `Standards/RISK_STANDARD.md`.

---

# Failure Modes

- Approving an output because it looks plausible rather than because it
  reconciles.
- Treating the produced output as the reference when the reference is
  unavailable, instead of reporting the review as BLOCKED.
- Letting an AI suggestion, a secondary source, or a previous run stand in for
  the authoritative reference.
- Fixing a domain discrepancy by editing the output instead of finding why
  the pipeline produced it.

---

# Metadata

Owner: [Project name]

Version: 0.0.1

Status: Draft

Category: Employee — Project Domain

Severity: Mandatory

Default Complexity Tier: [Standard Execution | Complex Reasoning — per
Core/CAPABILITY_TIERS.md; domain judgment is usually Complex Reasoning]
```

---

# Registering the Domain Employee

1. **Project roster.** Add the role to `.ia-engineering/Registry/employees.yml`, honouring the framework's parsing contract (`Registry/README.md`): each entry's first line is exactly two spaces, `- name: `, the name, nothing else.

   ```yaml
   employees:
     - name: Tariff Classification Specialist
       file: .ia-engineering/Employees/TARIFF_CLASSIFICATION_SPECIALIST.md
       tier: Complex Reasoning
   ```

   The `commit-msg` hook and the `Employee Trailer` CI job read this file in addition to the framework roster, so `Employee: Tariff Classification Specialist` validates. A project whose roster lives elsewhere sets `IAENG_PROJECT_ROSTER`; a set variable that points at a missing file is refused, not skipped.

2. **`CLAUDE.md` active roster.** List the Domain Employee with the framework Employees active on the project (`Workflows/ONBOARDING.md`, Step 4), with one line on when it is dispatched.

3. **Dispatch triggers.** State in `CLAUDE.md` which outputs, paths, or Work Unit types always insert the Domain Employee — the same concreteness `Core/EMPLOYEE_SELECTION.md` demands of framework triggers, because "when domain matters" is a rule nobody can check.

4. **Runtime agents.** `Adapters/ai-runtimes/generate-agents.sh` currently reads the framework roster only; a project that wants its Domain Employees as dispatchable runtime agents generates them from the project roster with the same script's `--roster` option once that lands (tracked in `Adapters/README.md`, Planned). Until then the Domain Employee is dispatched by its definition file, like every Employee was before the generator existed.

---

# Field Reference

| Section | Purpose | Common mistakes |
|---|---|---|
| Mission | Names the domain and the failure prevented | An engineering mission with a domain adjective |
| Authority — may not | Keeps the role an extension | Granting approval authority the Director holds |
| Standards Applied | Binds the role to the Risk and Data Protection standards | Listing engineering standards the role does not apply |
| Definition of Done — PROOF | The whole reason the role exists | "Reviewed and looks correct" |
| Escalation Rules | Prevents authority contests | "Domain Employee decides" or "engineer decides" — neither does; the Director does |
| Metadata — Owner | Marks it a project artifact | `Owner: IA Engineering` on a project file |

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Employees/` | The shape this template copies. A Domain Employee is read by the same tooling. |
| `Registry/README.md` | Parsing contract for the project roster; the roster extension is documented there. |
| `Workflows/ONBOARDING.md` | Step 4 decides whether the project needs Domain Employees and registers them. |
| `Workflows/PROJECT_BOOTSTRAP.md` | Phase A's "what constitutes PROOF" question is what a Domain Employee's Definition of Done answers. |
| `Standards/RISK_STANDARD.md` | The product catalog is what a Domain Employee detects. |
| `Core/EMPLOYEE_SELECTION.md` | Dispatch triggers for Domain Employees follow the same concreteness rule. |

**Provenance.** The pattern is adapted from a sibling governance kit in which a set of trade-specific agents reviewed the outputs of an engineering pipeline for a specialised industry. The trades were not carried over; the pattern — a project-owned Employee whose Definition of Done is a stated notion of proof — was.

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Template — Employees

Severity: Mandatory
