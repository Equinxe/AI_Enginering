# Dispatch in Practice

---

# Purpose

`Core/ORCHESTRATION.md` defines the dispatch protocol and `Core/EMPLOYEE_SELECTION.md` names the trigger for each of the 42 Employees. Both are correct. This document is neither: it records **what actually happens when the protocol is run**, and only where practice and the documents differ.

It is deliberately short. This corpus is checked by sixteen mechanical sections and not one of them can read a sentence, so every page of prose is a page that can go stale unnoticed — the Release Chain example drifted from `Workflows/RELEASE.md` within hours of that Workflow changing, twice in one morning. A long "how it really works" document would be the same defect at greater length.

**Where this disagrees with `Core/ORCHESTRATION.md`, that document is right and this one is a defect.**

---

# What the numbers say

The numbers are counted by `Adapters/scripts/usage-dashboard.sh` (see Measuring Usage, below), not by hand. A figure written here is a dated snapshot; the script is the source, and a reader who needs the current number runs it. Its headline on 6 October 2026, after 431 non-merge commits:

| | |
|---|---|
| Employees used — a dispatch, a commit or a registered Work Unit | **19 of 42**, 3 of them rarely |
| Employees never used | **23** |
| Dispatches found in this project's transcripts | **187**, 12 of them to agent types that are not Employees |

The 8 September hand count found 13 of 42 Employees dispatched and **zero** Employee definitions changed as a result of being dispatched. The second number has since moved, and how it moved is the point: ten definitions changed in a single day of roster work on 25 September — licence compliance given an owner, accessibility made a verified gate, adversarial testing of the framework's own controls. The one change with a dispatch in its provenance came from a dispatch that **failed** — a Penetration Tester that hit its session limit having tested nothing (Issue #112) — not from reading a successful report.

So the conclusion stands: **dispatching an Employee is not, by itself, how Employee definitions improve.** The improvements came from auditing the roster against the work, and from executing a control and reading its output.

---

# Measuring Usage

`Adapters/scripts/usage-dashboard.sh` counts usage on demand, for this repository or any project that adopted the framework:

```bash
Adapters/scripts/usage-dashboard.sh --project-dir <project> [--open]
```

In a Claude Code session, open it with **`/dashboard`**. The page opens at once, with no rebuild to wait for, because a `Stop` hook has been keeping it fresh at the end of every turn. It refreshes once more behind the open page, which reloads itself. Only the first `/dashboard` in a project, which has no page yet, waits for a build. Both are installed with the framework's other Claude Code Adapters (`install-hooks.sh`, `install-skills.sh`). Outside a session, two ways to open it in one step, rebuilt first only when something it shows has changed:

- **Windows** — `Adapters\scripts\usage-dashboard.cmd`, from PowerShell, cmd, or a double-click in Explorer. It runs the script with `--open` through Git for Windows' own `bash.exe`; typing `bash` in PowerShell reaches WSL instead (`Governance/TROUBLESHOOTING.md` entry AA). From an adopter's `ia-engineering` submodule it measures the adopting project.
- **macOS, Linux, Git Bash** — `Adapters/scripts/usage-dashboard.sh --open`.

Run from a linked git worktree, it looks for the worktree's own transcripts and finds none, so every dispatch reads as zero; pass `--transcripts-dir` with the main checkout's transcript directory.

It writes one self-contained page (default `.ia-engineering/usage/dashboard.html`, gitignored) showing, per Employee on the roster, its dispatches from the AI runtime's local transcripts, its commits from `Employee:` trailers, and its registered Work Units — with the Employees that have none marked **NEVER USED** — and, per Agent Chain, which steps' Employees are never exercised. It also shows the models doing the work and the tokens per day. Aggregates only: no prompt, reply or file content reaches the page (`Standards/DATA_PROTECTION_STANDARD.md`).

The decisions it informs, and the first question each one raises:

| What the page shows | First question | Whose decision |
|---|---|---|
| An Employee **never used** | Is its trigger in `Core/EMPLOYEE_SELECTION.md` reachable from the work this project does? A trigger that never fires is a trigger to fix; work the project never has is a role it may not need | Trigger fix: an ordinary Work Unit. Removing, merging or adding an Employee: **the Director** (`Governance/DEPRECATION_POLICY.md`) |
| A chain step **never exercised** | Was the chain run at all (no production, no Incident Chain), or did the Main Agent route around the step? The second is a Dispatch Discipline finding, not a roster one | Reworking a chain: **the Director** — `Core/AGENT_CHAINS.md` is a governed document |
| A dispatched agent type that is **not an Employee** | Is it one of the two cases in *When a non-Employee agent is acceptable* (below)? If not, that work was done without an accountable Employee (`Core/MAIN_AGENT_CONDUCT.md`, Dispatch Discipline) | The Main Agent's own conduct; when it repeats, an Issue |
| A requested model out of line with the Employee's tier | Does the brief's model match `Core/CAPABILITY_TIERS.md`? | Main Agent; changing a tier is a Director decision |

