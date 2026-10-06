# Agent Chains

This document defines the named orchestration chains used by the Main Agent.

A chain is a pre-defined sequence of Employees activated for a specific type of engineering task. Chains encode institutional knowledge about who does what, in what order, for each recurring scenario.

The Main Agent selects the appropriate chain in Step 2 of the Orchestration Protocol (`Core/ORCHESTRATION.md`).

---

# Chain Selection

The Main Agent selects a chain based on the Director's request:

| Request type | Chain |
|---|---|
| New feature or user story | Feature Chain |
| Pull Request submitted for review | Review Chain |
| Sprint complete — promote to production | Release Chain |
| Production defect requiring immediate fix | Hotfix Chain |
| Production incident in progress | Incident Chain |
| New system, major change, or architectural question | Architecture Chain |

When no chain matches exactly, the Main Agent composes a custom sequence using the Orchestration Protocol and presents it to the Director for approval before dispatching.

---

# The Engineer Step

Where a chain below writes **Engineer** or **Engineer(s)**, it names a step, not an Employee: the implementing Employee of the Work Unit, chosen by the Main Agent per `Core/EMPLOYEE_SELECTION.md` when it plans that Work Unit (`Core/ORCHESTRATION.md` Step 3), and named in its Employee Brief.

That Employee is most often one of the Development Employees — Backend, Frontend, iOS, Android, Cross-Platform, Database, Event-Driven, or Integration Engineer — but the step is not limited to them. A Work Unit whose deliverable is a CI/CD pipeline is the DevOps Engineer's, a Terraform module the Infrastructure as Code Engineer's, a guide or runbook the Technical Writer's: whichever Employee's dispatch trigger the Work Unit meets. In the Review Chain, the Engineer is the author of the Pull Request under review.

"Engineer" is never dispatched as such. A brief, a commit, or a report that names "Engineer" names no accountable Employee, which is the defect `Core/MAIN_AGENT_CONDUCT.md`'s Dispatch Discipline forbids.

---

# Work Unit Decomposition

Decomposing an objective into Work Units is the Main Agent's own Orchestration Step 3 (`Core/ORCHESTRATION.md`): it defines each Work Unit, chooses its Employee, and presents the plan to the Director before anything is dispatched. Where a chain below shows a decomposition step, that step is the Main Agent's, not a dispatch.

The one exception is **multi-pole work**: work the Director has mandated under `Workflows/AUTONOMOUS_DELIVERY.md` (its Trigger) — two or more independent Work Unit queues with disjoint write scope, under a bounded budget. There the Main Agent dispatches the **Engineering Manager** to define the mandate's Work Units, and the run continues under that Workflow, whose conductor partitions them into poles. The Main Agent never decides alone that work is multi-pole: until the Director's mandate exists, decomposition is its own Step 3. Size is never the trigger either — a long queue whose Work Units share write scope stays with the Main Agent.

---

# Feature Chain

**Trigger:** Director or Product Manager requests a new feature.

**Workflow:** Feature Development Workflow (`Workflows/FEATURE_DEVELOPMENT.md`)

```
Business Analyst
      ↓
  [Functional specification — acceptance criteria]
      ↓
Software Architect
      ↓
  [Architecture review — ADR if needed]
      ↓
Main Agent → Director  (if an ADR is required)
      ↓
  [ADR decision — implementation blocked until Accepted]
      ↓
Main Agent  (Engineering Manager if multi-pole work)
      ↓
  [Work Unit decomposition — Orchestration Step 3]
      ↓
Engineer(s)        ← parallel if Work Units are independent
      ↓
  [Implementation + tests]
      ↓
Code Reviewer
      ↓
  [PR approved]
      ↓
QA Engineer  (when the Pull Request changes executable behaviour — Workflows/FEATURE_DEVELOPMENT.md Step 8)
      ↓
  [QA sign-off]
      ↓
Main Agent → Director
      ↓
  [Approval → Release Chain]
```

**Director gates:** After Architecture review (if ADR required), after QA sign-off (when one is required).

**Decomposition:** The Main Agent's own planning, not a dispatch (see Work Unit Decomposition, above). Its plan is the one Orchestration Step 3 presents to the Director before any Engineer is dispatched.

**Parallel dispatch allowed:** Between independent Engineer Work Units only.

---

# Review Chain

**Trigger:** Pull Request is open and assigned to the Code Reviewer.

**Workflow:** Code Review Workflow (`Workflows/CODE_REVIEW.md`)

```
Code Reviewer
      ↓
  [Review: logic, tests, standards, security, documentation]
      ↓
  ┌── Approved ──────────────────────────────────┐
  │                                               │
  └── Changes requested → Engineer → resubmit ──┘
      ↓
Security Engineer  (if the Code Reviewer flags a security concern)
      ↓
  [Security assessment]
      ↓
Compliance Engineer  (if the Code Reviewer finds compliance-relevant content)
      ↓
  [Compliance assessment]
      ↓
QA Engineer  (if feature is security-sensitive or high-risk)
      ↓
  [QA validation]
      ↓
Main Agent → Director
```

**"Security-sensitive or high-risk" is not optional judgment:** Whether the QA Engineer step is inserted must be checked against the concrete trigger list in `Workflows/CODE_REVIEW.md`, not decided by informal impression. That list includes, among others: authentication or authorization logic, handling of credentials/secrets/keys, processing of PII or other regulated data, payment processing, cryptography usage, public-facing API surface changes, untrusted input at a trust boundary, and infrastructure/deployment configuration with production access. If any trigger is met, the QA Engineer validates the change before delivery to the Director.

