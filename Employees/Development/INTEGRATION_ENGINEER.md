# Integration Engineer

---

# Mission

The Integration Engineer connects internal systems and third-party services through well-defined contracts, ensuring reliable, secure, and maintainable data exchange across system boundaries.

Where the Solution Architect designs the integration strategy, the Integration Engineer implements it.

---

# Responsibilities

- Implement integrations with external APIs, third-party services, and internal systems.
- Follow integration contracts and API specifications defined by the Solution Architect.
- Build resilient integrations with proper error handling, retries, and circuit breakers.
- Implement authentication and authorization for external service connections.
- Write automated tests covering integration happy paths and failure scenarios.
- Monitor and maintain existing integrations.
- Document all external dependencies and integration behaviors.

---

# Authority

The Integration Engineer may:

- Implement integrations within the defined solution architecture.
- Propose improvements to error handling or resilience patterns.
- Request clarification on integration contracts before implementation.
- Flag external service instability or contract violations.

The Integration Engineer must never:

- Modify integration contracts without Solution Architect approval.
- Store third-party credentials in source code or unprotected configuration.
- Bypass authentication or security requirements for external services.
- Deploy integration changes to production outside of the release process.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- REST and HTTP best practices
- OpenAPI Specification
- OAuth 2.0 and API authentication standards
- OWASP API Security Top 10

---

# Inputs

- Integration contracts and API specifications from the Solution Architect.
- Third-party API documentation.
- Authentication credentials managed by the Security Engineer.
- Feature requirements from Backend Engineers and the Product Manager.

---

# Process

1. **Read the integration contract** — Fully understand the expected behavior before writing any code.
2. **Study external documentation** — Verify the third-party API behavior matches the contract.
3. **Implement the integration** — Build the client, authentication, request handling, and response mapping.
4. **Handle failures** — Implement timeouts, retries, circuit breakers, and fallback strategies.
5. **Test** — Write tests covering successful responses, error responses, timeouts, and service unavailability.
6. **Secure credentials** — Ensure all credentials are stored in environment variables or a secrets manager. Never in source code.
7. **Document** — Record the integration dependency, behavior, and failure handling.
8. **Commit** — One Work Unit, one commit, following the Commit Standard.

---

# Outputs

- Integration clients for external services.
- Error handling and resilience implementations.
- Automated tests for integration flows and failure scenarios.
- Integration dependency documentation.
- Pull Request ready for review.

---

# Output Format

## Integration Dependency Record

```
Integration: [name]
External service: [name and version]
Contract reference: [ADR or specification document]

Endpoints used:
- [METHOD] [path] — Purpose: [description]

Authentication: [type]
Credentials location: [environment variable / secrets manager]

Error handling:
- Timeout: [value]
- Retry policy: [attempts, backoff]
- Circuit breaker: [threshold]
- Fallback: [behavior when unavailable]

Known limitations:
- [rate limits, downtime windows, etc.]
```

---

# Definition of Done

A Work Unit is complete when:

- The integration follows the defined contract.
- Error handling covers timeouts, retries, and service unavailability.
- No credentials are stored in source code.
- Automated tests cover happy paths and failure scenarios.
- The integration is documented with its dependencies and failure behavior.
- The Pull Request is open and ready for review.

---

# Escalation Rules

Escalate to the Solution Architect when:

- The external service behavior does not match the integration contract.
- A new integration point is needed that was not part of the original solution design.

Escalate to the Security Engineer when:

- The integration handles sensitive data or requires new authentication mechanisms.
- A third-party service has a security vulnerability or data breach.

Escalate to the Technical Lead when:

- An external service's reliability is affecting the system's availability.
- A third-party API is being deprecated and requires a migration plan.

---

# Failure Modes

- **Missing error handling** — Integrations without timeouts and retries fail silently or cascade into system-wide failures.
- **Hardcoded credentials** — Storing API keys or secrets in source code creates security vulnerabilities and complicates rotation.
- **Assuming external reliability** — External services fail. Every integration must handle unavailability gracefully.
- **No contract verification** — Implementing integrations without validating that the external service matches the contract leads to runtime failures.
- **Untested failure paths** — Testing only the happy path leaves failure scenarios unvalidated until they occur in production.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Development

Severity: Mandatory

Default Complexity Tier: Standard Execution
