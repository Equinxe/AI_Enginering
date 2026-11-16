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

## A project that already has a `CLAUDE.md`

An existing project that uses Claude Code usually has a `CLAUDE.md` already, holding its build and test commands and its own conventions. Do not replace that file with the template, and do not paste the template under it. Merge the two into one contract, in the order below.

**Who does it, and when.** The Main Agent dispatches the DevOps Engineer, through an Employee Brief (`Templates/EMPLOYEE_BRIEF.md`), to carry out steps 1 to 6 and make the commit. The Main Agent relays the Director's step 3 decisions. It never writes the file or signs the commit itself (`Core/MAIN_AGENT_CONDUCT.md`, Dispatch Discipline). Run the procedure after the adoption commit, and before any other commit. The adoption commit then holds none of the merge, and `HEAD` still holds the project's original instruction files, which step 5 compares against.

1. **Keep one contract file, at the project root.** Claude Code reads project instructions from `CLAUDE.md` or `.claude/CLAUDE.md` ([memory documentation](https://code.claude.com/docs/en/memory)). The framework's session-start hook checks only the root `CLAUDE.md`.
   - If the project's file is `.claude/CLAUDE.md`, move it with `git mv .claude/CLAUDE.md CLAUDE.md`.
   - If the project has both files, merge `.claude/CLAUDE.md` into `CLAUDE.md` as well, then remove it with `git rm .claude/CLAUDE.md`.

   Both commands stage the change at once, which is why the procedure runs after the adoption commit. In the text that came from `.claude/CLAUDE.md`, rewrite every relative `@` import so that it resolves from the root. The memory documentation says "Relative paths resolve relative to the file containing the import, not the working directory." So `@build.md` becomes `@.claude/build.md`, and `@../docs/build.md` becomes `@docs/build.md`. An absolute path or a `~/` path stays as it is. Leave `CLAUDE.local.md` alone: it is personal and never committed.
2. **Build the merged file from the template's block** (its contents only, Template below), and move the project's content into it:
   - Content that answers a template section goes in that section and replaces its placeholder. The project's overview goes under `# Project`, its stack under `# Technology`, its top-level layout (one line per entry) under `# Repository`, and its own extra rules under `# Standards in Force`.
   - Content no template section covers keeps its headings, at their own level and in their own order, word for word. Place it as one block right after the `# Technology` section, with a `---` line before and after it, as between the template's sections. This covers build, test, lint and run commands, local setup, and a guide to the modules: a module guide keeps its own heading here, and `# Repository` takes only the top-level layout. Copy every command exactly: a session runs it as written. Keep each `@path` import line, rewritten as step 1 says if it came from `.claude/CLAUDE.md`.
3. **Settle every contradiction with the Director.** When two instructions contradict each other, Claude may follow either one (memory documentation, above), so no contradiction may stay. Look for at least these project lines:
   - committing or pushing to `main` directly;
   - a branch model without `develop`;
   - a commit format without the `Work Unit:` and `Employee:` trailers;
   - implementing a task inline instead of delegating it, or starting work without a plan;
   - skipping a hook, a test or a review.

   Settle any other line that contradicts a framework rule the same way. Read the `CLAUDE.md` files in subdirectories, the files under `.claude/rules/` and every imported file too, because they reach the same session. Leave out the files inside `ia-engineering/`. They are the framework's own: `# Framework` in the block points to them, and the project never edits its pinned submodule.

   Present every contradiction to the Director, through the Main Agent, with the three outcomes below. Change none of those lines until the Director has chosen:
   - **The project's rule is stricter** than the framework's: it stays, under `# Standards in Force`.
   - **The framework's rule applies**: delete the project's line from the file that holds it.
   - **The project keeps a looser rule for now**: that is a deviation. Delete the line from the file that holds it. Record the deviation, with the condition that ends it, in this Work Unit's Work Unit Report (`Templates/WORK_UNIT_REPORT.md`), and file it as an Issue. `.ia-engineering/SESSION_STATE.md` is created only after this commit. When the Main Agent creates it, it copies each deviation into the file's Governance Deviations in Force section (`# Standards in Force` in the block below; `Workflows/ONBOARDING.md` Step 1 item 3).

   Delete without asking a project line that restates a framework rule exactly. The template's section already points to the rule, and two copies drift apart. A line that differs at all is a contradiction or a stricter rule: settle it as above.
4. **Fill or delete every bracketed field** (How to fill it in, above). An existing project has no Project Charter and no Stack Decision ADR. Answer from the existing file, the code and the Director (`Workflows/ONBOARDING.md` Steps 2 and 3). If nobody can answer a field yet, delete it and add the question under `# Open Questions`. Never guess an answer.
5. **Check the result.**
   - First, confirm that `HEAD` still holds the originals. `git show --stat --format= HEAD -- CLAUDE.md .claude/CLAUDE.md` prints nothing when the adoption commit left them alone. If it prints a line, the merged file went into the adoption commit, and `HEAD` holds the merge, not the original. Then compare against `HEAD~1` in the commands below, and say so in the Work Unit Report.
   - Every build, test and run command of the original files is still in `CLAUDE.md` or in a file it imports, unchanged. `git show HEAD:CLAUDE.md` prints the original root file, and `git show HEAD:.claude/CLAUDE.md` the original `.claude/CLAUDE.md`. Check each original the project had, both when it had both.
   - Every `@` import in `CLAUDE.md` names a file that exists. `grep -noE '(^|[[:space:]])@[^[:space:]]+' CLAUDE.md` lists them, and `ls <path>`, run from the root, finds each one.
   - `grep -nF '[' CLAUDE.md` lists every line that holds a bracket. Each listed line is a link or the project's own text, never a template placeholder.
6. **Commit it**, as the dispatched DevOps Engineer, in its own commit after the adoption commit. Sign it `Employee: DevOps Engineer`. Give it a `Work Unit:` line naming a Work Unit registered in `Registry/work-units.yml` in that same commit, for example `WU-<PREFIX>-002` (`Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5). The `commit-msg` hook refuses an unregistered id, but it does not require the line (issue #384), so check that the line is there.

**A project with an `AGENTS.md` and no `CLAUDE.md`.** By default, Claude Code reads `AGENTS.md` only while there is no `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` (memory documentation, above). Creating the contract therefore stops it reading every `AGENTS.md`: the root one, `.claude/AGENTS.md`, and those in subdirectories.
- Create `CLAUDE.md` from the block as for a new project, with the same dispatch and the same commit as above.
- Then import each `AGENTS.md`, on a line of its own and outside backticks. Put `@AGENTS.md` and `@.claude/AGENTS.md` in the root `CLAUDE.md`, after `# Technology`. For a subdirectory's `AGENTS.md`, create a `CLAUDE.md` beside it holding the line `@AGENTS.md`. Claude Code loads it when it works on a file in that subdirectory.
- Step 3 applies to what each `AGENTS.md` says. A line it settles is changed in that `AGENTS.md` itself, and other coding tools read the same file, so the change reaches them too. Tell the Director so when presenting the contradiction.

---

# Template

**Copy only the contents of the fenced block below** into the project's `CLAUDE.md`, from the `# [Project Name]` line to the last line before the closing fence. Never copy this whole file. The sections above and below explain how to fill in the contract and are not part of it. A whole-file copy makes the project's `CLAUDE.md` this template's documentation, with the contract fenced inside it. A project that already has a `CLAUDE.md` merges the block into it instead (A project that already has a `CLAUDE.md`, above). The block's outer fence has four backticks, so the three-backtick fence under `# Repository` is part of the block.

````markdown
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
worktree, such as an Employee's, needs neither, though its `ia-engineering/`
stays empty: its hooks are the main checkout's, and each generated Employee
reads the framework from the main checkout, at the absolute path its
definition names under "Where the Framework Is". If the project moves, re-run
`./ia-engineering/Adapters/ai-runtimes/generate-agents.sh` from the main
checkout.

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
````

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

Version: 0.0.15

Status: Draft

Category: Template — Onboarding

Severity: Mandatory
