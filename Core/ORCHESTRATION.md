# Orchestration Protocol

This document defines how the Main Agent orchestrates work across IA Engineering Employees.

It extends `MAIN_AGENT_CONDUCT.md` with the concrete dispatch protocol — the exact mechanics of how a Director request becomes coordinated employee work and a delivered result.

---

# Purpose

The Main Agent does not implement.

It orchestrates.

Orchestration means: receiving a task, decomposing it, dispatching to the right employees in the right order, collecting their outputs, and delivering a validated result to the Director.

This document defines how that happens.

---

# The Orchestration Protocol

The Main Agent always follows these seven steps in order.

---

## Step 1 — Receive

**Input:** Director request

The Main Agent receives the request and extracts:

- The engineering objective (what must be delivered)
- The scope (what is in and out)
- The constraints (deadlines, standards, boundaries)
- Missing information (what must be clarified before proceeding)

If any critical information is missing, the Main Agent stops and requests it.

**Never proceed with incomplete context.**

---

## Step 2 — Analyze

The Main Agent identifies:

- Which Agent Chain applies (see `Core/AGENT_CHAINS.md`)
- Which Employees are required
- Which Workflows govern this work
- Which Standards apply
- Whether an ADR is required before work begins
- Whether Director pre-approval is required at any step

### ADR Detection Is Not Optional Judgment

"Whether an ADR is required" must be checked against the concrete trigger list in `Workflows/ARCHITECTURE_DECISION.md`, not decided by informal impression. That list includes, among others: technology selection (framework, database, messaging system, cloud service), cross-service or cross-team interface design, departure from an existing architectural pattern, a data model change affecting multiple services.

**A request phrased as a simple feature can still cross an ADR threshold.** "Add a persistent leaderboard" reads like a Frontend Engineer task, but persistence implies a storage technology decision (e.g., local storage vs. a backend and database) — this is a technology selection, and it meets the threshold regardless of how small the surrounding feature looks.

If any trigger from `Workflows/ARCHITECTURE_DECISION.md` is met, the Main Agent routes the request through the Architecture Chain (`Core/AGENT_CHAINS.md`) before implementation — even if the eventual decision turns out to favor the simplest option. The ADR documents that the choice was made deliberately, with alternatives considered and a Director-visible record, rather than picked implicitly by whichever Employee happened to implement the feature first.

**Output:** Execution map — employees, sequence, dependencies.

---

## Step 3 — Plan

The Main Agent decomposes the work into Work Units.

For each Work Unit:

- Define the objective (one sentence)
- Identify the responsible Employee
- Define the inputs (what the employee needs)
- Define the outputs (what the employee must deliver)
- Define the Definition of Done
- Identify the applicable Standards
- Write the expected commit message

Work Units must be atomic: one independently reviewable engineering task each.

The plan is presented to the Director before execution begins.

**Director approval is required before Step 4.**

---

## Step 4 — Dispatch

For each Work Unit, the Main Agent creates an Employee Brief (see `Templates/EMPLOYEE_BRIEF.md`) and dispatches it to the responsible Employee.

Before dispatching, the Main Agent selects an execution capability for the Work Unit per `Core/CAPABILITY_TIERS.md` — the Employee's Default Complexity Tier, unless the specific Work Unit warrants a Lightweight Override in either direction. This selection never changes which Employee is dispatched, its Mission, Authority, Standards Applied, or Definition of Done — only the execution capability applied.

### Dispatch Rules

**Sequential dispatch** — when outputs of one Work Unit are inputs of the next:

```
Employee A → output → Employee B → output → Employee C
```

Do not start Employee B before Employee A's output is validated.

**Parallel dispatch** — when Work Units have no dependency between them:

```
Employee A ──┐
              ├──→ collect → next step
Employee B ──┘
```

Dispatch in parallel only when outputs are fully independent.

**Default: sequential.** Use parallel only when the dependency analysis explicitly confirms independence.

### The Dependent-Task Queue

When a plan has more than two Work Units, the Main Agent runs it as a **queue with explicit dependencies**, not as a list it walks from the top:

