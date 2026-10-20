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

For this runtime, that mapping is Lightweight Execution → Haiku, Standard Execution → Sonnet, Strategic Judgment → Opus, **Frontier → Fable**.

Frontier is never a default. No Employee's Default Complexity Tier is ever Frontier (`Core/CAPABILITY_TIERS.md`), so `generate-agents.sh` never writes `fable` into any generated agent's `model:` field — the `frontier=` key exists only so the script's printed `tiers:` summary gives the Main Agent a value to pass as a per-dispatch **Tier Override** (`Core/CAPABILITY_TIERS.md`, Frontier Override) when a Work Unit already at Strategic Judgment is escalated, with Director approval, each time. Fable costs roughly **2.5× Opus** ($10 / $50 per million input/output tokens against Opus's $4 / $20 — [platform.claude.com/docs/en/about-claude/models/overview](https://platform.claude.com/docs/en/about-claude/models/overview)), which is the cost the Frontier Override paragraph above is deliberately not a default path to.

The mapping lives in the target definition, in the project's `.ia-engineering/tier-map`, and in `--map`. It never appears in `Core/`.

## Adding a runtime

Add a case branch to `generate-agents.sh` and a default output convention. The Employee definitions, `Registry/employees.yml`, and the tiers in `Core/CAPABILITY_TIERS.md` do not change — a second runtime reads the same sources through the same extraction. `--target list` prints what is available.

## Overriding the mapping

```bash
./Adapters/ai-runtimes/generate-agents.sh --map strategic=opus,standard=sonnet,lightweight=haiku,frontier=fable
```

A one-off override goes here. A project that has *decided* its own tier-to-capability mapping records it in the project instead (next section) rather than editing the script or relying on everyone typing the flag.

## A project's own mapping: `.ia-engineering/tier-map`

`Core/CAPABILITY_TIERS.md` makes the tier-to-model mapping project context. A flag is not a place to keep project context: the documented command, run without `--map`, reverted every Employee to the target defaults, and `--check` run the same way reported every agent stale and blamed `Employees/` for it. So `generate-agents.sh` reads an optional file, `<project>/.ia-engineering/tier-map`, on every run:

```
# why this mapping, and who decided it
map=strategic=claude-opus-5-5,standard=claude-opus-5-5,lightweight=claude-opus-5-5,frontier=fable
effort-map=strategic=high,standard=,lightweight=,frontier=
```

- **Two keys**, `map=` and `effort-map=`, each with exactly the syntax of the flag of the same name. Either may be omitted. Blank lines and `#` comments are ignored; CRLF line endings are tolerated.
- **Precedence, per tier: flags > the file > the target's defaults.** A flag naming one tier overrides that tier only; the file still supplies the others.
- **Refused, not skipped**: an unknown key, a line with no `key=`, a key given twice, an unknown tier, or an invalid effort level exits 2 with the file and line. A half-read mapping is a mapping nobody chose.
- **Reported**: the summary prints `mapping: file (<path>)`, `mapping: defaults (...)`, or `mapping: flags (...)`.
- **`--check` resolves the mapping the same way**, and a file that differs only in its `model:`/`effort:` lines and the model half of its header `Tier:` line is reported as a mapping difference ("mapping only: on disk X, effort: E; resolved Y, effort: F"), not as an Employee definition out of date. The tier *name* is still compared: a roster tier change is reported as out of date even when the mapping gives both tiers the same model.
- A UTF-8 byte order mark at the start of the file (Windows PowerShell 5.1 writes one) is ignored.
- **Frontier stays override-only.** A `frontier=` value in the file is printed in the `tiers:` summary like the flag's, and is never written into any agent's `model:`.
- **Read at runtime, not only at generation.** `generate-agents.sh --print-tier-map` resolves the mapping exactly as a generation would (same precedence, same refusals) and prints it as three lines that are themselves a valid tier-map file — `# mapping: <source>`, `map=…`, `effort-map=…` — writing nothing. It is refused with `--check` or `--dry-run`, which it does not perform. The Claude Code `session-start.sh` hook calls it on every session, so the map in force, Lightweight and Frontier included, is in the Main Agent's context before any dispatch (How a per-Work-Unit Execution tier is actually run, below). A runtime without a session-start hook gets the same line by running the command; nothing else re-parses the file.

Commit it. This repository tracks its own through a `!.ia-engineering/tier-map` exception in `.gitignore` (it ignores the rest of `.ia-engineering/`); an adopting project needs nothing, because `install.sh` ignores only `.ia-engineering/SESSION_STATE.md` there. The defaults in the script are not changed by any project's file — they remain what every other adopter gets.

This repository's own file records the Director's decision of 5 Oct 2026: every Employee runs on Opus 5.5, Strategic Judgment at high effort.

## Per-tier effort

Alongside the per-tier model, `generate-agents.sh` emits a per-tier `effort:` frontmatter field. Director decision, 25 Sep 2026: **Strategic Judgment runs at high effort; the other tiers inherit** the runtime's own default effort — which means Standard Execution, Lightweight Execution, and Frontier get no `effort:` field at all rather than an explicit one, so a future change to the runtime's own default effort still applies to them. This is deliberately an Adapter decision, not a Core one: `Core/CAPABILITY_TIERS.md` names no model, and by the same `AI_MANIFEST.md` Principle X, no effort level either.

```bash
./Adapters/ai-runtimes/generate-agents.sh --effort-map strategic=high,standard=,lightweight=,frontier=high
```

Overrides the default the same way `--map` does. An empty value (`standard=`) means "inherit" — no `effort:` field for that tier — which is also the default for every tier except Strategic Judgment. Values are validated against this runtime's accepted effort levels — `low`, `medium`, `high`, `xhigh`, `max` ([code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents), [code.claude.com/docs/en/model-config](https://code.claude.com/docs/en/model-config)) — and an unrecognised value is refused, not silently dropped.

## How a per-Work-Unit Execution tier is actually run

`Core/CAPABILITY_TIERS.md`'s **Tier Override** lets the Main Agent run a specific Work Unit at a different Execution tier than its Employee's Default Complexity Tier, in either direction. `generate-agents.sh` generates one static file per Employee with one model (and, for Strategic Judgment, one effort) baked into its frontmatter at generation time — it does not, and will not, emit a second `--lightweight` or `--frontier` variant per Employee. The override is carried instead by this runtime's own per-dispatch mechanism: the Main Agent's dispatch call (the `Agent` tool's `model` parameter, in the runtime this framework was written against) names an override model for that one invocation, which supersedes the generated file's pinned `model:` for that dispatch only — the generated file itself, and every other Employee's file, is untouched. Effort has no equivalent per-dispatch parameter today: a dispatch-time effort override is not something this runtime exposes, so an overridden dispatch runs at whatever effort the generated agent file already declares (inherited, or `high` for a Strategic Judgment Employee) regardless of which model tier the dispatch itself was overridden to. A runtime that later exposes a per-dispatch effort parameter closes that gap here, not in Core.

**The override model comes from the project's tier map, never from the Main Agent.** The project's mapping (`.ia-engineering/tier-map`, or the target's defaults when it has none — `--print-tier-map` above says which) is the only source of the concrete model a tier runs on. A Tier Override therefore resolves in this order:

1. Look up the target tier in the map in force (printed by `session-start.sh` as "Tier map in force").
2. If that model is the one the Employee's generated agent already pins — its default tier maps to the same value — dispatch **with no model parameter**: the override changes nothing to pass. A project mapping every tier to one model is entirely this case.
3. Otherwise pass **exactly** that value as the dispatch's model.
4. If the dispatch cannot take that value — the runtime's per-dispatch `model` parameter accepts only some aliases, and the map names a full model ID or an alias outside them — stop and ask the Director. Do not substitute the nearest alias: an alias resolves differently per provider (next section), so a substitute is a model nobody chose.

Measured, issue #212: in an adopting project whose map gave every tier `claude-opus-5-5`, a Main Agent applying a correct Lightweight Tier Override dispatched with `model: "sonnet"` — neither the project's Lightweight value nor the target's default — because nothing it read during the session named the Lightweight model. The map now reaches the session through `session-start.sh`; this rule makes the choice a lookup instead of a guess.

## Provider aliasing is not this mapping

`--map`'s values (`opus`, `sonnet`, `haiku`, `fable`) are Claude API model aliases. They are convenience pointers, and the snapshot they resolve to is **not the same across every provider that serves Claude, and not the same for every alias on a given provider**: `sonnet` currently resolves to an *older* dated snapshot than the Claude API on every non-Anthropic-API platform (Sonnet 4.5 on Amazon Bedrock and Google Cloud's Agent Platform, Sonnet 4.5 on Microsoft Foundry, Sonnet 4.6 on Claude Platform on AWS — against Sonnet 5 on the Claude API); `opus` resolves to the *same* Opus 5.5 as the Claude API on Amazon Bedrock and Google Cloud's Agent Platform, and is older only on Microsoft Foundry (Opus 4.6) — and the gap changes as new models ship ([code.claude.com/docs/en/model-config](https://code.claude.com/docs/en/model-config)). A project that needs a specific snapshot on a platform where the alias resolves older pins it with that platform's `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` / `ANTHROPIC_DEFAULT_HAIKU_MODEL` / `ANTHROPIC_DEFAULT_FABLE_MODEL` environment variable, set to that platform's own model ID — this is a runtime/provider configuration concern, out of scope for `--map`, which only ever writes the alias string into a generated agent's `model:` field and leaves resolving that alias to the runtime.

---

# Runtime Hooks — Refusing Before, Not Rejecting After

`generate-agents.sh` makes the Employees exist in the runtime. `claude-code/hooks/` makes the framework's rules bind **at the point the runtime acts**, which is earlier than any git hook or CI check can reach:

| Hook | Refuses | Rule |
|---|---|---|
| `session-start.sh` | Nothing — prints the read-first order, the current `SESSION_STATE.md`, and the tier map in force (`generate-agents.sh --print-tier-map`) into context | `Core/AGENT_CONDUCT.md`, Read First; `Core/CAPABILITY_TIERS.md`, Tier Override |
| `block-escape-hatches.sh` | A shell command using `--no-verify`, `--no-gpg-sign`, `stash`, interactive git, force/mirror push, protected-branch deletion, `reset --hard`, `clean -f`, `checkout -- .`, `branch -D`, history rewrite, `rm -rf .git` | `Standards/GIT_STANDARD.md`, Escape Hatches |
| `block-inline-suppression.sh` | An edit writing a lint/type/test disable directive, a skipped or focused test, or a swallowed exception into code (documentation exempt, by name) | `Standards/CODE_QUALITY_STANDARD.md`, No Inline Suppression |
| `post-edit-lint.sh` | Nothing — runs `bash -n`/`shellcheck` and the project's `.ia-engineering/lint.sh` on the file just written, returns failures to the model, says when nothing ran | `Standards/CODE_QUALITY_STANDARD.md`, Automated Quality |
| `stop-gate.sh` | Ending the session with tracked changes uncommitted and unexplained — once, then the loop guard yields | `Core/AGENT_CONDUCT.md`, Reporting Contract |

Installed by `claude-code/install-hooks.sh` into the project's committed `.claude/settings.json`, so every clone runs them without a per-clone step. The guard hooks (`block-escape-hatches`, `block-inline-suppression`) fail closed on unreadable input, and no hook has a disabling switch; `claude-code/hooks/README.md` is the reference. They are the executable form of Standards that exist first as documents — a rule that lived only in a hook would be a rule the framework does not have.

# Independent Review Bot

`claude-code/review-bot.yml` runs `Workflows/CODE_REVIEW.md` as the Code Reviewer Employee inside GitHub Actions, under the Actions identity — a second account, which is what the `Review Recorded` check never had. Setting the repository variable `IAENG_REVIEW_BOT_LOGIN` to that identity switches `Review Recorded` into **independent mode**, where only that login's `Decision:` block counts. Not installed by `install.sh` (it needs an API key and a Director decision to spend it); not a required check by default; documented in the file's header.

Its `claude_args` pins `--model claude-opus-5-5 --effort high --max-turns 40` — deliberately, not generated from the `--map`/`--effort-map` mechanism above. This file is a fixed, non-generated consumer of a model and an effort level, listed `sensitive` / `payments_and_spend` in `.ia-engineering/risk-map.yml` because it makes billed model calls: an independent review gate must not change what it runs on silently, so a bump to the pinned model or effort is itself a reviewed change, not a side effect of regenerating agents. Re-check `platform.claude.com/docs/en/about-claude/model-deprecations` before bumping — a pinned model ID can retire out from under an unreviewed pin.

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
