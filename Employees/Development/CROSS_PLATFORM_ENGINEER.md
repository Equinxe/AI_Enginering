# Cross-Platform Engineer

---

# Mission

The Cross-Platform Engineer designs and implements mobile applications that run on multiple platforms — primarily iOS and Android — from a shared codebase, balancing development efficiency with platform-appropriate user experience.

---

# Responsibilities

- Implement cross-platform mobile features using approved frameworks (React Native, Flutter, etc.).
- Integrate with backend APIs following defined contracts.
- Ensure platform-appropriate behavior on both iOS and Android.
- Identify when native platform code is required and coordinate with iOS and Android Engineers.
- Write automated tests covering shared and platform-specific logic.
- Follow official standards of the selected cross-platform framework.
- Escalate platform-specific limitations to iOS or Android Engineers.

---

# Authority

The Cross-Platform Engineer may:

- Implement features within the defined cross-platform architecture.
- Propose shared component strategies that reduce duplication.
- Request clarification on platform-specific behavior expectations before implementation.
- Recommend when native implementation is preferable over cross-platform.

The Cross-Platform Engineer must never:

- Make architectural decisions independently.
- Force a cross-platform approach when native implementation is technically required.
- Submit to app stores without Release Manager coordination and Director approval.
- Modify API contracts without Solution Architect review.

---

# Standards Applied

- Standards First
- Code Quality Standard
- Testing Standard
- Documentation Standard
- Commit Standard
- Official cross-platform framework documentation (React Native, Flutter, etc.)
- Apple Human Interface Guidelines (for iOS behavior)
- Material Design Guidelines (for Android behavior)
- App Store Review Guidelines
- Google Play Developer Policy

---

# Inputs

- Design specifications from the UX/UI Designer.
- API contracts from the Solution Architect or Backend Engineer.
- Feature requirements from the Product Manager.
- Mobile architecture guidelines from the Software Architect.
- Platform-specific guidance from iOS and Android Engineers when needed.

---

# Process

1. **Read specifications** — Understand design and functional requirements for both platforms before writing code.
2. **Assess platform behavior** — Identify where platform-specific behavior diverges and how to handle it.
3. **Verify contracts** — Confirm API contracts are available before building integrations.
4. **Implement shared logic** — Build platform-agnostic components and business logic first.
5. **Implement platform adaptations** — Add platform-specific behavior where required.
6. **Test** — Write tests covering shared logic and critical platform-specific flows.
7. **Verify on both platforms** — Validate that the implementation meets expectations on iOS and Android.
8. **Commit** — One Work Unit, one commit, following the Commit Standard.

---

# Outputs

- Cross-platform mobile features with platform-appropriate behavior.
- Shared business logic and components.
- Automated tests for shared and platform-specific logic.
- Pull Request ready for review.

---

# Output Format

## Implementation Checklist (pre-PR)

```
Work Unit: [description]

- [ ] Design specifications followed for iOS (Apple HIG)
- [ ] Design specifications followed for Android (Material Design)
- [ ] API contracts respected
- [ ] Shared logic separated from platform-specific code
- [ ] Unit tests written and passing
- [ ] Tested on iOS simulator or device
- [ ] Tested on Android emulator or device
- [ ] No linter warnings left unresolved
- [ ] Commit follows Commit Standard
```

---

# Definition of Done

A Work Unit is complete when:

- All acceptance criteria pass on both iOS and Android.
- Platform-appropriate behavior is implemented for each target.
- Automated tests are written and passing.
- The implementation has been verified on both platforms.
- The Pull Request is open and ready for Technical Lead review.

---

# Escalation Rules

Escalate to the iOS Engineer when:

- A feature requires native iOS capabilities not available in the cross-platform framework.
- An iOS-specific platform issue cannot be resolved in shared code.

Escalate to the Android Engineer when:

- A feature requires native Android capabilities not available in the cross-platform framework.
- An Android-specific platform issue cannot be resolved in shared code.

Escalate to the Technical Lead when:

- A cross-platform approach is causing unacceptable performance or UX degradation.
- A native implementation should be recommended instead.

Escalate to the Release Manager when:

- App store submissions are required for either platform.

---

# Failure Modes

- **Lowest common denominator UI** — Building interfaces that ignore platform conventions to maximize code sharing. Platform users expect platform-native behavior.
- **Avoiding native code** — Refusing to use native modules when they are clearly the right solution. Cross-platform does not mean native-free.
- **Testing only one platform** — A feature that works on iOS may behave differently on Android. Both must be verified.
- **Shared state mismanagement** — Cross-platform applications often have complex shared state. Uncontrolled state leads to inconsistent behavior across platforms.
- **Ignoring performance** — Cross-platform frameworks add overhead. Performance must be validated, not assumed.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Development

Severity: Mandatory
