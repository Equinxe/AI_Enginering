# AI Runtime Adapters

---

# Purpose

`Adapters/github/` turns the framework's git rules into checks a version-control host enforces. This directory does the equivalent for the other half of the framework: it turns the 42 Employee definitions into agents an AI runtime can actually dispatch to.

Until it existed, an Employee was prose. `Core/MAIN_AGENT_CONDUCT.md`'s `Dispatch Discipline` required every delegation to be framed as a named Employee carrying that Employee's Mission, Authority, Standards Applied, and Definition of Done — and stated that substituting a runtime's own generic subagent is "the same violation as not delegating at all". Three separate conduct sections exist to hold that line: `Dispatch Discipline`, `No Direct Implementation`, and `Git Execution via Named Employee`. Each was written after the rule had already been broken in practice.

The reason it kept being broken is structural, not a lapse of discipline. Under a runtime whose available agents are named "executor", "reviewer", and "coder", dispatching to a Backend Engineer means constructing that Employee from prose on every single dispatch, while a conveniently-named generic agent sits one keystroke away. The framework's response each time was a stronger prohibition. The mechanical response is to make the Employee exist as something the runtime can dispatch to — so that reaching for the right Employee is the path of least resistance rather than the disciplined exception.

---

# What It Generates

```bash
# From the framework repository:
./Adapters/ai-runtimes/generate-agents.sh --target claude-code

# From a project that imports the framework as a submodule:
./ia-engineering/Adapters/ai-runtimes/generate-agents.sh --target claude-code
```

One agent definition per Employee, read from that Employee's own definition file and the roster in `Registry/employees.yml` — **plus** the project's Domain Employees (`Templates/DOMAIN_EMPLOYEE.md`) from `.ia-engineering/Registry/employees.yml` when that file exists, or from `--roster <file>`. A `--roster` naming a missing file is refused, never skipped: generating the framework's Employees alone would leave the project's own undispatchable while reporting success.

Output goes to the **project's** agent directory — the directory the script was run from, or `--project <dir>` — because that is the only one a runtime reads. Until WU-IAENG-189 the default was resolved against the framework instead, so an adopter who ran the documented command got 42 files inside `ia-engineering/.claude/agents`, a path nothing reads, and a report saying 42 were written.

Each generated agent carries:

- The Employee's Mission, Responsibilities, Authority, Standards Applied, Inputs, Process, Outputs, Output Format, Definition of Done, Escalation Rules, and Failure Modes — extracted from `Employees/`, not paraphrased.
- The universal rules from `Core/AGENT_CONDUCT.md` and a pointer to `Core/DECISION_TREE.md`, which every Employee inherits.
- The exact commit trailer it must use, and the statement that a commit without it is rejected mechanically.
- Its first and last actions: Read First, and the Work Unit Report (`Core/AGENT_CONDUCT.md`), plus the risk-classification and escape-hatch rules.
- An execution capability derived from the Employee's Default Complexity Tier.
- A header naming the definition it came from and the roster that declared it, so a Domain Employee's provenance is visible in the generated file.

---

# Why This Does Not Violate AI-Agnosticism

`Core/AI_MANIFEST.md` Principle X and `Core/CAPABILITY_TIERS.md` are strict that no framework document names a model, and that strictness is not weakened here.

This directory is an **Adapter**, and `Core/GLOSSARY.md` already defines what that means: AI-agnostic in the sense that matters — it works for any Employee, under any runtime — while not tool-agnostic, the way a GitHub Adapter assumes GitHub. Naming concrete models inside a `claude-code` target is the same category of statement as naming `.github/workflows/` in the GitHub Adapter.

`Core/CAPABILITY_TIERS.md` anticipates this directly — it names no model itself and points here instead:

> See `Adapters/ai-runtimes/README.md` for where a runtime's tier-to-model mapping lives.

For this runtime, that mapping is Lightweight Execution → Haiku, Standard Execution → Sonnet, Strategic Judgment → Opus. (Frontier has no mapping here yet — a later Work Unit adds the key once a Frontier-capable model is chosen.)