**Live.** `--watch` keeps the page current while you work: it is rebuilt every 10 seconds by default (`--watch 30` for slower), reloads itself in the browser, and says when it was last updated. Stop the command and the page stays as it was. A cycle that finds no new commit and no grown transcript rebuilds nothing; otherwise only what changed is read again. The interval is optional and the flag can come after `--open`, so the Windows launcher of WU-IAENG-329, which passes its arguments after `--open`, keeps the page live with `usage-dashboard.cmd --watch`. The transcript directories are found once, when the watch starts: a session started afterwards in a new runtime worktree of the project is counted after the watch is restarted.

**Kept fresh.** Opening the page does not mean waiting for a rebuild. Every run keeps what it read in the project's `.ia-engineering/usage/cache/` — shape-checked values only, never a message or a transcript line — so only the very first run reads everything; a cache that is a link, is not yours, or is not ignored by git is not used, and the run says why. `--open` (and the Windows launcher, which passes it) opens the page at once when nothing it is built from has changed since — no new commit or tag, no transcript grown, no registry edited — and otherwise reads only what changed, then opens it. Two more modes keep the page current while you work: `--refresh-in-background` refreshes it detached, at most once a minute, and returns at once; `--open --no-wait` opens the page as it is and refreshes it behind, the open page reloading itself. In Claude Code both run on their own. The `Stop` hook `Adapters/ai-runtimes/claude-code/hooks/dashboard-refresh.sh` runs the first at the end of every turn, and `/dashboard` runs the second. So the page is **kept fresh automatically**, and `/dashboard` opens it instantly. The hook never blocks, slows or fails a turn, and never touches the stop gate's decision. A project that does not want it creates `.ia-engineering/usage-auto-refresh.off`, the reliable switch, or sets `IAENG_USAGE_AUTO_REFRESH=off` where the runtime passes it to hooks (`Adapters/ai-runtimes/claude-code/hooks/README.md`, Dashboard Refresh). Another runtime calls the same two modes from its own equivalent points. The contract is in the script's header, under KEPT FRESH.

**One page per project.** Run from a project — including through `ia-engineering/Adapters/scripts/`, or from inside that directory — it measures that project and nothing else: its git history, the framework roster plus its own Domain Employees, its own `Registry/`, the AI-runtime transcripts recorded for its own path, and it writes under its own `.ia-engineering/usage/`. A new project therefore starts with every Employee at zero. Two caveats, both about transcripts:

- a project re-created at the **same path** inherits that path's earlier transcripts — pass `--transcripts-dir`, or remove the old directory under the runtime's `projects/` folder;
- a project whose path is **very long** (beyond the 200 characters the runtime keeps in a directory name) is matched by the transcripts' recorded working directory; when that cannot settle it, the page says the transcripts are **ambiguous** and counts none, rather than count another project's — pass `--transcripts-dir`;
- the runtime **deletes** its transcripts after a retention period (Claude Code: `cleanupPeriodDays`, 30 days by default), so dispatches and tokens cover a rolling window, while everything read from git — commits per Employee, per Work Unit, per model — is permanent.

**The page informs; it decides nothing.** Zero use is evidence to examine, not a verdict: a rarely used Employee may be exactly as rare as its work. Roster and chain changes remain Director decisions, presented with the page's numbers as the evidence — the same rule as every other change to the framework's structure. The page's own footer lists what it cannot tell you: cost without configured prices, time saved, quality, and whether a chain ran end to end.

---

# When a non-Employee agent is acceptable

Dispatch Discipline (`Core/MAIN_AGENT_CONDUCT.md`) admits no generic agent doing a Work Unit. Practice found exactly two cases where a plain agent is the right instrument, and in both a named Employee owns the work and the agent does not:

1. **A simulated naive user in a usability or acceptance test.** The plain agent is the **test subject**: it is given only what a real newcomer would have, so that what it fails to find is a finding. An Employee would bring the framework's knowledge with it and invalidate the test. The protocol and the verdict belong to the **UX/UI Designer**; acceptance against the Work Unit's criteria belongs to the **QA Engineer**. The subject's transcript is evidence those Employees read, never a deliverable.
2. **A vendor-documentation lookup** — what a runtime, SDK or API actually does, read from its publisher's documentation. The Employee whose Work Unit needs the answer owns the question and the conclusion; for an AI model, AI provider or AI runtime question with no such Work Unit, that is the **AI Engineer**. The lookup agent only fetches.

In both, the owning Employee's brief names the plain agent it uses, and the commit, report and verdict carry that Employee's name. The test subject's own prompt names no Employee and carries nothing a real newcomer would not have. **Anything else is a Dispatch Discipline violation** — including a plain agent used because it was quicker to start, or a runtime's own reviewer standing in for the Code Reviewer.

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

Version: 0.0.14

Status: Draft

Category: Governance — Practice

Severity: Advisory
