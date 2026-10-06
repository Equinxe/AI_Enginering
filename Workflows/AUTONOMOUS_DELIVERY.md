# Autonomous Delivery Workflow

---

# Purpose

This workflow defines how a Director mandate larger than one orchestration queue is delivered by **several Main Agent sessions working in parallel** — poles — under one **conductor**, without any framework rule becoming weaker for having more sessions running.

`Core/ORCHESTRATION.md` governs one Main Agent running one dependent-task queue. Some mandates are wider than that: a milestone of twelve Work Units across three independent modules, a migration touching every service, a documentation corpus to bring up to a new Standard. Running them in one queue is slow; running them in several uncoordinated sessions produces the failure this workflow exists to prevent — the merge nobody owns, the conflict resolved by hand, the pole that quietly took a `Critical` decision because the Director was talking to a different session.

The rule that makes federation safe is simple to state and is the whole of this document: **every control that binds one Main Agent binds each pole, unchanged; every escalation that would reach the Director from one Main Agent reaches the Director through the conductor; nothing is delivered until an integration pass has run on the merged result.** Federation changes the pacing. It never changes a tier, a gate, or a Standard.

---

# Trigger

- The Director mandates a body of work that decomposes into **two or more independent Work Unit queues**, each with disjoint write scope (paths, modules, documents), and accepts the bounded budget in Step 1.

This workflow is **not** triggered by size alone. A large body of work whose Work Units share write scope is one queue, run by `Core/ORCHESTRATION.md`; splitting it across poles would create the merge conflicts the integration pass exists to catch, on purpose.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Director | Issues the mandate with its budget and stop conditions (Step 1); receives every `High`/`Critical` escalation; accepts or rejects the consolidated delivery (Step 6) |
| Conductor | A Main Agent session that does not implement and does not run a queue of its own. It decomposes, briefs poles, receives their reports and escalations, runs the integration pass, and reports to the Director |
| Pole | A Main Agent session running `Core/ORCHESTRATION.md` end to end on one Pole Brief, on its own branch, dispatching Employees exactly as any Main Agent does |
| Engineering Manager | Defines the mandate's Work Units before this workflow begins (Prerequisites) — the one case where decomposition is dispatched rather than done by the Main Agent (`Core/AGENT_CHAINS.md`, Work Unit Decomposition) |
| Employees | Dispatched by poles, per `Core/EMPLOYEE_SELECTION.md`; unchanged in every respect |
| Code Reviewer, QA Engineer | Review and validate the integrated result in Step 5, per `Workflows/CODE_REVIEW.md` — not each pole's branch in isolation |

The conductor and each pole are the **same kind of thing** — a Main Agent bound by `Core/MAIN_AGENT_CONDUCT.md` — with different briefs. There is no new role and no new authority.

---

# Prerequisites

Before this workflow begins:

- The mandate's Work Units are defined (`Templates/WORK_UNIT.md`) and registered — by the Engineering Manager, whom the Main Agent dispatches for this decomposition because the work is multi-pole (`Core/AGENT_CHAINS.md`, Work Unit Decomposition).
- The Work Units partition into groups with **disjoint write scope**. If two groups must write the same file, they are one group.
- The repository's controls are installed and required: hooks via `Adapters/scripts/install.sh`, the blocking checks via `Adapters/scripts/setup-branch-protection.sh`. A federation on an unprotected repository multiplies the ways to bypass a control that does not exist.
- `.ia-engineering/SESSION_STATE.md` exists and is current — poles resume from it.

---

# Steps

## Step 1 — Director mandate

**Actor:** Director → Conductor

The Director states, and the conductor records verbatim in the conductor's Session State:

1. **Scope** — the Work Units in the mandate, by ID.
2. **Budget** — three bounds, all mandatory: maximum number of poles (default **3**), maximum Work Units per pole, and a wall-clock or session bound after which every pole stops and reports whatever state it is in. An unbounded federation is an unattended one.
3. **Stop conditions** — beyond the budget: the events that end the run early (a `Critical` escalation from any pole, a failed integration pass, a named external dependency going away).
4. **Delivery form** — one Pull Request per pole, or one integrated Pull Request; and whether the Director wants to be interrupted for `High` escalations or only for `Critical` (`Standards/RISK_STANDARD.md`). The default is **both** interrupt.

**Director approval of this mandate is required before Step 2.** A conductor that starts poles on an inferred mandate has done what `Core/ORCHESTRATION.md` Step 1 forbids, at scale.

**Output:** Recorded mandate with scope, budget, stop conditions, delivery form.

---

## Step 2 — Decompose into poles

**Actor:** Conductor

