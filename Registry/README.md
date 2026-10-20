# Registry

---

# Purpose

Every document in `Core/`, `Standards/`, `Employees/`, and `Workflows/` is written for a reader — a human or an AI that reads prose and decides how to behave. That is the framework's premise and it is not changing.

The Registry is the same information in a second form: **the subset of the framework that a program can read.** Employee names and tiers, chain sequences and their Director gates, workflow steps and their actors, Work Unit identifiers. Nothing here is new policy. Every field restates something a governed document already says, in a shape a git hook, a CI job, or an AI runtime can consume without parsing English.

Two things become possible once that shape exists:

1. **Drift becomes detectable.** `Adapters/scripts/validate-framework.sh` compares the Registry against the documents it derives from and fails the build when they disagree. The "we changed X and forgot Y that references it" bug — hit at least three times in this repository's own history (the ADR trigger cross-reference, the security-sensitive QA trigger, the roster counts in `VERSION.md` and `README.md`) — stops being something an audit finds afterward.
2. **Orchestration becomes checkable.** `Core/AGENT_CHAINS.md`'s six chains are ASCII diagrams: readable, but a runtime cannot verify that a chain's Employees exist, that its Director gates were reached, or that a workflow step was actually dispatched. `chains.yml` and `workflows.yml` express the same sequences as data, so those questions have mechanical answers.

---

# Authority — the Registry Never Wins

**The governed documents are authoritative. The Registry is derived.**

Where the Registry and a document disagree, the document is right and the Registry is stale — the validator reports it as a Registry defect, never as a reason to change the document. This ordering matters because it is the opposite of how a code-generation registry usually works, and getting it backwards would let a data file quietly redefine framework policy.

Concretely, per file:

| File | Derived from | The Registry adds |
|---|---|---|
| `employees.yml` | `Employees/*/*.md` (name, category, Default Complexity Tier) | A single parseable roster, replacing the same list duplicated in six places |
| `chains.yml` | `Core/AGENT_CHAINS.md` | Chain sequences and Director gates as ordered data |
| `workflows.yml` | `Workflows/*.md` | Step numbers, actors, and mandatory gates as ordered data |
| `work-units.yml` | The Work Units executed in the repository that holds it: this one for the framework's file; a consuming project keeps its OWN `Registry/work-units.yml` (the bootstrap writes an empty starter) and the check never reads the framework's on its behalf. The framework's file lists the Work Units executed in this repository **from WU-IAENG-137 onward** — earlier ones are deliberately absent and unrecoverable; see that file's header | Existence — so a commit's `Work Unit:` trailer can be checked against reality, not only against a regex |

---

# The Duplication This Replaces

`Adapters/README.md` has carried this entry under `Planned` since v0.0.9:

> A single shared Employee-roster source file that both `git-hooks/commit-msg` and the `Employee Trailer` job in `github-actions/pr-validation.yml` read, instead of the 42-name array being duplicated in both.

`employees.yml` is that file, and the scope turned out to be wider than two consumers. The roster was duplicated in **six** locations: the `commit-msg` hook, the PR-validation Adapter, this repository's own installed copy of that Adapter, `VERSION.md`'s count and named list, `Core/CAPABILITY_TIERS.md`'s tier-assignment table, and `Core/EMPLOYEE_SELECTION.md`'s per-Employee triggers. Any one of them drifting silently breaks commit validation or misroutes a dispatch.

They are not merged into one file — `VERSION.md` still lists the roster for a reader, `CAPABILITY_TIERS.md` still explains the tiers, `EMPLOYEE_SELECTION.md` still gives each dispatch trigger. What changes is that the validator now proves they agree.

---

# Parsing Contract

Git hooks run on developer machines with no guaranteed YAML parser, and `Adapters/git-hooks/commit-msg` must read the roster with nothing but `grep` and `sed`. Each file therefore commits to a stable line shape, documented in its own header comment and enforced by the validator.

For `employees.yml`:

```sh
grep -E '^  - name: ' Registry/employees.yml | sed 's/^  - name: //'
```

Reformatting a Registry file — re-indenting, quoting values, adding a trailing comment to a `name:` line — breaks that contract. The validator fails on shape violations for exactly this reason: so the break surfaces at commit time rather than as a hook that silently accepts every Employee name.

---

# Regenerating

`employees.yml` is mechanically derivable from the Employee definitions:

```bash
./Adapters/scripts/validate-framework.sh --regenerate-roster
```

