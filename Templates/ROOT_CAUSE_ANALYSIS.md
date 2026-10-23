# Root Cause Analysis Template

---

# Usage

A Root Cause Analysis records **why** a failure happened, as evidence a reviewer can check, before a fix is chosen. It is filled in by the Employee diagnosing the failure:

- the SRE Engineer, during an incident (`Workflows/INCIDENT_RESPONSE.md`, Step 4);
- the Test Automation Engineer, for a flaky test, before it is fixed or taken out of quarantine (quarantine itself is containment and comes first when the test blocks the pipeline);
- any Employee fixing a defect whose cause is not already proven by the first reading.

The record goes into the artifact that needs the cause, not a directory of its own: the Root Cause section of the Incident Report (`Templates/INCIDENT_REPORT.md`, only once the status is Confirmed), the Flaky Test Report of the Test Automation Engineer, or the Work Unit Report of the fixing Work Unit.

The failure this template prevents is the jump from a symptom to a favourite explanation, then a fix that hides the symptom while the cause stays. Every step below ends on something a reviewer can check.

---

# Official References

This template orchestrates the official methods below, cited by reference. Three rules are framework practice, not taken from any of them: the six-level evidence ladder, the three-refutation circuit breaker, and the single instrumentation tag. They are adapted from the open-source oh-my-claudecode tracer and debugger agents.

