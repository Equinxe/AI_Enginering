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
2. `.ia-engineering/SESSION_STATE.md` — where things actually stand. Read **before any other action**, not only when in doubt. If it does not exist, create it from this template before doing anything else.
3. Only then, the task.

## Cadence

Updated **at least at mid-day and at end of day**, and always at session end. A session that resumes a project must be able to read yesterday's state without asking for it again. `CLAUDE.md` is touched in the same pass **only if the stable contract changed** — a principle, an architectural decision, an open question resolved. Progress never goes into `CLAUDE.md`.

Dates are absolute ("5 August 2026"), never relative ("yesterday", "today"). A relative date is wrong the moment it is read.

---

# Template

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

**Provenance.** The three-memory model and the never-committed rule are adapted from a sibling governance kit, where the rule was adopted after noticing that every project already gitignored this file without any text requiring it — the practitioners had reached the conclusion before the standard did.

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Template — Orchestration

Severity: Mandatory
