# Contributing to IA Engineering

---

# Purpose

This document defines how a change to the IA Engineering framework itself gets proposed, reviewed, and landed — whether the proposer is a new contributor, a Director running a different project on this framework, or an Employee that discovered a gap while doing unrelated work.

This is not about contributing to a project that *uses* IA Engineering. It is about contributing to the framework repository itself: `Core/`, `Standards/`, `Employees/`, `Workflows/`, `Templates/`, `Examples/`, `Governance/`, `Prompts/`, `Adapters/`.

This document does not redefine how Git, commits, branches, or Pull Requests work in this repository — `Standards/GIT_STANDARD.md`, `Standards/BRANCH_STANDARD.md`, `Standards/COMMIT_STANDARD.md`, and `Standards/PULL_REQUEST_STANDARD.md` already own that. Read all four before proposing any change. This document covers what those four do not: **how much process a given kind of change requires**, and **how the specific document types unique to this framework (Employees, Workflows, Templates, Standards, Core conduct documents) get proposed and reviewed.**

---

# Scope

This document applies to anyone proposing a change to the IA Engineering repository: external contributors, Directors of other projects built on this framework, and Employees who surface a gap while executing unrelated work.

It does not apply to work inside a *project that uses* IA Engineering — that project's own `CLAUDE.md` and its own contribution conventions govern there.

---

# 1. Change Tiers — How Much Process a Change Needs

Not every change to this repository carries the same weight. IA Engineering already has a framework for matching scrutiny to stakes: `Core/CAPABILITY_TIERS.md`'s three execution tiers (Lightweight Execution, Standard Execution, Strategic Judgment). That framing maps directly onto how much review a framework contribution needs, because the same question — *how much does getting this wrong cost, and how reversible is it?* — applies to both.

For a genuinely mechanical change, `Workflows/FEATURE_DEVELOPMENT.md`'s "Trivial / Mechanical Changes (Express Path)" section shows this tiering already running end-to-end at Lightweight Execution.

| Change type | Tier | Concrete review bar |
|---|---|---|
| Typo, broken link, formatting fix in a Workflow, Example, Template, or root-level doc (`README.md`, `CHANGELOG.md`, and other root-level `*.md`) | Lightweight Execution | Self-merge after one other person (or Employee) skims the diff. No PR discussion required. |
| Wording clarification in a Standard, Employee, Workflow, or root-level doc (`README.md`, `CHANGELOG.md`, and other root-level `*.md`) that does not change what the document requires or permits | Standard Execution | Standard Pull Request review per `Standards/PULL_REQUEST_STANDARD.md`. One reviewer approval. |
| Adding a new Workflow, Template, or Standard | Standard Execution, escalating to Strategic Judgment if it changes how existing Workflows or Employees operate | See Section 3. Requires the cross-reference check (Section 3) and Director awareness before merge. |
| Adding a new Employee to the 42-roster | Strategic Judgment | See Section 2. Requires Director approval before merge — a new Employee changes who is authorized to do what across every project on this framework. |
| Any change to a document under `Core/*.md` | Strategic Judgment — the highest scrutiny tier this framework has | See Section 4. Mandatory Director approval, no exceptions. |
| Any change that alters what an existing Standard requires or permits (not just wording) | Strategic Judgment | Mandatory Director approval. Must include the documented-deviation reasoning `Standards/STANDARDS_FIRST.md` requires when moving away from an official standard. |

**The concrete check, not the vague one:** if you cannot point to which row above your change falls into, it defaults to Strategic Judgment until a maintainer confirms otherwise. This mirrors the reasoning `Core/CAPABILITY_TIERS.md` already uses for Work Unit dispatch — ambiguity escalates, it does not get guessed downward.

---

# 2. Proposing a New Employee

A new Employee is a framework-level addition to the 42-roster in `Employees/` — this is distinct from `Core/MAIN_AGENT_CONDUCT.md`'s `Roster Gaps` section, which governs activating an *existing* framework Employee into one project's own `CLAUDE.md`. Adding a new Employee type to the framework itself is rarer and carries more weight than activating one that already exists.

## What the proposal must contain

A new Employee definition file (placed under the correct `Employees/<Category>/` subdirectory) must contain every section the existing 42 Employees already use, in the same order — check any existing file (e.g. `Employees/Documentation/DOCUMENTATION_ENGINEER.md`) for the exact shape:

