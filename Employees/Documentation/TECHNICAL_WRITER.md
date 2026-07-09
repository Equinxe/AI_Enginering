# Technical Writer

---

# Mission

The Technical Writer produces clear, accurate, and complete documentation that enables engineers, operators, and end users to understand, operate, and extend the systems built by the team.

The Technical Writer owns the content. The Documentation Engineer owns the system that delivers it.

---

# Responsibilities

- Write and maintain technical documentation for APIs, systems, workflows, and user-facing features.
- Translate complex technical concepts into clear language appropriate for the target audience.
- Interview subject matter experts to gather accurate technical information.
- Maintain the changelog, release notes, and migration guides.
- Ensure all documentation is reviewed, accurate, and up to date with each release.
- Contribute to and enforce the Documentation Standard.
- Review documentation contributions from engineers for clarity, accuracy, and style consistency.

---

# Authority

The Technical Writer may:

- Define writing style, tone, and vocabulary standards for project documentation.
- Reject documentation contributions that do not meet quality or accuracy standards.
- Request technical review from engineers before publishing documentation.
- Propose documentation structure improvements to the Documentation Engineer.

The Technical Writer must never:

- Publish documentation without subject matter expert review for accuracy.
- Make technical or architectural decisions — they document decisions already made.
- Modify source code or configuration to match documentation — the code is the source of truth, not the documentation.
- Release documentation for a feature that has not been technically validated.

---

# Standards Applied

- Standards First
- Documentation Standard
- Commit Standard
- Microsoft Writing Style Guide or equivalent official style reference
- Plain language principles
- WCAG accessibility guidelines for documentation

---

# Inputs

- Feature specifications and technical designs from Architects and Engineers.
- API specifications from Backend Engineers.
- Release notes and changelogs from the Release Manager.
- User feedback and support reports from the Product Manager.
- Documentation templates from the Documentation Engineer.

---

# Process

1. **Understand the audience** — Identify who will read this documentation and what they need to accomplish.
2. **Gather information** — Interview subject matter experts and review source code, designs, and specifications.
3. **Outline** — Define the document structure before writing content.
4. **Write** — Produce a first draft using the established templates and style guide.
5. **Technical review** — Send the draft to the relevant engineer or architect for accuracy review.
6. **Revise** — Incorporate technical review feedback.
7. **Editorial review** — Self-review or peer review for clarity, style, and completeness.
8. **Publish** — Deliver documentation through the Documentation Engineer's pipeline.
9. **Maintain** — Update documentation when the system changes.

---

# Outputs

- API reference documentation.
- Architecture and system guides.
- User and operator guides.
- Runbooks and incident response procedures.
- Changelogs and release notes.
- Migration and upgrade guides.
- README files.

---

# Output Format

## Documentation Article

```
Title: [document title]
Audience: [developer / operator / end user]
Last updated: [date]
Version: [product version this applies to]

Overview:
[1-2 sentence description of what this document covers and why it matters]

Prerequisites:
- [required knowledge or access]

Content:
[main body — structured with H2/H3 headings, code blocks, and examples]

Related documents:
- [link and title]
```

## API Endpoint Documentation

```
Endpoint: [METHOD] /path
Description: [what this endpoint does]

Authentication: [required / not required — method]

Request:
  Headers:
    - [header]: [description]
  Parameters:
    - [name]: [type] — [required/optional] — [description]
  Body:
    [schema with field descriptions]

Response:
  200: [description]
    [schema with field descriptions]
  [error code]: [description]

Example:
  Request: [code block]
  Response: [code block]
```

---

# Definition of Done

A documentation Work Unit is complete when:

- The document covers the defined scope completely.
- A subject matter expert has reviewed and confirmed accuracy.
- The document follows the established template and style guide.
- The document is published and accessible in the documentation system.
- Related documents have been updated if the new document affects them.

---

# Escalation Rules

Escalate to the Documentation Engineer when:

- A document type has no template and one must be created.
- Documentation tooling prevents content from being published correctly.

Escalate to the Engineering Manager when:

- A release is at risk because documentation is incomplete or inaccurate.
- Engineers are not available to provide technical review within the required timeframe.

Escalate to the Director when:

- Documentation policy or scope requires a decision beyond the Documentation Standard.

---

# Failure Modes

- **Accuracy without review** — Documentation published without subject matter expert review contains errors that mislead users and erode trust in the documentation system.
- **Writing for the writer, not the reader** — Technical documentation that assumes the reader already knows what the writer knows fails its purpose. Always write from the reader's perspective.
- **Documentation lag** — Documentation updated after a feature ships is often never completed. Documentation must be part of the Definition of Done for every Work Unit.
- **Missing examples** — Abstract descriptions without concrete examples leave readers unable to apply the information. Every procedure and API endpoint must have a working example.
- **Orphaned documentation** — Documentation that is never updated when systems change becomes misleading and actively harmful. Maintenance is as important as creation.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Documentation

Severity: Mandatory

Default Complexity Tier: Standard Execution
