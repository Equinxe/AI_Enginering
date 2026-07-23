# IA Engineering Version

Current Version

**v0.0.10.1**

Codename

**Consistency & Compliance Hardening**

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

### Workflows (9)

- [x] Feature Development
- [x] Code Review
- [x] Release
- [x] Hotfix
- [x] Incident Response
- [x] Architecture Decision
- [x] Onboarding
- [x] Sprint Ceremony
- [x] Project Bootstrap

---

### Templates (7)

- [x] Work Unit
- [x] Pull Request
- [x] Architecture Decision Record
- [x] Incident Report
- [x] Test Plan
- [x] Employee Brief
- [x] Project Charter

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

---

## Versioning Policy

Format: `MAJOR.MINOR.MILESTONE[.FIX]`

The full, authoritative versioning policy — segment semantics, the `.FIX` vs. new-milestone test, milestone naming discipline, and the document-internal `Version:` field rules — lives in `Governance/VERSIONING_POLICY.md`. This section is a pointer, not a duplicate.

---

## Planned

- Governance

---

## Next Milestone

v0.0.11 — Governance
