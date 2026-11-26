# Dispatch in Practice

---

# Purpose

`Core/ORCHESTRATION.md` defines the dispatch protocol and `Core/EMPLOYEE_SELECTION.md` names the trigger for each of the 42 Employees. Both are correct. This document is neither: it records **what actually happens when the protocol is run**, and only where practice and the documents differ.

It is deliberately short. This corpus is checked by twenty-two mechanical sections and not one of them can read a sentence, so every page of prose is a page that can go stale unnoticed — the Release Chain example drifted from `Workflows/RELEASE.md` within hours of that Workflow changing, twice in one morning. A long "how it really works" document would be the same defect at greater length.

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

**How it counts** (WU-IAENG-346). A commit's Employee is its `Employee:` trailer. When git does not parse that trailer, because a paragraph follows it or the block holds a line git does not take for a trailer, the page uses the first column-0 `Employee:` line, the line the Employee Trailer check validates. The page says how many commits were counted this way. The chains' **Engineer** step is not one of eight fixed Employees. It is any Employee who committed or registered a Work Unit (`Core/AGENT_CHAINS.md`, The Engineer Step), and the page names them. **Main Agent** and **Director** steps are framework roles, never a gap. A fork or helper started inside an Employee's own sub-agent is credited to that Employee, not listed as a dispatch without one. A **Measurement windows** table dates the range, the whole history and the retained transcripts. A **top-2 share** shows how much of the attributed work two Employees hold, the concentration `Core/EMPLOYEE_SELECTION.md` warns against. When the project's `CLAUDE.md` lists its Active Employees, an Employee outside that list with no activity reads **not active here** rather than NEVER USED.

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

# The Adopter-Worktree Rehearsal

On 26 November 2026, before the Director's first real use, one Work Unit was run end to end in an existing project (WU-IAENG-459, Usage plan item W2.1). Only the published documents were followed: `README.md` Getting Started (the existing-repository route), `Workflows/ONBOARDING.md` (The adoption route), `Adapters/ai-runtimes/claude-code/DAILY_USE.md` and `Workflows/FEATURE_DEVELOPMENT.md`.

**The project.** It was fabricated under the temp directory and was never one of the Director's. It was a Node.js library with:

- six commits on `main` and `develop`;
- its own CI workflow (pull requests to `main` only), a README, sources and tests;
- a `.claude/settings.json` with a `model` key and a `permissions.allow` list, and its own `.claude/agents/code-reviewer.md`;
- a path with spaces (`…/client projects/acme invoices`).

Its `origin` was a bare repository in the same temp directory, and nothing was pushed anywhere else. The framework was `develop` at 2496a78, pinned as "Which ref to pin" allows an early adopter. The machine ran Windows 11, Git Bash, git 2.54.0, Claude Code 2.1.332 and Node 24.

**What ran, how, and how long.**

