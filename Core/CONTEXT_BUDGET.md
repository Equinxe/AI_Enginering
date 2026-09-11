# Context Budget

---

# Purpose

Every AI runtime works inside a finite context window, and everything this framework asks an agent to read before acting is charged against it. `Core/CAPABILITY_TIERS.md` decides *which* capability a Work Unit needs. This document is about *how much room* the framework itself takes before the Work Unit has begun — and it is the first time that has been measured rather than assumed.

The discipline it asks for is one sentence: **measure in a unit you can count, estimate in the unit you care about, and say which is which.** Every number below is followed by the command that produced it, so a stale figure is one command away from being current rather than one more thing to trust.

---

# What is measured, and what is estimated

The measured unit is **characters**, because `wc -c` is exact and available everywhere. The unit that matters is tokens, and no offline tokenizer ships with this repository — so tokens are an **estimate**, using the common rule of about 4 characters per token for English prose. Markdown tables and code compress differently, so treat every token figure as ±25%.

Writing the conversion down is the point. A sibling framework published a context figure it had never measured, then measured, then corrected three times; the lesson it drew was to do the unit conversion out loud rather than let a reader infer one. This document does.

---

# The framework's own load, measured

Measured on 9 September 2026 at `develop` `c7a4a00`. Re-measure with the commands shown.

## What a Main Agent session reads before acting

`Core/AGENT_CONDUCT.md` (Read First) names `CLAUDE.md`, the Session State, and the Brief. In practice the Main Agent also reads its own conduct and the orchestration protocol, and the session-start hook injects a summary.

```bash
wc -c CLAUDE.md .ia-engineering/SESSION_STATE.md Core/MAIN_AGENT_CONDUCT.md Core/ORCHESTRATION.md
bash Adapters/ai-runtimes/claude-code/hooks/session-start.sh </dev/null | wc -c
```

| Read before any work | Characters | Share |
|---|---|---|
| `Core/MAIN_AGENT_CONDUCT.md` | 34,850 | **61 %** |
| `Core/ORCHESTRATION.md` | 12,315 | 21 % |
| `.ia-engineering/SESSION_STATE.md` | 6,456 | 11 % |
| `CLAUDE.md` | 2,736 | 5 % |
| session-start hook injection | 940 | 2 % |
| **Total** | **57,297** | ≈ **14 k tokens** (estimate) |

A Main Agent session begins roughly fourteen thousand tokens deep, and three fifths of that is one document.

## What one Employee dispatch loads

A dispatched Employee reads its own definition, its Brief, the universal conduct, the three Standards that bind every Employee regardless of its own list (`Core/AGENT_CONDUCT.md`), and the two files every session reads.

```bash
find .claude/agents -name '*.md' -exec wc -c {} + | sort -n     # per-agent, min/median/max
wc -c Templates/EMPLOYEE_BRIEF.md Core/AGENT_CONDUCT.md Standards/STANDARDS_FIRST.md Standards/RISK_STANDARD.md Standards/DATA_PROTECTION_STANDARD.md
```

| Loaded per dispatch | Characters |
|---|---|
| The Employee's generated definition (median of 42; min 7,917, max 10,799) | 9,689 |
| The Brief (template size; a filled brief is comparable) | 6,408 |
| `Core/AGENT_CONDUCT.md` | 6,213 |
| `Standards/RISK_STANDARD.md` | 16,687 |
| `Standards/DATA_PROTECTION_STANDARD.md` | 10,973 |
| `Standards/STANDARDS_FIRST.md` | 1,789 |
| `CLAUDE.md` + `.ia-engineering/SESSION_STATE.md` | 9,192 |
| **Total** | **60,951** ≈ **15 k tokens** (estimate) |

**Every fresh dispatch repays this.** An Employee that is continued keeps it. That single fact decides the rule in the next section.

Of the three binding Standards, `RISK_STANDARD.md` is **57 %** — and it grew by a section the day this was measured. A Standard that binds every Employee is read on every dispatch; its length is a cost paid forty-two ways.

## The whole corpus

```bash
git ls-files '*.md' | xargs wc -c | tail -1
find .claude/agents -name '*.md' -exec wc -c {} + | tail -1
```

| | Characters | Estimate |
|---|---|---|
| All 42 generated agent definitions | 405,434 | ≈ 100 k tokens |
| All tracked markdown | 871,795 | ≈ 220 k tokens |

Nobody loads either whole. They are here because a runtime that *indexes* agent definitions, or a reader who asks "read everything under `Core/`", pays a bill of this size — and should know it before asking.

---

# Cost is not occupation

Prompt caching changes what a block **costs**. It does not change what a block **occupies**. A cached 15,000-token dispatch preamble is cheaper to send and takes exactly as much of the window as an uncached one. Decisions about *what to load* are about occupation; decisions about *how often to reload* are about cost. Do not let a low bill persuade you the window is empty.

---

# The rules that follow

1. **Re-brief before you re-dispatch.** A continued Employee has its context; a fresh one repays ≈15 k tokens before reading your message. If the previous Employee can take a follow-up, send one.

2. **Findings first, and state a length budget in the Brief.** A dispatched Employee's reply is cut at a fixed length in transit — observed, and recorded in `Governance/DISPATCH_IN_PRACTICE.md`. A three-part report loses its third part, which is where the findings were.

3. **Do not read what you will not use.** "Read everything under `Core/`" is 114,432 characters, ≈28 k tokens (`wc -c Core/*.md`). Read First names four things; the others are read when a Work Unit needs them.

   That figure was first written here as "≈40 k" from memory, in the document whose opening rule is to measure. The command caught it before the commit did. Every number in this file now carries the command that produced it for exactly that reason.

4. **A Standard that binds everyone is read by everyone.** Before adding to `RISK_STANDARD.md`, `DATA_PROTECTION_STANDARD.md` or `STANDARDS_FIRST.md`, ask whether the addition must bind every Employee or belongs in the document of the one it concerns. The three together are ≈7 k tokens per dispatch today.

5. **Measure before restructuring.** The largest single lever in the numbers above is `Core/MAIN_AGENT_CONDUCT.md` at 61 % of session start. Whether to split its rarely-read sections is a Director decision, not a conclusion of this document — but it is the number that decision should start from.

---

# Not measured here — borrowed, and labelled

A sibling framework measured, on its own sessions, that **tool output** filled about a third of the context; that **images** are charged in tokens rather than characters, at a rate it had to correct after quoting an unmeasured constant; and that a single oversized skill file was its largest payload at roughly 165 k tokens. Those are *its* measurements on *its* corpus. **None has been reproduced here**, and this document does not claim them. They are listed so the next person knows where to look, and knows the figures are someone else's.

---

# Relationship to Other Documents

- `Core/CAPABILITY_TIERS.md` — which capability a Work Unit needs. This document is what that capability has already spent on arrival.
- `Core/AGENT_CONDUCT.md`, Read First — the list this document costs out.
- `Governance/DISPATCH_IN_PRACTICE.md` — the observed truncation of dispatched replies that rule 2 answers.
- `Templates/EMPLOYEE_BRIEF.md` — where the length budget of rule 2 is stated.

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

Status: Draft

Category: Core — Operating Constraint

Severity: Advisory
