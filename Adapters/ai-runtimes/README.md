# AI Runtime Adapters

---

# Purpose

`Adapters/github/` turns the framework's git rules into checks a version-control host enforces. This directory does the equivalent for the other half of the framework: it turns the 42 Employee definitions into agents an AI runtime can actually dispatch to.

Until it existed, an Employee was prose. `Core/MAIN_AGENT_CONDUCT.md`'s `Dispatch Discipline` required every delegation to be framed as a named Employee carrying that Employee's Mission, Authority, Standards Applied, and Definition of Done — and stated that substituting a runtime's own generic subagent is "the same violation as not delegating at all". Three separate conduct sections exist to hold that line: `Dispatch Discipline`, `No Direct Implementation`, and `Git Execution via Named Employee`. Each was written after the rule had already been broken in practice.

The reason it kept being broken is structural, not a lapse of discipline. Under a runtime whose available agents are named "executor", "reviewer", and "coder", dispatching to a Backend Engineer means constructing that Employee from prose on every single dispatch, while a conveniently-named generic agent sits one keystroke away. The framework's response each time was a stronger prohibition. The mechanical response is to make the Employee exist as something the runtime can dispatch to — so that reaching for the right Employee is the path of least resistance rather than the disciplined exception.

---

# What It Generates

```bash
./Adapters/ai-runtimes/generate-agents.sh --target claude-code
```

One agent definition per Employee, read from that Employee's own definition file and the roster in `Registry/employees.yml`. Each generated agent carries:

- The Employee's Mission, Responsibilities, Authority, Standards Applied, Inputs, Process, Outputs, Output Format, Definition of Done, Escalation Rules, and Failure Modes — extracted from `Employees/`, not paraphrased.
- The universal rules from `Core/AGENT_CONDUCT.md` and a pointer to `Core/DECISION_TREE.md`, which every Employee inherits.
- The exact commit trailer it must use, and the statement that a commit without it is rejected mechanically.
- An execution capability derived from the Employee's Default Complexity Tier.

---

# Why This Does Not Violate AI-Agnosticism

`Core/AI_MANIFEST.md` Principle X and `Core/CAPABILITY_TIERS.md` are strict that no framework document names a model, and that strictness is not weakened here.

This directory is an **Adapter**, and `Core/GLOSSARY.md` already defines what that means: AI-agnostic in the sense that matters — it works for any Employee, under any runtime — while not tool-agnostic, the way a GitHub Adapter assumes GitHub. Naming concrete models inside a `claude-code` target is the same category of statement as naming `.github/workflows/` in the GitHub Adapter.

`Core/CAPABILITY_TIERS.md` anticipates this directly:

> A project's own `CLAUDE.md` may map these tiers to concrete models for its chosen AI runtime (e.g., "Lightweight Execution → Haiku, Standard Execution → Sonnet, Strategic Judgment → Opus" for a Claude-based project). That mapping is project context, not part of this framework document.

The mapping lives in the target definition and in `--map`. It never appears in `Core/`.

## Adding a runtime

Add a case branch to `generate-agents.sh` and a default output convention. The Employee definitions, `Registry/employees.yml`, and the tiers in `Core/CAPABILITY_TIERS.md` do not change — a second runtime reads the same sources through the same extraction. `--target list` prints what is available.

## Overriding the mapping

```bash
./Adapters/ai-runtimes/generate-agents.sh --map strategic=opus,standard=sonnet,lightweight=haiku
```

A project that has decided its own tier-to-capability mapping supplies it here rather than editing the script.

---

# Generated Output Is a Build Artifact

Regenerate it. Do not hand-edit it.

An edited agent file is a second definition of an Employee, and it will diverge from `Employees/` without anything reporting it — exactly the duplication `Registry/employees.yml` was created to end. Every generated file carries that warning in its own header, and `--check` exits non-zero when any generated file no longer matches its source, which is what a CI job should run.

**This repository does not commit its generated agents** — `.gitignore` excludes `.claude/agents/`. The reasoning: 42 files of roughly 210 lines each is about 9,000 lines of derived content in a repository whose entire source is 15,000, and every Employee edit would produce a large mechanical diff alongside the real one.

That is a trade-off, not a rule, and it has a real cost: anyone cloning this repository must run the generator before the Employees exist as dispatchable agents, the same way they must run `install.sh` before the hooks exist. A project that would rather have the agents present on clone should commit them and add `generate-agents.sh --check` to its CI. Which way to go is the Director's call per project.

---

# Relationship to Other Adapters

| Adapter | Enforces | Where
|---|---|---|
| `Adapters/github/`, `Adapters/github-actions/`, `Adapters/git-hooks/` | The git and review rules | On the host, after the work is produced |
| `Adapters/ai-runtimes/` | That the work is produced by a named Employee at all | In the runtime, before the work is produced |

The two are complementary and neither replaces the other. The `commit-msg` hook can prove a commit *claims* `Employee: Backend Engineer`; it cannot prove a Backend Engineer produced it. This directory closes that distance from the other side — by making the Backend Engineer a thing that exists, so the claim is true by construction rather than by discipline.

It does not make the claim unfalsifiable, and nothing can. `Core/MAIN_AGENT_CONDUCT.md`'s `No Direct Implementation` remains the rule that matters: attributing self-authored work to an Employee that was never dispatched is a Dispatch Discipline violation regardless of what tooling exists.

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Adapter — AI Runtime

Severity: Recommended

Depends On:

- `Employees/` (all 42 definitions)
- `Registry/employees.yml`
- `Core/CAPABILITY_TIERS.md`
- `Core/AGENT_CONDUCT.md`
- `Core/MAIN_AGENT_CONDUCT.md`

Referenced By:

- `Adapters/README.md`
