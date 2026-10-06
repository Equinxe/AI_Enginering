# Dispatch in Practice

---

# Purpose

`Core/ORCHESTRATION.md` defines the dispatch protocol and `Core/EMPLOYEE_SELECTION.md` names the trigger for each of the 42 Employees. Both are correct. This document is neither: it records **what actually happens when the protocol is run**, and only where practice and the documents differ.

It is deliberately short. This corpus is checked by sixteen mechanical sections and not one of them can read a sentence, so every page of prose is a page that can go stale unnoticed — the Release Chain example drifted from `Workflows/RELEASE.md` within hours of that Workflow changing, twice in one morning. A long "how it really works" document would be the same defect at greater length.

**Where this disagrees with `Core/ORCHESTRATION.md`, that document is right and this one is a defect.**

---

# What the numbers say

Measured from `Registry/work-units.yml` on 8 September 2026, after 243 Work Units:

| | |
|---|---|
| Employees dispatched at least once | **13 of 42** |
| Employee definitions changed as a result of being dispatched | **0** |

The second number is the useful one. Sixty-three dispatches produced no correction to any Employee definition. Every Employee sits at two to four commits, all of them from mass edits across the whole roster.

Two readings are available and neither is comfortable. Either the definitions are good enough that use finds nothing, or nobody has been looking at them with the question "did this brief produce usable work?" in mind. The evidence cannot separate them, and this document says so rather than choosing the flattering one.

What it does settle: **dispatching an Employee is not, by itself, how Employee definitions improve.** The improvements this project has made all came from executing a control and reading its output.

---

# Measuring Usage

The table above was counted by hand, once. `Adapters/scripts/usage-dashboard.sh` counts it on demand, for this repository or any project that adopted the framework:

```bash
Adapters/scripts/usage-dashboard.sh --project-dir <project> [--open]
```

Two ways to build and open it in one step:

- **Windows** — `Adapters\scripts\usage-dashboard.cmd`, from PowerShell, cmd, or a double-click in Explorer. It runs the script with `--open` through Git for Windows' own `bash.exe`; typing `bash` in PowerShell reaches WSL instead (`Governance/TROUBLESHOOTING.md` entry AA). From an adopter's `ia-engineering` submodule it measures the adopting project.
- **macOS, Linux, Git Bash** — `Adapters/scripts/usage-dashboard.sh --open`.

It writes one self-contained page (default `.ia-engineering/usage/dashboard.html`, gitignored) showing, per Employee on the roster, its dispatches from the AI runtime's local transcripts, its commits from `Employee:` trailers, and its registered Work Units — with the Employees that have none marked **NEVER USED** — and, per Agent Chain, which steps' Employees are never exercised. It also shows the models doing the work and the tokens per day. Aggregates only: no prompt, reply or file content reaches the page (`Standards/DATA_PROTECTION_STANDARD.md`).

The decisions it informs, and the first question each one raises:

| What the page shows | First question | Whose decision |
|---|---|---|
| An Employee **never used** | Is its trigger in `Core/EMPLOYEE_SELECTION.md` reachable from the work this project does? A trigger that never fires is a trigger to fix; work the project never has is a role it may not need | Trigger fix: an ordinary Work Unit. Removing, merging or adding an Employee: **the Director** (`Governance/DEPRECATION_POLICY.md`) |
| A chain step **never exercised** | Was the chain run at all (no production, no Incident Chain), or did the Main Agent route around the step? The second is a Dispatch Discipline finding, not a roster one | Reworking a chain: **the Director** — `Core/AGENT_CHAINS.md` is a governed document |
| A dispatched agent type that is **not an Employee** | Was that work done without an accountable Employee (`Core/MAIN_AGENT_CONDUCT.md`, Dispatch Discipline)? | The Main Agent's own conduct; when it repeats, an Issue |
| A requested model out of line with the Employee's tier | Does the brief's model match `Core/CAPABILITY_TIERS.md`? | Main Agent; changing a tier is a Director decision |

**The page informs; it decides nothing.** Zero use is evidence to examine, not a verdict: a rarely used Employee may be exactly as rare as its work. Roster and chain changes remain Director decisions, presented with the page's numbers as the evidence — the same rule as every other change to the framework's structure. The page's own footer lists what it cannot tell you: cost without configured prices, time saved, quality, and whether a chain ran end to end.

---

# What practice added to the protocol

Five things that are true in use and are not obvious from reading `Core/ORCHESTRATION.md`.

## The brief is where the work is decided

A dispatch whose brief names the deliverable, the standards that bind it, the Definition of Done, and **the report's destination** produces a usable Work Unit Report. A dispatch that names only the task produces prose. `Templates/EMPLOYEE_BRIEF.md` carries all four as fields; the failure mode is not omitting them from the template but summarising them in the dispatch instead of stating them.

## Ask for the denominator, or the report will not have one

"All checks pass" and "all 3 of 3 checks pass" cost the same to write and are not the same claim. A brief that asks for the denominator gets it. `Adapters/README.md`'s Check Convention says this about checks; it is equally true of reports.

## A declared gap is worth more than a clean report

The most useful line in the v0.0.12 QA report was *"never saw `release.sh publish`'s plan output — branch guard fired first; uncovered, not passing."* Nothing else in that report changed what happened next. Ask explicitly for **what was not done**; a report without that section is not a shorter report, it is a less trustworthy one.

## Re-verify the claim, not the report

`Core/ORCHESTRATION.md` Step 5 says to re-verify a Work Unit Report against the repository. In practice this means running the thing yourself, not reading the paste. Two dispatches in this project's history reported success against a control that had not run.

## Long reports are truncated in transit

A dispatched Employee's reply is cut at a fixed length. A three-part report loses its third part, which is where the findings usually are. Ask for the findings first and the methodology last, and state a length budget in the brief.

---

# What practice did not change

The gates. Every Director gate in every Workflow held, including the ones it would have been convenient to pass — `Workflows/RELEASE.md` Step 5 stopped a release that was otherwise ready, and the escape-hatch hook refused two of the Main Agent's own commands on the day this was written. Nothing here suggests loosening them.

---

# Related Documents

- `Core/ORCHESTRATION.md` — the protocol itself, and the authority
- `Core/EMPLOYEE_SELECTION.md` — dispatch triggers for all 42 Employees
- `Core/MAIN_AGENT_CONDUCT.md` — Dispatch Discipline, Verification Over Waiting
- `Templates/EMPLOYEE_BRIEF.md`, `Templates/WORK_UNIT_REPORT.md` — the two halves of the contract
- `Governance/TROUBLESHOOTING.md` — the incident catalog

---

# Metadata

Owner: IA Engineering

Version: 0.0.13

Status: Draft

Category: Governance — Practice

Severity: Advisory
