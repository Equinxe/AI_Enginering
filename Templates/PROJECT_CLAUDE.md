# Project CLAUDE.md Template

---

# Usage

`CLAUDE.md` at a project's root is the **stable contract** between the project and every AI session that works on it. It is the first thing read on every resume (`Core/AGENT_CONDUCT.md`, Read First) and the one file that tells a session what this project is, who works on it, and which rules are in force.

`Workflows/ONBOARDING.md` Step 1 creates it; Step 4 fills in the roster; Step 7 confirms it. Until this template existed, that instruction said "adapted from the IA Engineering `CLAUDE.md`" and every adopter improvised the single most important file in the project.

## What belongs in it — and what does not

| Content | Where |
|---|---|
| Objective, users, stack, architecture, active roster, dispatch triggers, standards in force, git workflow, Director — things that change when the **contract** changes | **`CLAUDE.md`** — committed |
| Where things stand today, next step, what is blocked, deviations in force, the journal — things that change every session | `.ia-engineering/SESSION_STATE.md` — **never committed** (`Templates/SESSION_STATE.md`) |
| What the project's domain terms mean, as settled | `.ia-engineering/DOMAIN_GLOSSARY.md` — committed, created when the first domain term is settled (`Templates/PROJECT_GLOSSARY.md`) |
| The operator's cross-project preferences and method lessons | The AI runtime's own memory — not repository content |

A fact lives in exactly one of them. Progress never goes in `CLAUDE.md`; a copy of the contract never goes in the runtime's memory.

## How to fill it in

Answer from the Project Charter (`Templates/PROJECT_CHARTER.md`, produced by `Workflows/PROJECT_BOOTSTRAP.md` Phase A) and the Stack Decision ADR (Phase B). Every bracketed field is either filled or deleted — a template placeholder left in a committed contract is the same defect as an unfilled Pull Request description, and it is the first thing a reader stops trusting.

Keep it short. This file is read in full at the start of every session; a contract nobody finishes reading is a contract nobody follows. If a section needs more than a screen, it belongs in a document this file links to.

---

# Template

