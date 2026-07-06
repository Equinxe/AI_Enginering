# Architecture Decision Record Template

---

# Usage

An Architecture Decision Record (ADR) documents a significant architectural decision: what was decided, why, and what the consequences are.

Every ADR is permanent. Accepted ADRs are never deleted — they may be superseded or deprecated, but the record of the decision must persist.

Follow the Architecture Decision Workflow when creating an ADR.

---

# Template

```markdown
## ADR-[ID] — [Title: short, decision-oriented]

**Date:** [YYYY-MM-DD]
**Status:** [Proposed | Accepted | Superseded | Deprecated | Rejected]
**Author:** [Software Architect]
**Approved by:** [Director]
**Supersedes:** [ADR-ID or N/A]
**Superseded by:** [ADR-ID or N/A]

---

### Context

[Describe the situation that makes this decision necessary. What problem are we solving? What forces are at play? What constraints exist?

Be factual and specific. This section explains WHY a decision was needed at all.]

---

### Options Considered

#### Option 1 — [Name]

[Description]

Pros:
- [Pro 1]
- [Pro 2]

Cons:
- [Con 1]
- [Con 2]

#### Option 2 — [Name]

[Description]

Pros:
- [Pro 1]
- [Pro 2]

Cons:
- [Con 1]
- [Con 2]

#### Option 3 — [Name] (if applicable)

[...]

---

### Decision

**We will [chosen option].**

[One or two sentences stating the decision clearly. Start with "We will" to make the decision unambiguous.]

---

### Rationale

[Why was this option chosen over the others? Reference the specific pros and cons that were decisive. What trade-offs were accepted?

This section must justify the decision — not just restate it.]

---

### Consequences

**Positive:**
- [What becomes easier or better as a result of this decision]

**Negative:**
- [What becomes harder, more constrained, or must be accepted as a result]

**Neutral:**
- [Changes that are neither positive nor negative but must be acknowledged]

---

### Standards Applied

[List the standards that governed this decision:]
- [e.g., Standards First]
- [e.g., Official documentation for [technology]]
- [e.g., OWASP guidelines]

---

### Implementation Notes

[Optional: specific guidance for engineers implementing this decision. Link to relevant Work Units.]

Related Work Units:
- [WU-ID — description]
```

---

# ADR ID Convention

Format: `ADR-[project]-[sequential number]`

Example: `ADR-SHOP-007`

IDs are assigned by the Software Architect and are unique per project.

---

# ADR Status Reference

| Status | Meaning | Who sets it |
|---|---|---|
| Proposed | Draft under review | Software Architect |
| Accepted | Approved by Director, ready for implementation | Director |
| Superseded | Replaced by a newer ADR | Software Architect, referencing the new ADR |
| Deprecated | No longer applicable, not replaced by a new decision | Software Architect + Director |
| Rejected | Reviewed and not adopted | Director, with documented rationale |

---

# Storage Convention

ADRs are stored in: `docs/adr/` or `Architecture/decisions/` within the project repository.

File naming: `ADR-[ID]-[kebab-case-title].md`

Example: `ADR-SHOP-007-use-postgresql-for-primary-storage.md`

---

# Metadata

Owner: IA Engineering

Version: 0.0.5

Status: Draft

Category: Template — Architecture

Severity: Mandatory
