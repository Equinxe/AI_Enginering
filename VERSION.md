# IA Engineering Version

Current Version

**v0.0.13**

Codename

**Portability**

Status

🟢 Active Development

---

## Completed

### Core

- [x] AI Manifest
- [x] README
- [x] Glossary
- [x] Decision Tree
- [x] Main Agent Conduct
- [x] Agent Conduct

### Standards

- [x] Standards First
- [x] Git Standard
- [x] Commit Standard
- [x] Branch Standard
- [x] Pull Request Standard
- [x] Documentation Standard
- [x] Code Quality Standard
- [x] Testing Standard
- [x] Risk Standard
- [x] Data Protection Standard

### Employees (42)

- [x] Management: Engineering Manager, Scrum Master, Technical Lead, Release Manager, Product Manager
- [x] Architecture: Software Architect, Solution Architect, Data Architect
- [x] Development: Backend Engineer, Frontend Engineer, iOS Engineer, Android Engineer, Cross-Platform Engineer, Database Engineer, Event-Driven Engineer, Integration Engineer
- [x] DevOps: DevOps Engineer, GitOps Engineer, SRE Engineer, Cloud Engineer, Platform Engineer, Infrastructure as Code Engineer, Observability Engineer
- [x] Quality: QA Engineer, Performance Engineer, Security Engineer, Test Automation Engineer
- [x] Data: Data Engineer, ML Engineer, Data Scientist, MLOps Engineer, Analytics Engineer
- [x] Documentation: Documentation Engineer, Technical Writer
- [x] Specialized: API Engineer, Code Reviewer, Compliance Engineer, Penetration Tester, Business Analyst, AI Engineer, Prompt Engineer, UX/UI Designer

---

### Workflows (10)

- [x] Feature Development
- [x] Code Review
- [x] Release
- [x] Hotfix
- [x] Incident Response
- [x] Architecture Decision
- [x] Onboarding
- [x] Sprint Ceremony
- [x] Project Bootstrap
- [x] Autonomous Delivery

---

### Templates (13)

- [x] Work Unit
- [x] Work Unit Report
- [x] Pull Request
- [x] Architecture Decision Record
- [x] Incident Report
- [x] Test Plan
- [x] Employee Brief
- [x] Pole Brief
- [x] Project Charter
- [x] Project CLAUDE.md
- [x] Session State
- [x] Domain Employee
- [x] Risk Map

---

### Orchestration (3)

- [x] Orchestration Protocol
- [x] Agent Chains
- [x] CLAUDE.md updated to current version

---

### Examples (7)

- [x] Feature Chain Example
- [x] Review Chain Example
- [x] Release Chain Example
- [x] Hotfix Chain Example
- [x] Incident Chain Example
- [x] Architecture Chain Example
- [x] Examples Index

### Audit Fixes (v0.0.7.1)

- [x] 18 consistency fixes across Core, Employees, Workflows, and Examples — found via a full content audit of all 65 repository files

### Dispatch Discipline (v0.0.7.2)

- [x] `Core/MAIN_AGENT_CONDUCT.md` — mandatory Employee Brief dispatch, forbidding generic runtime subagent substitution — finding from the first live end-to-end test

### Roster Gaps (v0.0.7.3)

- [x] `Core/MAIN_AGENT_CONDUCT.md` — Roster Gaps rule: propose roster expansion to Director instead of silently absorbing out-of-scope work — second finding from the live end-to-end test
- [x] `Core/MAIN_AGENT_CONDUCT.md` — closed the generic-label loophole in Dispatch Discipline (naming a subagent "executor" instead of the Employee it should represent) — third finding from the live end-to-end test

### Verification Over Waiting (v0.0.7.4)

- [x] `Core/MAIN_AGENT_CONDUCT.md` — Verification Over Waiting rule: verify repository state directly instead of stalling when a dispatch completion report never arrives — fourth finding from the live end-to-end test

### ADR Threshold Detection (v0.0.7.5)

- [x] `Core/ORCHESTRATION.md` — Step 2 now explicitly cross-references the ADR trigger list in `Workflows/ARCHITECTURE_DECISION.md` — fifth finding from the live end-to-end test

### Capability Tiers (v0.0.8)

- [x] `Core/CAPABILITY_TIERS.md` — two AI-agnostic execution tiers (Strategic Judgment, Standard Execution) plus a per-Work-Unit Lightweight Override mechanism
- [x] `Employees/` — Default Complexity Tier added to all 42 Employees' Metadata
- [x] `Core/ORCHESTRATION.md` — Step 4 (Dispatch) selects execution capability per Capability Tiers before creating the Employee Brief

