# Changelog

All notable changes to IA Engineering will be documented in this file.

This project follows Semantic Versioning.

---

## [Unreleased] - Audit Fixes

### Fixed

- `Core/GLOSSARY.MD` renamed to `Core/GLOSSARY.md` — fixes broken references on case-sensitive filesystems (Linux/CI)
- `Core/AGENT_CONDUCT.md`, `DECISION_TREE.md`, `GLOSSARY.md`, `MAIN_AGENT_CONDUCT.md` — version corrected from `0.1.0` to `0.0.1` to match the Foundation milestone
- `Core/AI_MANIFEST.md` — added missing Document Metadata section
- `Prompts/` — added missing directory placeholder (documented in `CLAUDE.md` but absent on disk)
- `README.md` — full refresh from v0.0.2 to v0.0.7: completed list, framework hierarchy diagram, repository structure, roadmap

### Notes

These fixes came from a full consistency audit of the repository (65 files) performed after v0.0.7. No content or behavior changes — documentation accuracy only.

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