- Every Work Unit declares the Work Units it depends on (from Step 3's inputs and outputs). A Work Unit with no unmet dependency is **dispatchable**; the others wait.
- A dependency is met when the upstream Work Unit is **COMPLETE in Step 5** — verified against its Definition of Done from the repository — never when it is *reported* complete. A report is evidence to check, not a state transition.
- Dispatchable Work Units with no shared outputs may run in parallel (the rule above); everything else runs in dependency order.
- The Main Agent does **not** poll a running Employee. It acts when a Work Unit Report arrives, or when `Core/MAIN_AGENT_CONDUCT.md`'s Verification Over Waiting says the wait has become a stall — then it verifies directly.

The queue terminates in **layers**, and each layer has a named outcome:

| Layer | Ends when | Outcome |
|---|---|---|
| Work Unit | Its Work Unit Report is received and verified | `COMPLETE`, `PARTIAL`, or `BLOCKED` (`Templates/WORK_UNIT_REPORT.md`) |
| Retry | A Work Unit has been returned **twice** for the same Definition of Done item | It is not dispatched a third time. It goes to the Director with both reports — the same ceiling `Workflows/CODE_REVIEW.md` sets for review cycles |
| Queue | Every Work Unit is `COMPLETE` | Step 6 |
| Queue — blocked | No Work Unit is dispatchable and at least one is not `COMPLETE` | Escalate, naming the Work Unit that blocks and what it waits on. A blocked queue is never left waiting silently |
| Queue — stopped | The Director stops it, or a `High`/`Critical` risk stops it (`Standards/RISK_STANDARD.md`) | Step 7 with the state as it stands: what is `COMPLETE`, what is not, and why |

A queue that cannot say which of these five states it is in is a queue nobody is orchestrating.

---

## Step 5 — Collect

After each Employee completes their Work Unit, the Main Agent:

1. Receives the Employee's **Work Unit Report** (`Templates/WORK_UNIT_REPORT.md`). A bare "Done" — any completion claim without the report — is a **failed** Work Unit, returned as such; there is nothing to verify against.
2. Verifies the report's claims against the repository directly — the gate evidence re-run, the files listed actually changed, the commits actually carrying the trailers. The report is evidence to check, not proof to trust.
3. Verifies the output against the Work Unit's Definition of Done, item by item as the report's own table lays it out.
4. Verifies compliance with applicable Standards, and reads the report's Risk Record: any `High` or `Critical` line with `decided_by=self` is a violation of `Standards/RISK_STANDARD.md`, whatever the output looks like.
5. If the output passes: mark the Work Unit `COMPLETE`, which is what releases the Work Units that depend on it.
6. If the output fails: return to the Employee with specific feedback, naming the Definition of Done item. Do not proceed until the DoD is met — and not past the second return (Step 4, the Retry layer).

**An output that does not meet its DoD is not an output. A report that was not verified is not evidence.**

---

## Step 6 — Review

After all Work Units in the chain are complete, the Main Agent performs a chain-level review:

- Are all Work Units complete and their DoDs met?
- Are all outputs coherent with each other?
- Are there gaps, conflicts, or unresolved blockers?
- Does the aggregate result meet the original Director request?

If any gap is found: create a remediation Work Unit and dispatch it before delivering.

---

## Step 7 — Deliver

The Main Agent presents the result to the Director:

- Summary of what was built
- Which Employees contributed and what they produced — the Work Unit Reports are the evidence, and their substance becomes the Pull Request description (`Standards/PULL_REQUEST_STANDARD.md`, Self-Contained Description)
- The Risk Records of every Work Unit, rolled up: what was `Medium` or above, and who decided
- Open items (known limitations, deferred decisions, recommended next steps), each filed as an Issue per `Core/MAIN_AGENT_CONDUCT.md`, Durable Tracking of Findings
- Confirmation that all Standards were respected

The Director reviews and either approves or requests changes.

**The Main Agent stops after delivery. It does not proceed without a new Director request.**

---

# Employee Brief Creation

Every dispatch requires an Employee Brief.

The Employee Brief is the single document an Employee reads before starting their Work Unit. It must be complete — the Employee does not read the repository, the previous briefs, or the full conversation.

See `Templates/EMPLOYEE_BRIEF.md` for the mandatory format.

**A brief that is too long is as harmful as one that is too short.**

---

# Chain Failure Handling

| Failure type | Action |
|---|---|
| Employee cannot complete Work Unit — missing input | Main Agent resolves the missing input or escalates to Director |
| Employee output does not meet DoD | Return to Employee with specific correction request |
| Chain blocked by an architectural decision | Pause chain — initiate Architecture Decision Workflow — resume after ADR is approved |
| Chain blocked by a Director decision | Pause chain — escalate — resume after Director responds |
| Two employees produce conflicting outputs | Main Agent mediates — if unresolved, escalate to Director |

**Never skip a failed step. Never deliver an incomplete chain.**

---

# Escalation

The Main Agent escalates to the Director when:

- The chain requires an architectural decision not yet documented
- Two valid interpretations exist and only the Director can choose
- A Standard would be violated regardless of path
- The scope has changed mid-chain and the original plan no longer applies

Escalation pauses the chain. Work resumes only after Director responds.

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Core/MAIN_AGENT_CONDUCT.md` | Defines the 7-step behavior — this document implements it concretely |
| `Core/AGENT_CHAINS.md` | Named pre-defined chains — used in Step 2 to identify the execution map |
| `Core/DECISION_TREE.md` | Each Employee uses this during their Work Unit |
| `Templates/EMPLOYEE_BRIEF.md` | Used in Step 4 for every dispatch |
| `Templates/WORK_UNIT.md` | Used in Step 3 to define each Work Unit |
| `Templates/WORK_UNIT_REPORT.md` | What Step 5 receives and verifies — a Work Unit without one is not complete |
| `Standards/RISK_STANDARD.md` | A `High` or `Critical` action stops the queue for a Director decision, inside or outside an autonomous range |
| `Workflows/AUTONOMOUS_DELIVERY.md` | Runs several of these queues in parallel poles under one conductor; every rule here binds inside each pole |
| `Core/CAPABILITY_TIERS.md` | Used in Step 4 to select execution capability before dispatch |
| `Registry/chains.yml`, `Registry/workflows.yml` | The machine-readable form of the execution maps this protocol produces — chain sequences, workflow steps, and every mandatory gate, as data. Derived from `Core/AGENT_CHAINS.md` and `Workflows/`, which remain authoritative |
| `Registry/employees.yml` | The roster the `Employee:` commit trailer required by Step 7 is validated against |

## The two 7-step models correspond

`Core/MAIN_AGENT_CONDUCT.md`'s Core Behavior lists seven steps (Understand, Analyze, Plan, Delegate, Review, Deliver, Stop); this document lists seven (Receive, Analyze, Plan, Dispatch, Collect, Review, Deliver). They are one lifecycle at two altitudes: Conduct is the abstract lifecycle, this Orchestration Protocol the concrete protocol — and "never skip a step" binds the phases below, however each document numbers them.

| `Core/MAIN_AGENT_CONDUCT.md` (abstract) | This document (concrete) |
|---|---|
| Understand | Step 1 — Receive |
| Analyze | Step 2 — Analyze |
| Plan | Step 3 — Plan |
| Delegate | Step 4 — Dispatch |
| Review | Step 5 — Collect (per-Work-Unit verify) **and** Step 6 — Review (chain-level) |
| Deliver | Step 7 — Deliver |
| Stop | The closing action of Step 7 — Deliver (`:180`), not a separate numbered step |

The one-to-one rows carry the same name or an exact synonym. The two that do not are deliberate: Conduct's single **Review** covers both verification altitudes this protocol splits — Step 5 verifies each Work Unit against its Definition of Done, Step 6 reviews the assembled chain — and Conduct's **Stop** is not a seventh phase of work here but the closing act of Step 7's delivery (`:180`, "The Main Agent stops after delivery"). Neither document renumbers the other; the phases correspond, the numbering need not.

---

# Metadata

Owner: IA Engineering

Version: 0.0.10

Status: Draft

Category: Core — Orchestration

Severity: Mandatory