- IEEE Std 1044-2009, *IEEE Standard Classification for Software Anomalies* — the vocabulary for recording an anomaly: the failure is what was observed, the defect is what caused it. Until the analysis is Confirmed, a named defect is a hypothesis.
- ISTQB Glossary — *error*, *defect*, *failure*, *root cause*, *root cause analysis*.
- Google, *Site Reliability Engineering* (O'Reilly, 2016), chapter 12, *Effective Troubleshooting* — the hypothetico-deductive loop (observe, hypothesise, test) and the rule that negative results are recorded, not discarded.
- The cause-and-effect (Ishikawa) diagram — used in Step 3 to widen the hypothesis set across categories.
- The 5 Whys (Toyota Production System) — used after Step 6 to go from a confirmed proximate cause to the systemic one. Each "because" is itself a hypothesis and is held to the same evidence ladder.
- `Standards/TESTING_STANDARD.md`, Falsifiability — what the regression test of the fix must show (Step 7).
- `Standards/DATA_PROTECTION_STANDARD.md` — what may enter a report (Step 1).

---

# Evidence-Strength Ladder

Every piece of evidence is graded. Evidence is never counted flat: one Level 1 result outweighs any number of Level 5 clues.

| Level | Evidence | Example |
|---|---|---|
| 1 | **Controlled reproduction** — the symptom appears when only the suspected cause is introduced, and disappears when only it is removed | A regression test red at the base commit and green on the fix; a flaky test failing on every run with the suspected ordering forced, and never without it |
| 2 | **Primary artifact** with tight provenance, bearing directly on the claim | A timestamped log line, a trace, a metric, a config snapshot, `git log` of the change, the failing assertion's output |
| 3 | **Independent sources** converging on the same mechanism | A metric and an unrelated log, read separately, pointing to the same component. The same log read twice is one source |
| 4 | **Code inference** — a code path that would produce the symptom, read but not yet run | "`parse()` returns null when the header is absent" |
| 5 | **Circumstantial** — temporal proximity, naming, stack position, resemblance to a past incident | "It started after Tuesday's deploy" |
| 6 | **Intuition or analogy** | "This looks like a race" |

Two rules apply the ladder:

- When a higher level contradicts a lower one, the lower one is set aside. It is not averaged in.
- Only Level 1 evidence makes a cause **Confirmed**. A hypothesis supported only by Levels 4 to 6 is a candidate, not a cause.

---

# Method

Each step ends on its completion criterion. A step without its criterion met is not done, and the next step does not start.

**1. Observe.** List what was seen, without interpretation. Each observation states what, where (file:line, log, metric, command and its output), and when (UTC). It contains no "because", "probably" or "seems": those belong to hypotheses. Capture the primary artifacts (logs, state, the failing output) before a retry, a restart or a containment step erases them, as long as capturing them does not delay containment. Before anything enters the record, replace secrets, credentials, tokens and personal identifiers with `<REDACTED>`, because a report is shared and committed (`Standards/DATA_PROTECTION_STANDARD.md`). A cause that is a current, unfixed defensive weakness is not described in a committed record: it follows that Standard's section *Operational State Is Also Sensitive*, and the Security Engineer is engaged, as `Workflows/INCIDENT_RESPONSE.md`'s escalation table already requires.
*Done when:* someone who disagrees with every hypothesis would still accept every line of the observation list, and nothing in it needs redacting.

**2. Frame the question.** Write the one "why" this analysis answers: *Why does [observed behaviour] happen [under these conditions] [since when]?*
*Done when:* the question names an observed behaviour from Step 1, not a suspected cause.

**3. Hypothesise, and rank before testing.** Write 3 to 5 candidate causes, ranked by how well each fits the observations, **before testing any of them**. Ranking first prevents anchoring on the first plausible story. Draw them from different frames, the Ishikawa categories applied to software:

- code path;
- data or state;
- configuration or environment;
- timing, concurrency or order;
- a dependency or an external system;
- a measurement artifact: the observation itself is wrong (a stale log, a misread metric, a test that measures the wrong thing).

For each hypothesis, write what it **predicts**: what should be observable if it is true.
*Done when:* 3 to 5 hypotheses are ranked with their predictions. If fewer than 3 exist, the record names the frames that were considered and found empty. There are never fewer than 2: a single hypothesis has nothing to be tested against, and the measurement-artifact frame always yields a second one.

**4. Gather evidence for and against.** For each hypothesis, record the evidence for it and the evidence against it, with its level on the ladder. Test one hypothesis at a time, with one change per probe, so a result can be attributed. Tag every piece of temporary instrumentation (a log line, a print, a debug flag) with one marker for the whole analysis, `[DEBUG-<4 hex>]`, so that one search finds all of it.
*Done when:* every hypothesis has an "against or gaps" entry, even if it reads "none found, searched: [what]", and each is marked open, refuted, or surviving.

**5. Refute the favourite.** Before naming a cause, attack the leading hypothesis:

- Which of its predictions was checked, and did it hold?
- Which observation from Step 1 does it fail to explain?
- What is the best case of the strongest remaining alternative?

A hypothesis that survives only because nobody looked for evidence against it stays Provisional.
*Done when:* the three questions are answered in the record and the leader either stands or is down-ranked.

**6. Conclude.** The status is **Confirmed** only with Level 1 evidence for the surviving hypothesis. For a defect, when one hypothesis survives and the only Level 1 evidence still missing is the regression test, the status is **Confirmed pending Step 7**, and Step 7 settles it. Otherwise the status is **Provisional**, and the record names:

- the **critical unknown**: the one missing fact that keeps the top two hypotheses apart;
- the **discriminating probe**: the cheapest probe whose result differs between them, and what each result would mean.

An analysis never ends on "not sure". It ends on a cause, or on the probe to run next.
*Done when:* the status is set, and a Provisional record carries both the critical unknown and the discriminating probe.

**7. Prove the fix.** The regression test of the fix follows `Standards/TESTING_STANDARD.md`, Falsifiability: it is seen red against the pre-fix code (the base commit) and green on the fix, and the evidence is pasted. That red-then-green pair is the Level 1 evidence that confirms the cause.

If no regression test can attach at a correct seam (the interface where the behaviour is specified), report the missing seam as the finding instead of testing through internals: file it as an Issue, and escalate the testability gap to the Technical Lead. A test forced through private state is coupled to the implementation and proves nothing about the behaviour. This is a shortfall, not an exemption. The Standard grants none for it, so the Work Unit Report declares "Falsifiability item 2 not met: no seam (#n)" under Deviations. The cause stays Provisional unless another Level 1 reproduction exists.
*Done when:* the red and green runs are pasted, and the red-then-green pair sets the status to Confirmed. Otherwise the missing seam is filed, linked and declared as a deviation, and the status is Provisional or Confirmed by another Level 1 reproduction.

**8. Clean up.** Remove every piece of tagged instrumentation before the commit. The search for the tag over the working tree (`git grep -n "DEBUG-<tag>"`) returns nothing, and its empty output is pasted.
*Done when:* the empty search output is in the record.

---

# Circuit Breaker

**After three refuted hypotheses in total, stop and escalate to the Technical Lead** with the record as it stands. A hypothesis counts as refuted when Level 1 or Level 2 evidence contradicts it. When every current hypothesis is refuted before the third refutation, the analysis returns to Step 3 for new ones, and the count carries over.

Three refutations usually mean the frame is wrong: the cause is elsewhere, or the observation is. A fourth variation of the same idea rarely succeeds. The Technical Lead questions the frame and either redirects the analysis or escalates an architectural cause to the Software Architect, following the Technical Lead's own Escalation Rules. When the analyst is the Technical Lead, the escalation goes to the Software Architect directly.

During an incident, the circuit breaker does not stop containment (`Workflows/INCIDENT_RESPONSE.md`, Step 5). The Incident Commander is told that the diagnosis has been escalated.

---

# Template

```markdown
## Root Cause Analysis — [INC-ID | WU-ID | test name]

**Analyst:** [Employee]
**Date:** [YYYY-MM-DD]
**Status:** [Open | Provisional | Confirmed pending Step 7 | Confirmed | Escalated]
**Instrumentation tag:** [DEBUG-xxxx]

---

### 1. Observation

| # | What was observed (no interpretation) | Source (file:line, log, metric, command) | When (UTC) |
|---|---|---|---|
| O1 | [...] | [...] | [...] |

Redacted before entry: [what kinds, or "nothing to redact"]

### 2. Question

Why does [observed behaviour] happen [under these conditions] [since when]?

### 3. Hypotheses (ranked before any test)

| Rank | Hypothesis | Frame | Predicts, if true |
|---|---|---|---|
| H1 | [...] | [code path / data or state / configuration or environment / timing or order / dependency / measurement artifact] | [...] |

Frames considered and found empty: [only if fewer than 3 hypotheses]

### 4. Evidence

| Hypothesis | Evidence for (level) | Evidence against or gaps (level) | Verdict |
|---|---|---|---|
| H1 | [...] (L2) | [...] (L4) | [open / refuted / surviving] |

### 5. Refutation pass against [leading hypothesis]

- Prediction checked: [...] — held: [yes / no]
- Observation it fails to explain: [O-number, or "none"]
- Strongest alternative's best case: [...]
- Result: [stands / down-ranked]

### 6. Conclusion

**Root cause:** [the mechanism, at file:line where known]
**Status:** [Confirmed — Level 1: what reproduced it | Confirmed pending Step 7 | Provisional]
**Critical unknown:** [Provisional only: the one fact that separates the top two hypotheses]
**Discriminating probe:** [Provisional only: the cheapest probe, and what each result would mean]

### 7. Regression test

- Test: [name]
- Seen red: [base commit or mutant] — [command] — [failing line]
- Green on the fix: [command] — [result]

or

- Missing seam: [why no correct seam exists] — Issue #[n] — declared in the Work Unit Report under Deviations as "Falsifiability item 2 not met: no seam (#n)"

### 8. Cleanup

git grep -n "DEBUG-xxxx" → [empty output, pasted]

### Circuit breaker

Refuted hypotheses: [n] of 3. [At 3: escalated to the Technical Lead on YYYY-MM-DD]
```

---

# When to Use This Template

Use it:

- in every incident diagnosis (`Workflows/INCIDENT_RESPONSE.md`, Step 4), and before the Root Cause section of an Incident Report is written;
- for every flaky test, before it is fixed or taken out of quarantine. A flaky test that blocks the pipeline is quarantined first, as containment, once Step 1's artifacts are captured;
- for a defect whose cause the first reading of the code and the error does not prove.

It is not needed when the failure states its own cause and the next run confirms the fix, for example a compiler error naming the line and the missing symbol. The Level 1 evidence is already in hand.

---

# Relationship to Other Documents

- `Templates/INCIDENT_REPORT.md` receives the Confirmed root cause. This record is the evidence behind it.
- `Standards/TESTING_STANDARD.md`, Falsifiability, defines the red-then-green proof that Step 7 uses as Level 1 evidence.
- `Templates/WORK_UNIT_REPORT.md` carries the record of a defect fix, with the red run under Gate Evidence.
- The circuit breaker and the missing seam escalate along routes the Employees already have: the Test Automation Engineer's and the Technical Lead's Escalation Rules.

---

# Metadata

Owner: IA Engineering

Version: 0.0.15

Status: Draft

Category: Template — Quality

Severity: Mandatory

Depends On:

- `Standards/TESTING_STANDARD.md`
- `Standards/DATA_PROTECTION_STANDARD.md`
- `Templates/INCIDENT_REPORT.md`

Referenced By:

- `Workflows/INCIDENT_RESPONSE.md`
- `Templates/INCIDENT_REPORT.md`
- `Employees/Quality/TEST_AUTOMATION_ENGINEER.md`
- `Employees/DevOps/SRE_ENGINEER.md`
- `Employees/Management/TECHNICAL_LEAD.md`
