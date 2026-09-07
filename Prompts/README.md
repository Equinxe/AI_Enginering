# Prompts

---

# Status

**Reserved and empty.** This directory has held only a `.gitkeep` since the repository's first commit.

It is listed in `README.md`'s Repository Structure, in `CLAUDE.md`'s Repository block, and in `Governance/CONTRIBUTING.md`'s scope, described in `CLAUDE.md` as "Reusable prompts". That is the only description of it anywhere: `Core/GLOSSARY.md` — which defines Adapter, Artifact, Chain, Employee, Template, Work Unit, and Workflow — has no entry for a Prompt, and no Standard, Workflow, or Employee definition references this directory or says what belongs in it.

This file exists so that a reader who follows the structure listing here is not left inferring the answer from an empty directory. It does not invent one.

---

# The Open Question

`Governance/` was in exactly this position until v0.0.11 — advertised since the first commit, holding only a placeholder — and the Governance milestone resolved it by deciding what governance documents the framework actually needed and writing them. `Prompts/` is the last placeholder of that kind.

Resolving it is a scoping decision for the Director, not something to fill in opportunistically, and there is a real question underneath it. `Core/EMPLOYEE_SELECTION.md`'s "Prompt Engineer vs. Software Architect — an open question" already works through the tension this directory sits on top of: this framework's own documents are simultaneously architecture (they define roles, structure, and decision flow) and literally prompts (they are instructions consumed by an AI model to govern its behavior). That section deliberately declines to assert a winner.

Which means the question `Prompts/` raises is not "what files go here" but the prior one:

- If a reusable prompt is an **artifact of a project using the framework** — a versioned prompt library for an AI feature, the kind `Employees/Specialized/PROMPT_ENGINEER.md` describes designing and evaluating — then it belongs in that project's repository, and this directory has no reason to exist in the framework.
- If it is an **artifact of the framework itself** — a reusable instruction block that Employees or the Main Agent draw on — then it needs a definition in `Core/GLOSSARY.md`, a stated relationship to `Templates/` (which already holds the framework's reusable documents), and a rule for why a given piece of text belongs in one and not the other.

Until that is decided, adding files here would create a directory whose contents nobody can evaluate against a definition, which is the condition `Standards/DOCUMENTATION_STANDARD.md` calls out under Single Source of Truth: each piece of information should exist in one authoritative location, and `Templates/` may already be it.

---

# What to Do Instead, For Now

Nothing goes here. Two existing homes cover the real cases:

| If the content is | It belongs in |
|---|---|
| A reusable document an Employee fills in (Work Unit, Employee Brief, ADR, Test Plan, Project Charter, Incident Report, Pull Request) | `Templates/` |
| A generated AI-runtime instruction derived from an Employee definition | `Adapters/ai-runtimes/`, generated — never hand-written (see that directory's README) |

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Placeholder — Undefined Scope

Severity: Informative
