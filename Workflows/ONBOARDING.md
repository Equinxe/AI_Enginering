# Onboarding Workflow

---

# Purpose

This workflow defines how IA Engineering is imported and configured for a new project, and how the AI team is initialized so work can begin.

It applies both to new projects starting from scratch and to existing projects adopting IA Engineering mid-lifecycle.

---

# Trigger

- Director decides to apply IA Engineering to a new or existing project.

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Director | Authorizes onboarding, defines project context and goals |
| Main Agent (Claude) | Executes onboarding, initializes context, confirms readiness |
| Engineering Manager | First employee activated — receives the project brief |
| Software Architect | Reviews existing architecture (for existing projects) |

---

# Prerequisites

- The project repository exists (or is being created).
- The Director has a clear project objective.
- The IA Engineering framework repository is accessible.

---

# Steps

## Step 1 — Import the framework

**Actor:** Director + Main Agent

1. Add the IA Engineering framework to the project:
   - As a git submodule, copied reference, or linked documentation directory.
2. Create `CLAUDE.md` at the project root, adapted from the IA Engineering `CLAUDE.md` template:
   - Project identity and objective
   - Technology stack
   - Active standards (reference IA Engineering Standards)
   - Active employees for this project
   - Git workflow confirmation
   - Director identity
3. Create `.ia-engineering/SESSION_STATE.md` from `Templates/SESSION_STATE.md` — the project's dated operational state, read immediately after `CLAUDE.md` on every resume. It is **never committed**: `Adapters/scripts/install.sh` gitignores it and the `pre-commit` hook refuses it, because a file that records what is currently weak does not belong in the repository it describes. `CLAUDE.md` holds the stable contract; this file holds where things stand. One fact lives in exactly one of them.
4. Run `Adapters/scripts/install.sh` from the project root so the hooks, CI workflows, `.gitignore` data-protection rules, and local data directory exist before the first commit — `Standards/DATA_PROTECTION_STANDARD.md` is enforceable only if its controls predate the data.
5. Confirm the framework loads correctly in the AI assistant context.

**Output:** Framework imported. `CLAUDE.md` created and active. `SESSION_STATE.md` created and ignored. Adapters installed.

---

## Step 2 — Define project context

**Actor:** Director → Main Agent

The Director provides the project brief to the Main Agent:

- What is being built and why
- Target users or consumers
- Technology stack (or constraints)
- Known constraints (deadline, budget, compliance requirements)
- Team composition (human engineers involved, if any)

The Main Agent documents this in the project context and confirms understanding before proceeding.

**Output:** Project context documented and confirmed.

---

## Step 3 — Architecture review (existing projects only)

**Actor:** Software Architect

For existing projects:
1. Review the existing codebase and architecture.
2. Identify alignment and gaps against IA Engineering standards.
3. Produce an onboarding architecture assessment:
   - Current state summary
   - Standards gaps
   - Recommended ADRs to document existing decisions
   - Recommended remediation Work Units

**Output:** Architecture assessment (existing projects only).

---

## Step 4 — Activate employees

**Actor:** Main Agent + Engineering Manager

1. Define which employees are active for this project based on its scope.
   - A solo backend project may not need iOS Engineer or Android Engineer.
   - A data project may not need Frontend Engineer.
2. Decide whether the project's **business domain** needs expertise no framework Employee has — actuarial rules, clinical coding, customs classification, construction estimating. If it does, define a Domain Employee from `Templates/DOMAIN_EMPLOYEE.md` under `.ia-engineering/Employees/` and register it in the project roster `.ia-engineering/Registry/employees.yml`, so its `Employee:` trailer validates in the hook and in CI. Its Definition of Done states what constitutes **proof** that a domain output is correct — the question `Workflows/PROJECT_BOOTSTRAP.md` Phase A asks and a Domain Employee answers.
3. Document the active employee roster — framework and Domain Employees — in `CLAUDE.md`, with the concrete dispatch triggers for each Domain Employee (which outputs, paths, or Work Unit types always insert it).
4. Engineering Manager receives the project brief and confirms team readiness.

**Output:** Active employee roster defined, Domain Employees registered where the domain requires them. Engineering Manager briefed.

---

## Step 5 — Initialize git workflow

**Actor:** Main Agent

1. Confirm the repository has the required branches: `main`, `develop`.
2. Confirm branch protection is configured on `main` (no direct pushes).
3. Confirm CI/CD is configured or planned (if applicable).
4. Document the git workflow confirmation in `CLAUDE.md`.

**Output:** Git workflow initialized and confirmed.

---

## Step 6 — Create first Work Unit

**Actor:** Engineering Manager → Director

1. Engineering Manager proposes the first Work Unit based on the project brief.
2. Director reviews and approves.
3. Work Unit is assigned to the appropriate engineer.

This step confirms the framework is operational: the full loop from Director → Main Agent → Engineering Manager → Engineer is active.

**Output:** First Work Unit created and approved by Director.

---

## Step 7 — Confirm readiness

**Actor:** Main Agent → Director

The Main Agent confirms:
- Framework is imported and active.
- `CLAUDE.md` is complete and accurate.
- `.ia-engineering/SESSION_STATE.md` exists, is gitignored, and records the state as of this step with an absolute date.
- Active employee roster is defined, including any Domain Employees and their project roster.
- Git workflow is initialized.
- First Work Unit is ready.

Director gives final confirmation. Work begins.

**Output:** Project onboarded. IA Engineering operational.

---

# Exit Criteria

This workflow is complete when:

- `CLAUDE.md` is present, complete, and loads correctly.
- Active employee roster is defined.
- Git workflow is confirmed.
- First Work Unit is approved by the Director.
- Main Agent has confirmed readiness to the Director.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Existing project has critical standards violations | Director — remediation plan required before normal work begins |
| Technology stack is incompatible with a standard | Director — exception or adaptation required |
| Project scope is unclear | Director — cannot onboard without a clear objective |

---

# Related Workflows

- Feature Development Workflow
- Architecture Decision Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.5

Status: Draft

Category: Workflow — Onboarding

Severity: Mandatory
