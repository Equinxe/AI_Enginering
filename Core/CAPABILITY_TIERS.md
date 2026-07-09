# Capability Tiers

This document defines how the Main Agent selects an appropriate AI execution capability for a Work Unit, independent of any specific AI provider or model.

IA Engineering is AI-agnostic (`AI_MANIFEST.md`, Principle X). This document never names a specific model. It defines two abstract tiers, based on the nature of the task, that any AI runtime can map to its own available capability levels.

---

# Purpose

Not every Work Unit requires the same depth of reasoning. Assigning maximum capability to a mechanical task wastes budget and time. Assigning minimal capability to an ambiguous, high-stakes decision produces shallow, unreliable output.

Capability Tiers give the Main Agent a consistent, principled way to match execution capability to task complexity — without hardcoding a model name anywhere in the framework.

---

# The Two Tiers

## Strategic Judgment

Work that involves ambiguous tradeoffs, cross-cutting decisions, risk assessment, or problems without a clear precedent to follow. Getting it wrong is expensive or hard to reverse.

Characteristic signals:

- Multiple valid options exist and choosing between them requires weighing consequences, not just facts.
- The decision affects more than one component, team, or Employee.
- Security, compliance, legal, or financial risk is directly in scope.
- There is no existing pattern, contract, or precedent in the project to follow — one must be created.

Employees whose Mission is centered on this kind of work default to this tier: architectural design, security and compliance assessment, authorized offensive security testing, requirements arbitration, engineering leadership and technical direction, AI/prompt design under uncertainty, and analytical work that requires forming and testing hypotheses under ambiguity.

## Standard Execution

Work that is well-scoped: implementing against an existing contract, following an established pattern, testing against defined acceptance criteria, or reviewing for adherence to Standards.

Characteristic signals:

- A contract, specification, ADR, or existing pattern already defines what "correct" looks like.
- The task is bounded to one component or one Employee's ordinary responsibility.
- Getting it wrong is caught by review or tests before it causes lasting damage.

Most Employees — implementation, testing, review, documentation, infrastructure operation within established platforms, and design within an existing system — default to this tier.

---

# Default Tier Assignment

Every Employee definition (`Employees/`) declares a **Default Complexity Tier** in its Metadata section. This is a starting point, not a constraint on any individual Work Unit.

| Tier | Employees |
|---|---|
| Strategic Judgment | Software Architect, Solution Architect, Data Architect, Security Engineer, Compliance Engineer, Penetration Tester, Business Analyst, Data Scientist, AI Engineer, Prompt Engineer, Engineering Manager, Technical Lead |
| Standard Execution | All other Employees |

---

# Lightweight Override

The Default Complexity Tier belongs to the Employee, not to the Work Unit. A specific Work Unit may deviate from its Employee's default in either direction:

- A Strategic Judgment Employee can have a genuinely mechanical Work Unit (e.g., a Software Architect updating a diagram to match an already-Accepted ADR). The Main Agent may apply a **Lightweight Override** and dispatch it at Standard Execution capability.
- A Standard Execution Employee can encounter a Work Unit with real ambiguity (e.g., a Backend Engineer facing a genuinely underspecified edge case with no existing pattern to follow). The Main Agent must not force Standard capability onto a task that actually needs Strategic Judgment — escalate the ambiguity per `Core/DECISION_TREE.md` instead of guessing at a lower capability.

**The override always requires a reason, and it never changes the Employee dispatched, its Mission, Authority, Standards Applied, or Definition of Done — it changes only the execution capability applied to that one Work Unit.** Dispatch Discipline (`Core/MAIN_AGENT_CONDUCT.md`) still applies in full.

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Core/AI_MANIFEST.md` | Principle X (AI Agnostic) — this document defines tiers, never models |
| `Core/ORCHESTRATION.md` | Step 4 (Dispatch) — the Main Agent selects capability per this document before creating the Employee Brief |
| `Core/MAIN_AGENT_CONDUCT.md` | Dispatch Discipline still governs naming and briefing regardless of capability tier chosen |
| `Employees/` | Each Employee's Metadata declares its Default Complexity Tier |

---

# Metadata

Owner: IA Engineering

Version: 0.0.8

Status: Draft

Category: Core — Orchestration

Severity: Mandatory