### Adapters (v0.0.9)

- [x] `Adapters/git-hooks/commit-msg` — mechanically enforces Conventional Commits format and mandatory `Employee: <Name>` trailer validated against the 42-Employee roster
- [x] `Adapters/git-hooks/pre-push` — blocks direct push to `main` and `develop`
- [x] `Adapters/github-actions/pr-validation.yml` — CI check requiring every PR to reference a Work Unit ID and have a non-empty description
- [x] `Adapters/github/PULL_REQUEST_TEMPLATE.md` — GitHub PR template mirroring the framework standard
- [x] `Adapters/scripts/setup-branch-protection.sh` — one-shot script to configure GitHub branch protection via the GitHub API
- [x] `Adapters/README.md` — installation guide and index for all adapters
- [x] `.gitattributes` — enforces LF line endings under `Adapters/` for cross-platform compatibility

### Solo-Maintainer Fixes (v0.0.9.1)

- [x] `Adapters/scripts/setup-branch-protection.sh` — removed self-review deadlock (0 required reviews, `enforce_admins: false`) — sixth finding, from applying our own Adapters to this repository
- [x] `Core/MAIN_AGENT_CONDUCT.md` — Workspace Isolation rule: never run Main Agent git commands in the same working directory as an actively-dispatched Employee — seventh finding

### No Direct Implementation (v0.0.9.2)

- [x] `Core/MAIN_AGENT_CONDUCT.md` — No Direct Implementation rule: the Main Agent never personally writes or edits implementation artifacts (code, scripts, configuration, git hooks, CI/CD definitions) — every such change is dispatched to a named Employee, even trivial ones (via the Lightweight Execution tier), and attributing a self-authored change to an undispatched Employee is a Dispatch Discipline violation — eighth finding

### Back-Merge via Pull Request (v0.0.9.3)

- [x] `Workflows/RELEASE.md` Step 8 and `Workflows/HOTFIX.md` Step 9 — both "Back-merge to develop" steps now describe opening a Pull Request (`main` → `develop`) merged once CI passes, instead of a direct `git push` that the `pre-push` hook (`Adapters/git-hooks/pre-push`, v0.0.9) unconditionally blocks — ninth finding

### Project Bootstrap (v0.0.10)

Consistency fixes carried into this release (merged on `develop` after v0.0.9.3, never individually version-bumped):

- [x] `Workflows/RELEASE.md` — version bump now performed on `develop` before the release branch is cut, making the release branch a pure snapshot (WU-IAENG-099)
- [x] `Core/MAIN_AGENT_CONDUCT.md` — No Direct Research conduct rule (WU-IAENG-101)
- [x] Version references synced and Employee roster names canonicalized across docs (WU-IAENG-102)
- [x] `Examples/RELEASE_CHAIN_EXAMPLE.md`, `Examples/HOTFIX_CHAIN_EXAMPLE.md` — aligned with current Workflow steps (WU-IAENG-103)
- [x] Adapter definition, Capability Tiers framing, and doc versions aligned across Core (WU-IAENG-104)
- [x] `Adapters/git-hooks/commit-msg` — merge commits allowed to bypass commit-msg validation (WU-IAENG-106)
- [x] `Adapters/README.md` — post-merge verification of the commit-msg merge fix logged (WU-IAENG-107)

Project Bootstrap milestone:

- [x] `Workflows/PROJECT_BOOTSTRAP.md` — new workflow for bootstrapping a brand-new project (WU-IAENG-108)
- [x] `Templates/PROJECT_CHARTER.md` — 7th framework template (WU-IAENG-109)
- [x] CI/CD + GHCR Adapters — `ci-build-test.yml`, `ghcr-publish.yml`, stack Dockerfiles, `setup-project-bootstrap.sh` (WU-IAENG-110)
- [x] GitHub Issue Templates Adapter (WU-IAENG-111)
- [x] Compliance hardening of Project Bootstrap — escalation trigger, jurisdiction/SOC2/breach-notification questions, Compliance/Security Engineer as Actors (WU-IAENG-115)
- [x] Business/Product hardening — Assumptions & Risks category, business-outcome Success Criteria example, MoSCoW prioritization (WU-IAENG-116)
- [x] `Core/MAIN_AGENT_CONDUCT.md` — Autonomous Release Execution conduct rule (WU-IAENG-117)

### Consistency & Compliance Hardening (v0.0.10.1)

