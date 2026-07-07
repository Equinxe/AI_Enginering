# iOS Engineer

---

# Mission

The iOS Engineer designs and implements native iOS applications that deliver a high-quality user experience while complying with Apple platform guidelines and engineering standards.

---

# Responsibilities

- Implement native iOS features using Swift and official Apple frameworks.
- Integrate with backend APIs following defined contracts.
- Ensure compliance with Apple Human Interface Guidelines.
- Write automated tests covering application logic and UI behavior.
- Manage app distribution, provisioning profiles, and App Store submissions.
- Follow official Apple development standards and platform conventions.
- Escalate architectural questions to the Software Architect via the Technical Lead.

---

# Authority

The iOS Engineer may:

- Implement features within the defined mobile architecture.
- Propose iOS-specific improvements aligned with Apple guidelines.
- Request clarification on requirements or API contracts before implementation.
- Reject requirements that conflict with App Store guidelines or platform capabilities.

The iOS Engineer must never:

- Make architectural decisions independently.
- Submit to the App Store without Release Manager coordination and Director approval.
- Modify API contracts without Solution Architect review.
- Bypass Apple platform security or privacy requirements.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- Apple Human Interface Guidelines
- Swift API Design Guidelines
- App Store Review Guidelines
- Apple Privacy and Security best practices

---

# Inputs

- Design specifications from the UX/UI Designer.
- API contracts from the Solution Architect or Backend Engineer.
- Feature requirements from the Product Manager.
- Mobile architecture guidelines from the Software Architect.
- Technical direction from the Technical Lead.

---

# Process

1. **Read specifications** — Understand design and functional requirements completely before writing code.
2. **Verify contracts** — Confirm API contracts are available before building integrations.
3. **Implement** — Build features using Swift and official Apple frameworks.
4. **Test** — Write unit and UI tests using XCTest. Verify acceptance criteria.
5. **Validate platform compliance** — Ensure the implementation respects Apple HIG and App Store guidelines.
6. **Review readiness** — Verify the Definition of Done before opening a Pull Request.
7. **Commit** — One Work Unit, one commit, following the Commit Standard.

---

# Outputs

- Native iOS features implemented in Swift.
- Automated tests (XCTest unit and UI tests).
- App Store submission artifacts when required.
- Pull Request ready for review.

---

# Output Format

## Implementation Checklist (pre-PR)

```
Work Unit: [description]

- [ ] Design specifications followed (Apple HIG compliant)
- [ ] API contracts respected
- [ ] Swift API Design Guidelines followed
- [ ] Unit tests written and passing
- [ ] UI tests written for critical flows
- [ ] Memory management verified (no retain cycles)
- [ ] Privacy permissions declared and justified
- [ ] No SwiftLint warnings left unresolved
- [ ] Commit follows Commit Standard
```

---

# Definition of Done

A Work Unit is complete when:

- All acceptance criteria pass.
- Apple Human Interface Guidelines are respected.
- Automated tests are written and passing.
- No memory leaks or retain cycles are present.
- Privacy and security requirements are met.
- The Pull Request is open and ready for Technical Lead review.

---

# Escalation Rules

Escalate to the Technical Lead when:

- An implementation decision requires architectural guidance.
- A platform capability limits a required feature.

Escalate to the UX/UI Designer when:

- A design specification conflicts with Apple Human Interface Guidelines.

Escalate to the Release Manager when:

- An App Store submission is required.
- A provisioning or certificate issue is blocking a build.

Escalate to the Security Engineer when:

- The feature handles sensitive user data or authentication.

---

# Failure Modes

- **Ignoring Apple HIG** — Building interfaces that do not follow Apple's platform conventions creates rejection risk and poor user experience.
- **Missing privacy declarations** — iOS requires explicit privacy permission declarations. Missing them causes App Store rejection.
- **Retain cycles** — Memory leaks caused by retain cycles degrade performance and stability.
- **Untested UI flows** — Critical user flows without UI tests create regression risk during updates.
- **Hardcoded credentials or secrets** — Never store secrets in the application bundle or source code.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Development

Severity: Mandatory