1. Partition the Work Units into pole groups by **write scope**: the paths, modules, and documents each group changes. Groups must be disjoint. Where a Work Unit reads another group's output, that is a dependency between poles, and it is recorded — see 3.
2. Write one **Pole Brief** per group (`Templates/POLE_BRIEF.md`): mandate, owned paths, forbidden paths, branch name, Work Units in order, budget share, integration contract, escalation channel, stop conditions.
3. Order poles by dependency. A pole whose brief depends on another pole's output **does not start** until that pole's report is `COMPLETE` and verified by the conductor — the same rule `Core/ORCHESTRATION.md` Step 4's queue applies to Work Units. Prefer partitions with no inter-pole dependency; a partition that needs three levels of ordering is one queue pretending to be several.
4. Create each pole's branch from the same base commit, named per `Standards/BRANCH_STANDARD.md` with the pole identifier.

**Output:** Pole Briefs, one per pole, and the branches they run on. Presented to the Director as the plan (`Core/ORCHESTRATION.md` Step 3) — the mandate approved the *scope*; this approves the *partition*.

---

## Step 3 — Poles execute

**Actor:** Poles (each a Main Agent)

Each pole runs `Core/ORCHESTRATION.md` in full on its brief: Receive, Analyze, Plan, Dispatch, Collect, Review, Deliver — where Deliver means delivering to the **conductor**, not to the Director.

Inside a pole, **every control binds unchanged**:

- Employees are dispatched by name, per `Core/EMPLOYEE_SELECTION.md`; the pole never implements (`Core/MAIN_AGENT_CONDUCT.md`, No Direct Implementation).
- Every commit carries its `Work Unit:` and `Employee:` trailers and passes the `commit-msg` and `pre-commit` hooks. A pole never uses an escape hatch (`Standards/GIT_STANDARD.md`).
- Every Work Unit ends in a Work Unit Report; a bare "Done" fails the Work Unit.
- Every `High` or `Critical` action **stops the pole** and is escalated — Step 4 — before anything else happens in that pole. Autonomy governs pacing, never tier (`Standards/RISK_STANDARD.md`).
- A pole writes only inside its owned paths. A Work Unit that needs to touch a forbidden path is `BLOCKED` and reported, not done anyway.
- A pole's budget is its brief's budget. When it is exhausted the pole stops and reports its state, whether or not its queue is finished.

Each pole maintains its own Session State (`Templates/SESSION_STATE.md`, at a per-pole path the brief names), so that a pole interrupted and resumed picks up where it stopped rather than where it thinks it stopped.

**Output:** Per pole, a pushed branch and a **Pole Report** — a Work Unit Report (`Templates/WORK_UNIT_REPORT.md`) whose scope is the pole's whole brief, with one row per Work Unit.

---

## Step 4 — Centralised escalation

**Actor:** Poles → Conductor → Director

Escalation in a federation has one path, because a Director talking to several sessions at once will be told about the same hazard three times or not at all:

1. A pole meeting a `High` or `Critical` action stops, writes the escalation block from `Standards/RISK_STANDARD.md`, and sends it to the **conductor**. It does not proceed, and it does not escalate to the Director directly.
2. The conductor **stops that pole** (it is already stopped; the conductor records it as stopped), checks whether the hazard touches other poles' scope — a data-purge, a schema change, a shared dependency — and stops those too if it does. Other poles continue.
3. The conductor escalates to the Director with the pole's block plus the federation context: which poles are stopped, which continue, what is at stake in each.
4. The Director's decision returns through the conductor to the pole, quoted verbatim in the pole's Session State and Risk Record. `decided_by=Director` names the Director, never the conductor.

A `Critical` escalation is a **stop condition** for the run unless the Director's decision says otherwise: every pole is stopped and reports its state, because a `Critical` hazard in one pole is evidence about the mandate, not only about that pole.

**Output:** Every `High`/`Critical` decision recorded once, with the Director's words, in the affected poles' Risk Records.

---

## Step 5 — Integration pass

**Actor:** Conductor, then Code Reviewer and QA Engineer

Mandatory. A federation whose poles each pass every check can still produce a merged state no pole ever saw — the same reason `framework-validation.yml` runs on push, not only on Pull Requests.

1. The conductor merges every pole branch, in dependency order, into an **integration branch** created from the same base. Merge commits, never squashes (attribution depends on it — `Standards/COMMIT_STANDARD.md`).
2. **Conflicts are Work Units.** A conflict is dispatched to the Employee who owns the conflicting content, with both sides quoted in the brief; the conductor never resolves a conflict by hand, and never by preferring the later pole.
3. The full gate suite runs on the integrated result: the project's build and tests, `Adapters/scripts/validate-framework.sh` where the framework is in scope, the `Data Policy` scan in `--history` mode over the whole integrated range. A red result is a remediation Work Unit, dispatched before anything else.
4. `Workflows/CODE_REVIEW.md` runs on the integrated branch. Where any pole carried a `High`/`Critical` Risk Record or touched a security-sensitive trigger, the review is **Multi-Lens**.
5. The QA Engineer validates the integrated result against the mandate's acceptance criteria — not each pole's.