`chains.yml`, `workflows.yml`, and `work-units.yml` are hand-maintained: chain sequences, gate placement, and Work Unit history are editorial content, not text extractable from a heading. When one of the documents they derive from changes, update the Registry file in the same Work Unit — the same rule `Governance/CONTRIBUTING.md` §3 already sets for cross-references, now with a validator behind it.

---

# Project Roster Extension

A project may define **Domain Employees** — roles whose expertise is the project's business domain rather than an engineering discipline (`Templates/DOMAIN_EMPLOYEE.md`). They are project artifacts: their definitions live in the project under `.ia-engineering/Employees/`, and they are registered in a **project roster** at `.ia-engineering/Registry/employees.yml`, which follows the parsing contract above exactly.

The `commit-msg` hook, the `Employee Trailer` CI job, and `generate-agents.sh` read the project roster **in addition to** `Registry/employees.yml`, so a Domain Employee's trailer validates and its runtime agent is generated without touching the framework. Each roster's `file:` paths are relative to **its own** root — the framework's to the framework, a project's to the project. Resolution is the same in both: `IAENG_PROJECT_ROSTER` if set — and a set value naming a missing file is refused, not skipped, because validating against the framework roster alone would silently refuse every Domain Employee — otherwise the default path, whose absence is the ordinary case and is stated in the rejection message.

The project roster never wins over the framework roster either: a project cannot redefine or remove a framework Employee by listing it. It can only add.

---

# Work Unit `milestone` in a Consuming Project

Each entry in `work-units.yml` carries `id`, `employee`, `title`, `milestone` and `delivers`. In this repository `milestone` is a framework milestone codename (`Precision`, `Automation`). A consuming project has no `VERSION.md` and no framework milestones, so the field means **the project's own release or iteration label**: free text, one line, chosen by the project.

- The adoption Work Unit (the commit that installs the framework and its tooling, `Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5) uses `milestone: Bootstrap`.
- Every later Work Unit uses the label of the release or iteration it ships in (`v1.0`, `Sprint 3`, `MVP`).

What the tooling requires of it, exactly:

- `Adapters/scripts/check-work-units.sh` (the required `Work Unit Exists` check) reads only the `  - id: ` lines. It does not read `milestone`, so any value, or a missing field, passes that check.
- `Adapters/scripts/validate-framework.sh` (the installed Framework Validation check) runs inside the imported framework directory and validates the framework's own registry, never the project's, so it does not read the project's `milestone` either.
- `Adapters/scripts/release.sh check` is the one consumer. It treats a milestone as released once `CHANGELOG.md` has a section naming it, and confirms every Work Unit registered against the milestone being released has landed. A project that uses it keeps `milestone` spelled exactly as its `CHANGELOG.md` section (or passes `--milestone <name>`); a mismatch fails with "no Work Units registered against milestone". `Bootstrap` never gets a CHANGELOG section of its own, so once another milestone is unreleased alongside it, `release.sh check` fails with "cannot determine which milestone is being released". Name it in the project's first CHANGELOG heading, for example `## [0.1.0] - Bootstrap & v1.0` (the " & " list form is supported), or pass `--milestone <name>` every time.

---

# Consumers

| Consumer | Reads | For |
|---|---|---|
| `Adapters/git-hooks/commit-msg` | `employees.yml`, project roster | Validating the `Employee:` trailer against the real roster, extended by the project's Domain Employees |
| `Adapters/github-actions/pr-validation.yml` | `employees.yml` (the framework's roster, by design), project roster, and `work-units.yml` — the PROJECT's own in a consuming project, never the framework's | Server-side trailer re-validation; Work Unit existence |
| `Adapters/scripts/validate-framework.sh` | all four | Drift detection across every derived location |
| `Adapters/ai-runtimes/generate-agents.sh` | `employees.yml`, project roster | Generating runtime agent definitions from Employee definitions, framework and Domain alike |
| `Adapters/scripts/release.sh` | `work-units.yml` | Listing the Work Units a release contains |

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Registry — Machine-Readable Framework

Severity: Mandatory

Depends On:

- `Employees/` (all 42 definitions)
- `Core/AGENT_CHAINS.md`
- `Core/CAPABILITY_TIERS.md`
- `Core/EMPLOYEE_SELECTION.md`
- `Workflows/` (all 10 workflows)

Referenced By:

- `Adapters/README.md`
- `Adapters/git-hooks/commit-msg`
- `Adapters/github-actions/pr-validation.yml`
- `Adapters/scripts/validate-framework.sh`
