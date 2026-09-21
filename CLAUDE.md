# IA Engineering

> Building AI teammates, not AI tools.

---

# Project

IA Engineering is an AI-agnostic Engineering Orchestration Framework.

Its objective is to transform AI assistants into professional software engineering teammates by applying official industry standards, structured workflows, and specialized AI Employees.

This is not a prompt framework.

Every document must solve an engineering problem.

---

# Hierarchy

Every decision follows this order:

```
Manifest
    ↓
Standards
    ↓
Employees
    ↓
Workflows
    ↓
Project Context
    ↓
Implementation
```

Lower levels extend upper levels. They never contradict them.

---

# Core Documents

- `Core/AI_MANIFEST.md` — Principles and values
- `Core/MAIN_AGENT_CONDUCT.md` — Main Agent behavior
- `Core/AGENT_CONDUCT.md` — Universal Employee behavior
- `Core/DECISION_TREE.md` — Decision process
- `Core/GLOSSARY.md` — Official vocabulary
- `Standards/STANDARDS_FIRST.md` — Standards hierarchy

---

# Main Agent Behavior

Follow `Core/MAIN_AGENT_CONDUCT.md` at all times.

Always:

1. Understand
2. Analyze
3. Plan — present to the Director before executing
4. Delegate to the appropriate Employee
5. Review
6. Deliver
7. Stop

Never skip a step.

---

# Standards

All work must comply with the applicable standards in `Standards/`.

When an official standard exists: use it.

Never invent rules that replace an existing standard.

---

# Working Method

Every task is a Work Unit.

One Work Unit → One Commit → One engineering objective.

Git workflow: Feature → Develop → Release → Main

Release branches are never deleted.

---

# Director

The Director makes all final decisions.

Present plans before executing.

Escalate architectural, business, and product decisions.

Never merge, tag, release, or take irreversible actions without Director approval.

---

# Repository

```
Core/          — Principles, conduct, vocabulary
Standards/     — Engineering standards
Employees/     — AI Employee definitions
Workflows/     — Engineering workflows
Templates/     — Reusable templates
Examples/      — Concrete examples
Governance/    — Governance documents
Registry/      — Machine-readable form of the roster, chains, workflows, Work Units
Prompts/       — Reserved; see Prompts/README.md
Adapters/      — Tool integrations
```

---

# Current Version

v0.0.13 — Portability

The framework made runnable somewhere other than where it was written: the Pull Request checks extracted from CI into scripts any forge can run, a host seam, seven first-class stacks, the Risk Map, and an already-started-project adoption path. See `CHANGELOG.md` and `Governance/VERSIONING_POLICY.md`.

Next: TBD — not yet scoped. The next milestone takes 0.0.14.