**Output:** An integration branch that is green on every gate, reviewed, and validated. Or: a named list of what is not, and why.

---

## Step 6 — Consolidated delivery

**Actor:** Conductor → Director

The conductor delivers, per `Core/ORCHESTRATION.md` Step 7:

- The mandate as recorded in Step 1, and the budget actually consumed against each bound.
- One Pole Report per pole, verified by the conductor — not summarised, attached.
- The integration pass result, with its evidence pasted.
- The Risk Records of the whole run, rolled up, with the Director's decisions quoted.
- What is **not** delivered: Work Units `PARTIAL` or `BLOCKED`, poles stopped by budget, remediation still open — each filed as an Issue.
- The Pull Request(s), in the form the mandate chose, with descriptions that stand alone (`Standards/PULL_REQUEST_STANDARD.md`).

**The Director accepts or rejects. No merge happens without that decision.** The conductor stops after delivery, as any Main Agent does.

**Output:** Director decision recorded. Pull Requests merged by the standard process, or returned.

---

## Step 7 — Close the run

**Actor:** Conductor

1. Every pole's Session State is folded into the project's `.ia-engineering/SESSION_STATE.md`: where things stand, what is open, what was learned. Pole-level state files are deleted; they were working copies.
2. Every incident met during the run — a control that fired, a conflict, an escalation — becomes an entry in the project's troubleshooting catalog, or in `Governance/TROUBLESHOOTING.md` when it generalises (`Governance/CONTRIBUTING.md`, Section 7).
3. Pole branches are deleted **after** the integration branch or their Pull Requests are merged, never before; the integration branch follows `Standards/BRANCH_STANDARD.md` for its own lifecycle.

**Output:** One Session State, one catalog, no orphan branches.

---

# Exit Criteria

This workflow is complete when:

- Every Work Unit in the mandate is `COMPLETE`, or is `PARTIAL`/`BLOCKED` with an Issue and the Director's acknowledgement.
- The integration pass is green and reviewed, or the Director has explicitly accepted the delivery without it (recorded as a `Critical` Risk Record — an unintegrated federation is exactly that).
- Every `High`/`Critical` decision of the run is recorded once with the Director's words.
- Session State is consolidated and the catalog is updated.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Any pole meets a `High` or `Critical` action | Conductor → Director, immediately (Step 4); the pole stops |
| Two poles need to write the same path | Conductor: the partition was wrong. Re-partition (Step 2) or serialise; never let both proceed |
| A pole exhausts its budget with its queue unfinished | Conductor: report to the Director with the pole's state; do not extend the budget on conductor judgment |
| The integration pass is red after one remediation round | Director: the merged state disagrees with what each pole verified — a fact about the partition, not about one pole |
| A pole is unresponsive | Conductor, per `Core/MAIN_AGENT_CONDUCT.md` Verification Over Waiting: verify its branch directly, then treat the pole as stopped |
| The conductor itself is asked to implement, resolve a conflict by hand, or take a `High` decision | It refuses and escalates — it is a Main Agent, and No Direct Implementation binds it |

---

# What This Workflow Does Not Change

Stated because federation is where rules quietly weaken:

- **No new authority.** The conductor approves nothing the Director must approve. A pole decides nothing an Employee could not.
- **No relaxed gate.** Every Workflow gate inside a pole's Work Units — ADR approval, release approval, hotfix authorisation — is still a Director gate, reached through the conductor.
- **No shared identity shortcut.** Each pole's commits are attributed to the Employees the pole dispatched, not to "the pole". A `Employee:` trailer naming a pole is a tool label and is refused.
- **No skipped report.** Three poles produce three Pole Reports and one integration report. Fewer means the run is not finished.

**Provenance.** The conductor/pole structure and the four rules — per-pole controls, centralised escalation, bounded budget, mandatory integration — are adapted from a sibling governance corpus's multi-session orchestration, stripped of the runtime it was built on. `Adapters/ai-runtimes/omc/` records how one such runtime maps onto this workflow; the workflow itself names none.

---

# Related Workflows

- Feature Development Workflow
- Code Review Workflow
- Release Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Workflow — Orchestration

Severity: Mandatory

Depends On: `Core/ORCHESTRATION.md`, `Core/MAIN_AGENT_CONDUCT.md`, `Standards/RISK_STANDARD.md`, `Templates/POLE_BRIEF.md`, `Templates/WORK_UNIT_REPORT.md`, `Templates/SESSION_STATE.md`

Referenced By: `Core/ORCHESTRATION.md`, `Templates/POLE_BRIEF.md`, `Adapters/ai-runtimes/omc/README.md`
