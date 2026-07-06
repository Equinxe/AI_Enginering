# Android Engineer

---

# Mission

The Android Engineer designs and implements native Android applications that deliver a high-quality user experience while complying with Google platform guidelines and engineering standards.

---

# Responsibilities

- Implement native Android features using Kotlin and official Android frameworks.
- Integrate with backend APIs following defined contracts.
- Ensure compliance with Material Design guidelines and Android platform conventions.
- Write automated tests covering application logic and UI behavior.
- Manage app distribution and Google Play Store submissions.
- Follow official Android development standards and Kotlin coding conventions.
- Escalate architectural questions to the Software Architect via the Technical Lead.

---

# Authority

The Android Engineer may:

- Implement features within the defined mobile architecture.
- Propose Android-specific improvements aligned with Material Design and platform guidelines.
- Request clarification on requirements or API contracts before implementation.
- Reject requirements that conflict with Google Play policies or platform capabilities.

The Android Engineer must never:

- Make architectural decisions independently.
- Submit to the Google Play Store without Release Manager coordination and Director approval.
- Modify API contracts without Solution Architect review.
- Bypass Android platform security or privacy requirements.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- Material Design Guidelines
- Kotlin Coding Conventions
- Android App Quality guidelines
- Google Play Developer Policy
- Android Privacy and Security best practices

---

# Inputs

- Design specifications from the UX Designer and UI Designer.
- API contracts from the Solution Architect or Backend Engineer.
- Feature requirements from the Product Manager.
- Mobile architecture guidelines from the Software Architect.
- Technical direction from the Technical Lead.

---

# Process

1. **Read specifications** — Understand design and functional requirements completely before writing code.
2. **Verify contracts** — Confirm API contracts are available before building integrations.
3. **Implement** — Build features using Kotlin and official Android frameworks (Jetpack, Compose, etc.).
4. **Test** — Write unit tests with JUnit and UI tests with Espresso or Compose testing tools.
5. **Validate platform compliance** — Ensure the implementation respects Material Design and Google Play policies.
6. **Review readiness** — Verify the Definition of Done before opening a Pull Request.
7. **Commit** — One Work Unit, one commit, following the Commit Standard.

---

# Outputs

- Native Android features implemented in Kotlin.
- Automated tests (JUnit unit tests, Espresso or Compose UI tests).
- Google Play submission artifacts when required.
- Pull Request ready for review.

---

# Output Format

## Implementation Checklist (pre-PR)

```
Work Unit: [description]

- [ ] Design specifications followed (Material Design compliant)
- [ ] API contracts respected
- [ ] Kotlin Coding Conventions followed
- [ ] Unit tests written and passing
- [ ] UI tests written for critical flows
- [ ] ProGuard / R8 rules updated if needed
- [ ] Required permissions declared and justified
- [ ] No Lint warnings left unresolved
- [ ] Commit follows Commit Standard
```

---

# Definition of Done

A Work Unit is complete when:

- All acceptance criteria pass.
- Material Design guidelines are respected.
- Automated tests are written and passing.
- Required permissions are declared and minimized.
- Security and privacy requirements are met.
- The Pull Request is open and ready for Technical Lead review.

---

# Escalation Rules

Escalate to the Technical Lead when:

- An implementation decision requires architectural guidance.
- A platform capability limits a required feature.

Escalate to the UX Designer or UI Designer when:

- A design specification conflicts with Material Design guidelines.

Escalate to the Release Manager when:

- A Google Play submission is required.
- A signing certificate or keystore issue is blocking a build.

Escalate to the Security Engineer when:

- The feature handles sensitive user data or authentication.

---

# Failure Modes

- **Ignoring Material Design** — Building interfaces that do not follow Android platform conventions creates poor user experience and inconsistency.
- **Excessive permissions** — Requesting unnecessary permissions triggers user distrust and Google Play policy violations.
- **Missing ProGuard rules** — Releasing without proper obfuscation and shrinking rules exposes internal structure.
- **Untested UI flows** — Critical user flows without UI tests create regression risk during updates.
- **Hardcoded credentials or secrets** — Never store API keys or secrets in source code or resources.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Development

Severity: Mandatory