The mapping lives in the target definition and in `--map`. It never appears in `Core/`.

## Adding a runtime

Add a case branch to `generate-agents.sh` and a default output convention. The Employee definitions, `Registry/employees.yml`, and the tiers in `Core/CAPABILITY_TIERS.md` do not change — a second runtime reads the same sources through the same extraction. `--target list` prints what is available.

## Overriding the mapping

```bash
./Adapters/ai-runtimes/generate-agents.sh --map strategic=opus,standard=sonnet,lightweight=haiku
```

A project that has decided its own tier-to-capability mapping supplies it here rather than editing the script.

---

# Runtime Hooks — Refusing Before, Not Rejecting After

`generate-agents.sh` makes the Employees exist in the runtime. `claude-code/hooks/` makes the framework's rules bind **at the point the runtime acts**, which is earlier than any git hook or CI check can reach:

| Hook | Refuses | Rule |
|---|---|---|
| `session-start.sh` | Nothing — prints the read-first order and the current `SESSION_STATE.md` into context | `Core/AGENT_CONDUCT.md`, Read First |
| `block-escape-hatches.sh` | A shell command using `--no-verify`, `--no-gpg-sign`, `stash`, interactive git, force/mirror push, protected-branch deletion, `reset --hard`, `clean -f`, `checkout -- .`, `branch -D`, history rewrite, `rm -rf .git` | `Standards/GIT_STANDARD.md`, Escape Hatches |
| `block-inline-suppression.sh` | An edit writing a lint/type/test disable directive, a skipped or focused test, or a swallowed exception into code (documentation exempt, by name) | `Standards/CODE_QUALITY_STANDARD.md`, No Inline Suppression |
| `post-edit-lint.sh` | Nothing — runs `bash -n`/`shellcheck` and the project's `.ia-engineering/lint.sh` on the file just written, returns failures to the model, says when nothing ran | `Standards/CODE_QUALITY_STANDARD.md`, Automated Quality |
| `stop-gate.sh` | Ending the session with tracked changes uncommitted and unexplained — once, then the loop guard yields | `Core/AGENT_CONDUCT.md`, Reporting Contract |

Installed by `claude-code/install-hooks.sh` into the project's committed `.claude/settings.json`, so every clone runs them without a per-clone step. Every hook fails closed on unreadable input and has no disabling switch; `claude-code/hooks/README.md` is the reference. They are the executable form of Standards that exist first as documents — a rule that lived only in a hook would be a rule the framework does not have.

# Independent Review Bot

`claude-code/review-bot.yml` runs `Workflows/CODE_REVIEW.md` as the Code Reviewer Employee inside GitHub Actions, under the Actions identity — a second account, which is what the `Review Recorded` check never had. Setting the repository variable `IAENG_REVIEW_BOT_LOGIN` to that identity switches `Review Recorded` into **independent mode**, where only that login's `Decision:` block counts. Not installed by `install.sh` (it needs an API key and a Director decision to spend it); not a required check by default; documented in the file's header.

# Other Runtimes

`omc/README.md` maps the framework onto oh-my-claudecode, an orchestration layer that runs on Claude Code: which of its agents, modes, and state files correspond to which framework concepts, which do not, and where the framework binds regardless. It is a transport mapping recorded from the runtime's own documentation and not tested here; adopters correct it as a Work Unit.

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
| `Adapters/ai-runtimes/claude-code/hooks/` | That no escape hatch, inline suppression, or unexplained stop happens in the first place | In the runtime, at the moment of the action |

The two are complementary and neither replaces the other. The `commit-msg` hook can prove a commit *claims* `Employee: Backend Engineer`; it cannot prove a Backend Engineer produced it. This directory closes that distance from the other side — by making the Backend Engineer a thing that exists, so the claim is true by construction rather than by discipline.

It does not make the claim unfalsifiable, and nothing can. `Core/MAIN_AGENT_CONDUCT.md`'s `No Direct Implementation` remains the rule that matters: attributing self-authored work to an Employee that was never dispatched is a Dispatch Discipline violation regardless of what tooling exists.

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

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