| Step | How it ran | Time | Outcome |
|---|---|---|---|
| Adoption, README route | By hand, command by command, each git command as `git -C "<project root>"`, because the rehearsing session's own worktree isolation refuses git behind `cd`. Not dispatched to the DevOps Engineer | 2,281 s of commands, of which 1,644 s were `generate-agents.sh` in three runs | Adopted; #533, #534, #535, #536 |
| Adoption Pull Request | Emulated: the merge commit was made in a second clone of the bare remote, as GitHub would. No CI, no review, no `size/approved` | — | Merged |
| Session start | The SessionStart command from the project's settings, run with Claude Code's payload, then for real in each headless run | 42.7 s | Printed the reading order, the state, the tier map, the cap and the agents, naming the missing Code Reviewer (#534) |
| 1–2 Plan and approval | Real: a headless Main Agent | 99 s | A full plan with two questions for the Director. No worktree chosen (#538) |
| 3–4 Dispatch, commit, push | Real: the Backend Engineer, `isolation: "worktree"` | 152 s + 198 s | First run BLOCKED by the rehearsal's own allow list, then resumed; 3928b72 pushed |
| 5 Review | Real: the Code Reviewer, `isolation: "worktree"` | 259 s | `Decision: changes requested` on 3928b72: no test caught a change to the rounding |
| 5 Fix round and re-review | Real: the same two agents, resumed | 378 s + 518 s | 1297118 pushed; `Decision: approved` on 1297118 |
| QA (FEATURE_DEVELOPMENT Step 7) | By hand, by this Work Unit's QA Engineer | 1 min | 14 of 14 tests pass; a replayed mutant fails 2 |
| 6 Merge | Emulated on the bare remote; the head was matched to 1297118 by hand, as `--match-head-commit` would | — | 4a2f7b6 |
| 7 Cleanup | By hand, DAILY_USE Step 7's commands in order | 27 s for the pull and both removals | 2 worktrees, 3 local branches and 1 remote branch removed, with no refusal |
| 8 Back on `develop` | Real: a headless Main Agent | 226 s | `## develop...origin/develop` and `?? .ia-engineering/reports/` (#540) |

Each headless run used these flags: `claude -p --model opus --setting-sources project,local --strict-mcp-config --permission-mode dontAsk --allowedTools <list>`. Each was capped at 15 minutes, 60 turns and USD 6, and none used `--dangerously-skip-permissions`. The seven runs resumed one conversation, which reported USD 4.20 in total.

**Agents and processes.** In the project there were three agents:

- one Main Agent conversation, run as seven headless runs, never two at once;
- the Backend Engineer, dispatched once and resumed twice, in its own worktree;
- the Code Reviewer, dispatched once and resumed once, in its own worktree.

Never more than one subagent ran at a time. This Work Unit's QA Engineer drove the runs from outside the project.

The machine ran 530 to 656 processes throughout:

- 13 `claude.exe` before and after every run, so none of them was the rehearsal's (a headless run shows as `node.exe`);
- 10 to 20 `node.exe`;
- 17 to 69 `bash.exe`.

The Main Agent counted only its own subagents against the parallel-agent cap. Nothing told it the machine's count.

**Plan items.**

- **S3-27 passes.** S3-27 checks that a worktree subagent's own hooks run with `$CLAUDE_PROJECT_DIR` set to the main checkout. It was never evaluated in v0.0.15.
  - The Employee's calls came from its worktree, where `ia-engineering/` is empty, and went through the framework's PreToolUse guard. The resumed run recorded 26 guard runs, its own and the Employee's. The one refusal answered a call from the worktree, an unreadable heredoc, with an `iaeng: BLOCKED` line, so the hook command resolved through the main checkout.
  - Its two commits ran the project's git hooks (`data-policy: clean`).
  - The worktree started on `worktree-agent-…`, at the remote's `main`. The Employee branched from `origin/develop`, and `git worktree list --porcelain` showed `locked claude agent <name> (pid <n>)`. All three match DAILY_USE Step 3.
- **S2-07 is still refused at 2496a78.** S2-07 is the read `echo "…$(git config --get core.hooksPath)"` around the bootstrap, which was refused in v0.0.15. All three forms, `echo`, `printf` and backtick, exit 2, while `git config --get core.hooksPath` alone passes. #272 holds the evidence, and PR #529 targets it.

**The gap "the Stop gate blocks after every pull of develop" is refuted as stated.** The gate blocks a stop when HEAD's last commit is newer than `.ia-engineering/SESSION_STATE.md` (`stop-gate.sh`, SESSION_STATE gate). A pull alone does not trigger it:

- Right after the pull that brought merge 4a2f7b6, made after the state was last saved, the gate exited 2 with `iaeng: stop gate — .ia-engineering/SESSION_STATE.md is behind the repository`.
- In the real Step 8 run, the Main Agent updated the file before its turn ended, and both Stop hooks exited 0.
- After a pull that brought nothing, the gate exited 0.

So it asks once for each merge that lands after the last save, as DAILY_USE Step 8 says to expect, and never when the Main Agent keeps the state current.

**Findings.** Each is filed as an `adoption-finding` issue. None is fixed here.

- #533: the project's own `code-reviewer.md` makes `generate-agents.sh` exit 1, leaving the Code Reviewer with no agent. The data-policy hook then refuses the rename that the generator asks for, until an allow rule exists. README's route mentions neither.
- #534: the route's `git switch develop` checks out a pre-adoption commit that tracks that file, which overwrites the generated agent, and the pull then removes it. Session start catches it, and regenerating took another 395 s.
- #535: the adoption documents give `git config core.hooksPath`, which the guard refuses next to a quoted path, and a path with spaces needs quotes.
- #536: each `generate-agents.sh` run took 395 to 633 s, a commit's git hooks took 98 to 130 s, and the Stop gate took 8.9 to 35.2 s.
- #538: nothing the adopter's Main Agent reads asks for the worktree dispatch of DAILY_USE Step 3. Its plan chose none until the Director asked.
- #540: the brief sent the worktree Employee's report to the main checkout, which the Employee cannot write to, and the report directory is not ignored.
- #541: Step 7 does not cover the reviewer's detached worktree, and nothing deletes the adoption branch.

**Limits.**

- There was no forge, so there was no Pull Request, no CI check, no `size/approved` and no `gh pr merge`. Review decisions were in the Main Agent's reports, not in Pull Request comments.
- This Work Unit's QA Engineer, not a dispatched Employee, ran the adoption and the Step 7 cleanup by hand, and made both merges in the emulated forge.
- The headless runs loaded the project's settings only, not a Director's user settings. Claude Code also ignored the project's `permissions.allow`, because the workspace had never been trusted interactively.
- The first dispatch stopped because the rehearsal's allow list did not include `node -e`. The Employee reported the refusal and did not route around it.
- The fabricated project's `npm test` script fails on Node 24. That is a defect of the fabrication, so the agents ran `node --test` instead.
- The rehearsal's own adoption commits put a blank line between `Employee:` and the attribution line. The Employee copied that layout, and the Code Reviewer flagged it against `Standards/COMMIT_STANDARD.md`. This was an operator error, not a framework finding.
- The timings come from one run on one loaded machine.

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

Version: 0.0.15

Status: Draft

Category: Governance — Practice

Severity: Advisory
