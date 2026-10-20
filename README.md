# IA Engineering

> **Building AI teammates, not AI tools.**

IA Engineering is an AI-agnostic Software Engineering Framework that transforms AI assistants into professional engineering teammates.

Instead of optimizing code generation, IA Engineering optimizes the entire software engineering process through standards, workflows, specialized AI employees, and collaborative engineering practices.

---

## Getting Started

IA Engineering is imported into a project as a git submodule. It does not
replace your stack, your CI, or your tooling — it adds standards, workflows and
a roster of named Employees on top of them.

```bash
# from the root of your project (skip git init if it is already a repository)
git init -b main
git submodule add https://github.com/Equinxe/AI_Enginering ia-engineering
git -C ia-engineering checkout v0.0.14   # pin a release tag: see "Which ref to pin" below
git add ia-engineering                   # records the pinned commit

# CI checks, git hooks, data-protection rules, PR and issue templates
./ia-engineering/Adapters/scripts/setup-project-bootstrap.sh <stack>

# turn the 42 Employee definitions into agents your runtime can dispatch to
./ia-engineering/Adapters/ai-runtimes/generate-agents.sh
```

**Which ref to pin.** A submodule records one exact commit, and the framework
promises nothing across versions yet: `VERSION.md` Status is Active Development
and no backward-compatibility guarantee applies
(`Governance/VERSIONING_POLICY.md`). So pin a release tag, never a moving
branch; the latest is `v0.0.14`. A fix that lands on `develop` after a tag
reaches you only with the next tag. An early adopter who needs one sooner pins
a specific `develop` commit instead, and moves to the next tag when it is cut.
Upgrading is a deliberate `git -C ia-engineering checkout <newer tag>` followed
by `git add ia-engineering`, reviewed like any other change.

If the framework comes from a local directory instead of a URL, `git submodule
add` fails with `fatal: transport 'file' not allowed`; see
[`Governance/TROUBLESHOOTING.md`](Governance/TROUBLESHOOTING.md) entry Y.

`<stack>` is one of `node`, `web`, `python`, `go`, `jvm`, `dotnet`, `php`,
`generic`. **`web` is a static front end** — a site or single-page application
built to files and served by a web server — and it is a different stack from
`node`, which ships a running process. Neither can be told from the other by
looking at `package.json`, which is why the choice is recorded rather than
guessed.

Using Claude Code as the runtime? Two more, both **required for Claude Code** (without them no hook or `/create-project` skill is loaded) and not needed for any other runtime:

```bash
./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh   # refuse before, not report after
./ia-engineering/Adapters/ai-runtimes/claude-code/install-skills.sh  # adds /create-project
```

On GitHub, one command configures the ten required status checks, branch
protection, and the release-branch ruleset:

```bash
./ia-engineering/Adapters/scripts/setup-branch-protection.sh
```

On any other forge it changes nothing and prints the equivalent as a checklist
to apply by hand.

### The steps that are not commands

Copy `Templates/PROJECT_CLAUDE.md` to your project's `CLAUDE.md` and fill it in.
It is the contract every session reads first; a project without one starts every
session with no context and no rules. Make your first commit (the adoption itself: the submodule and the installed
tooling; `CLAUDE.md` goes in a later commit), signed `Employee: DevOps Engineer`
(`Workflows/PROJECT_BOOTSTRAP.md` Step 4). Then create
`.ia-engineering/SESSION_STATE.md`. The helper
`./ia-engineering/Adapters/scripts/create-session-state.sh` does it for you: it
refuses before the first commit and never overwrites an existing file, writes the
fenced block with the project name and today's date in the form described below,
and checks that the file is gitignored. By hand, it comes from the fenced block under **Template** in
`Templates/SESSION_STATE.md`: the block's contents only, not the whole file,
whose other sections explain how to keep the state file and are not part of
it. Fill in the placeholders, and at least the `_Last updated:` line with
today's absolute date in the form `6 October 2026` (day, English month name,
year). The session-start hook reads the date from that line and reports a
placeholder as unparsable. This file is the project's dated operational state,
read right after `CLAUDE.md` on every resume, and never committed (the install
gitignores it). Create it **after** that commit, not before: the session-start
hook compares the file's modification time with the latest commit, so a file
that predates the first commit is reported as "1 commit(s) behind" on the very
first session. `Workflows/PROJECT_BOOTSTRAP.md` walks
through the questions behind it — including the one that decides whether your
project needs a Domain Employee of its own.

### Working on the framework itself

Everything above is for *consuming* IA Engineering inside another project. If you
have instead been handed *this* repository to work on the framework itself, start
with two documents: `CLAUDE.md` — the operating contract every session in this
repository reads first — and
[`Governance/CONTRIBUTING.md`](Governance/CONTRIBUTING.md), which defines how a
change to the framework is proposed, reviewed, and landed.

---

## What this is not

- **Not a prompt library.** There are no prompts to paste. The content is
  standards, workflows and role definitions that an AI reads as its operating
  rules.
- **Not a code generator.** It changes how work is decomposed, reviewed and
  released. Your model still writes the code.
- **Not tied to one AI.** The framework content names no vendor. Everything
  runtime-specific lives under `Adapters/ai-runtimes/`, and today only the
  Claude Code adapter has been executed end to end.
- **Not a substitute for engineers.** The Director makes every final decision,
  and several gates exist specifically to stop an agent passing them alone.

## What is proven, and what is not

Honest scope, because adopting a framework on a false claim costs more than
skipping it:

| | |
|---|---|
| **Proven by execution** | as of v0.0.14: 200 framework self-validation checks, 1208 behaviour tests over the check scripts, 791 over the runtime hooks, and ten required CI checks — all green on every merge, on Linux |
| **Proven once, end to end** | a fresh project importing the framework, bootstrapping, generating its 42 agents, installing hooks that refuse a bad commit and accept a good one |
| **Not yet proven** | **the framework has only ever been used on itself.** No third-party project has adopted it. The first one will find things `Governance/TROUBLESHOOTING.md` does not yet contain |
| **Not yet proven** | 29 of the 42 Employees have never been dispatched. Their definitions are careful; carefulness is not evidence |

---

## Why?

Modern AI can generate code.

Professional software engineering requires much more.

Successful projects depend on:

- Architecture
- Collaboration
- Documentation
- Git discipline
- Code reviews
- Small and reviewable changes
- Maintainability

IA Engineering teaches AI how to work inside a real engineering team.

---

## Core Principles

- Human First
- Engineering Before Automation
- Incremental Development
- Reviewability
- Transparency
- Maintainability
- Continuous Improvement
- AI Agnostic

See `Core/AI_MANIFEST.md` for the complete manifesto.

---

## Framework

```

AI Manifest
↓
Standards
↓
Employees
↓
Workflows
↓
Project Context
↓
Implementation

```

Each layer extends the previous one without violating its rules.

---

## Current Status

Current Version

```

v0.0.14 - Precision

```

Completed

- ✅ Core (AI Manifest, Glossary, Decision Tree, Main Agent Conduct, Agent Conduct, Orchestration, Agent Chains, Employee Selection, Capability Tiers, Context Budget)
- ✅ Standards (Standards First, Git, Commit, Branch, Pull Request, Documentation, Code Quality, Testing, Risk, Data Protection)
- ✅ Employees (42 AI Employee definitions across 8 categories, each with a Default Complexity Tier; projects add Domain Employees for their own business domain)
- ✅ Workflows (10 engineering workflows, from feature development to incident response, project bootstrap, and multi-session autonomous delivery)
- ✅ Templates (Work Unit, Work Unit Report, Pull Request, ADR, Incident Report, Test Plan, Employee Brief, Pole Brief, Domain Employee, Project Charter, Project CLAUDE.md, Session State, Risk Map)
- ✅ Orchestration (Main Agent dispatch protocol, 6 named Agent Chains)
- ✅ Examples (6 end-to-end chain walkthroughs on a single fictional project)
- ✅ Capability Tiers (AI-agnostic execution tiers matching capability to Work Unit complexity)
- ✅ Adapters (GitHub git hooks, Actions CI checks, PR template, branch protection setup script, CI/CD + GHCR publishing, GitHub Issue Templates, data-policy scanner, PR size gate, Claude Code runtime hooks, independent review bot)
- ✅ Project Bootstrap (dedicated bootstrap workflow, Project Charter template, CI/CD + GHCR publishing adapters, GitHub Issue Templates, compliance and business/product hardening)
- ✅ Governance (Contributing, Versioning Policy, Deprecation Policy, Troubleshooting Catalog, Dispatch in Practice)
- ✅ Registry (machine-readable roster, agent chains, workflow steps and gates, Work Units — derived from the governed documents, never authoritative over them)
- ✅ Automation (framework self-validation in CI, one-command Adapter installation, release-workflow automation up to the Director gate, runtime agent generation from the Employee definitions)
- ✅ Convergence (governance concepts absorbed from sibling frameworks and made framework-wide: a shared Risk scale with stop tiers, structural Data Protection with a pre-commit hook and a history-scanning CI check, the Work Unit Report and Session State contracts, Domain Employees with a project roster, a review-size gate, the escape-hatch ban list enforced by Claude Code hooks, multi-lens review, the dependent-task queue, the conductor/pole Autonomous Delivery workflow, and the Troubleshooting Catalog with its learning loop)
- ✅ Portability (the framework made runnable off its own repository: the four Pull Request checks extracted from CI into scripts any forge can run with a real behaviour suite, a host seam where the host fetches and acts but never decides, seven first-class stacks each pinned to a starter Dockerfile, the Risk Map by which a project classifies its own paths, and an already-started-project adoption path that never overwrites the project's own work)
- ✅ Precision (the framework made exact and usable: every front-facing surface audited and pinned against drift by the validator, the controls that grade a Pull Request attacked from the inside and each finding closed as a check, a hook rule or a stated limit, the newcomer path dogfooded on real adoptions, and a local usage dashboard for roster and chain tuning)

Planned

- **Adoption** (next, targets v0.0.15) — sustained adoption on a real project and the follow-ups it finds

---

## Repository Structure

```

Core/
Standards/
Employees/
Workflows/
Templates/
Examples/
Governance/
Registry/
Prompts/
Adapters/

```

---

## Roadmap

- Foundation
- Engineering Standards
- Employee System
- Workflow Engine
- Templates
- Orchestration
- Examples
- Capability Tiers
- Adapters
- Governance
- Automation
- Convergence
- Portability
- Public Release

---

## Contributing

See **[`Governance/CONTRIBUTING.md`](Governance/CONTRIBUTING.md)**: how a change
to the framework is proposed and reviewed, what a new Employee, Workflow,
Template or Standard must contain, the higher bar for anything under `Core/`,
the Code of Conduct, and the learning loop that turns an incident into a rule
and a rule into a mechanical control.

Two things worth knowing before opening a Pull Request:

- **Every commit carries a `Work Unit:` and an `Employee:` trailer**, and CI
  resolves both against `Registry/`. The git hooks install these locally so the
  failure happens before the push, not after it.
- **The review limit is 1,500 changed lines.** Past that a review is a skim.
  Split the change, or the Director accepts the size explicitly with a label.

---

## License

Licensed under the Apache License, Version 2.0. See `LICENSE.md` for the full text.
