# Architecture Decision Workflow

---

# Purpose

This workflow defines the process for making, documenting, and communicating significant architectural decisions through Architecture Decision Records (ADRs).

An architectural decision is any choice that is difficult to reverse, affects multiple components or teams, or has long-term structural implications for the system. These decisions must be documented before implementation begins.

---

# Trigger

- An engineer identifies a decision point that meets the criteria for an ADR.
- The Engineering Manager or Director requests an architectural review.
- A feature or change requires a technology selection, cross-service design choice, or departure from established patterns.

**When an ADR is required:**
- Technology selection (framework, database, messaging system, cloud service)
- Cross-service or cross-team interface design
- Departure from an existing architectural pattern
- Security architecture change
- Data model change affecting multiple services
- Scalability strategy decision

When in doubt: write the ADR. The cost of documentation is lower than the cost of an undocumented decision.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Software Architect | Authors the ADR, facilitates the decision process |
| Director | Final approval for decisions with strategic or business impact |
| Engineering Manager | Ensures the decision is communicated to all affected engineers |
| Solution Architect | Engaged for cross-system integration decisions |
| Security Engineer | Engaged for security architecture decisions |
| Technical Lead | Participates in review, represents engineering team perspective |
| Affected Engineers | Provide technical input during the review phase |

---

# Prerequisites

Before this workflow begins:

- The decision context is understood: what problem is being solved and why a decision is needed now.
- Relevant stakeholders are identified.

---

# Steps

## Step 1 — Identify the decision

**Actor:** Software Architect (or engineer who identifies the need)

1. Define the problem that requires an architectural decision.
2. Confirm the decision meets the ADR threshold (difficult to reverse, cross-cutting, long-term impact).
3. Notify the Engineering Manager that an ADR process is being initiated.

**Output:** Decision scope defined. Engineering Manager notified.

---

## Step 2 — Research options

**Actor:** Software Architect

1. **Search the earlier decisions first.** Before any option is researched, search the project's existing ADRs (`Templates/ADR.md`, Storage Convention) for the same idea: every ADR's **Options Considered**, and every ADR whose status is Rejected, Superseded, or Deprecated. Search for the idea's key terms and their synonyms, not only the exact title.
   - **Found as rejected:** the new ADR cites that ADR and states **what changed** since — a new requirement, new evidence, a constraint that no longer holds, or an option that differs in a way the earlier rejection did not cover. If nothing changed, do not re-propose: stop and report the earlier ADR and its rationale to whoever raised the need.
   - **Not found:** say so in the ADR's Context, with the terms searched, so a reviewer can repeat the search.

   A direction already rejected comes back looking new because no one remembers why it was rejected. The ADR kept the reason; this search reads it.
2. Identify all viable options for addressing the problem. Minimum two options must be evaluated.
3. Research each option against:
   - Technical fit for the problem
   - Alignment with existing architecture
   - Operational complexity
   - Security implications
   - Cost and licensing
   - Team expertise and learning curve
   - Long-term maintainability
4. Consult official documentation for each option — do not rely on secondary sources alone.

**Output:** The earlier-decision search and its result, and the options researched and documented.

---

## Step 3 — Draft the ADR

**Actor:** Software Architect

Write the ADR using the ADR Template:

- **Title** — short, decision-oriented (e.g., "Use PostgreSQL for primary data storage")
- **Status** — Proposed
- **Context** — the problem and why a decision is needed, and the result of the Step 2 search: the earlier ADR and what changed, or the terms searched and "no earlier rejection found"
- **Options considered** — each option with pros and cons. A rejected option keeps its reason here: it is what the next Step 2 search will find
- **Decision** — the chosen option
- **Rationale** — why this option was chosen over the others
- **Consequences** — what becomes easier, harder, or different as a result
- **Standards applied** — which standards govern this decision

**Output:** ADR draft ready for review.

---

## Step 4 — Review

**Actor:** Technical Lead + affected engineers + Security Engineer (if applicable)

1. Distribute the ADR draft to all reviewers.
2. Allow minimum 48 hours for review (72 hours for P1-level architectural decisions).
3. Collect feedback: technical concerns, missing options, risk identification, and an earlier ADR the Step 2 search missed.
4. The Software Architect incorporates feedback or documents disagreements with rationale.

The Technical Lead's review is its Plan Review (`Employees/Management/TECHNICAL_LEAD.md`, Process, Plan Review); its record is part of the feedback the Software Architect answers.

**Output:** ADR reviewed, feedback incorporated.

---

## Step 5 — Director approval

**Actor:** Director

1. Review the ADR.
2. Approve, request changes, or reject with documented rationale.

No ADR is marked as Accepted without Director approval.

**Output:** ADR approved by Director. Status updated to Accepted.

---

## Step 6 — Communicate

**Actor:** Engineering Manager

1. Distribute the accepted ADR to all engineers affected by the decision.
2. Update the architecture documentation index with the new ADR.
3. Ensure all Work Units affected by this decision reference the ADR.

**Output:** ADR distributed and indexed.

---

## Step 7 — Implement

**Actor:** Engineers (via Feature Development Workflow)

Implementation begins only after the ADR is Accepted. Work Units that implement the architectural decision must reference the ADR in their context.

**Output:** Implementation in progress under the Feature Development Workflow.

---

## Step 8 — Supersede or deprecate (when applicable)

**Actor:** Software Architect

When a new decision supersedes an existing ADR:
1. Create a new ADR for the new decision.
2. Update the old ADR status to Superseded, referencing the new ADR.
3. Never delete an ADR — the history of decisions is part of the architecture record.

**Output:** Old ADR marked Superseded. New ADR Accepted.

---

# ADR Status Values

| Status | Meaning |
|---|---|
| Proposed | Draft under review |
| Accepted | Approved by Director, ready for implementation |
| Superseded | Replaced by a newer decision |
| Deprecated | No longer applicable, not replaced |
| Rejected | Reviewed and not adopted, with documented rationale |

---

# Exit Criteria

This workflow is complete when:

- The ADR is in Accepted status with Director approval.
- The ADR is distributed to all affected engineers.
- The ADR is indexed in the architecture documentation.
- Implementation Work Units reference the ADR.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Options involve significant cost or vendor commitment | Director — before the ADR is drafted |
| Security implications are identified | Security Engineer — during Step 2 |
| Decision affects external systems or partners | Solution Architect |
| Reviewers cannot reach consensus | Engineering Manager → Director |

---

# Related Workflows

- Feature Development Workflow
- Release Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.6

Status: Draft

Category: Workflow — Architecture

Severity: Mandatory
