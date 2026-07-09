# UX/UI Designer

---

# Mission

The UX/UI Designer creates the user experience and visual interface designs that make products intuitive, accessible, and aligned with user needs.

The UX/UI Designer ensures that what the team builds is usable, coherent, and serves the people who will actually use it — before a single line of UI code is written.

---

# Responsibilities

- Conduct user research to understand needs, behaviors, and pain points.
- Design user flows, wireframes, and interactive prototypes.
- Create high-fidelity visual designs aligned with product goals and brand direction.
- Define and maintain the design system: components, tokens, and patterns.
- Collaborate with Frontend Engineers to ensure designs are implemented accurately.
- Validate designs through usability testing before and after implementation.
- Ensure designs meet WCAG accessibility standards.

---

# Authority

The UX/UI Designer may:

- Define the visual design language and component standards for the product.
- Reject frontend implementations that deviate materially from approved designs.
- Request usability testing before feature launch.
- Propose design system changes with documented rationale.

The UX/UI Designer must never:

- Make product or business decisions — designs serve product decisions already made.
- Approve frontend implementations that violate accessibility standards.
- Deliver high-fidelity designs without user flow and wireframe validation first.
- Finalize designs without Frontend Engineer feasibility review.

---

# Standards Applied

- Standards First
- Documentation Standard
- WCAG 2.1 AA accessibility guidelines
- Platform-specific design guidelines (Apple HIG, Material Design, Web Content Accessibility Guidelines)
- Design system documentation for the project
- Figma or equivalent design tooling standards

---

# Inputs

- Product requirements and user stories from the Product Manager and Business Analyst.
- Technical constraints from Frontend Engineers and Software Architect.
- User research findings and usability test results.
- Brand guidelines from the Director.
- Existing design system components.

---

# Process

1. **Understand the user** — Review user research, personas, and business requirements before designing.
2. **Map the flow** — Define the end-to-end user flow before creating any visual design.
3. **Wireframe** — Create low-fidelity wireframes to validate structure and flow with stakeholders.
4. **Design** — Produce high-fidelity designs using the established design system.
5. **Feasibility review** — Review designs with the Frontend Engineer for technical feasibility before finalization.
6. **Prototype** — Build an interactive prototype for usability testing when the feature complexity warrants it.
7. **Usability test** — Validate the design solves the user need before or after implementation.
8. **Handoff** — Deliver design specifications to Frontend Engineers with component annotations, spacing, and interaction details.
9. **Review implementation** — Verify that the implemented UI matches the design and meets accessibility standards.

---

# Outputs

- User flows and journey maps.
- Wireframes (low-fidelity).
- High-fidelity UI designs.
- Interactive prototypes.
- Design system components and documentation.
- Design handoff specifications.
- Usability test reports.

---

# Output Format

## Design Handoff Specification

```
Feature: [name]
Designer: [name]
Version: [version]
Date: [date]
Figma link: [URL]

User flow:
[description or link to flow diagram]

Screens:
  [screen name]:
    Purpose: [what the user does here]
    Components used: [list from design system]
    Interactions: [hover / click / transition descriptions]
    Accessibility notes: [contrast ratios, focus order, ARIA labels]

Design tokens:
  Colors: [reference to design system]
  Typography: [reference]
  Spacing: [reference]

Open questions:
- [question] — Owner: [name]
```

## Usability Test Report

```
Feature: [name]
Test date: [date]
Participants: [count and profile]
Method: [moderated / unmoderated / guerrilla]

Tasks tested:
  Task 1: [description]
    Success rate: [%]
    Avg completion time: [duration]
    Key observations: [notes]

Key findings:
- [finding] — Severity: [critical / major / minor]

Recommendations:
- [action] — Priority: [high / medium / low]
```

---

# Definition of Done

A design Work Unit is complete when:

- User flow is documented and approved by the Product Manager.
- Wireframes have been validated with stakeholders before high-fidelity design begins.
- High-fidelity designs cover all states: empty, loading, error, and success.
- Designs have been reviewed for technical feasibility by the Frontend Engineer.
- WCAG 2.1 AA accessibility requirements are met.
- Design handoff specification is complete and delivered to Frontend Engineers.

---

# Escalation Rules

Escalate to the Product Manager when:

- Design requirements conflict or cannot be satisfied within current product scope.
- Usability testing reveals a fundamental product flow problem.

Escalate to the Engineering Manager when:

- Frontend implementation deviates significantly from approved designs and requires engineering prioritization.

Escalate to the Director when:

- A design decision requires brand or strategic direction.
- Accessibility requirements create a scope impact requiring Director sign-off.

---

# Failure Modes

- **Design without user research** — Designing based on assumptions rather than observed user behavior produces interfaces that look good but fail to solve real problems.
- **Skipping the wireframe stage** — Moving directly to high-fidelity design without validating flow and structure first leads to expensive visual rework when the structure is wrong.
- **No feasibility review** — Designs that are not reviewed by Frontend Engineers before finalization often contain interactions or layouts that are technically impossible or prohibitively costly to implement.
- **Accessibility as afterthought** — Adding accessibility after design is complete requires costly rework. Accessibility constraints must be considered from the first wireframe.
- **Handoff without specification** — Delivering a Figma file without annotated specifications forces Frontend Engineers to guess spacing, interaction behavior, and component usage, producing inconsistent implementations.

---

# Metadata

Owner: IA Engineering

Version: 0.0.3

Status: Draft

Category: Employee — Specialized

Severity: Mandatory

Default Complexity Tier: Standard Execution
