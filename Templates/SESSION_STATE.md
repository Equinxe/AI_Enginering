# Session State Template

---

# Usage

A project worked on across many sessions accumulates three kinds of memory, and they have three different lifetimes. Keeping them separate is what lets a new session resume without re-asking what was already answered, and what keeps sensitive operational detail out of the repository.

| Memory | Holds | Lifetime | Committed? |
|---|---|---|---|
| **`CLAUDE.md`** (project root) | The project's **stable contract**: objective, users, non-negotiable principles with their reasons, architecture, active Employee roster, open questions of substance | Changes only when the contract changes | **Yes** — it is the project's definition, and every session and every Director must see it |
| **`.ia-engineering/SESSION_STATE.md`** (this template) | The project's **dated operational state**: where things stand, the next step, what is blocked and on whom, governance deviations currently in force, the journal of what was done and why | Changes every working session | **Never** — see below |
| **Runtime memory** (the AI runtime's own persistent memory, local to the machine) | **Durable cross-project facts**: the operator's preferences, method lessons, conventions that hold from one project to the next | Survives sessions and projects | No — it is not repository content |

**Anti-duplication.** A fact lives in exactly one of the three. If it is in `CLAUDE.md`, runtime memory keeps at most a pointer ("read `CLAUDE.md` before resuming"), never a copy. A copy diverges, and a wrong note is worse than no note.

## Why `SESSION_STATE.md` is never committed

This file describes what is currently **weak**: a branch protection temporarily relaxed while a reviewer is away, a vulnerability class found but not yet fixed everywhere, a governance rule knowingly deviated from with its restoration condition. That is the most sensitive content a project produces about itself, and it does not belong in the system it describes as fragile. A private repository can leak — through a visibility mistake, a compromised token, a departed collaborator. `Standards/DATA_PROTECTION_STANDARD.md` treats operational state as protected content for this reason.

So: `.ia-engineering/SESSION_STATE.md` is in `.gitignore` from the project's first commit, and the `pre-commit` Adapter refuses it by name — the same treatment as `.env`.

## Reading order on resume

1. `CLAUDE.md` — the contract.
2. `.ia-engineering/SESSION_STATE.md` — where things actually stand. Read **before any other action**, not only when in doubt. If it does not exist, create it from the fenced block under **Template** below before doing anything else.
3. Only then, the task.

## Cadence

Updated **at least at mid-day and at end of day**, and always at session end. A session that resumes a project must be able to read yesterday's state without asking for it again. `CLAUDE.md` is touched in the same pass **only if the stable contract changed** — a principle, an architectural decision, an open question resolved. Progress never goes into `CLAUDE.md`.

Dates are absolute ("5 August 2026"), never relative ("yesterday", "today"). A relative date is wrong the moment it is read.

## Snapshot Discipline

The file's current-state sections are a **snapshot**, not a log. Each update **rewrites** "Where the Project Stands" and "Next Step" to reflect the state as of that update — it does not append a new paragraph under the old one and leave both standing. A reader opening those sections mid-project should see only what is true now, not an accumulating history of what used to be true; the history belongs in the Journal.

The **Journal** is where the history lives, and it is allowed to grow — one line per day, not one line per action. Old entries may stay: nothing requires pruning them (No Size Limit, below). What keeps the file usable on resume is that "Where the Project Stands" and "Next Step" say what is true now, not how short the file is.

The `_Last updated:` header is refreshed — a fresh absolute date — on **every** edit, not only on the days a new Journal line is added. A header that stops moving while the body keeps changing is the specific failure this rule exists to prevent: on this repository the header read "9 September" for fifteen days while the file's content kept changing underneath it, and a new session would have trusted a fifteen-day-old header.

**No Size Limit.** This file has no size limit, by Director decision (22 October 2026): it is the agent's memory of the project and of what was done, and it is the one file allowed to be very long and to keep its history. The snapshot rule above still holds for the current-state sections — "Where the Project Stands" and "Next Step" are rewritten, never appended to — but the file as a whole is not pruned to meet any character count, and no hook warns about its size.

**Enforcement is mechanical where the runtime allows it.** The discipline above is universal — it holds regardless of which AI runtime drives the session. Its enforcement is runtime-specific: the Claude Code adapter's `session-start.sh` and `stop-gate.sh` warn (at session start) or block (at session end) when this file falls behind the repository or when its header was not refreshed — see `Adapters/ai-runtimes/claude-code/hooks/README.md`, SESSION_STATE Freshness. A runtime without an equivalent hook still owes the same discipline; it just holds itself to it without a mechanical check.

---

# Handoff to a New Conversation

Before a session ends, or before its context is about to be compacted or replaced, the Main Agent confirms every item below — this is what `Core/ORCHESTRATION.md`'s Step 7 (Deliver) points to before its closing Stop. A new conversation reads only `CLAUDE.md` and this file (Read First, `Core/AGENT_CONDUCT.md`); anything not true here at handoff time is invisible to it.

1. **The header date is today's absolute date** — not the date of the last Journal entry, the date of this update.
2. **"Where the Project Stands" and "Next Step" are current** — rewritten as of now (Snapshot Discipline, above), not left from an earlier point in the session.
3. **"Blocked On" lists every open Director decision**, and what is being asked for each — not only that something is blocked, but the specific question the Director needs to answer.
4. **Open Pull Requests and in-flight Employee dispatches are named**, and whether their work is committed. A dispatch a new session cannot see is a dispatch it will re-run or lose track of.
5. **The runtime's own persistent memory, if it has one, points to this file rather than duplicating it.** A fact copied into runtime memory and also written here has two places to go stale; the anti-duplication rule (`Usage`, above) applies to the runtime's memory exactly as it applies to `CLAUDE.md`.
6. **The working directory is the right project.** Framework work happens in the framework repository; a product project's work happens in that project's own repository, with its own `.ia-engineering/SESSION_STATE.md` — never one project's work carried out from another's folder. Measured: 24 September 2026, the Director caught a new product project about to be started from the framework repository. This check exists because that mistake is silent until a commit lands in the wrong place.

A handoff that skips any item is not a handoff — it is a session ending and hoping the next one figures it out.

---

# Template

**Copy only the contents of the fenced block below** into `.ia-engineering/SESSION_STATE.md`, from the `<!--` line to the last line before the closing fence. Never copy this whole file. The sections above explain how to keep the state file and are not part of it. A whole-file copy leaves the session-start hook reading the placeholder `_Last updated:` line inside the fence and reporting "no parsable date". Then replace the placeholders. At minimum, the `_Last updated:` line takes today's absolute date as day, English month name, year (`6 October 2026`), which is the form `session-start.sh` parses.

```markdown
<!--
  .ia-engineering/SESSION_STATE.md — dated operational state.
  NEVER committed. Gitignored and refused by the pre-commit Adapter.
  Read immediately after CLAUDE.md on every resume. Absolute dates only.
-->

# SESSION STATE — [project name]

_Last updated: [DD Month YYYY, morning/evening] by [Employee or person]_

## Where the Project Stands

[Three to five lines. The most recent milestone reached, the current working
branch, what runs and what does not yet.]

## Next Step

[The very next concrete action, so a resume needs no deliberation. Then the
two or three that follow, if they are already clear.]

## Blocked On — and On Whom

[What is waiting for a decision or an external action, and from whom: "PR #12
awaiting Director approval since 3 August", "domain question sent to the
client on 1 August, no answer". Empty if nothing — write "Nothing".]

## Governance Deviations in Force — and How Each Is Restored

[Every framework or project rule currently relaxed, WHY, and the condition
that ends the deviation: "branch protection on develop lowered to 0 required
reviews while the second reviewer is on leave until 20 August — restore the
day they return". This is the section that makes the file unfit to commit.]

## Journal — What Was Done, Why, How

[Most recent first. One entry per decision or body of work. Record the WHY,
not only the what.]

- **[DD Month YYYY]** — [what] · _why:_ [...] · _how:_ [...] · _Work Units:_ [WU-IDs]

## Errors and Traps Met on This Project

[Dead ends, expensive bugs, wrong assumptions already paid for once — so they
are not paid for twice. "The write API returns False on success", "do not
restart service X without clearing cache Y".]

## What Holds — What Is Fragile

- ✅ [solid; can be relied on]
- ⚠️ [fragile; watch or consolidate]

## Open Questions

[Undecided. Ask the Director again — do not assume a direction.]
```

---

# Field Reference

| Section | Purpose | Common mistakes |
|---|---|---|
| Where the Project Stands | Orientation in under a minute | A history instead of a state; progress that belongs in the Journal |
| Next Step | Resume without deliberating | Vague ("continue the feature"); a list of everything left |
| Blocked On | Makes waiting visible and attributable | Omitting who; leaving a stale block after it cleared |
| Deviations in Force | The reason the file is not committed | Recording a deviation without its restoration condition |
| Journal | The why survives the session | Only the what; relative dates |
| Errors and Traps | Pay once | Recording symptoms without the cause that was found |

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Workflows/ONBOARDING.md` | Step 1 creates this file alongside `CLAUDE.md`; Step 7 confirms both exist. |
| `Workflows/PROJECT_BOOTSTRAP.md` | The `.gitignore` written in Step 3 excludes it from the first commit. |
| `Standards/DATA_PROTECTION_STANDARD.md` | Classifies operational state as protected content; the `pre-commit` Adapter refuses this file by name. |
| `Core/MAIN_AGENT_CONDUCT.md` | Durable Tracking of Findings: a finding recorded here and nowhere else is not durable — file it as an Issue too. |
| `Core/ORCHESTRATION.md` | Step 7 (Deliver) points here, before its closing Stop, for the Handoff to a New Conversation checklist above. |
| `Adapters/ai-runtimes/claude-code/hooks/README.md` | SESSION_STATE Freshness documents this runtime's mechanical enforcement of the Snapshot Discipline above — universal rule, runtime-specific check. |

**Provenance.** The three-memory model and the never-committed rule are adapted from a sibling governance kit, where the rule was adopted after noticing that every project already gitignored this file without any text requiring it — the practitioners had reached the conclusion before the standard did.

---

# Metadata

Owner: IA Engineering

Version: 0.0.14

Status: Draft

Category: Template — Orchestration

Severity: Mandatory
