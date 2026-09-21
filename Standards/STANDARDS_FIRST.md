# Standards First

---

# Purpose

IA Engineering is built on existing industry standards.

Its purpose is not to replace official standards, but to orchestrate and apply them consistently across projects.

---

# Principles

## Official Standards First

Whenever an official standard exists, it must be used.

IA Engineering does not redefine or replace existing standards without a documented justification.

---

## Industry Best Practices

If no official standard exists, IA Engineering follows widely accepted industry best practices.

---

## IA Engineering Additions

IA Engineering only defines rules that orchestrate the use of standards.

These additions must never conflict with official standards.

---

## Documented Deviations

If a project intentionally deviates from an official standard, the deviation must be:

- documented;
- justified;
- approved.

---

# Standard Hierarchy

This hierarchy governs **which body of engineering standards applies to the work product** — the code, documents, and artifacts an Employee produces. It is a separate axis from **which framework document governs a decision**, which `Core/AI_MANIFEST.md`'s Decision Hierarchy defines. The two never compete: one ranks engineering standards, the other ranks framework documents.

Every project follows the same priority order.

1. Official Standards
2. Industry Best Practices
3. Project Standards
4. IA Engineering Standards

---

# Governed Precedence — Project Convention vs Framework Standard

The priority order above answers "project convention or framework Standard — which wins?" one way in every case, so the two never both silently apply to the same decision:

1. **Official and external standards apply first.** Where an official standard governs (see *Official Standards First* above), the framework never overrides it.
2. **Where no official standard governs, the framework's Standards are the default and apply.** A framework Standard is not a suggestion a local habit may quietly displace.
3. **A project may set a stricter or more specific Project Standard, or deviate from a framework default, only through a Documented Deviation** — documented, justified, approved (see *Documented Deviations* above). An *undocumented* local convention never silently wins over a framework Standard; absent an approved deviation, the framework default holds.
4. **Framework governance and process Standards are not overridable by project context at all.** Work Unit discipline, `Standards/COMMIT_STANDARD.md`, `Standards/RISK_STANDARD.md`, and the mandatory review and approval gates bind every project regardless of local convention. They sit outside the deviation mechanism, not inside it as a stricter application.

---

# Responsibilities

Every Employee must:

- identify applicable standards;
- apply them correctly;
- avoid inventing new rules;
- document any justified deviation.

---

# Rationale

Following existing standards provides:

- predictable engineering;
- easier onboarding;
- interoperability;
- maintainability;
- better AI consistency.

---

# References

Examples of applicable standards include:

- Git
- Conventional Commits
- OpenAPI
- OWASP
- PEP 8
- Docker Best Practices
- RFCs
- Language-specific style guides

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Core Principle

Severity: Mandatory
