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
2. Create `CLAUDE.md` at the project root from `Templates/PROJECT_CLAUDE.md`, filling every bracketed field from the Project Charter and the Stack Decision ADR:
   - Project identity, objective, and profile
   - **What constitutes PROOF** for each output someone will act on
   - Technology stack
   - Active standards, and any project rule that is stricter
   - Active Employees — framework and Domain — with concrete dispatch triggers
   - Working method, and which enforcement is installed
   - Director identity
   - Open questions
3. Create `.ia-engineering/SESSION_STATE.md` from `Templates/SESSION_STATE.md` — the project's dated operational state, read immediately after `CLAUDE.md` on every resume. It is **never committed**: `Adapters/scripts/install.sh` gitignores it and the `pre-commit` hook refuses it, because a file that records what is currently weak does not belong in the repository it describes. `CLAUDE.md` holds the stable contract; this file holds where things stand. One fact lives in exactly one of them.
4. Run `Adapters/scripts/install.sh`, found in your imported framework directory, from the project root so the hooks, CI workflows, `.gitignore` data-protection rules, and local data directory exist before the first commit — `Standards/DATA_PROTECTION_STANDARD.md` is enforceable only if its controls predate the data. `install.sh` alone is the host-agnostic subset, for when no stack bootstrap is wanted — a project adopting a technology stack should instead run `Adapters/scripts/setup-project-bootstrap.sh <stack>`, which runs `install.sh` internally and additionally installs the stack's CI workflows and `Dockerfile` (see `Workflows/PROJECT_BOOTSTRAP.md` Step 4).
5. Install the AI-runtime integration — a separate, deliberate step from item 4 above, for the same reason `Workflows/PROJECT_BOOTSTRAP.md` Step 4 gives it its own step: `.claude/settings.json` is committed content that decides what the model may do, not something a per-clone installer writes unasked. From the project root, run `Adapters/ai-runtimes/generate-agents.sh`, found in your imported framework directory, to turn the Employee roster into agents the runtime can dispatch to. Using Claude Code as the runtime, also run `Adapters/ai-runtimes/claude-code/install-hooks.sh` and `Adapters/ai-runtimes/claude-code/install-skills.sh`, both in the same framework directory. A different runtime uses its own Adapter under `Adapters/ai-runtimes/<runtime>/` (`Core/AI_MANIFEST.md` Principle X). Restart the session afterward — Claude Code reads `.claude/settings.json` at session start — and confirm the session-start hook prints `.ia-engineering/SESSION_STATE.md`'s pointers into context.
6. Confirm the framework loads correctly in the AI assistant context.

For a project that already has code and history, the install adds alongside what is there and never overwrites it — see **Adopting into an already-started project** below for the four realities greenfield never meets.

**Output:** Framework imported. `CLAUDE.md` created and active. `SESSION_STATE.md` created and ignored. Adapters installed, including the AI-runtime integration for the runtime in use.

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

# Adopting into an already-started project

**Applies to:** existing projects (Step 3 above). A project with code and history adopts the framework the same way, with four realities greenfield never meets. Each is a consequence of the project pre-dating the framework, not a limitation of it. All four are verified on a real adoption, not asserted.

1. **The project's own files are never overwritten.** `install.sh` and the stack bootstrap install *alongside* what the project already has: an existing file at a path the framework would write — a CI workflow, a `Dockerfile` — is left untouched, and the run says so on that line. Re-run with `--force` only to replace one deliberately. So the project's existing CI keeps running and the framework's CI is installed next to it; the project runs **both** until the Director decides which to keep.

2. **The checks judge the change set under review, not the whole history.** The Employee-trailer, Work-Unit and review checks read the commits in the change being submitted — not every commit in the repository. Commits made before adoption carry no `Employee:` / `Work Unit:` trailers and are **not** judged retroactively: submit the adoption as a change set that begins at the adoption commit, and prior history is left exactly as it is. Every commit from adoption onward carries the trailers (`Standards/COMMIT_STANDARD.md`).

3. **Existing inline suppressions are grandfathered — until a file is rewritten.** The suppression control refuses a lint or test suppression being *written into* a file; it does not reach back into code already committed. A pre-existing `disable-next-line` stays. But rewriting that whole file re-introduces the directive as new text and is refused — for partial changes, edit the file in place rather than rewriting it whole, or remove the suppression as part of the change (`Standards/CODE_QUALITY_STANDARD.md`).

4. **The starter Risk Map covers only the files the bootstrap installed.** The project's own sensitive areas — authentication, payments, migrations, secrets, personal data — are unmapped until the Director classifies them, and `check-risk-map.sh` names each category still unaccounted for rather than assuming it absent. Mapping the existing code's zones (`Templates/RISK_MAP.md`) is among the first Work Units, not an afterthought: an unmapped project is unclassified, not safe (`Standards/RISK_STANDARD.md`).

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

Version: 0.0.7

Status: Draft

Category: Workflow — Onboarding

Severity: Mandatory
