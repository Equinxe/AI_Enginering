---
name: create-project
description: Start a new project under IA Engineering. Runs Workflows/PROJECT_BOOTSTRAP.md end to end — Phase A discovery, Project Charter, stack decision ADR, Adapter installation, and the first Work Unit. Use when the user asks to create, bootstrap, scaffold or start a new project, repository, application, service or site.
---

# Create a project under IA Engineering

**This skill points at a workflow. It does not contain one.**

`Workflows/PROJECT_BOOTSTRAP.md` is the authority for every step, question and gate below. Read it and follow it. Nothing here paraphrases it, because a paraphrase is a second copy that goes stale — and this repository has already watched an Example drift from the Workflow it demonstrated within hours of that Workflow changing.

If anything in this file appears to contradict the Workflow, the Workflow is right and this file is a defect.

---

## 1. Locate the framework

It is normally a submodule at `ia-engineering/`. Confirm before starting:

```
ls ia-engineering/Workflows/PROJECT_BOOTSTRAP.md
```

If it is somewhere else, use that path throughout. If it is nowhere, the project has not imported IA Engineering yet, and that — not bootstrapping — is the first thing to fix.

## 2. Read the Workflow, then follow it

Read `Workflows/PROJECT_BOOTSTRAP.md` in full before asking the user anything. It defines the phases, the Actors for each, the Coverage Checklist, and the Exit Criteria.

Two points it makes that are easy to skip under time pressure, repeated here only because skipping them is what goes wrong:

- **Phase A question 12 — what constitutes PROOF** for this project's domain. Its answer is what decides whether the project needs a Domain Employee (`Templates/DOMAIN_EMPLOYEE.md`). A project that never answers it discovers the gap much later, when an Employee produces domain output nobody can verify.
- **The confidential-data question is asked at inception**, not after the first file exists. `Standards/DATA_PROTECTION_STANDARD.md` is structural: the local data directory and the ignore rules have to exist before there is anything to protect.

## 3. Run the mechanical half

Three commands, from the project root:

```
./ia-engineering/Adapters/scripts/setup-project-bootstrap.sh <stack>
./ia-engineering/Adapters/ai-runtimes/generate-agents.sh
./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh
```

`<stack>` is one of `node`, `web`, `python`, `go`, `jvm`, `dotnet`, `php`, `generic`. **`web` is a static front end** — a site or single-page application that builds to files served by a web server — and it is a different stack from `node`, which ships a running process. Neither can be inferred from `package.json`, which is why the bootstrap records the choice.

`setup-project-bootstrap.sh` prints the Coverage Checklist items it cannot complete itself. **Read that list.** Each one needs a decision, a Director, or an authenticated API call, and the Exit Criteria requires every one of them.

## 4. Do not skip the project's own contract

`Templates/PROJECT_CLAUDE.md` becomes the project's `CLAUDE.md`. It is the first thing every future session reads, so a project without one starts every session with no context and no rules.

## 5. Stop at the gates

`Workflows/PROJECT_BOOTSTRAP.md` names its Director gates. They are decisions, not confirmations — do not pass one by summarising it and continuing.

---

## Why this file lives where it does

Slash commands are a Claude Code feature. `Core/AI_MANIFEST.md` Principle X requires the framework itself to stay AI-agnostic, so this skill lives under `Adapters/ai-runtimes/claude-code/` with the rest of the runtime-specific integration, and `install-skills.sh` places it in a project's `.claude/skills/`.

The framework content proper never mentions it. A different runtime writes its own wrapper beside this one and the Workflow is untouched — which is the whole point of the Adapter layer.
