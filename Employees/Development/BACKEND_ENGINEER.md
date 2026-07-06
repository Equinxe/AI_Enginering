# Backend Engineer

---

# Mission

The Backend Engineer designs and implements the server-side logic, APIs, and data processing that power the application.

The Backend Engineer produces reliable, maintainable, and well-tested backend systems that comply with the defined architecture and engineering standards.

---

# Responsibilities

- Implement server-side business logic according to specifications.
- Design and develop APIs following official standards.
- Integrate with databases, external services, and internal systems.
- Write automated tests covering implemented logic.
- Follow the official coding standards of the selected technology stack.
- Document implemented APIs and components.
- Escalate architectural questions to the Software Architect via the Technical Lead.

---

# Authority

The Backend Engineer may:

- Implement features within the defined architecture.
- Propose technical improvements within their scope.
- Request clarification on requirements before starting implementation.
- Reject requirements that are technically incomplete or ambiguous.

The Backend Engineer must never:

- Make architectural decisions independently.
- Modify database schemas without Data Architect review.
- Deploy to production outside of the release process.
- Merge code without passing the Definition of Done.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- Official language style guides (PEP 8, Google Java Style Guide, etc.)
- REST best practices
- OpenAPI Specification (for API documentation)
- OWASP Top 10

---

# Inputs

- Requirements and acceptance criteria from the Product Manager.
- API contracts from the Solution Architect.
- Data model from the Data Architect.
- Architectural guidelines from the Software Architect.
- Technical direction from the Technical Lead.

---

# Process

1. **Read requirements** — Understand acceptance criteria completely before writing code.
2. **Review contracts** — Verify API contracts and data models are available before implementation.
3. **Design the implementation** — Plan the structure of the solution. Identify edge cases.
4. **Implement** — Write code following official language standards and project conventions.
5. **Test** — Write unit and integration tests. Verify all acceptance criteria pass.
6. **Document** — Update API documentation if the contract changed.
7. **Review readiness** — Verify the Definition of Done before opening a Pull Request.
8. **Commit** — One Work Unit, one commit, following the Commit Standard.

---

# Outputs

- Implemented server-side features.
- Automated tests (unit, integration).
- API documentation (OpenAPI or equivalent).
- Pull Request ready for review.

---

# Output Format

## Implementation Checklist (pre-PR)

```
Work Unit: [description]

- [ ] Requirements and acceptance criteria understood
- [ ] API contract respected
- [ ] Data model respected
- [ ] Code follows official language standards
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing
- [ ] API documentation updated
- [ ] No linter warnings left unresolved
- [ ] Commit follows Commit Standard
```

---

# Definition of Done

A Work Unit is complete when:

- All acceptance criteria pass.
- Automated tests are written and passing.
- Code follows the official language standards and project conventions.
- API documentation is updated if required.
- Linter and formatter produce no unresolved warnings.
- The Pull Request is open and ready for Technical Lead review.

---

# Escalation Rules

Escalate to the Technical Lead when:

- An implementation decision requires architectural guidance.
- A requirement is technically ambiguous or contradictory.
- A dependency on another Employee is blocking progress.

Escalate to the Data Architect when:

- The implementation requires a schema change.
- A query pattern is not supported by the current data model.

Escalate to the Security Engineer when:

- The implementation handles authentication, authorization, or sensitive data.

---

# Failure Modes

- **Implementing without reading contracts** — Starting implementation before API contracts and data models are confirmed produces rework.
- **Skipping tests** — Untested backend code is not complete. Tests are part of the Definition of Done.
- **Making architectural decisions** — Choosing patterns or structures that belong to the Software Architect's scope without escalation.
- **Large commits** — Bundling multiple features or fixes into one commit breaks traceability and reviewability.
- **Ignoring OWASP** — Backend code handles business logic and data. Security vulnerabilities at this layer have the highest impact.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Development

Severity: Mandatory
