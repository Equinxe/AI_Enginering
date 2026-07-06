# Sprint Ceremony Workflow

---

# Purpose

This workflow defines the recurring ceremonies of a Scrum sprint: Planning, Daily Standup, Review, and Retrospective.

It ensures the team operates with a consistent cadence, that every sprint starts with a clear goal and ends with a verified delivery and documented improvement.

---

# Trigger

- Start of a new sprint (Planning).
- Each working day during the sprint (Daily Standup).
- End of sprint (Review + Retrospective).

---

# Actors

| Actor | Role in this workflow |
|---|---|
| Scrum Master | Facilitates all ceremonies, removes impediments |
| Director | Participates in Sprint Review — final acceptance of delivered work |
| Product Manager | Owns the backlog, defines sprint goal, accepts or rejects deliverables |
| Engineering Manager | Participates in planning, monitors sprint health |
| Engineers (all active) | Participate in all ceremonies, report progress and blockers |
| Technical Lead | Resolves technical blockers during standup and planning |

---

# Sprint Length

Default: 2 weeks. Adjustable by Director based on project phase.

---

# Ceremonies

---

## Ceremony 1 — Sprint Planning

**When:** First day of the sprint.

**Actors:** Scrum Master, Product Manager, Engineering Manager, all Engineers.

**Steps:**

1. **Define the sprint goal** — Product Manager proposes a sprint goal aligned with the project roadmap. Director approves the goal.
2. **Review the backlog** — Product Manager presents the top-priority Work Units from the backlog.
3. **Estimate** — Engineers estimate the effort for each Work Unit. Only Work Units with clear acceptance criteria and a Definition of Done are added to the sprint.
4. **Commit** — The team commits to a set of Work Units that form the sprint scope. Do not overcommit — the committed scope must be achievable within the sprint.
5. **Assign** — Engineering Manager assigns each Work Unit to the appropriate engineer.

**Output:**
- Sprint goal documented.
- Sprint backlog defined (list of committed Work Units).
- Work Units assigned to engineers.

---

## Ceremony 2 — Daily Standup

**When:** Every working day of the sprint. Maximum 15 minutes.

**Actors:** Scrum Master, all Engineers.

**Format:** Each engineer answers three questions:

1. What did I complete since the last standup?
2. What will I work on today?
3. Is there anything blocking me?

**Rules:**
- The standup is not a status report to management — it is a team synchronization.
- Blockers are noted and assigned to the Scrum Master for resolution immediately after.
- Detailed technical discussions are taken offline — the standup surfaces the need, it does not solve it.

**Output:**
- Team is synchronized on progress.
- Blockers are identified and assigned for resolution.

---

## Ceremony 3 — Sprint Review

**When:** Last day of the sprint (before Retrospective).

**Actors:** Scrum Master, Director, Product Manager, Engineering Manager, all Engineers.

**Steps:**

1. **Demo** — Each engineer demonstrates the Work Units they completed this sprint.
2. **Acceptance** — Product Manager and Director review each deliverable against the acceptance criteria:
   - Accepted: Work Unit is complete.
   - Not accepted: Work Unit returns to the backlog with documented reasons.
3. **Backlog update** — Product Manager updates the backlog based on sprint outcomes and new inputs from the Director.

Only demonstrated, working software is accepted. Work in progress is not accepted.

**Output:**
- Accepted deliverables documented.
- Rejected Work Units returned to backlog with documented reasons.
- Backlog updated.

---

## Ceremony 4 — Sprint Retrospective

**When:** Last day of the sprint (after Review).

**Actors:** Scrum Master, Engineering Manager, all Engineers. Director optional.

**Format:** Three questions:

1. What went well this sprint?
2. What did not go well?
3. What one thing will we change in the next sprint?

**Rules:**
- The retrospective is blameless. Issues are systemic, not personal.
- Every retrospective produces exactly one actionable improvement for the next sprint. Not a list — one improvement, owned by one person, with a measurable outcome.
- The improvement from the previous retrospective is reviewed at the start of the next retrospective.

**Output:**
- Retrospective findings documented.
- One improvement action defined, assigned, and added to the next sprint.

---

# Sprint Health Indicators

The Scrum Master monitors these during the sprint:

| Indicator | Healthy | Warning |
|---|---|---|
| Standup blockers resolved | Same day | Unresolved after 24 hours |
| Sprint scope changes | None after Day 2 | Multiple scope changes mid-sprint |
| Work Units in progress simultaneously | 1–2 per engineer | 3+ per engineer |
| Accepted at Review | >80% of committed scope | <60% of committed scope |

---

# Exit Criteria

A sprint is complete when:

- Sprint Review is conducted and deliverables are accepted or returned.
- Sprint Retrospective is conducted and one improvement action is assigned.
- The next sprint's Planning is scheduled.

---

# Escalation

| Situation | Escalate to |
|---|---|
| Sprint goal cannot be achieved due to scope or blockers | Director — sprint goal adjustment required |
| Blocker is unresolved after 24 hours | Engineering Manager |
| Less than 60% of committed scope delivered at Review | Director — root cause analysis required |
| Team conflict surfaced in Retrospective | Engineering Manager → Director |

---

# Related Workflows

- Feature Development Workflow
- Release Workflow

---

# Metadata

Owner: IA Engineering

Version: 0.0.4

Status: Draft

Category: Workflow — Agile

Severity: Recommended