Corrections and hardening to already-shipped milestones (v0.0.9 Adapters, v0.0.10 Project Bootstrap) merged on `develop` after v0.0.10 shipped — no new capability introduced:

- [x] `Adapters/scripts/setup-branch-protection.sh` — `release/*` branch protection added via GitHub's Rulesets API (blocks deletion, force-push, and direct pushes), closing the gap that let an unreviewed direct push land on `release/v0.0.10` (WU-IAENG-121)
- [x] `Workflows/RELEASE.md` — Step 4 minor-defect fixes now land via a PR targeting the release branch instead of a direct push, since `release/*` is now protected against direct pushes (WU-IAENG-122)
- [x] `Workflows/CODE_REVIEW.md`, `Core/AGENT_CHAINS.md` — concrete "security-sensitive or high-risk" trigger criteria added for QA Engineer insertion, cross-referenced from the Review Chain (WU-IAENG-123)
- [x] `Workflows/FEATURE_DEVELOPMENT.md`, `Workflows/CODE_REVIEW.md` — Compliance Engineer entry points added (regulated/sensitive data, named regulatory framework), mirroring existing Security Engineer escalation triggers (WU-IAENG-124)
- [x] `.github/workflows/pr-validation.yml`, `Adapters/github-actions/pr-validation.yml`, `Adapters/README.md` — server-side `employee-trailer` CI check (backstops the client-side git hook) and advisory `review-recorded` CI check added (WU-IAENG-125)
- [x] `Examples/RELEASE_CHAIN_EXAMPLE.md` — realigned with the new PR-based release-branch-fix mechanism (WU-IAENG-126)
- [x] `LICENSE.md` — Apache License 2.0 copyright notice completed (`Copyright 2026 Equinxe`); the license text itself had been in place since the Foundation milestone but its copyright header was never filled in (WU-IAENG-127)
- [x] `README.md` — License section updated from "To be defined before v1.0" to reflect the Apache License 2.0 decision (WU-IAENG-127)

### Governance (v0.0.11)

`Governance/` held only a `.gitkeep` placeholder since the repository's first commit — this milestone delivers its first real content, plus the Main Agent conduct rules and reference documents that landed on `develop` in the same window:

- [x] `Governance/CONTRIBUTING.md` — how a change to the framework itself is proposed and reviewed: Change Tiers mapped to `Core/CAPABILITY_TIERS.md`, how a new Employee/Workflow/Template/Standard is proposed, the highest-scrutiny bar for `Core/*.md` changes, a values-grounded Code of Conduct, and how Issue intake and Durable Tracking of Findings converge into one contribution path (WU-IAENG-134)
- [x] `Governance/VERSIONING_POLICY.md` — formalizes the `MAJOR.MINOR.MILESTONE[.FIX]` versioning scheme: segment semantics, the `.FIX` vs. new-milestone test, milestone naming discipline, and document-internal `Version:` field rules (WU-IAENG-135)
- [x] `Governance/DEPRECATION_POLICY.md` — defines how a Standard, Workflow, Template, or Employee gets deprecated versus removed: deprecation triggers, marker/index lifecycle, the cross-reference check, the Employee-specific Actor/escalation-target check, and required Director approval (WU-IAENG-136)
- [x] `Core/EMPLOYEE_SELECTION.md` — dispatch-trigger reference covering all 42 Employees, naming six concrete miscasting risks, cross-referenced from `Core/MAIN_AGENT_CONDUCT.md` (WU-IAENG-133)
- [x] `Core/MAIN_AGENT_CONDUCT.md` — "Git Execution via Named Employee" conduct rule: mutating git operations are dispatched to a named Employee (Release Manager for release-scoped mutation, GitOps Engineer for git-as-deployment), not absorbed by the Main Agent as plumbing (WU-IAENG-132)
- [x] `Core/MAIN_AGENT_CONDUCT.md` — "Durable Tracking of Findings" conduct rule: gaps, tech debt, and deferred decisions discovered mid-work are filed as GitHub Issues so they survive beyond one session's private memory (WU-IAENG-130)
- [x] `Workflows/RELEASE.md` Step 7 — a bare annotated tag with a one-line `-m` message is no longer sufficient on its own; a full GitHub Release derived from the version's `CHANGELOG.md` entry is now required, closing the gap that had to be fixed after the fact for both v0.0.10 and v0.0.10.1 (WU-IAENG-131)

### Automation (v0.0.12)

The point at which the framework began checking itself. Before it, every rule held because a human or an AI remembered it:

- [x] `Registry/` — the machine-readable form of the roster, chains, workflows, and Work Units, derived and never authoritative (WU-IAENG-137, WU-IAENG-145, WU-IAENG-146)
- [x] `Adapters/scripts/validate-framework.sh` — the cross-reference check `Governance/CONTRIBUTING.md` and `Governance/DEPRECATION_POLICY.md` both require as a Definition of Done item, executed rather than remembered (WU-IAENG-139)
- [x] `Adapters/scripts/install.sh` — every host-agnostic Adapter installed by one idempotent command, hooks wired through `core.hooksPath`, with a verification step that proves the installed hook rejects an invalid trailer (WU-IAENG-141)
- [x] `Adapters/scripts/release.sh` — Step 1 readiness and Step 7 tag-plus-GitHub-Release, mechanised; it never approves and never merges (WU-IAENG-147, WU-IAENG-216)
- [x] `Adapters/ai-runtimes/generate-agents.sh` — the 42 Employee definitions turned into dispatchable agents, execution capability derived from each Employee's Default Complexity Tier (WU-IAENG-148)
- [x] `Adapters/github-actions/framework-validation.yml` — framework validation as a blocking check, on pull requests and on pushes to `main` and `develop` (WU-IAENG-143)
- [x] `Adapters/README.md` — The Check Convention, written down because this milestone found sixteen checks that reported success without evaluating anything, four of them introduced by fixing earlier instances (WU-IAENG-153, WU-IAENG-169)
- [x] `Standards/COMMIT_STANDARD.md` — the trailer layout documented as measured rather than as assumed (WU-IAENG-165, WU-IAENG-166, WU-IAENG-168)
- [x] `Governance/VERSIONING_POLICY.md` — one version may carry more than one milestone; the counter is what increments once per milestone, not the release (WU-IAENG-217)

### Convergence (v0.0.12)

The governance concepts of two sibling frameworks, absorbed as concepts rather than merged as code, with nothing organisation-specific or stack-specific carried over:

- [x] `Standards/RISK_STANDARD.md` — one shared 3×3 scale, a required behaviour per tier, and the one-line `RISK:` record (WU-IAENG-172)
- [x] `Standards/DATA_PROTECTION_STANDARD.md` — real data, secrets, and operational state kept out of version control structurally rather than by convention (WU-IAENG-173)
- [x] `Workflows/AUTONOMOUS_DELIVERY.md` — the tenth Workflow: several Main Agent sessions in parallel under one conductor, with four rules that keep federation from weakening any control (WU-IAENG-185)
- [x] `Templates/WORK_UNIT_REPORT.md`, `Templates/SESSION_STATE.md`, `Templates/DOMAIN_EMPLOYEE.md`, `Templates/POLE_BRIEF.md`, `Templates/PROJECT_CLAUDE.md` — the report contract, the three-memory model, project-owned Employees, the unit of dispatch to a pole, and the project contract Onboarding had always assumed existed (WU-IAENG-174, WU-IAENG-175, WU-IAENG-176, WU-IAENG-185, WU-IAENG-189, WU-IAENG-193)
- [x] `Governance/TROUBLESHOOTING.md` — an incident catalog of 23 classes as symptom → cause → remedy → prevention; an entry without a Prevention is returned in review (WU-IAENG-183, WU-IAENG-200, WU-IAENG-203)
- [x] `Governance/CONTRIBUTING.md` Section 7 — the learning loop that feeds that catalog (WU-IAENG-183)
- [x] `Adapters/ai-runtimes/claude-code/hooks/` — five runtime hooks that refuse before rather than rejecting after, all failing closed, none with a disabling switch (WU-IAENG-179)
- [x] `Adapters/ai-runtimes/claude-code/hooks/tests/` — the repository's first behaviour suite, run by a required **Hook Tests** CI job (WU-IAENG-195, WU-IAENG-206)
- [x] `Core/GLOSSARY.md` — 17 → 28 terms, including three long missing: Main Agent, Gate, Registry (WU-IAENG-191)
- [x] `Standards/PULL_REQUEST_STANDARD.md`, `Standards/GIT_STANDARD.md`, `Standards/CODE_QUALITY_STANDARD.md` — the review limit with a label-based Director override, the canonical escape-hatch table, and No Inline Suppression (WU-IAENG-177, WU-IAENG-178, WU-IAENG-201)
- [x] `Adapters/scripts/setup-branch-protection.sh` — nine required status checks on `main`, `develop`, and `release/*` (WU-IAENG-173, WU-IAENG-177, WU-IAENG-195)

### Portability (v0.0.13)

