# IA Engineering Glossary

This glossary defines the official vocabulary used throughout IA Engineering.

Every artifact, employee, workflow, and standard must use these definitions consistently.

Terms are grouped by initial letter, and both the letter sections and the terms within them are in alphabetical order. `Adapters/scripts/validate-framework.sh` checks that ordering, because a glossary that is hard to scan is a glossary nobody consults.

---

# A

## Adapter

A concrete, installable integration for a specific version-control host and CI platform (currently: GitHub) that turns a subset of IA Engineering's rules from written policy into technical enforcement — for example, git hooks that validate commit format, a CI check that validates pull requests, or branch-protection setup.

An Adapter is AI-agnostic — it checks work by any Employee, running under any AI runtime — but it is not tool-agnostic: a GitHub Adapter assumes GitHub, and another version-control host or CI platform (e.g. GitLab, Azure DevOps) needs its own equivalent Adapter. See `Adapters/README.md`.

---

## Artifact

Any document, standard, workflow, template, employee, or resource that is part of IA Engineering.

---

# C

## Chain (Agent Chain)

A named, pre-defined sequence of Employees activated by the Main Agent for a specific type of engineering task (e.g., Feature Chain, Release Chain).

Chains encode institutional knowledge about who does what, in what order, for recurring scenarios. See `Core/AGENT_CHAINS.md`.

---

## Conductor

The Main Agent session that coordinates several other Main Agent sessions — Poles — through one Director mandate, in `Workflows/AUTONOMOUS_DELIVERY.md`.

A Conductor is not a new role and holds no new authority: it partitions the mandate's defined Work Units into Poles, briefs each Pole, receives their reports and escalations, runs the integration pass, and reports to the Director. Like any Main Agent, it does not implement, and it never decides what the Director must decide.

---

# D

## Director

The human accountable for a project using IA Engineering.

The Director makes all final decisions and approves every release, tag, merge to `main`, and architectural or business decision. Merging an approved Pull Request into `develop` is delegable (`Workflows/FEATURE_DEVELOPMENT.md` Step 8). See `Core/MAIN_AGENT_CONDUCT.md` and `CLAUDE.md`.

---

## Domain Employee

An Employee defined **by a project, for that project**, whose expertise is the project's business domain rather than an engineering discipline — actuarial rules, clinical coding, customs classification.

A Domain Employee lives in the project, is registered in the project roster, and is what makes an output that is *engineering-correct but domain-wrong* detectable. It extends the roster; it never redefines a framework Employee. See `Templates/DOMAIN_EMPLOYEE.md`.

---

# E

## Employee

A specialized AI role with a defined mission, responsibilities, authority, inputs, outputs, and stop conditions.

An Employee represents a profession, not a technology.

---

## Engineering Standard

A mandatory rule that defines how software must be developed within IA Engineering.

---

## Escape Hatch

A mechanism that makes a control stop applying with nothing recording that it did — `--no-verify`, `--no-gpg-sign`, a stash in place of a commit, a force-push to a protected branch, an inline linter suppression.

Escape hatches exist for genuine emergencies and are forbidden in engineering work: a control that is in the way is a rule that is in the way, and the rule is escalated rather than routed around. See `Standards/GIT_STANDARD.md` and `Standards/CODE_QUALITY_STANDARD.md`.

---

## Execution Tier

The AI execution capability the Main Agent selects for a Work Unit — Lightweight Execution, Standard Execution, Strategic Judgment, or the override-only Frontier — set per Work Unit at dispatch: the Employee's Default Complexity Tier unless a Tier Override changes it, the Employee's tier being only the starting point.

Not to be confused with Risk Tier, below: an Execution Tier is a capability applied to a Work Unit, a Risk Tier is a hazard classification of an action. See `Core/CAPABILITY_TIERS.md`.

---

# F

## Framework

The complete collection of principles, standards, workflows, employees, and adapters that compose IA Engineering.

---

# G

## Gate

