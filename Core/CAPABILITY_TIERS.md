# Capability Tiers

This document defines how the Main Agent selects an appropriate AI execution capability for a Work Unit, independent of any specific AI provider or model.

IA Engineering is AI-agnostic (`AI_MANIFEST.md`, Principle X). This document never names a specific model. It defines two abstract default execution tiers — Standard Execution and Strategic Judgment — based on the nature of the task, plus a per-Work-Unit Lightweight Override mechanism that reaches a third, override-only capability level (Lightweight Execution). Any AI runtime can map these to its own available capability levels.

A project's own `CLAUDE.md` may map these tiers to concrete models for its chosen AI runtime (e.g., "Lightweight Execution → Haiku, Standard Execution → Sonnet, Strategic Judgment → Opus" for a Claude-based project). That mapping is project context, not part of this framework document — it changes per runtime and per project; the tiers themselves do not.

---

# Purpose

Not every Work Unit requires the same depth of reasoning. Assigning maximum capability to a mechanical task wastes budget and time. Assigning minimal capability to an ambiguous, high-stakes decision produces shallow, unreliable output.

Capability Tiers give the Main Agent a consistent, principled way to match execution capability to task complexity — without hardcoding a model name anywhere in the framework.

---

# The Tiers

IA Engineering defines **two default execution tiers** — **Standard Execution** and **Strategic Judgment** — plus a third capability level, **Lightweight Execution**, that is never a default tier. Every Employee is normally assigned one of the two default tiers; Lightweight Execution is reached only through an explicit, per-Work-Unit **Lightweight Override** (see below). It is described first here because the override mechanism references it, but no Employee is ever assigned it by default.

## Lightweight Execution

Work that is mechanical, deterministic, or bounded to a single well-defined check. There is exactly one correct answer, and producing it does not require weighing tradeoffs.

Characteristic signals:

- The task is a lookup, a format conversion, a status check, or verifying a fact against a single authoritative source.
- Success criteria are binary and explicit (matches / does not match, passes / fails a stated rule).
- No two competent Employees would reasonably disagree on the outcome.

Examples: a quick web lookup to confirm a current pricing figure, running a validation script and reporting pass/fail, formatting a report from already-decided content, confirming a dependency version.

No Employee defaults to this tier — it is reached only through a Lightweight Override (see below), because even an Employee whose ordinary work is simple (e.g., Technical Writer) still requires real judgment most of the time (audience, clarity, accuracy).

## Standard Execution

Work that is well-scoped: implementing against an existing contract, following an established pattern, testing against defined acceptance criteria, or reviewing for adherence to Standards.

Characteristic signals:

- A contract, specification, ADR, or existing pattern already defines what "correct" looks like.
- The task is bounded to one component or one Employee's ordinary responsibility.
- Getting it wrong is caught by review or tests before it causes lasting damage.

Most Employees — implementation, testing, review, documentation, infrastructure operation within established platforms, and design within an existing system — default to this tier.

## Strategic Judgment

Work that involves ambiguous tradeoffs, cross-cutting decisions, risk assessment, or problems without a clear precedent to follow. Getting it wrong is expensive or hard to reverse.

Characteristic signals:

- Multiple valid options exist and choosing between them requires weighing consequences, not just facts.
- The decision affects more than one component, team, or Employee.
- Security, compliance, legal, or financial risk is directly in scope.
- There is no existing pattern, contract, or precedent in the project to follow — one must be created.

Employees whose Mission is centered on this kind of work default to this tier: architectural design, security and compliance assessment, authorized offensive security testing, requirements arbitration, engineering leadership and technical direction, AI/prompt design under uncertainty, and analytical work that requires forming and testing hypotheses under ambiguity.

---

# Default Tier Assignment

Every Employee definition (`Employees/`) declares a **Default Complexity Tier** in its Metadata section: either Strategic Judgment or Standard Execution. This is a starting point, not a constraint on any individual Work Unit. No Employee defaults to Lightweight Execution — it is a per-Work-Unit designation only (see Lightweight Override).

| Tier | Employees |
|---|---|
| Strategic Judgment | Software Architect, Solution Architect, Data Architect, Security Engineer, Compliance Engineer, Penetration Tester, Business Analyst, Data Scientist, AI Engineer, Prompt Engineer, Engineering Manager, Technical Lead |
| Standard Execution | All other Employees |

---

# Lightweight Override

The Default Complexity Tier belongs to the Employee, not to the Work Unit. A specific Work Unit may run at a different tier than its Employee's default, in either direction:

- **Downgrade.** Any Employee, regardless of default tier, can have a genuinely mechanical Work Unit that meets the Lightweight Execution criteria above (e.g., a DevOps Engineer confirming a current hosting-provider price before signup; a Database Engineer re-running a validation script after a one-line fix; a Software Architect updating a diagram to match an already-Accepted ADR). The Main Agent may apply a **Lightweight Override** and dispatch it at Lightweight Execution capability.
- **Upgrade.** A Standard Execution Employee can encounter a Work Unit with real ambiguity (e.g., a Backend Engineer facing a genuinely underspecified edge case with no existing pattern to follow). The Main Agent must not force Standard capability onto a task that actually needs Strategic Judgment — escalate the ambiguity per `Core/DECISION_TREE.md` instead of guessing at a lower capability.

**The override always requires a reason, and it never changes the Employee dispatched, its Mission, Authority, Standards Applied, or Definition of Done — it changes only the execution capability applied to that one Work Unit.** Dispatch Discipline (`Core/MAIN_AGENT_CONDUCT.md`) still applies in full: the dispatch is still named and briefed as the responsible Employee, never as a generic "quick task" label.

**Downgrading to Lightweight is the tool for reducing turnaround time and cost on genuinely mechanical sub-tasks** — verification checklists, status reports, format-only edits — without lowering capability on the substantive Work Units that actually determine quality (implementation, review, architecture, sign-off).

`Workflows/FEATURE_DEVELOPMENT.md`'s "Trivial / Mechanical Changes (Express Path)" section is a worked example of a whole-Work-Unit downgrade: every participant and gate in that workflow stays, run at this tier.

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Core/AI_MANIFEST.md` | Principle X (AI Agnostic) — this document defines tiers, never models |
| `Core/ORCHESTRATION.md` | Step 4 (Dispatch) — the Main Agent selects capability per this document before creating the Employee Brief |
| `Core/MAIN_AGENT_CONDUCT.md` | Dispatch Discipline still governs naming and briefing regardless of capability tier chosen |
| `Employees/` | Each Employee's Metadata declares its Default Complexity Tier |
| `Governance/CONTRIBUTING.md` | §1 (Change Tiers) maps these tiers onto how much review a change to the framework repository itself needs |

---

# Metadata

Owner: IA Engineering

Version: 0.0.8

Status: Draft

Category: Core — Orchestration

Severity: Mandatory
