# Examples

Concrete, end-to-end walkthroughs of each named Agent Chain (`Core/AGENT_CHAINS.md`), applied to a single fictional project — **TaskFlow**, a task management API — so the examples read as one coherent narrative.

These examples are reference material. They are not templates to copy — they show the templates and workflows already in this framework being used correctly.

---

# Index

| Example | Chain | Shows |
|---|---|---|
| `FEATURE_CHAIN_EXAMPLE.md` | Feature Chain | Director request → Work Unit → Employee Brief → sequential dispatch → delivery |
| `REVIEW_CHAIN_EXAMPLE.md` | Review Chain | Severity-labeled findings, changes-requested loop, non-blocking suggestions |
| `RELEASE_CHAIN_EXAMPLE.md` | Release Chain | Changelog, release Test Plan, mandatory Director gate before merge to `main` |
| `HOTFIX_CHAIN_EXAMPLE.md` | Hotfix Chain | Dual Director gates, branching from `main`, back-merge to `develop` |
| `INCIDENT_CHAIN_EXAMPLE.md` | Incident Chain | P1 notification, mitigation vs. resolution, blameless post-mortem, handoff to Hotfix Chain |
| `ARCHITECTURE_CHAIN_EXAMPLE.md` | Architecture Chain | ADR drafting, cross-system impact review, Director decision gate, handoff to Feature Chain |

---

# Reading Order

For a first read, follow the TaskFlow narrative in order: Feature → Review → Release → Hotfix → Incident → Architecture. Each example references the ones before it.

---

# Metadata

Owner: IA Engineering

Version: 0.0.7

Status: Draft

Category: Example — Index

Severity: Reference
