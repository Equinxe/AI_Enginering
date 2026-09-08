# Pole Brief Template

---

# Usage

A Pole Brief is what the **conductor** hands to a **pole** in `Workflows/AUTONOMOUS_DELIVERY.md`. A pole is a Main Agent session; the brief is the whole of what it knows about the run. It does not read the mandate, the other poles' briefs, or the conductor's conversation.

The Employee Brief (`Templates/EMPLOYEE_BRIEF.md`) is the unit of dispatch from a Main Agent to an Employee. The Pole Brief is one level up: the unit of dispatch from a conductor to a Main Agent. The pole then writes Employee Briefs of its own, per `Core/ORCHESTRATION.md` Step 4, for every Work Unit in its queue.

Two properties make a Pole Brief safe to run unattended for a while:

- **Write scope is explicit and disjoint.** The brief names the paths the pole owns and the paths it may not touch. Two briefs in the same run never own the same path. A Work Unit that would need a forbidden path is `BLOCKED`, reported, and not done.
- **The budget and the stop conditions are in the brief**, not in the conductor's head. A pole that has spent its budget stops and reports whatever state it is in. Nothing in the brief can be read as "continue until finished".

---

# Template

```markdown
## Pole Brief — [Pole identifier, e.g. P2]

**From:** Conductor
**To:** Pole [P2] (Main Agent session)
**Run:** [Mandate title] — Director mandate of [DD Month YYYY]
**Base commit:** [sha] — every pole branches from this commit
**Branch:** [feature/<mandate>-p2-<scope>] — per Standards/BRANCH_STANDARD.md

---

### Mandate (verbatim from the Director)

[Quoted, not paraphrased. The pole must be able to check its own work against
the Director's words, not the conductor's summary of them.]

---

### This pole's scope

**Work Units, in order:**
1. [WU-ID] — [title] — Employee: [name]
2. [WU-ID] — [title] — Employee: [name]

**Owned paths (the only places this pole writes):**
- `path/one/**`
- `path/two/file.md`

**Forbidden paths (another pole owns these — never write, even to fix a typo):**
- `path/three/**` — owned by P1
- `Registry/work-units.yml` — owned by the conductor; report the entries you need

**Dependencies on other poles:**
- [None — preferred.]
- [or: reads P1's output at `path/three/api.md`; this pole does not start until
  the conductor confirms P1's report COMPLETE and verified.]

---

### Budget

- Work Units: at most [N] (the list above; no additions without the conductor)
- Session bound: [wall-clock / token / turn bound as the runtime measures it]
- When either is exhausted: **stop and report** the state as it stands.

---

### Stop conditions (stop and report immediately)

- Any action classified High or Critical per Standards/RISK_STANDARD.md — stop,
  write the escalation block, send it to the conductor, wait. Never to the
  Director directly; never proceed on pole judgment.
- A Work Unit needs a forbidden path.
- A Work Unit returned twice for the same Definition of Done item
  (Core/ORCHESTRATION.md, Retry layer).
- Any gate in a Workflow this pole's Work Units enter (ADR approval, release
  approval) — reached through the conductor.
- [Run-specific conditions from the mandate.]

---

### Controls that bind inside this pole — unchanged

- Core/MAIN_AGENT_CONDUCT.md in full: dispatch by named Employee, No Direct
  Implementation, Verification Over Waiting, Durable Tracking of Findings.
- Core/ORCHESTRATION.md in full, including the dependent-task queue and its
  layered termination.
- Every commit passes the commit-msg and pre-commit hooks with its Work Unit:
  and Employee: trailers. No escape hatch, ever (Standards/GIT_STANDARD.md).
- Every Work Unit ends in a Work Unit Report; a bare "Done" fails it.
- Session State for this pole at `.ia-engineering/poles/[P2]/SESSION_STATE.md`
  (gitignored), updated at every Work Unit boundary and on every stop.

---

### Integration contract (what this pole leaves behind)

- Branch [name] pushed, rebased on nothing — the conductor merges; the pole
  never rewrites its branch.
- Every Work Unit's commit present with valid trailers; `git log <base>..HEAD`
  quoted in the Pole Report.
- Project gates green on the branch: [build / tests / validator commands, as
  the project defines them], output quoted.
- Data Policy clean in `--history <base>..HEAD` mode.
- **Pole Report** written to `[.ia-engineering/poles/P2/REPORT.md]` in the form
  of Templates/WORK_UNIT_REPORT.md, with one Definition-of-Done row per Work
  Unit, every RISK line, and every open item filed as an Issue with its number.

---

### Escalation channel

- All escalations go to the conductor at [channel / mechanism the runtime
  provides — a file the conductor polls, a message, a handoff artefact].
- Format: the escalation block from Standards/RISK_STANDARD.md, plus the Work
  Unit ID and this pole's identifier.
- The pole is stopped from the moment it escalates until the conductor
  returns the Director's decision, quoted.

---

### Definition of Done for this pole

- [ ] Every Work Unit above is COMPLETE with its report, or PARTIAL/BLOCKED with
      the reason and an Issue.
- [ ] Integration contract met, evidence pasted in the Pole Report.
- [ ] No write outside owned paths (`git diff --stat <base>..HEAD` quoted).
- [ ] Every RISK line Medium or above recorded; none High/Critical decided by
      the pole.
- [ ] Session State current, with an absolute date.
```

---

# Field Reference

| Field | Purpose | Common mistakes |
|---|---|---|
| Mandate (verbatim) | The pole checks itself against the Director, not the conductor | A paraphrase; a mandate that grew in transit |
| Owned / forbidden paths | Disjoint write scope is what makes parallel poles safe | Overlapping globs; "shared" paths; letting a pole fix "just a typo" in another's file |
| Dependencies | An ordered pole is a queue with a longer wait; recorded so the conductor can gate it | An implicit dependency discovered at integration |
| Budget | Bounded autonomy | "Until done"; a bound the runtime cannot measure |
| Stop conditions | The pole knows when to stop without being told | Omitting the High/Critical rule as if the pole would remember it |
| Integration contract | The conductor can merge without asking | A pole that rebases or force-pushes its own branch "to be clean" |
| Escalation channel | One path to the Director | A pole with the Director's ear; a pole that decides `High` because the conductor was busy |

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Workflows/AUTONOMOUS_DELIVERY.md` | The workflow this brief is written in (Step 2) and executed under (Step 3) |
| `Templates/EMPLOYEE_BRIEF.md` | What the pole writes, one level down, for each Work Unit |
| `Templates/WORK_UNIT_REPORT.md` | The form of the Pole Report |
| `Templates/SESSION_STATE.md` | The per-pole state file the brief names |
| `Standards/RISK_STANDARD.md` | The stop-and-escalate rule, and the escalation block format |
| `Core/ORCHESTRATION.md` | Everything the pole does between receiving this brief and reporting |

---

# Metadata

Owner: IA Engineering

Version: 0.0.12

Status: Draft

Category: Template — Orchestration

Severity: Mandatory
