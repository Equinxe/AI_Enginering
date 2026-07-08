# Changelog

All notable changes to IA Engineering will be documented in this file.

This project follows Semantic Versioning, extended with an informal 4th segment (`MAJOR.MINOR.MILESTONE.FIX`) for post-release consistency fixes that do not warrant a new milestone number. See `VERSION.md` for the versioning policy.

---

## [0.0.7.3] - Roster Gaps

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Roster Gaps" section: when a request requires an Employee outside the project's active roster, the Main Agent must stop, propose the roster expansion to the Director, update `CLAUDE.md`, and only then dispatch — instead of silently performing the work itself

### Notes

Second finding from the live end-to-end test (2048 game leaderboard feature). The project's onboarding-time roster excluded Architecture/Backend/Data roles as out of scope for a frontend-only game. When a later request (persistent leaderboard) genuinely required a Software Architect ADR and Backend/Database/API Engineers, the Main Agent absorbed the work itself rather than recognizing the scope had changed. A roster gap is a scope signal that must reach the Director, not something the Main Agent routes around.

---

## [0.0.7.2] - Dispatch Discipline

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Dispatch Discipline" section mandating Employee Brief dispatch for every delegation, forbidding substitution of native/generic AI runtime subagents for a named Employee

### Notes

Finding from the first live end-to-end test of IA Engineering on a real project (a browser 2048 game). The Main Agent defaulted to a generic native reviewer subagent instead of dispatching to the Code Reviewer, QA Engineer, and Security Engineer through Employee Briefs, because the conduct document told it what to do but never explicitly forbade this substitution. This is a direct application of Core Principle IX (Continuous Improvement): every project should improve the framework.

---

## [0.0.7.1] - Audit Fixes

### Fixed

- `Core/GLOSSARY.MD` renamed to `Core/GLOSSARY.md` — fixes broken references on case-sensitive filesystems (Linux/CI)
- `Core/AGENT_CONDUCT.md`, `DECISION_TREE.md`, `GLOSSARY.md`, `MAIN_AGENT_CONDUCT.md` — version corrected from `0.1.0` to `0.0.1` to match the Foundation milestone
- `Core/AI_MANIFEST.md` — added missing Document Metadata section
- `Core/AI_MANIFEST.md` — decision hierarchy corrected to list Employees before Workflows, aligning with `CLAUDE.md` and `README.md`
- `Core/GLOSSARY.md` — added missing "Director" and "Chain (Agent Chain)" entries
- `Prompts/` — added missing directory placeholder (documented in `CLAUDE.md` but absent on disk)
- `README.md` — full refresh from v0.0.2 to v0.0.7: completed list, framework hierarchy diagram, repository structure, roadmap
- `Employees/Development/FRONTEND_ENGINEER.md`, `IOS_ENGINEER.md`, `ANDROID_ENGINEER.md`, `CROSS_PLATFORM_ENGINEER.md` — "UX Designer and UI Designer" corrected to the single combined `UX/UI Designer` role
- `Employees/Architecture/DATA_ARCHITECT.md` — ADR ID convention aligned to `ADR-[project]-[number]`
- `Employees/Quality/SECURITY_ENGINEER.md` — vulnerability ID convention aligned to `SEC-[project]-[number]`
- `Employees/Quality/QA_ENGINEER.md` — Test Case ID convention aligned to `TC-[project]-[number]`
- `Workflows/FEATURE_DEVELOPMENT.md` — non-existent "Mobile Engineer" actor replaced with the actual iOS/Android/Cross Platform Engineer roles; Business Analyst added to the Actors table
- `Workflows/HOTFIX.md`, `RELEASE.md` — Observability Engineer added to the Actors table (was used in steps but not declared)
- `Examples/INCIDENT_CHAIN_EXAMPLE.md` — now uses the Incident Commander role defined in `Workflows/INCIDENT_RESPONSE.md`
- `Examples/ARCHITECTURE_CHAIN_EXAMPLE.md` — "Recommendation" renamed to "Decision" to match `Templates/ADR.md`

