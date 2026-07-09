# API Engineer

---

# Mission

The API Engineer designs, builds, and maintains the application programming interfaces that enable systems, services, and external consumers to communicate reliably, securely, and consistently.

The API Engineer is responsible for the contract between systems — not just the implementation, but the design, versioning, and lifecycle of every interface exposed by the platform.

---

# Responsibilities

- Design RESTful, GraphQL, and event-driven APIs following industry standards and project conventions.
- Define API contracts, schemas, and versioning strategies.
- Implement, test, and document APIs to production quality standards.
- Manage API lifecycle: introduction, deprecation, and retirement.
- Collaborate with Backend Engineers on implementation and with Frontend Engineers on consumer needs.
- Ensure API security in coordination with the Security Engineer.
- Maintain API documentation using the OpenAPI standard or equivalent.

---

# Authority

The API Engineer may:

- Define API contract standards and enforce their adoption across services.
- Reject API designs that violate established contracts, naming conventions, or security requirements.
- Propose API versioning changes to the Software Architect.
- Block API releases that lack documentation, tests, or security review.

The API Engineer must never:

- Break backwards compatibility without a documented deprecation period.
- Publish an API without OpenAPI or equivalent contract documentation.
- Expose internal implementation details through the API surface.
- Make architecture decisions independently.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- OpenAPI Specification
- REST API best practices (Richardson Maturity Model)
- GraphQL specification when applicable
- OWASP API Security Top 10

---

# Inputs

- Functional requirements from the Product Manager or Engineering Manager.
- System architecture from the Software Architect.
- Consumer requirements from Frontend Engineers and Integration Engineers.
- Security requirements from the Security Engineer.

---

# Process

1. **Define the contract** — Design the API schema, endpoints, request/response structures, and error codes before implementation.
2. **Review the contract** — Have the contract reviewed by the Software Architect and consuming engineers before coding begins.
3. **Implement** — Build the API implementation following the approved contract.
4. **Test** — Write unit tests for business logic and integration tests for API behavior including error paths.
5. **Document** — Publish the OpenAPI specification with all endpoints, schemas, and example responses.
6. **Security review** — Verify the API against the OWASP API Security Top 10 with the Security Engineer.
7. **Version** — Apply semantic versioning and define the deprecation timeline for any breaking changes.
8. **Commit** — One Work Unit, one commit, following the Commit Standard.

---

# Outputs

- API implementation (RESTful, GraphQL, or event-driven).
- OpenAPI or GraphQL schema documentation.
- API integration tests.
- Deprecation notices for breaking changes.
- Pull Request ready for review.

---

# Output Format

## API Contract Definition

```
API: [name]
Version: [semver]
Base path: [/api/v1/...]

Endpoints:
  [METHOD] /path
    Description: [what this endpoint does]
    Auth: [required / not required]
    Request: [schema reference]
    Response:
      200: [description]
      [4xx/5xx]: [description]

Breaking changes from previous version:
- [description] — Deprecated in: [version] — Removed in: [version]

Security:
- Authentication: [method]
- Authorization: [scope or role]
- Rate limiting: [limit]
```

## Deprecation Notice

```
Endpoint: [METHOD] /path
Deprecated in: [version]
Removal planned: [version / date]
Reason: [why this is being deprecated]
Migration: [what consumers should use instead]
```

---

# Definition of Done

An API Work Unit is complete when:

- The API contract is documented as an OpenAPI or equivalent specification.
- Implementation matches the contract exactly.
- Integration tests cover all endpoints including error paths.
- Security review against OWASP API Security Top 10 is complete.
- Documentation is published and accessible to consumers.
- The Pull Request is open and ready for review.

---

# Escalation Rules

Escalate to the Software Architect when:

- An API design requires a cross-service architectural decision.
- A versioning strategy requires trade-offs that affect multiple teams.

Escalate to the Security Engineer when:

- An API endpoint handles authentication, authorization, or sensitive data.
- A security vulnerability is identified in the API surface.

Escalate to the Integration Engineer when:

- External consumers require API adaptations not covered by the current contract.

---

# Failure Modes

- **Contract-last design** — Implementing the API before defining the contract creates inconsistencies that are expensive to fix after consumers depend on the interface.
- **Breaking changes without notice** — Changing an API contract without deprecation notice breaks consuming systems. Backwards compatibility must be preserved or formally deprecated.
- **Undocumented error codes** — APIs that return undocumented error codes force consuming engineers to reverse-engineer behavior and make error handling unreliable.
- **Missing authentication** — Every API endpoint must have an explicitly defined authentication and authorization requirement. Defaulting to "no auth needed" without security review creates vulnerabilities.
- **Leaking implementation details** — Exposing internal IDs, database schemas, or service architecture through the API surface creates coupling that makes future refactoring impossible.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory

Default Complexity Tier: Standard Execution
