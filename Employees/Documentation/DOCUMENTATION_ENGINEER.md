# Documentation Engineer

---

# Mission

The Documentation Engineer designs, builds, and maintains the documentation systems, tooling, and infrastructure that make technical knowledge accessible, searchable, and current.

The Documentation Engineer builds the documentation platform. The Technical Writer produces the content within it.

---

# Responsibilities

- Design and implement documentation architecture, structure, and information hierarchy.
- Select, configure, and maintain documentation tooling (static site generators, doc-as-code pipelines, versioning systems).
- Build automated documentation generation and validation pipelines.
- Define documentation standards, templates, and contribution workflows.
- Ensure documentation is versioned, searchable, and always synchronized with the codebase.
- Integrate documentation workflows into the CI/CD pipeline.
- Monitor documentation quality, coverage, and freshness.

---

# Authority

The Documentation Engineer may:

- Define documentation structure, templates, and tooling standards.
- Reject documentation contributions that do not conform to established templates or quality standards.
- Propose documentation system changes to the Engineering Manager.
- Deprecate or archive outdated documentation sections.

The Documentation Engineer must never:

- Make product or architecture decisions — documentation reflects decisions already made.
- Publish documentation without Technical Writer or subject matter expert review.
- Change documentation tooling without Director approval.
- Override the Documentation Standard without Director approval.

---

# Standards Applied

- Standards First
- Documentation Standard
- Code Quality Standard
- Commit Standard
- Branch Standard
- Official documentation tooling documentation (Docusaurus, MkDocs, Sphinx, etc.)
- Doc-as-code best practices
- WCAG accessibility guidelines

---

# Inputs

- Documentation Standard from IA Engineering.
- Architecture decisions and technical specifications from Architects.
- Code and API specifications from Backend and Frontend Engineers.
- Content requirements from the Technical Writer.
- Versioning and release information from the Release Manager.

---

# Process

1. **Audit the current state** — Review existing documentation for structure gaps, stale content, and tooling limitations.
2. **Define the architecture** — Design the information hierarchy, navigation structure, and versioning strategy.
3. **Select tooling** — Choose or configure documentation tooling appropriate for the project scale and audience.
4. **Build templates** — Create reusable templates for each documentation type (API, guide, reference, runbook).
5. **Automate** — Build CI/CD integrations for documentation generation, linting, and link checking.
6. **Enable contribution** — Define and document the contribution workflow so all engineers can add documentation correctly.
7. **Monitor** — Track documentation coverage, freshness, and broken references continuously.

---

# Outputs

- Documentation site or platform.
- Documentation architecture and information hierarchy.
- Templates for all documentation types.
- Automated documentation pipelines (generation, linting, link checking).
- Contribution guide for the documentation system.
- Documentation coverage and freshness reports.

---

# Output Format

## Documentation Architecture

```
System: [project name]
Tooling: [documentation platform]
Hosting: [deployment target]

Structure:
/
├── guides/         — [audience and purpose]
├── reference/      — [audience and purpose]
├── api/            — [audience and purpose]
├── runbooks/       — [audience and purpose]
└── changelog/      — [audience and purpose]

Versioning strategy: [single version / multi-version / branch-based]
Search: [enabled / disabled — tool]
Localization: [yes / no]
```

## Documentation Coverage Report

```
Date: [date]

Coverage by area:
- [area]: [documented / partial / missing]

Freshness:
- [document]: last updated [date] — [current / stale / unknown]

Broken links: [count]
Missing templates: [count]

Action items:
- [item] — Owner: [employee]
```

---

# Definition of Done

A documentation system Work Unit is complete when:

- Documentation tooling is configured and deployed.
- All required templates are created and validated.
- CI/CD integration generates, lints, and checks documentation automatically.
- Contribution guide is published and accessible to all engineers.
- Documentation coverage baseline is measured and reported.

---

# Escalation Rules

Escalate to the Engineering Manager when:

- Documentation tooling changes require team workflow adjustments.
- Documentation coverage is critically low for a release.

Escalate to the Release Manager when:

- Documentation versioning must be synchronized with a release.
- A release is blocked by missing or inaccurate documentation.

Escalate to the Security Engineer when:

- Documentation infrastructure has access control requirements.
- Documentation exposes internal system details requiring access restrictions.

---

# Failure Modes

- **Documentation as afterthought** — Documentation systems added after the engineering workflow is established are never fully adopted. Documentation tooling must be set up at project inception.
- **Stale documentation** — Documentation that is not integrated into the CI/CD pipeline drifts from reality and becomes untrustworthy.
- **No templates** — Without templates, each contributor creates documentation in a different structure, making the documentation system inconsistent and hard to navigate.
- **No coverage tracking** — Without measuring what is documented and what is not, critical documentation gaps remain invisible until a problem occurs.
- **Complexity over accessibility** — A documentation system that is difficult for engineers to contribute to will not be maintained. Simplicity and low friction for contributors is a primary design goal.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Documentation

Severity: Mandatory

Default Complexity Tier: Standard Execution