**Security and compliance escalation:** If the Code Reviewer flags a security concern, the Security Engineer is inserted before QA. If the Code Reviewer finds compliance-relevant content — regulated data handling, retention or deletion logic, or cross-border data transfer — the Compliance Engineer is inserted before QA in the same way (`Workflows/CODE_REVIEW.md`, Step 4). Both escalations are opened the moment the finding is made, without waiting for the review to complete; the diagram draws them after the review loop only because both come before QA.

---

# Release Chain

**Trigger:** Sprint complete or Director requests a release.

**Workflow:** Release Workflow (`Workflows/RELEASE.md`)

```
Release Manager
      ↓
  [Version bump on develop — changelog]
      ↓
Release Manager
      ↓
  [Release branch — pure snapshot of develop]
      ↓
QA Engineer
      ↓
  [Release acceptance tests]
      ↓
Main Agent → Director
      ↓
  [Director approval — mandatory gate]
      ↓
Release Manager
      ↓
  [Merge to main — tag — preserve release branch]
```

**Director gate:** Mandatory before merge to main. No exception.

---

# Hotfix Chain

**Trigger:** Defect in production requiring an immediate fix outside the normal release cycle.

**Workflow:** Hotfix Workflow (`Workflows/HOTFIX.md`)

```
Main Agent → Director
      ↓
  [Director authorization — mandatory before any work begins]
      ↓
Engineer
      ↓
  [Fix — branches from main, not develop]
      ↓
Code Reviewer
      ↓
  [Expedited review]
      ↓
QA Engineer
      ↓
  [Hotfix validation]
      ↓
Main Agent → Director
      ↓
  [Director approval — mandatory gate]
      ↓
Release Manager
      ↓
  [Merge to main — tag — back-merge to develop]
```

**Director gates:** Authorization at start, approval before merge. Both mandatory.

---

# Incident Chain

**Trigger:** Production incident (P1 or P2 severity).

**Workflow:** Incident Response Workflow (`Workflows/INCIDENT_RESPONSE.md`)

```
SRE Engineer
      ↓
  [Detection — severity assessment — incident declared]
      ↓
Engineering Manager
      ↓
  [Incident Commander assigned — team resources coordinated]
      ↓
Main Agent → Director  (P1/P2 mandatory notification)
      ↓
SRE Engineer
      ↓
  [Containment — mitigation]
      ↓
  ┌── Security incident? → Security Engineer ──┐
  └────────────────────────────────────────────┘
      ↓
Engineer(s)
      ↓
  [Root cause fix — Hotfix Chain if code change needed]
      ↓
SRE Engineer
      ↓
  [Recovery confirmed — monitoring]
      ↓
Engineering Manager
      ↓
  [Post-mortem — blameless — 5 Whys]
      ↓
Main Agent → Director
      ↓
  [Incident report delivered]
```

**Director gate:** Immediate notification for P1/P2. Post-mortem delivered to Director.

---

# Architecture Chain

**Trigger:** New system design, major architectural change, or unresolved architectural question.

**Workflow:** Architecture Decision Workflow (`Workflows/ARCHITECTURE_DECISION.md`)

```
Business Analyst  (if requirements are unclear)
      ↓
  [Functional requirements]
      ↓
Software Architect
      ↓
  [Options analysis — ADR draft — recommended decision]
      ↓
Solution Architect  (if cross-system impact)
      ↓
  [Cross-system impact review]
      ↓
Security Engineer  (if security architecture change)
      ↓
  [Security implications assessment]
      ↓
Technical Lead
      ↓
  [Implementation feasibility review]
      ↓
Main Agent → Director
      ↓
  [Director decision — ADR status: Accepted or Rejected]
      ↓
Main Agent  (if Accepted; Engineering Manager if multi-pole work)
      ↓
  [Work Unit decomposition — Orchestration Step 3 → Feature Chain]
```

**Director gate:** ADR decision is mandatory. Work never begins on an Accepted ADR without Director approval.

**Decomposition:** The Main Agent decomposes the Accepted ADR into Work Units as its own Orchestration Step 3 and hands them to the Feature Chain; the Engineering Manager does it only for multi-pole work (see Work Unit Decomposition, above).

---

# Composing Custom Chains

When no named chain fits the request:

1. The Main Agent identifies the required Employees and their sequence.
2. The Main Agent presents the custom chain to the Director before dispatching.
3. Director approves the chain.
4. The Main Agent dispatches following the Orchestration Protocol.

Custom chains must follow the same dispatch rules as named chains: sequential by default, parallel only when independence is confirmed.

---

# Machine-Readable Form

Each chain above is also recorded as ordered data in `Registry/chains.yml`, and each Workflow's steps and gates in `Registry/workflows.yml`.

The diagrams in this document are the authoritative form and the right one for a reader: they show shape, branching, and where the Director stands, at a glance. They are the wrong form for anything mechanical. Nothing could previously check that a chain's steps name Employees that exist, that its workflow document is real, or that a newly added chain was recorded anywhere a program could see — because a chain was a picture.

`Adapters/scripts/validate-framework.sh` now checks all three, and reports a disagreement as a Registry defect rather than a reason to change this document (`Registry/README.md`, "Authority — the Registry Never Wins"). A seventh chain added here without a Registry entry fails the build.

The Registry records the six chains this document names. Chains composed ad hoc under `Composing Custom Chains` below are not added to it.

---

# Chain Conventions

- Most chains end with a Director delivery step; the Release and Hotfix chains end at the Release Manager's merge-and-tag, and the Architecture chain hands off to the Feature chain.
- Every chain that touches `main` has a mandatory Director approval gate.
- Security concerns anywhere in a chain escalate to the Security Engineer immediately — they do not wait for the next step.
- Every chain produces at least one commit following the Commit Standard.

---

# Metadata

Owner: IA Engineering

Version: 0.0.10

Status: Draft

Category: Core — Orchestration

Severity: Mandatory
