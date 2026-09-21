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
Engineering Manager
      ↓
  [Work Unit decomposition — assignments]
      ↓
Engineer(s)        ← parallel if Work Units are independent
      ↓
  [Implementation + tests]
      ↓
Code Reviewer
      ↓
  [PR approved]
      ↓
QA Engineer
      ↓
  [QA sign-off]
      ↓
Main Agent → Director
      ↓
  [Approval → Release Chain]
```

**Director gates:** After Architecture review (if ADR required), after QA sign-off.

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
QA Engineer  (if feature is security-sensitive or high-risk)
      ↓
  [QA validation]
      ↓
Main Agent → Director
```

**"Security-sensitive or high-risk" is not optional judgment:** Whether the QA Engineer step is inserted must be checked against the concrete trigger list in `Workflows/CODE_REVIEW.md`, not decided by informal impression. That list includes, among others: authentication or authorization logic, handling of credentials/secrets/keys, processing of PII or other regulated data, payment processing, cryptography usage, public-facing API surface changes, untrusted input at a trust boundary, and infrastructure/deployment configuration with production access. If any trigger is met, the QA Engineer validates the change before delivery to the Director.

**Security escalation:** If the Code Reviewer flags a security concern, the Security Engineer is inserted before QA.

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
Technical Lead
      ↓
  [Implementation feasibility review]
      ↓
Main Agent → Director
      ↓
  [Director decision — ADR status: Accepted or Rejected]
      ↓
Engineering Manager  (if Accepted)
      ↓
  [Work Unit decomposition → Feature Chain]
```

**Director gate:** ADR decision is mandatory. Work never begins on an Accepted ADR without Director approval.

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

- Every chain ends with a Director delivery step.
- Every chain that touches `main` has a mandatory Director approval gate.
- Security concerns anywhere in a chain escalate to the Security Engineer immediately — they do not wait for the next step.
- Every chain produces at least one commit following the Commit Standard.

---

# Metadata

Owner: IA Engineering

Version: 0.0.8

Status: Draft

Category: Core — Orchestration

Severity: Mandatory
