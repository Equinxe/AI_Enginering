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
| DevOps Engineer | Dispatched by the Main Agent to write the project's `CLAUDE.md` and make its commit (Step 1) |
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

**Actor:** Director + Main Agent, with the DevOps Engineer dispatched to write `CLAUDE.md` and make its commit (items 1 and 2)

1. Add the IA Engineering framework to the project:
   - As a git submodule, copied reference, or linked documentation directory. As a submodule, pin a release tag, not a branch; `README.md` Getting Started says which and why. A submodule from a local path needs the workaround in `Governance/TROUBLESHOOTING.md` entry Y. Commit the adoption (the submodule and the installed tooling, without `CLAUDE.md`) once items 4 and 5 have run (item 5 installs `.claude/settings.json` and the skills, which belong to the same commit), signed `Employee: DevOps Engineer`, with an adoption Work Unit registered in the same commit (`Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5). `CLAUDE.md` (item 2) goes in a later commit, also signed `Employee: DevOps Engineer` (Director decision, 4 November 2026), so every commit of the adoption has the same signer. That commit carries a `Work Unit:` line of its own, registered in that commit, because the `commit-msg` hook does not require the line. The Main Agent dispatches the DevOps Engineer, through an Employee Brief, to write `CLAUDE.md` from the Director's answers and make that commit. The Main Agent never writes the file or signs the commit itself (`Core/MAIN_AGENT_CONDUCT.md`, Dispatch Discipline). Item 3 below is created after those commits. In an existing repository, whose `main` is already on its remote, both commits are made on a branch cut from `develop` and reach `develop` through a Pull Request, never `main` (**Adopting into an already-started project**, The adoption route, below).
2. After the adoption commit of item 1, the dispatched DevOps Engineer creates `CLAUDE.md` at the project root from the fenced block under **Template** in `Templates/PROJECT_CLAUDE.md` (the block's contents only, not the whole file), filling every bracketed field from the Project Charter and the Stack Decision ADR:
   - Project identity, objective, and profile
   - **What constitutes PROOF** for each output someone will act on
   - Technology stack
   - Active standards, and any project rule that is stricter
   - Active Employees — framework and Domain — with concrete dispatch triggers
   - The Main Agent rule — delegate every Work Unit to the named Employee, plan first — as the template's short pointer to `Core/MAIN_AGENT_CONDUCT.md`, not restated
   - Working method, and which enforcement is installed
   - Director identity
   - Open questions

   A project with no Project Charter and no Stack Decision ADR, as an existing project that adopts the framework usually is, answers each field from its code, its existing documents and the Director (Steps 2 and 3), never from a guess. A field nobody can answer yet is deleted, and its question goes under `# Open Questions`, as step 4 of `Templates/PROJECT_CLAUDE.md`, A project that already has a `CLAUDE.md`, says for a merge.

   A project that already has a `CLAUDE.md` keeps it, and the block is merged into it instead, so its build commands and conventions stay (`Templates/PROJECT_CLAUDE.md`, A project that already has a `CLAUDE.md`). That section also says three things: where the answers come from when there is no Project Charter, how each contradiction between the project's files and the framework is settled with the Director, and where a deviation the Director keeps is recorded until item 3.
3. Create `.ia-engineering/SESSION_STATE.md`, the project's dated operational state, read immediately after `CLAUDE.md` on every resume. From the project root, run `Adapters/scripts/create-session-state.sh`, found in your imported framework directory. It writes the fenced block of `Templates/SESSION_STATE.md` with the project name and today's date, in the form the session-start hook parses, and checks that git ignores the file. It refuses, and writes nothing, before the project's first commit or over an existing file. By hand, copy the contents of the fenced block under **Template** in `Templates/SESSION_STATE.md`, never the whole file, and write today's date in its `_Last updated:` line in the form `6 October 2026`. Either way, then fill in its other placeholders. Copy into its Governance Deviations in Force section each deviation the `CLAUDE.md` merge recorded in its Work Unit Report. Create it **after the commits of item 1**, not before: the session-start hook warns "N commit(s) behind" when the file is older than the latest commit, so a file written ahead of them is stale on the first session (if it already exists, `touch` it). In an existing repository, create it once the adoption's Pull Request is merged and `develop` is pulled, since that merge commit is newer than both. It is **never committed**: `Adapters/scripts/install.sh` gitignores it and the `pre-commit` hook refuses it, because a file that records what is currently weak does not belong in the repository it describes. `CLAUDE.md` holds the stable contract; this file holds where things stand. One fact lives in exactly one of them.
4. First run `git config core.hooksPath`. It must print nothing. A path means the project already runs git hooks of its own from there (husky, for example, sets `.husky/_`). `install.sh`, which `setup-project-bootstrap.sh` also runs, points that setting at the framework's hooks without looking at the project's (issue #280), and those then stop running with no message. Stop there and bring it to the Director before running either script. Then run `Adapters/scripts/install.sh`, found in your imported framework directory, from the project root so the hooks, CI workflows, `.gitignore` data-protection rules, and local data directory exist before the first commit — `Standards/DATA_PROTECTION_STANDARD.md` is enforceable only if its controls predate the data. `install.sh` alone is the host-agnostic subset, for when no stack bootstrap is wanted — a project adopting a technology stack should instead run `Adapters/scripts/setup-project-bootstrap.sh <stack>`, which runs `install.sh` internally and additionally installs the stack's CI workflows and `Dockerfile`, and writes the project's own, empty `Registry/work-units.yml`. That registry must exist before the first Pull Request: the required `Work Unit Exists` check reads the project's registry and never the framework's, and fails, naming the file to create, if it is missing. A project that ran `install.sh` alone creates it by hand (`work_units:` followed by one entry per Work Unit, shape in `Registry/README.md`; the stack bootstrap is `Workflows/PROJECT_BOOTSTRAP.md` Step 4).
5. Install the AI-runtime integration — a separate, deliberate step from item 4 above, for the same reason `Workflows/PROJECT_BOOTSTRAP.md` Step 4 gives it its own step: `.claude/settings.json` is committed content that decides what the model may do, not something a per-clone installer writes unasked. From the project root, run `Adapters/ai-runtimes/generate-agents.sh`, found in your imported framework directory, to turn the Employee roster into agents the runtime can dispatch to. Using Claude Code as the runtime, also run `Adapters/ai-runtimes/claude-code/install-hooks.sh` and `Adapters/ai-runtimes/claude-code/install-skills.sh`, both in the same framework directory. A different runtime uses its own Adapter under `Adapters/ai-runtimes/<runtime>/` (`Core/AI_MANIFEST.md` Principle X). Restart the session afterward — Claude Code reads `.claude/settings.json` at session start — and confirm the session-start hook prints `.ia-engineering/SESSION_STATE.md`'s pointers into context.
6. Confirm the framework loads correctly in the AI assistant context.

For a project that already has code and history, the install adds alongside what is there and never overwrites it — see **Adopting into an already-started project** below for the four realities greenfield never meets, and for the route by which the adoption reaches `develop` when `main` is already on the remote.

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

The Main Agent documents this in the project context and confirms understanding before proceeding. What is unclear is asked in numbered rounds, each question with a recommended answer (`Core/MAIN_AGENT_CONDUCT.md`, Presenting a Decision to the Director, item 3; `Employees/Specialized/BUSINESS_ANALYST.md`, Clarification Rounds). When an answer settles what a domain term means, it is recorded in `.ia-engineering/DOMAIN_GLOSSARY.md`, created at that first settled term from `Templates/PROJECT_GLOSSARY.md` and never before. A project that already keeps a domain glossary names it in `CLAUDE.md` instead.

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
2. Confirm branch protection is configured on `main` (no direct pushes). On a private repository on GitHub Free, GitHub offers no branch protection, and nothing can make a check required. Only the local git hooks and the CI checks enforce the rules there, and a red check does not block a merge. Record that in `CLAUDE.md`, so whoever merges reads the checks first.
3. Confirm CI/CD is configured or planned (if applicable).
4. Document the git workflow confirmation in `CLAUDE.md`.

**Output:** Git workflow initialized and confirmed.

---

## Step 6 — Create first Work Unit

**Actor:** Main Agent → Director

1. The Main Agent proposes the first Work Unit based on the project brief — its own Orchestration Step 3 (`Core/ORCHESTRATION.md`), not a dispatch (`Core/AGENT_CHAINS.md`, Work Unit Decomposition).
2. Director reviews and approves.
3. The Work Unit is dispatched to the implementing Employee chosen per `Core/EMPLOYEE_SELECTION.md`.

This step confirms the framework is operational: the full loop from Director → Main Agent → Employee is active.

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

**Applies to:** existing projects (Step 3 above). A project with code and history adopts the framework the same way, with four realities greenfield never meets, and by the route that follows them. Each is a consequence of the project pre-dating the framework, not a limitation of it. The four and the route were replayed with the framework's own scripts on a throwaway existing repository, with `main` on a bare remote (WU-IAENG-436). No project other than the framework has adopted it yet (`README.md`, What is proven, and what is not), so a real adoption may still meet a fifth.

1. **The project's own files are never overwritten.** `install.sh` and the stack bootstrap install *alongside* what the project already has: an existing file at a path the framework would write — a CI workflow, a `Dockerfile` — is left untouched, and the run says so on that line. Re-run with `--force` only to replace one deliberately. So the project's existing CI keeps running and the framework's CI is installed next to it; the project runs **both** until the Director decides which to keep.

2. **The checks judge the change set under review, not the whole history.** The Employee-trailer, Work-Unit and review checks read the commits in the change being submitted — not every commit in the repository. Commits made before adoption carry no `Employee:` / `Work Unit:` trailers and are **not** judged retroactively: submit the adoption as a change set that begins at the adoption commit, and prior history is left exactly as it is. Every commit from adoption onward carries the trailers (`Standards/COMMIT_STANDARD.md`).

3. **Existing inline suppressions are grandfathered — until a file is rewritten.** The suppression control refuses a lint or test suppression being *written into* a file; it does not reach back into code already committed. A pre-existing `disable-next-line` stays. But rewriting that whole file re-introduces the directive as new text and is refused — for partial changes, edit the file in place rather than rewriting it whole, or remove the suppression as part of the change (`Standards/CODE_QUALITY_STANDARD.md`).

4. **The starter Risk Map covers only the files the bootstrap installed.** The project's own sensitive areas — authentication, payments, migrations, secrets, personal data — are unmapped until the Director classifies them, and `check-risk-map.sh` names each category still unaccounted for rather than assuming it absent. Mapping the existing code's zones (`Templates/RISK_MAP.md`) is among the first Work Units, not an afterthought: an unmapped project is unclassified, not safe (`Standards/RISK_STANDARD.md`).

## The adoption route

An existing repository has `main` on its remote already, and the `pre-push` hook that Step 1 installs refuses every update of an existing `main` (`Standards/BRANCH_STANDARD.md`). So the adoption reaches `develop` through a Pull Request, and `main` only at the project's first release (Director decision, 4 November 2026). `README.md` Getting Started gives the commands.

**Adopting v0.0.15.** v0.0.15's own documents, the ones in `ia-engineering/` once it is pinned, do not contain this route, the merge procedure of `Templates/PROJECT_CLAUDE.md` for a project that already has a `CLAUDE.md`, or the rule that the DevOps Engineer signs the `CLAUDE.md` commit (#379), and v0.0.15's `Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5 still sends the adoption commit to `main`. An existing project adopting v0.0.15 therefore reads every framework document from the `develop` branch of the framework repository, never from its own `develop` and never from the pinned submodule: this section, `README.md`, `Workflows/PROJECT_BOOTSTRAP.md` (Step 4) and `Templates/PROJECT_CLAUDE.md`. It reads them at one fixed point until v0.0.16 is tagged, so that they do not change during the adoption: the `develop` commit that merged Pull Request #465, which that Pull Request's page names. It reads them without checking that commit out, on GitHub or with `git -C ia-engineering fetch origin develop` followed by `git -C ia-engineering show <that commit>:<file>`. The submodule stays pinned to v0.0.15, and only the scripts come from it. The route works with v0.0.15's scripts unchanged, with two exceptions:
- The closing-report lines of `setup-project-bootstrap.sh` that issue #453 corrects are ignored: its `main + develop created`, `CLAUDE.md` and `SESSION_STATE.md` lines, written for a new project.
- v0.0.15's `generate-agents.sh` does not write the section "Where the Framework Is" (WU-IAENG-430) into the agents. In a linked git worktree `ia-engineering/` is empty, so an Employee dispatched there cannot read the framework's Standards. Until v0.0.16, the Main Agent's default is to dispatch every Employee in the main checkout, never with `isolation: worktree`, and the Director may change that default. Workspace Isolation (`Core/MAIN_AGENT_CONDUCT.md`) still applies: while one Employee's git-touching Work Unit is active in the main checkout, the Main Agent waits for it, or gives a second Employee a separate clone made with `--recurse-submodules`, where `install.sh` is run again. In the `CLAUDE.md` merged from the template, replace the tail of the paragraph on a git worktree, from "A git worktree" to its end, with this text, word for word:

  ```
  A git worktree needs neither: its hooks are the main checkout's. Until this project pins v0.0.16, the Main Agent dispatches every Employee in the main checkout, never with `isolation: worktree`, because a worktree's `ia-engineering/` is empty and v0.0.15's agents do not name the main checkout's framework. While one Employee's git-touching Work Unit is active there, a second waits or works in a separate clone made with `--recurse-submodules` (`Core/MAIN_AGENT_CONDUCT.md`, Workspace Isolation). The Director may change this default.
  ```

The route ships in v0.0.16.

**Actor:** the DevOps Engineer, dispatched by the Main Agent through an Employee Brief, for steps 1 to 3 up to the opened Pull Request: creating and pushing `develop`, the branch, both commits and the push are git mutations, which the Main Agent never performs itself (`Core/MAIN_AGENT_CONDUCT.md`, Git Execution via Named Employee). The Code Reviewer reviews the Pull Request. The merge follows `Workflows/FEATURE_DEVELOPMENT.md` Step 8, which names who may merge and on what conditions. The Director applies `size/approved` and decides the project's first release (`Workflows/RELEASE.md`).

The route needs `main` as the remote's default branch. Check it before step 1, as a command of its own, and read the result before running anything else: `git ls-remote --symref origin HEAD` prints `ref: refs/heads/main` on its first line. A default of `develop` is part of the same model. Any other default, `master` for example, is not covered: the `pre-push` hook, the checks and `Workflows/RELEASE.md` name `main`. Stop and bring it to the Director before step 1 creates `develop`: renaming the default branch is the Director's decision, and the route starts once `main` exists on the remote.

1. **Create `develop` from `main`, before the bootstrap.** `git switch main`, `git pull --ff-only`, `git switch -c develop`, then `git push -u origin develop`. Nothing refuses that push: no hook is installed yet, and `pre-push` allows creating an absent `develop` in any case. Where the remote already has one, run `git switch develop` and `git pull --ff-only` instead.
2. **Adopt on a branch cut from `develop`**, `chore/adopt-ia-engineering`. Step 1 items 1, 4 and 5 run on it, and both commits of item 1 are made on it: the adoption commit, then the `CLAUDE.md` commit. Before the adoption commit, decline what the project does not want of the bootstrap's starter `Dockerfile` and its `ghcr-publish.yml` (`README.md`, The steps that are not commands).
3. **Merge it into `develop` through a Pull Request.** Push the branch and open the Pull Request, its description filled in from the installed `.github/PULL_REQUEST_TEMPLATE.md`. A project that already had a pull request template of its own keeps it: the bootstrap leaves it as it is and does not fail on it, and `install.sh --check` lists one action, to copy into it by hand the framework's parts it lacks (the `Work Unit:` line, Merge danger, How to test, the Falsifiability item) from `Adapters/github/PULL_REQUEST_TEMPLATE.md` in the framework directory (issue #472). It runs the CI workflows that the adoption commit adds, so `Work Unit Exists` and `Employee Trailer` read both adoption commits and none from before them (reality 2 above). The adoption is larger than the 1,500-line review limit, so `PR Size` fails until the Director applies the `size/approved` label (`Standards/PULL_REQUEST_STANDARD.md`, Reviewability). The advisory `Risk Map` check stays red until the map is complete (reality 4), and does not hold the merge. Merge it only when all three hold:
   - the Code Reviewer has approved it, and every other approval `Workflows/FEATURE_DEVELOPMENT.md` Step 8 requires is given;
   - the Director has applied `size/approved`;
   - the ten checks that `setup-branch-protection.sh` makes required all pass: PR Compliance, Work Unit Exists, Employee Trailer, Shellcheck Adapters, Validate Workflow YAML, Hook Tests, Script Tests, PR Size, Framework Validation and Data Policy.

   Merge with a merge commit, never a squash (`Standards/COMMIT_STANDARD.md`). Then the local clone takes the merge (`git switch develop`, then `git pull --ff-only`), and `SESSION_STATE.md` is created (Step 1 item 3). On a private repository on GitHub Free, nothing on GitHub can make these checks required (Step 5), so this list is the only lock on the merge.
4. **`main` receives the adoption at the project's first release** (`Workflows/RELEASE.md`), which the Director may cut as soon as the adoption is merged. An adopting project's first release has not been rehearsed yet: `release.sh check`, which `Workflows/RELEASE.md` Step 1 runs, reads a `VERSION.md` and a `CHANGELOG.md` that the adoption does not install (issue #469). Until that issue is resolved, bring the first release to the Director before `Workflows/RELEASE.md` Step 1. Until the first release, `main` does not change:
   - Whatever deploys from `main` keeps deploying the code it had before the adoption. Work merged into `develop` reaches production only through that release.
   - The framework's `ghcr-publish.yml` does not run, since it runs on pushes to `main` and on tags.
   - A workflow of the project's own that runs only for Pull Requests to `main` does not run for those to `develop` until `develop` is added to its branches.
   - `Workflows/HOTFIX.md` cannot be followed yet. A branch cut from `main` has no `Registry/work-units.yml`, so the `commit-msg` hook refuses a commit there that claims a Work Unit. Do not create the registry on `main` to get around this: it would adopt `main` in part, against this route, and collide with `develop`'s registry at the back-merge. A fix that cannot wait goes out in the first release.

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

Version: 0.0.19

Status: Draft

Category: Workflow — Onboarding

Severity: Mandatory