- **Mission** — one paragraph, what this Employee exists to do that no existing Employee already does.
- **Responsibilities** — a bulleted list of concrete duties.
- **Authority** — what the Employee may decide alone, and what it must never do without escalation.
- **Standards Applied** — which `Standards/*.md` documents govern this Employee's work.
- **Inputs** / **Process** / **Outputs** — the operational shape of the work.
- **Output Format** (where applicable).
- **Definition of Done**.
- **Escalation Rules** — a table of blocker types and who they escalate to.
- **Failure Modes** — concrete, named anti-patterns this Employee is prone to, not generic warnings.
- **Metadata** — Owner, Version, Status, Category, Severity, and **Default Complexity Tier** (Strategic Judgment or Standard Execution, per `Core/CAPABILITY_TIERS.md`).

A proposal missing any of the above sections is incomplete — return it for revision rather than merging a partial Employee definition, per `Templates/EMPLOYEE_BRIEF.md`'s own standard: an incomplete brief is the framework's fault, not the reader's.

## The non-overlap check

Before drafting the file, check `Core/EMPLOYEE_SELECTION.md` for whether an existing Employee already covers this ground. If the proposed Employee's Mission substantially overlaps an existing one, either narrow the proposal or document why a split is warranted (the same reasoning `Core/EMPLOYEE_SELECTION.md`'s Miscasting Risks section already models for existing near-duplicate pairs, e.g. Technical Lead vs. Software Architect).

## Who reviews and approves

- A maintainer familiar with the Employee roster reviews the definition for completeness against the checklist above and for non-overlap with the existing 42.
- **The Director gives final approval before merge.** Adding an Employee changes who is authorized to do what across every project that adopts this framework — this is Strategic Judgment tier (Section 1), not something a contributor merges unilaterally.

## What must be updated in the same Work Unit

Adding Employee #43 (or beyond) is not just a new file. The following must be updated **in the same Work Unit**, not deferred to a follow-up:

1. **`VERSION.md`** — both the roster count (currently "Employees (42)") and the named list under the relevant category must reflect the new Employee. A roster count that does not match the actual file count is exactly the kind of drift this repository has caught and fixed before.
2. **`Core/EMPLOYEE_SELECTION.md`** — add a "dispatch this Employee when…" trigger under the correct category, written from the new Employee's own Mission (per that document's own stated method), and add a Miscasting Risks entry if the new Employee is a plausible near-miss for an existing one.

A Pull Request that adds an Employee file but leaves `VERSION.md` or `Core/EMPLOYEE_SELECTION.md` unchanged is incomplete — do not approve it. This is the same "shipped X, forgot to update cross-referencing Y" failure mode named explicitly in Section 3 below; it applies here too.

---

# 3. Proposing a New Workflow, Template, or Standard

## What each must contain

- **A new Workflow** (`Workflows/`) must define: Purpose, Trigger, Actors (with role), Prerequisites, numbered Steps (each with Actor, action, Output, and Handoff), a Coverage Checklist / Exit Criteria, an Escalation table, Related Workflows, and Metadata. Use an existing Workflow (e.g. `Workflows/PROJECT_BOOTSTRAP.md`) as the structural reference.
- **A new Template** (`Templates/`) must contain: Usage (who fills it in and when), the template body itself in a fenced code block, "When to Use This Template," and Metadata. Follow `Templates/EMPLOYEE_BRIEF.md`'s own shape.
- **A new Standard** (`Standards/`) must follow `Standards/STANDARDS_FIRST.md`'s hierarchy explicitly: Purpose, Scope, Official References (the authoritative external standard this document orchestrates — never invented from scratch when an official one exists), Industry Best Practices, IA Engineering Additions, Responsibilities, Forbidden Practices, Rationale, Related Standards, Metadata.

## Who reviews

A maintainer with working knowledge of the affected area (Workflows, Templates, or Standards) reviews for structural completeness against the list above. The Director is informed before merge for any new Standard (Section 1: Strategic Judgment), and for any new Workflow or Template that changes how an *existing* Workflow or Employee operates rather than adding a purely new, additive capability.

## The cross-reference check — name the failure mode explicitly

This repository has repeatedly shipped a new document and forgotten to update the other document that was supposed to reference it. Two concrete, already-fixed instances: the ADR trigger list that `Core/ORCHESTRATION.md` Step 2 needed to cross-reference from `Workflows/ARCHITECTURE_DECISION.md`, and the security-sensitive QA trigger that `Core/AGENT_CHAINS.md`'s Review Chain needed to cross-reference from `Workflows/CODE_REVIEW.md`. Both were found only after the fact, in dedicated audits.

**Any new Workflow, Template, or Standard must include an explicit cross-reference check as part of its own Definition of Done**, answering, concretely:

