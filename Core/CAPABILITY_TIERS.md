# Capability Tiers

This document defines how the Main Agent selects an appropriate AI execution capability for a Work Unit, independent of any specific AI provider or model.

IA Engineering is AI-agnostic (`AI_MANIFEST.md`, Principle X). This document never names a specific model. It defines two abstract default execution tiers — Standard Execution and Strategic Judgment — based on the nature of the task, plus a per-Work-Unit **Tier Override** mechanism that lets any Work Unit run at a different tier than its Employee's default, in either direction, including reaching a third, override-only capability level (Lightweight Execution) or — upgrading only from Strategic Judgment, and only with Director approval each time — a fourth, override-only capability level (Frontier). Any AI runtime can map these to its own available capability levels.

A project's own AI runtime maps these tiers to concrete models. That mapping is runtime and project context, not part of this framework document — it changes per runtime and per project; the tiers themselves do not. See `Adapters/ai-runtimes/README.md` for where a runtime's tier-to-model mapping lives.

---

# Purpose

Not every Work Unit requires the same depth of reasoning. Assigning maximum capability to a mechanical task wastes budget and time. Assigning minimal capability to an ambiguous, high-stakes decision produces shallow, unreliable output.

Capability Tiers give the Main Agent a consistent, principled way to match execution capability to task complexity — without hardcoding a model name anywhere in the framework.

---

# The Tiers

IA Engineering defines **two default execution tiers** — **Standard Execution** and **Strategic Judgment** — plus two override-only capability levels that are never a default tier: **Lightweight Execution**, reached by downgrading any Work Unit that meets its criteria, and **Frontier**, reached only by upgrading a Work Unit already at Strategic Judgment, and only with Director approval each time. Every Employee is normally assigned one of the two default tiers; the two override-only levels are reached solely through an explicit, per-Work-Unit **Tier Override** (see below). Lightweight Execution is described first here because the override mechanism references it, but no Employee is ever assigned either override-only level by default.

## Lightweight Execution

Work that is mechanical, deterministic, or bounded to a single well-defined check. There is exactly one correct answer, and producing it does not require weighing tradeoffs.

Characteristic signals:

- The task is a lookup, a format conversion, a status check, or verifying a fact against a single authoritative source.
- Success criteria are binary and explicit (matches / does not match, passes / fails a stated rule).
- No two competent Employees would reasonably disagree on the outcome.

Examples: a quick web lookup to confirm a current pricing figure, running a validation script and reporting pass/fail, formatting a report from already-decided content, confirming a dependency version.

No Employee defaults to this tier — it is reached only through a Tier Override (see below), because even an Employee whose ordinary work is simple (e.g., Technical Writer) still requires real judgment most of the time (audience, clarity, accuracy).

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

## Frontier

Work at the far edge of Strategic Judgment: demanding reasoning or long-horizon work where Strategic Judgment has demonstrably fallen short on the Work Unit at hand.

Frontier is never a default and is never dispatched directly — it is reached only as a **Tier Override** upgrade from a Work Unit already at Strategic Judgment (see below), and it requires Director approval each time, recorded with its reason. Cost, not capability, is why an approval does not carry forward: a per-Work-Unit approval keeps the highest-cost capability level a deliberate, visible decision rather than a default anyone can reach for.

---

# Task Signals

The tier descriptions above characterize the nature of work in general terms. In practice, the Main Agent reads the task itself for signals of what tier it needs, independent of which Employee is dispatched:

| Task signal | Tier |
|---|---|
| Read-only search, lookup, status check, re-running a script with a pass/fail result, confirming one fact | Lightweight |
| Mechanical edit with a binary success criterion (a count, a link, a format fix), a registry or changelog entry from already-decided content, a session handoff | Lightweight |
| Commit or merge plumbing, unless it carries a Medium-or-higher RISK (`Tier Override`, Guardrails) | Lightweight |
| Implementation against an existing contract, authored documentation, a test plan, review of a non-sensitive change | Standard |
| Cross-cutting work with no precedent, a tradeoff to weigh, or security/compliance/financial risk in scope | Strategic |

These signals select the tier for the specific Work Unit; they never change which Employee is dispatched — see `Tier Override`, below.

---

# Default Tier Assignment

Every Employee definition (`Employees/`) declares a **Default Complexity Tier** in its Metadata section: either Strategic Judgment or Standard Execution. This is a starting point, not a constraint on any individual Work Unit — the Main Agent sets an **Execution tier per Work Unit** at dispatch, in either direction, per `Tier Override` below. No Employee defaults to Lightweight Execution or Frontier — both are per-Work-Unit designations only.

| Tier | Employees |
|---|---|
| Strategic Judgment | Software Architect, Solution Architect, Data Architect, Security Engineer, Compliance Engineer, Penetration Tester, Business Analyst, Data Scientist, AI Engineer, Prompt Engineer, Engineering Manager, Technical Lead |
| Standard Execution | All other Employees |

---

# Tier Override

The Default Complexity Tier belongs to the Employee, not to the Work Unit. The Main Agent sets an **Execution tier per Work Unit** at dispatch — the Employee's default, unless the specific Work Unit warrants otherwise, in either direction:

