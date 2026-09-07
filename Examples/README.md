# Examples

Concrete, end-to-end walkthroughs of each named Agent Chain (`Core/AGENT_CHAINS.md`), applied to a single fictional project — **TaskFlow**, a task management API — so the examples read as one coherent narrative.

These examples are reference material. They are not templates to copy — they show the templates and workflows already in this framework being used correctly.

Because they show the framework in use, they are also the place where a change to a Workflow shows up as a contradiction. `Governance/CONTRIBUTING.md` §3's cross-reference check applies to them: a Work Unit that changes what a Workflow requires updates the example that demonstrates it, in the same commit. The Convergence milestone reached them one Work Unit late — the examples showed reviews with no denominator, a Collect step with no Work Unit Report, and hotfixes and incidents with no risk record, for as long as it took someone to read them.

---

# Index

| Example | Chain | Shows |
|---|---|---|
| `FEATURE_CHAIN_EXAMPLE.md` | Feature Chain | Director request → Work Unit → Employee Brief → sequential dispatch → Work Unit Reports re-verified → delivery |
| `REVIEW_CHAIN_EXAMPLE.md` | Review Chain | Severity-labeled findings, a decision that states its denominator, line re-anchoring on the second pass, changes-requested loop, non-blocking suggestions |
| `RELEASE_CHAIN_EXAMPLE.md` | Release Chain | Changelog, release Test Plan, mandatory Director gate before merge to `main` |
| `HOTFIX_CHAIN_EXAMPLE.md` | Hotfix Chain | Dual Director gates, branching from `main`, back-merge to `develop` |
| `INCIDENT_CHAIN_EXAMPLE.md` | Incident Chain | P1 notification, the one gate that does not pause the chain, a `Critical` risk recorded as it happens, mitigation vs. resolution, blameless post-mortem, handoff to Hotfix Chain |
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