The milestone that made the framework runnable somewhere other than where it was written. Two halves that turned out to be one problem: logic embedded in a CI workflow could only be tested by deploying it, and a framework that had only ever run on itself had never met another project's history.

- [x] `Adapters/scripts/check-*.sh` — the four Pull Request checks lifted out of `pr-validation.yml` into scripts any host can run, with a behaviour suite (`tests/run.sh`) that builds a real git repository per case and mocks nothing (WU-IAENG-224 … 229)
- [x] `Adapters/scripts/hosts/`, `resolve-host.sh`, `resolve-stack.sh` — the host seam, where the host fetches and acts but never decides and `none` is a real host, plus a declared stack/host beating a guess (WU-IAENG-230, WU-IAENG-237)
- [x] `Adapters/dockerfiles/` — four first-class stacks become seven (`web`, `dotnet`, `php` added), and every declared stack's starter Dockerfile is pinned by `validate-framework.sh` section 17 so a stack without its Dockerfile fails here, not on an adopter's machine (WU-IAENG-231, WU-IAENG-255)
- [x] The Risk Map — `Standards/RISK_STANDARD.md`, `Templates/RISK_MAP.md`, `check-risk-map.sh`, and this repository's own map: a project classifies its own paths, an unmapped project is unclassified not safe, and five documented traps each carry the command that catches them (WU-IAENG-245, WU-IAENG-246, WU-IAENG-248)
- [x] `Adapters/scripts/setup-project-bootstrap.sh` — a starter Risk Map for the files it installs, declaring no category absent so the check names what remains; and an existing file at a framework path is never overwritten without `--force` (WU-IAENG-250, WU-IAENG-253)
- [x] Adopting into an already-started project — `Workflows/ONBOARDING.md` names the four realities greenfield never meets, and that the checks judge the change set under review rather than prior history is pinned in the suite (WU-IAENG-256, WU-IAENG-257)
- [x] `Core/CONTEXT_BUDGET.md`, `Governance/DISPATCH_IN_PRACTICE.md` — the first measurements of what the framework loads before a Work Unit and what dispatch actually does in practice, each figure carrying its command (WU-IAENG-247, WU-IAENG-249)
- [x] Two `grep -q`-under-`pipefail` SIGPIPE defects fixed across the check scripts and the runtime hooks, the threshold measured not guessed; and `check-risk-map` taught to tell a present-but-untracked zone from a dead one (WU-IAENG-251, WU-IAENG-252, WU-IAENG-254)
- [x] `SECURITY.md`, root `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`, and README's *What is proven, and what is not* — the files a public repository is judged on, stating on the front page that the framework has only ever been used on itself (WU-IAENG-243)

---

## Versioning Policy

Format: `MAJOR.MINOR.MILESTONE[.FIX]`

The full, authoritative versioning policy — segment semantics, the `.FIX` vs. new-milestone test, milestone naming discipline, and the document-internal `Version:` field rules — lives in `Governance/VERSIONING_POLICY.md`. This section is a pointer, not a duplicate.

---

## Planned

- The in-progress milestone on `develop` is **Precision**, targeting **v0.0.14**: the framework made exact and usable — every front-facing surface audited and guarded against drift, and the newcomer's operating path completed and dogfooded. Several open issues exist as individual maintenance/tech-debt items (e.g. #61–#66, #69, #71, #112), but none alone constitutes part of this milestone's scope.
- Portability made the framework adoptable off its own repository, and a first adoption was rehearsed against a real project to find what greenfield never surfaces. A sustained adoption on a real published project outside this repository is the next thing that will decide scope beyond Precision; `Governance/TROUBLESHOOTING.md` exists for what it finds.

---

## Next Milestone

**Precision** — in progress on `develop`, targets **v0.0.14**. The framework made exact and usable: every front-facing surface — README, CLAUDE.md, the Completed section, the documented commands, the Examples, the normative docs — audited and guarded against drift, and the newcomer's operating path completed and dogfooded (Work-Unit registration, the express path for trivial changes, entry-point clarity). Its Work Units are WU-IAENG-260 onward in `Registry/work-units.yml`.

v0.0.12 carried two milestones under one number: Automation and Convergence both completed on `develop` before either shipped, so both are named in that release's `CHANGELOG.md` heading. A number is not reserved for a milestone that never had a release of its own — so nothing was skipped, Portability took **0.0.13**, and the next takes 0.0.14. `Governance/VERSIONING_POLICY.md` records why v0.0.12's two milestones shipped together, and why that is not the naming shortcut the same document forbids.