- **Downgrade.** Any Employee, regardless of default tier, can have a genuinely mechanical Work Unit that meets the Lightweight Execution criteria above (e.g., a DevOps Engineer confirming a current hosting-provider price before signup; a Database Engineer re-running a validation script after a one-line fix; a Software Architect updating a diagram to match an already-Accepted ADR). The Main Agent applies a **Tier Override** and dispatches it at Lightweight Execution capability.
- **Upgrade.** Any Employee, regardless of default tier, can have a Work Unit with real ambiguity that no existing pattern resolves — including a Standard Execution Employee dispatched at Strategic Judgment for that one Work Unit (e.g., a Backend Engineer facing a genuinely underspecified edge case with no existing pattern to follow, or a Technical Writer resolving a documentation-structure question with a real tradeoff and no precedent). The Main Agent must not force Standard capability onto a task that actually needs Strategic Judgment — escalate the ambiguity per `Core/DECISION_TREE.md` instead of guessing at a lower capability, and apply a **Tier Override** to Strategic Judgment.

**The override always requires a reason, and it never changes the Employee dispatched, its Mission, Authority, Standards Applied, or Definition of Done — it changes only the execution capability applied to that one Work Unit.** Dispatch Discipline (`Core/MAIN_AGENT_CONDUCT.md`) still applies in full: the dispatch is still named and briefed as the responsible Employee, never as a generic "quick task" label.

**Downgrading to Lightweight is the tool for reducing turnaround time and cost on genuinely mechanical sub-tasks** — verification checklists, status reports, format-only edits — without lowering capability on the substantive Work Units that actually determine quality (implementation, review, architecture, sign-off).

`Workflows/FEATURE_DEVELOPMENT.md`'s "Trivial / Mechanical Changes (Express Path)" section is a worked example of a whole-Work-Unit downgrade: every participant and gate in that workflow stays, run at this tier.

## Guardrails

- **Never below Standard** for review of a change in a Sensitive change zone (`.ia-engineering/risk-map.yml`) or for any Work Unit carrying a Medium-or-higher RISK decision (`Standards/RISK_STANDARD.md`).
- **Never below the Employee's default** for a sign-off or gate step — a Director delivery gate, a release approval, or a merge approval to `main`. This does not narrow `Workflows/FEATURE_DEVELOPMENT.md`'s Express Path: the Director decided (23 Sep 2026, "Alléger sans supprimer" — lighten without removing) that its Code Review and QA Validation steps run at Lightweight Execution for a genuinely mechanical Work Unit, except that the guardrail above still applies — a change in a Sensitive zone or carrying a Medium-or-higher RISK gets Standard review regardless.
- **Plumbing that executes an already-recorded gate decision is not itself the gate step** — e.g., running the merge once a Director approval is already recorded may be dispatched at Lightweight Execution; the approval decision itself still runs at the Employee's default or higher.
- **Any change from the default carries a one-line reason** — the same reason the paragraph above already requires, not a second, separate record.
- **A Work Unit that fails its Definition of Done because of a capability shortfall is re-dispatched one tier up, capped at Strategic Judgment**, within the existing return limit (`Core/ORCHESTRATION.md`, the Retry layer). Going beyond Strategic Judgment is a Frontier Override (Director approval each time, see below), never an automatic retry step. A failure caused by missing information or an incomplete brief is not a capability shortfall — it is resolved per `Core/DECISION_TREE.md` (stop and request what is missing), not by raising the tier.

## Frontier Override

Frontier is reached the same way, with one further condition: the upgrade is only ever from a Work Unit whose current Execution tier is already Strategic Judgment, and it requires **Director approval each time** — approval on one Work Unit does not carry forward to the next, however similar, and does not carry forward across a return of the same Work Unit either: a Work Unit returned and re-dispatched needs a fresh approval, even though it is nominally "the same" Work Unit. The Main Agent records the approval and its reason alongside the tier override. Frontier exists for demanding reasoning or long-horizon work where Strategic Judgment has demonstrably fallen short on the Work Unit at hand, not as a default upgrade path for every ambiguous task.

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Core/AI_MANIFEST.md` | Principle X (AI Agnostic) — this document defines tiers, never models |
| `Core/ORCHESTRATION.md` | Step 4 (Dispatch) — the Main Agent selects capability per this document before creating the Employee Brief |
| `Core/MAIN_AGENT_CONDUCT.md` | Dispatch Discipline still governs naming and briefing regardless of capability tier chosen |
| `Employees/` | Each Employee's Metadata declares its Default Complexity Tier |
| `Governance/CONTRIBUTING.md` | §1 (Change Tiers) maps these tiers onto how much review a change to the framework repository itself needs |
| `Templates/EMPLOYEE_BRIEF.md` | Records the Execution tier selected here, and the one-line reason whenever it differs from the Employee's default |
| `Templates/WORK_UNIT_REPORT.md` | Records the tier the Work Unit actually executed at, and the runtime model that ran it |
| `Adapters/ai-runtimes/README.md` | Where a runtime's tier-to-model mapping lives — never here, per `AI_MANIFEST.md` Principle X |

---

# Metadata

Owner: IA Engineering

Version: 0.0.10

Status: Draft

Category: Core — Orchestration

Severity: Mandatory