1. Which existing documents (Core, other Workflows, `Core/AGENT_CHAINS.md`, `Core/ORCHESTRATION.md`) should now point to this new document?
2. Have those documents been updated in this same Work Unit to add that reference?
3. If the new document introduces a trigger, threshold, or escalation condition, is it cross-referenced from every place an equivalent trigger already lives (e.g., a new Standard with a security implication should be referenced from `Core/AGENT_CHAINS.md`'s Review Chain, the same way the two examples above are)?

A reviewer who cannot answer all three questions with a specific document name and a completed edit — not "we should probably update something" — has not finished the cross-reference check. This is the concrete version of "keep documentation in sync"; the vague version is exactly what let the ADR and QA trigger gaps ship in the first place.

---

# 4. Changes to `Core/*.md`

Documents under `Core/` (`AI_MANIFEST.md`, `MAIN_AGENT_CONDUCT.md`, `AGENT_CONDUCT.md`, `DECISION_TREE.md`, `GLOSSARY.md`, `CAPABILITY_TIERS.md`, `EMPLOYEE_SELECTION.md`, `ORCHESTRATION.md`, `AGENT_CHAINS.md`) govern the Main Agent's own behavior — not just in this repository, but in every project that adopts this framework. A wording change here changes how the Main Agent behaves everywhere IA Engineering is used.

**This is the highest scrutiny tier this framework has.** Concretely:

- Every change to a `Core/*.md` document is Strategic Judgment tier (Section 1) — no downgrade, regardless of how small the diff looks. A one-line wording change to `Core/MAIN_AGENT_CONDUCT.md` is not a typo fix; it is a behavioral change to every Main Agent instance running this framework.
- The proposal must state, in the Pull Request description, exactly what behavior changes and why — the same "why does this change exist, in one sentence" bar `Standards/COMMIT_STANDARD.md` already sets for commits, applied here to behavior instead of code.
- **Director approval is mandatory before merge, with no exception for size or perceived obviousness.** This mirrors `CLAUDE.md`'s own standing rule that the Director makes all final decisions and that architectural, business, and irreversible decisions are always escalated — a `Core/*.md` change is exactly that kind of decision, because it is never scoped to one project.
- If the change adds a new rule that could plausibly conflict with an existing one (e.g., a new conduct rule that touches git execution, dispatch, or escalation), the Pull Request must explicitly state how it relates to the existing rules it is closest to — the same "does not touch X, does not make Y redundant" discipline `Core/MAIN_AGENT_CONDUCT.md`'s own recent rules already model for each other.

---

# 5. Code of Conduct

This is deliberately short and concrete, grounded in this project's own stated values (`Core/AI_MANIFEST.md`) rather than generic boilerplate.

- **Shared Responsibility (`AI_MANIFEST.md` Principle VIII).** Contributors and Employees build this framework together; neither a human contributor nor an AI Employee "owns" a document merely because they wrote the first draft. Review feedback is addressed, not defended against.
- **Transparency (Principle VI).** State uncertainty, assumptions, and limitations in a proposal explicitly. A Pull Request that hides an unresolved question to look more finished is a Transparency violation, not a shortcut.
- **Human First (Principle I).** The Director's decision is final on anything escalated per Sections 2 and 4 above. Disagreement is welcome in review comments; overriding a Director decision by merging anyway is not.
- **Reviewability (Principle IV).** Keep proposals scoped to one engineering objective (`Standards/PULL_REQUEST_STANDARD.md`'s "One Engineering Objective"). A reviewer who cannot understand a proposal in one sitting has grounds to request it be split, not to wave it through.
- **Respectful disagreement.** Critique the proposal, not the proposer. A rejected proposal is a normal outcome of review, not a judgment on the contributor.

Violations of these norms in review comments or Pull Request conduct are handled the same way any other Escalation is handled in this framework — raised to the Director, per `Core/MAIN_AGENT_CONDUCT.md`'s Escalation section.

---

# 6. How an Idea Becomes a Change

IA Engineering already has two intake mechanisms for "something should change here." This document does not create a third — it ties the two existing ones into one path from idea to merged Pull Request.

1. **External or informal contribution ideas** — a bug report, a feature request, a gap noticed by anyone (not necessarily someone with write access) — go through the **GitHub Issue Templates** scaffolded by `Workflows/PROJECT_BOOTSTRAP.md` Step 6 (`.github/ISSUE_TEMPLATE/`: bug report, feature request, config). This is deliberately an independent intake surface, not wired automatically into the Work Unit/Pull Request flow — filing an Issue records the idea durably; whether and when it becomes a Work Unit is a separate judgment call, at the Engineering Manager's discretion.
2. **Findings discovered during work** — a gap, a technical-debt item, or a deferred decision surfaced by the Main Agent or an Employee while doing unrelated work — are filed as a **GitHub Issue** per `Core/MAIN_AGENT_CONDUCT.md`'s `Durable Tracking of Findings` section, precisely so the finding survives beyond one session's private memory and is visible to any future Director, contributor, or AI runtime working from this repository.

Both paths converge on the same artifact: a GitHub Issue. From there, once someone (a contributor, a Director, an Employee) decides to act on it:

1. A Work Unit is defined (`Templates/WORK_UNIT.md`), scoped to the Change Tier it falls into (Section 1).
2. A branch is created per `Standards/BRANCH_STANDARD.md`.
3. The change is made and committed per `Standards/COMMIT_STANDARD.md` — one Work Unit, one commit, one engineering objective.
4. A Pull Request is opened per `Standards/PULL_REQUEST_STANDARD.md`, referencing the originating Issue where one exists.
5. Review happens at the scrutiny level Section 1 assigns to that kind of change, up to and including Director approval where Sections 2 or 4 require it.

An Issue is where an idea becomes durable and visible. A Work Unit and Pull Request are where it becomes a reviewed, merged change. Neither step is optional, and neither replaces the other.

---

# 7. The Learning Loop — How an Incident Becomes a Rule

Section 6 covers ideas. This section covers **failures**: a red check nobody expected, a review that found a defect, a hook that rejected a correct commit, a claim that turned out false, a data-protection near miss. The framework's own history shows what happens without a loop — the same defect class was found sixteen times in one milestone, four of them inside fixes to earlier instances, before it was named and given a rule.

The loop has three steps, and the first two are part of the fixing Work Unit's Definition of Done:

1. **Record the instance.** The Work Unit that fixes the incident adds an entry to `Governance/TROUBLESHOOTING.md` — symptom, cause, remedy, prevention — in the same commit. An entry with no Prevention is returned in review: it describes an incident that will recur. Incidents specific to one project go in that project's catalog, or in the Errors and Traps section of its `.ia-engineering/SESSION_STATE.md` while fresh.
2. **Name the class at the second instance.** When an entry is the second of its kind, the fixing Work Unit also names the class and writes the rule — in the document that owns the mechanism (a Check Convention rule in `Adapters/README.md`, a Forbidden Practice in a Standard, a Failure Mode in an Employee). The Check Convention was written after the eleventh instance of its class; the standard this framework holds itself to is the second.
3. **Turn the rule into a control where one is possible.** A rule that can be checked mechanically becomes a validator check, a hook, or a CI job in a follow-up Work Unit (Section 1, Tier 2). A rule that cannot — most conduct rules — is made concrete enough to be checked by a reader: `Core/EMPLOYEE_SELECTION.md`'s dispatch triggers are the model.

Two things the loop is not. It is not blame: entries name mechanisms, and where they name an Employee it is because attribution is the point of the `Employee:` trailer, not because the Employee is the cause. And it is not optional at review: a Pull Request that fixes an incident and does not touch `Governance/TROUBLESHOOTING.md` is asked why.

---

# Related Documents

- `Standards/GIT_STANDARD.md`, `Standards/BRANCH_STANDARD.md`, `Standards/COMMIT_STANDARD.md`, `Standards/PULL_REQUEST_STANDARD.md` — the git-mechanics standards this document does not repeat.
- `Standards/STANDARDS_FIRST.md` — the hierarchy a new Standard must follow.
- `Core/CAPABILITY_TIERS.md` — the tier framing Section 1 reuses.
- `Core/EMPLOYEE_SELECTION.md` — the non-overlap and dispatch-trigger reference for Section 2.
- `Core/MAIN_AGENT_CONDUCT.md` — `Roster Gaps`, `Durable Tracking of Findings`, and `Escalation`.
- `Templates/EMPLOYEE_BRIEF.md` — the Employee file structure reference for Section 2.
- `Workflows/PROJECT_BOOTSTRAP.md` — Step 6, the Issue Templates intake mechanism referenced in Section 6.
- `Core/AI_MANIFEST.md` — the Principles grounding Section 5.
- `Governance/TROUBLESHOOTING.md` — the catalog Section 7 feeds; `Adapters/README.md`'s Check Convention is the worked example of a class becoming a rule.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Governance

Severity: Mandatory

Depends On:

- `Standards/STANDARDS_FIRST.md`
- `Standards/GIT_STANDARD.md`, `Standards/BRANCH_STANDARD.md`, `Standards/COMMIT_STANDARD.md`, `Standards/PULL_REQUEST_STANDARD.md`
- `Core/CAPABILITY_TIERS.md`
- `Core/EMPLOYEE_SELECTION.md`
- `Core/MAIN_AGENT_CONDUCT.md`
- `Templates/EMPLOYEE_BRIEF.md`
- `Workflows/PROJECT_BOOTSTRAP.md`
- `Core/AI_MANIFEST.md`

Referenced By:

- `Governance/TROUBLESHOOTING.md`
- `Adapters/github-actions/framework-validation.yml`
- `Adapters/scripts/validate-framework.sh`
