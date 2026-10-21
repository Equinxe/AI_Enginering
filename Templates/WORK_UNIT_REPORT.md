# Work Unit Report Template

---

# Usage

A Work Unit Report is what a dispatched Employee hands back to the Main Agent when its Work Unit ends. It is the mirror of the Employee Brief: the brief is the complete input an Employee receives; the report is the complete output it returns.

**Writing the report is the Employee's final action, and it is what "done" means.** A bare "Done", "Complete", or "Finished" returned without a report is a **failed** Work Unit, not a completed one — the Main Agent has nothing to verify against the Definition of Done, no evidence to check, and no record of what was not done. `Core/ORCHESTRATION.md` Step 5 (Collect) reads this report; `Core/MAIN_AGENT_CONDUCT.md`'s Verification Over Waiting then confirms its claims against the repository directly.

Two consequences follow:

- **Evidence is pasted, never paraphrased.** "Tests pass" is a claim. The actual final lines of the test runner's output are evidence. The report carries the second, because the first has been wrong in practice — an Employee reported "no attribution trailers on the commits" when all four carried one, and the report that quoted `git log` would have shown it.
- **The Main Agent re-verifies anyway.** A report is evidence to check, not proof to trust. Reading the report and independently re-running the gates are both part of Step 5.

---

# Template

```markdown
## Work Unit Report — [WU-ID]

**From:** [Employee name]
**To:** Main Agent
**Work Unit:** [WU-ID] — [title]
**Date:** [YYYY-MM-DD]
**Executed at:** [tier] / [runtime model as reported by the runtime — the model that actually ran, never one dictated by the brief]

---

### Verdict

[ONE line. Exactly one of:]
- **COMPLETE** — every Definition of Done item is met, with evidence below.
- **PARTIAL** — some items are met; the unmet ones and the reason are listed below.
- **BLOCKED** — no further progress is possible without [the named decision / input / Employee].

---

### What Was Done

[What now exists or works that did not before. Concrete — the endpoint, the
migration, the document section — not "implemented the feature".]

---

### What Was NOT Done

[Anything in the brief's Outputs that is not delivered, and why. "Nothing" is
a valid entry and must be written explicitly — an empty section is ambiguous.]

---

### Files Changed

[One line per file: path — what changed. Generated files marked as such.]

---

### Gate Evidence

[The ACTUAL output of every gate the Definition of Done names. Pasted, not
summarised. Trimmed to the lines that carry the verdict.]

**Tests**
```
[e.g. the final summary line of the test runner — "42 passed in 3.1s"]
```

**Falsification**
```
[Each new or changed test that guards a criterion or a fix, seen red as
`Standards/TESTING_STANDARD.md` (Falsifiability) requires: the mutant or the
base commit, the command, the failing line, then the green run on the real
code — or "not applicable — no executable behaviour"]
```

**Lint / static analysis**
```
[e.g. "Your code has been rated at 10.00/10" or "All checks passed"]
```

**Build**
```
[final lines, or "not applicable — documentation-only Work Unit"]
```

**Commits**
```
[git log <base>..HEAD --format='%h %s' — every commit this Work Unit produced,
so the Main Agent can see the Employee trailer and the Work Unit trailer
without asking]
```

---

### Deviations From the Brief

[Anything done differently from what the brief specified, with the reason.
"None" written explicitly if so. A deviation not reported here is a
Transparency violation (Core/AI_MANIFEST.md, Principle VI), not a judgment call.]

---

### Risk Record

[One line per Medium-or-higher risk decision taken during the Work Unit, in the
format Standards/RISK_STANDARD.md defines:]

RISK: [hazard] | tier=[Low|Medium|High|Critical] | mitigation=[...] | decided_by=[Director|self]

[Or: "No Medium-or-higher risk decisions."]

---

### Open Risks and Follow-Ups

[Anything discovered that is worth tracking and is NOT being acted on in this
Work Unit — a gap, tech debt, a deferred decision. Each one is filed as an
Issue per Core/MAIN_AGENT_CONDUCT.md, Durable Tracking of Findings; list the
Issue numbers here. A finding that exists only in this report does not survive
the session.]

---

### Definition of Done — Item by Item

| DoD item (from the brief) | Met? | Evidence |
|---|---|---|
| [item 1] | yes / no | [pointer to the evidence section above, or the reason it is unmet] |
| [item 2] | yes / no | ... |
```

---

# Field Reference

| Field | Purpose | Common mistakes |
|---|---|---|
| Executed at | The tier the Work Unit ran at, and the runtime's own model identifier | Copying the brief's Execution tier instead of reporting the runtime model actually used; leaving the model blank |
| Verdict | One word the Main Agent can act on | "Mostly done"; a paragraph; a verdict that contradicts the DoD table |
| What Was NOT Done | Makes omission visible | Left empty — silence reads as "everything", which is the failure this template exists to prevent |
| Gate Evidence | Pasted output, checkable | Paraphrase ("tests green"); a Falsification block with only the green run, or a red run caused by something other than the criterion; output from a previous run; output from a different branch |
| Deviations | Transparency | Unreported changes of approach discovered later in review |
| Risk Record | Auditability | Missing for a Medium action; `decided_by=self` on a High |
| Open Risks | Durability of findings | Findings noted here but never filed as Issues |
| DoD table | Traceability to the brief | Items reworded from the brief so they are easier to satisfy |

---

# Where the Report Lives

The brief names the destination. Two forms are standard:

- **For a Work Unit that ends in a Pull Request**, the report's substance becomes the PR description — self-contained, per `Standards/PULL_REQUEST_STANDARD.md`, readable by someone with no access to the Employee's working files. The Main Agent's Step 5 verification then works from the PR.
- **For a Work Unit that does not produce a PR** — research, assessment, a report to the Director — the brief names a file path, and the Employee writes the report there. The chat return is one line: the path.

In either case the report is a file or a PR body, not a message in a conversation. Conversations are not durable and are not reviewable by the next Director.

---

# Relationship to Other Documents

| Document | Relationship |
|---|---|
| `Templates/EMPLOYEE_BRIEF.md` | The input this report answers. Every Output and every Definition of Done item in the brief has a row here. |
| `Core/CAPABILITY_TIERS.md` | Defines the tiers this report's "Executed at" field names, and the Tier Override that re-dispatches a failed Work Unit one tier up. |
| `Core/ORCHESTRATION.md` | Step 5 (Collect) reads this report before anything else. |
| `Core/MAIN_AGENT_CONDUCT.md` | Verification Over Waiting: the report is evidence, and the Main Agent re-verifies it directly. Durable Tracking of Findings: every open item becomes an Issue. |
| `Standards/RISK_STANDARD.md` | Defines the Risk Record line. |
| `Standards/PULL_REQUEST_STANDARD.md` | Governs the report when it takes the form of a PR description. |
| `Standards/COMMIT_STANDARD.md` | Defines the optional runtime attribution trailer — if the runtime adds one to the commit, it names the same model this field's "runtime model" half reports. |

**Provenance.** The "a bare Done is a failure" rule and the pasted-evidence requirement are adapted from a sibling governance corpus, where they were written after delegated agents repeatedly returned one-word completions that concealed unfinished work and unverified claims.

---

# Metadata

Owner: IA Engineering

Version: 0.0.14

Status: Draft

Category: Template — Orchestration

Severity: Mandatory