### Notes

These fixes came from a full content and consistency audit of all 65 repository files performed after v0.0.7. No content or behavior changes beyond consistency — documentation accuracy only.

---

## [0.0.7] - Examples

### Added

- 6 end-to-end chain walkthroughs on a single fictional project (TaskFlow): Feature, Review, Release, Hotfix, Incident, Architecture Chains
- `Examples/README.md` — index and recommended reading order

### Notes

This release makes the Orchestration Protocol and Agent Chains concrete. Each example shows real Work Units, Employee Briefs, and templates filled in, and shows how chains hand off into each other (Incident → Hotfix, Architecture → Feature). Combined with all prior milestones, the framework has everything needed for a real end-to-end test on a new project.

---

## [0.0.6] - Orchestration

### Added

- `Core/ORCHESTRATION.md` — Main Agent dispatch protocol: receive, analyze, plan, dispatch, collect, review, deliver
- `Core/AGENT_CHAINS.md` — 6 named orchestration chains: Feature, Review, Release, Hotfix, Incident, Architecture

### Fixed

- `CLAUDE.md` version updated from v0.0.2 to v0.0.5 (was outdated since Templates milestone)
- `MAIN_AGENT_CONDUCT.md` now references ORCHESTRATION.md and AGENT_CHAINS.md

### Notes

This release formalizes the orchestration layer — how the Main Agent receives a Director request, decomposes it into Work Units, dispatches Employee Briefs, collects outputs, and delivers a validated result. Combined with the 42 Employees, 8 Workflows, and 6 Templates from previous milestones, the framework is now ready for end-to-end testing on a real project.

---

## [0.0.5] - Templates

### Added

- 6 Engineering Templates: Work Unit, Pull Request, Architecture Decision Record, Incident Report, Test Plan, Employee Brief
- Employee Brief template formalizes the Context Engine: employees receive only the context they need, never the whole repository

### Notes

This release delivers the complete IA Engineering template library. Combined with Employees (v0.0.3) and Workflows (v0.0.4), every engineering action now has a standard format. The framework is ready for orchestration.

---

## [0.0.4] - Workflows

### Added

- 8 Engineering Workflows: Feature Development, Code Review, Release, Hotfix, Incident Response, Architecture Decision, Onboarding, Sprint Ceremony
- Each workflow defines: Trigger, Actors, Prerequisites, Step-by-step process with handoffs, Exit Criteria, Escalation rules

### Notes

This release delivers the complete IA Engineering workflow library. Combined with the 42 Employees from v0.0.3, the framework can now orchestrate end-to-end engineering sequences from requirements to production.

---

## [0.0.3] - Employees

### Added

- 42 AI Employee definitions across 8 categories: Management, Architecture, Development, DevOps, Quality, Data, Documentation, Specialized
- Each Employee defines: Mission, Responsibilities, Authority, Standards Applied, Inputs, Process, Outputs, Output Format, Definition of Done, Escalation Rules, Failure Modes

### Notes

This release delivers the complete IA Engineering employee library. Every employee is an operational manual — not a role description — defining precisely what the employee does, what authority they hold, and what constitutes completion.

---

## [0.0.2] - Engineering Standards

### Added

- Standards First
- Git Standard
- Commit Standard
- Branch Standard
- Pull Request Standard
- Documentation Standard
- Code Quality Standard
- Testing Standard

### Notes

This release establishes the complete engineering standards library used by all IA Engineering Employees, Workflows, and Projects.

---

## [0.0.1] - Foundation

### Added

- AI Manifest
- README
- Glossary
- Decision Tree
- Main Agent Conduct
- Agent Conduct

### Notes

Initial foundation of the IA Engineering framework.

This release establishes the core principles and behavioral contracts that all future components will inherit.

---

## Next

v0.0.8 — Governance
