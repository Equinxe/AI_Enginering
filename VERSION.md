# IA Engineering Version

Current Version

**v0.0.9**

Codename

**Adapters**

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
- [x] Development: Backend Engineer, Frontend Engineer, iOS Engineer, Android Engineer, Cross Platform Engineer, Database Engineer, Event Driven Engineer, Integration Engineer
- [x] DevOps: DevOps Engineer, GitOps Engineer, SRE Engineer, Cloud Engineer, Platform Engineer, IaC Engineer, Observability Engineer
- [x] Quality: QA Engineer, Performance Engineer, Security Engineer, Test Automation Engineer
- [x] Data: Data Engineer, ML Engineer, Data Scientist, MLOps Engineer, Analytics Engineer
- [x] Documentation: Documentation Engineer, Technical Writer
- [x] Specialized: API Engineer, Code Reviewer, Compliance Engineer, Penetration Tester, Business Analyst, AI Engineer, Prompt Engineer, UX/UI Designer

---

### Workflows (8)

- [x] Feature Development
- [x] Code Review
- [x] Release
- [x] Hotfix
- [x] Incident Response
- [x] Architecture Decision
- [x] Onboarding
- [x] Sprint Ceremony

---

### Templates (6)

- [x] Work Unit
- [x] Pull Request
- [x] Architecture Decision Record
- [x] Incident Report
- [x] Test Plan
- [x] Employee Brief

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

---

## Versioning Policy

Format: `MAJOR.MINOR.MILESTONE[.FIX]`

- `MAJOR.MINOR` remain `0.0` until the framework reaches a stable public release.
- `MILESTONE` increments once per completed milestone (Foundation, Standards, Employees, Workflows, Templates, Orchestration, Examples, Capability Tiers, Governance, Adapters, ...).
- `.FIX` is an optional 4th segment used only for post-release consistency corrections that do not introduce new capability and do not warrant consuming the next milestone number.

---

## Planned

- Governance

---

## Next Milestone

v0.0.10 — Governance
