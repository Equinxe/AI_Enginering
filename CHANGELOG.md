# Changelog

All notable changes to IA Engineering will be documented in this file.

This project follows Semantic Versioning, extended with an informal 4th segment (`MAJOR.MINOR.MILESTONE.FIX`) for post-release consistency fixes that do not warrant a new milestone number. See `VERSION.md` for the versioning policy.

---

## [0.0.8] - Capability Tiers

### Added

- `Core/CAPABILITY_TIERS.md` — two AI-agnostic execution tiers (Strategic Judgment, Standard Execution) the Main Agent uses to match execution capability to Work Unit complexity, without ever naming a specific model, plus a per-Work-Unit Lightweight Override mechanism
- `Employees/` — Default Complexity Tier added to all 42 Employees' Metadata (12 Strategic Judgment: architects, Security Engineer, Compliance Engineer, Penetration Tester, Business Analyst, Data Scientist, AI Engineer, Prompt Engineer, Engineering Manager, Technical Lead; 30 Standard Execution: all others)
- `Core/ORCHESTRATION.md` — Step 4 (Dispatch) now selects execution capability per Capability Tiers before creating each Employee Brief

### Notes

Prioritized ahead of Governance (now v0.0.9) in response to live-test token/session-limit pressure observed during the 2048 game test. This is the framework's only concrete lever for execution efficiency: routing mechanical Work Units to lighter capability while reserving strategic judgment for decisions that need it, without compromising Dispatch Discipline or AI Agnosticism (Principle X).

---

## [0.0.7.5] - ADR Threshold Detection

### Fixed

- `Core/ORCHESTRATION.md` — Step 2 (Analyze) now explicitly cross-references `Workflows/ARCHITECTURE_DECISION.md`'s ADR trigger list instead of leaving "whether an ADR is required" to informal judgment

### Notes

Fifth finding from the live end-to-end test (2048 game leaderboard feature). A persistent leaderboard was implemented directly via the Frontend Engineer using `localStorage`, without recognizing that persistence implies a storage technology decision meeting the existing ADR threshold ("technology selection... database"). The rule to check for an ADR already existed in both `Core/ORCHESTRATION.md` and `Workflows/ARCHITECTURE_DECISION.md`, but the two were never explicitly linked, and a simply-phrased feature request did not visibly trigger the check. This is a documentation clarity gap, not a new rule.

---

## [0.0.7.4] - Verification Over Waiting

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Verification Over Waiting" section: when a dispatched Employee's completion report never arrives, the Main Agent must verify the actual repository state directly (git status/diff/log) instead of stalling on repeated status requests or assuming success from silence

### Notes

Fourth finding from the live end-to-end test (2048 game leaderboard feature). Dispatched Employees repeatedly showed as "finished" in the AI runtime without ever delivering a completion report, and the Main Agent looped on re-requesting status instead of checking the repository directly. This is a runtime dispatch fault, not a framework fault — but the framework can and should make silence non-blocking by requiring direct verification as the fallback source of truth.

---

## [0.0.7.3] - Roster Gaps

### Fixed

- `Core/MAIN_AGENT_CONDUCT.md` — added a "Roster Gaps" section: when a request requires an Employee outside the project's active roster, the Main Agent must stop, propose the roster expansion to the Director, update `CLAUDE.md`, and only then dispatch — instead of silently performing the work itself
- `Core/MAIN_AGENT_CONDUCT.md` — closed a loophole in Dispatch Discipline (v0.0.7.2): naming a subagent by function or tool label (e.g., "executor") instead of by the responsible Employee's name is now explicitly treated as equivalent to not delegating at all

### Notes

Second and third findings from the live end-to-end test (2048 game leaderboard feature). (2) The project's onboarding-time roster excluded Architecture/Backend/Data roles as out of scope for a frontend-only game — when a later request genuinely required a Software Architect ADR and Backend/Database/API Engineers, the Main Agent absorbed the work itself rather than recognizing the scope had changed. (3) After being corrected, the Main Agent did delegate — but to a subagent named "executor" rather than the responsible "Frontend Engineer", satisfying the letter of Dispatch Discipline while discarding its purpose (traceable Mission, Authority, Standards Applied, and Definition of Done).

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

v0.0.9 — Governance