A step in a Workflow that cannot be passed without an explicit decision — almost always the Director's.

A gate pauses the sequence: work between gates may run without prompting (`Core/MAIN_AGENT_CONDUCT.md`, Autonomous Release Execution), work past one may not. Gates are recorded as data in `Registry/workflows.yml` so that "run to the next gate, then stop" is answerable without re-reading every Workflow.

---

# H

## Human

The final decision maker.

Humans always retain authority over architectural, business, and product decisions.

---

# I

## Implementation

The concrete code, documentation, configuration, or deliverable produced during a work unit.

---

# M

## Main Agent

The AI session that receives the Director's request and orchestrates the work: it understands, analyzes, plans, dispatches to Employees, reviews, delivers, and stops.

The Main Agent does not implement. Work it performs itself, or attributes to an Employee it never dispatched, is a Dispatch Discipline violation. See `Core/MAIN_AGENT_CONDUCT.md` and `Core/ORCHESTRATION.md`.

---

## Milestone

A named body of work spanning several Work Units, delivered together and recorded as such — Governance, Automation, Convergence.

Every Work Unit in `Registry/work-units.yml` carries its milestone, and a milestone with no `CHANGELOG.md` section is the one a release is being prepared for. See `Governance/VERSIONING_POLICY.md`.

---

# P

## Pole

One Main Agent session in a federated run, executing a single Pole Brief on its own branch with a write scope disjoint from every other Pole's.

Every control that binds one Main Agent binds each Pole unchanged; a Pole escalates through the Conductor, never directly to the Director. See `Workflows/AUTONOMOUS_DELIVERY.md` and `Templates/POLE_BRIEF.md`.

---

## Project

A software project using IA Engineering.

Projects extend the framework but never modify it.

---

# R

## Registry

The machine-readable form of the framework: the Employee roster, the chains, the workflow steps and their gates, and the Work Units — as data a git hook, a CI job, or an AI runtime can read without parsing English.

The Registry is **derived and never authoritative**: where it and a governed document disagree, the document is right and the Registry is stale. See `Registry/README.md`.

---

## Responsibility

The scope of work assigned to an Employee.

Responsibilities define what an Employee owns.

---

## Risk Tier

The classification of a risk-bearing action as Low, Medium, High, or Critical, obtained from its likelihood and its impact, and carrying a required behaviour: proceed, proceed with a stated mitigation, stop and escalate, or stop and require a named Director decision plus independent verification.

A Risk Tier is never lowered to avoid a gate. See `Standards/RISK_STANDARD.md`.

---

# S

## Session State

A project's dated operational state — where things stand, the next step, what is blocked and on whom, which governance rules are currently relaxed and how each is restored.

Session State is **never committed**: a file describing what is currently weak does not belong in the repository it describes. It is distinct from `CLAUDE.md`, which is the project's stable contract and is committed. See `Templates/SESSION_STATE.md`.

---

## Standard

A mandatory engineering rule.

Standards ensure consistency across all projects.

---

## Stop Condition

A condition requiring an Employee to stop working and return control to the requester.

---

# T

## Task

A specific objective assigned to an Employee.

A task belongs to a single work unit.

---

## Template

A reusable document used to standardize outputs.

---

# W

## Work Unit

The smallest independently reviewable engineering task.

A Work Unit should produce one coherent result suitable for review and commit.

---

## Work Unit Report

The complete output an Employee returns when its Work Unit ends: a one-word verdict, what was done, what was **not** done, gate evidence pasted rather than described, deviations from the brief, risk records, and the Definition of Done item by item.

Writing it is the Employee's final action and is what "done" means — a bare "Done" is a failed Work Unit, not a completed one. See `Templates/WORK_UNIT_REPORT.md`.

---

## Workflow

A sequence of coordinated work units executed to achieve an engineering objective.

---

# Document Metadata

Version: 0.0.5

Status: Stable

Owner: IA Engineering

Depends On:

- AI_MANIFEST.md

Referenced By:

- All Artifacts