```markdown
# [Project Name]

> [One sentence: what this project is for, in the Director's words.]

---

# Project

[Two or three sentences. The problem it solves, who acts on its output, and
what "working" means. From the Project Charter, not re-invented here.]

**Profile:** [A — web application | B — integration with a heavy external
system | C — library or CLI] (`Workflows/PROJECT_BOOTSTRAP.md`, Phase B)

**Status:** [prototype | product | long-lived system]

---

# Framework

This project is governed by IA Engineering, imported at `ia-engineering/`.

Every decision follows the hierarchy in that framework's `CLAUDE.md`:
Manifest → Standards → Employees → Workflows → Project Context →
Implementation. Lower levels extend upper levels and never contradict them.
Where this file and a framework document disagree, the framework wins — except
where this file is **stricter**, which is always allowed.

Read on every session, in this order:

1. This file — the contract.
2. `.ia-engineering/SESSION_STATE.md` — where things actually stand.
3. The Employee Brief for the Work Unit, and the Standards it names.

---

# Main Agent

The Main Agent follows `ia-engineering/Core/MAIN_AGENT_CONDUCT.md`.

Every Work Unit is delegated to the named Employee in `.claude/agents/` and is
never implemented inline. An `Employee:` trailer names the Employee that
actually did the work, never the Main Agent's own.

Present the plan to the Director and wait for approval before executing,
whatever the runtime's effort or orchestration mode (Claude Code's `ultracode`
dynamic workflows included).

---

# What Constitutes PROOF

[For each output someone will act on, what concretely shows it is CORRECT.
This is Phase A question 12, and it is the question that keeps an
engineering-correct pipeline from shipping a wrong answer. "The job ran
without error" is never the answer.]

| Output | Reference of truth | What proves it correct |
|---|---|---|
| [report / total / classification] | [named source, with version] | [reconciles to X to the cent / equals the reference table entry / signed off by a named expert on a named sample] |

---

# Technology

- **Language / runtime:** [...]
- **Framework:** [...]
- **Data store:** [...] — decided in ADR-[NNN]
- **API style:** [...]
- **Hosting:** [...]
- **CI:** [...]
- **Secrets:** [where they live; never in the repository]

Architecture decisions are recorded as ADRs in [`docs/adr/`]. A decision that
meets a trigger in `Workflows/ARCHITECTURE_DECISION.md` is not made inline.

---

# Active Employees

Framework Employees active on this project:

- [Employee Name] — [when it is dispatched, concretely]
- [Employee Name] — [...]

Domain Employees, defined by this project (`Templates/DOMAIN_EMPLOYEE.md`),
registered in `.ia-engineering/Registry/employees.yml`:

- [Domain Employee Name] — dispatched for [which outputs, paths, or Work Unit
  types — concretely, in the shape `Core/EMPLOYEE_SELECTION.md` uses. "When
  domain matters" is not a trigger anyone can check.]

Employees NOT active here, and why: [e.g. no mobile work, so no iOS Engineer
or Android Engineer.]

---

# Standards in Force

The framework's Standards apply in full. In addition, this project:

- [project-specific rule, and the reason for it]
- [...]

Nothing here relaxes a framework Standard. A relaxation is a **deviation**: it
is recorded in `.ia-engineering/SESSION_STATE.md` with its restoration
condition, not normalised here.

**Data:** real data lives only in `[local_test_data/]`, gitignored from the
first commit; fixtures are synthetic and carry the `SYNTHETIC_` prefix
(`Standards/DATA_PROTECTION_STANDARD.md`).

---

# Working Method

Every task is a Work Unit. One Work Unit → one commit → one engineering
objective, with `Work Unit:` and `Employee:` trailers
(`Standards/COMMIT_STANDARD.md`).

Every Work Unit ends with a Work Unit Report
(`Templates/WORK_UNIT_REPORT.md`). A bare "Done" is a failed Work Unit.

Git workflow: feature → `develop` → `release/*` → `main`. Release branches are
never deleted. Protected branches are reached only through a reviewed Pull
Request.

Enforcement installed here: [git hooks via `core.hooksPath`; the CI checks
listed in `Adapters/scripts/setup-branch-protection.sh`; the runtime hooks in
`Adapters/ai-runtimes/<runtime>/`]. In every fresh clone, fetch the framework
first (`git submodule update --init`, or clone with `--recurse-submodules`),
since `install.sh` lives in the submodule, then re-run
`./ia-engineering/Adapters/scripts/install.sh` from the main checkout. A git
worktree, such as an Employee's, needs neither: its hooks are the main
checkout's.

---

# Director

[Name or role.] The Director makes all final decisions.

Present plans before executing. Escalate architectural, business, and product
decisions. Never tag, release, merge to `main`, or take another irreversible
action without Director approval. Merging an approved Pull Request into
`develop` is delegable (`Workflows/FEATURE_DEVELOPMENT.md` Step 8). High and
Critical risks stop and wait for a confirmation that names the action
(`Standards/RISK_STANDARD.md`).

---

# Domain Glossary

Domain terms mean what `.ia-engineering/DOMAIN_GLOSSARY.md` says they mean
(`ia-engineering/Templates/PROJECT_GLOSSARY.md`). Use a term in that meaning
and cite its entry where the meaning matters. The file is created when the
first domain term is settled; until then, a domain word whose meaning matters
is an Open Question below. A domain word with no entry is a question, never a
guess.

---

# Open Questions

[Decisions of substance that are not settled. Ask again; do not assume a
direction. Move an answered one into the body of this file and delete it here.]

---

# Repository

```
[top-level layout, one line each — what a newcomer needs to find their way]
```
```

---

# Field Reference

| Section | Purpose | Common mistakes |
|---|---|---|
| Project / Profile | Orients a session in one screen | Marketing copy; a re-derived objective that drifts from the Charter |
| What Constitutes PROOF | The difference between "it ran" and "it is right" | Left empty because it is hard — that is the sign it is needed |
| Active Employees | Dispatch without deliberation | A roster with no triggers; listing all 42 |
| Standards in Force | Additions, never subtractions | A relaxation recorded here as if it were policy |
| Main Agent | Dispatch and plan-first rule, loaded every session | Restating `Core/MAIN_AGENT_CONDUCT.md` instead of pointing to it |
| Director | Names who decides | "The team" |
| Domain Glossary | Points to where domain words are defined | Definitions written into this file instead; a glossary created empty |
| Open Questions | Prevents invented answers | Questions that were answered and never removed |

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Workflows/ONBOARDING.md` | Step 1 creates this file from this template; Step 4 fills the roster; Step 7 confirms it |
| `Workflows/PROJECT_BOOTSTRAP.md` | Phase A and B produce the answers; question 12 is the PROOF section |
| `Templates/PROJECT_CHARTER.md` | The durable record of Phase A — this file is its operational summary, not a second copy |
| `Templates/SESSION_STATE.md` | The other half of the memory split: dated state, never committed |
| `Templates/DOMAIN_EMPLOYEE.md` | The Domain Employees this file lists and gives triggers for |
| `Templates/PROJECT_GLOSSARY.md` | The project domain glossary this file points to |
| `Core/AGENT_CONDUCT.md` | Read First — this file is the first document read |

---

# Metadata

Owner: IA Engineering

Version: 0.0.14

Status: Draft

Category: Template — Onboarding

Severity: Mandatory
