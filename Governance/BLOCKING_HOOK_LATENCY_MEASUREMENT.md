# Blocking Hook Latency Measurement

---

# Purpose

Issue #351 (peer K2) asked one question: **on Windows, with several agents working in parallel, how long do the framework's blocking hooks take, and how often do they run past the timeout after which Claude Code lets the action through?** This document is the measurement that answers it (WU-IAENG-410), and the record of what was changed because of it. It follows `Core/CONTEXT_BUDGET.md`'s rule: every number says where it comes from, and what is measured is kept apart from what is modelled.

The measurement was taken on 28 October 2026 and the decision was made on 29 October 2026.

**Verdict.**

1. **The premise was wrong.** The issue assumed a 10-second timeout. The two PreToolUse guards and the Stop gate had no `timeout` of their own, so Claude Code's default of **600 s** applied. A guard that hung was given ten minutes, and then the tool call went through.
2. **That fail-open happened once in production.** On 27 October, `block-inline-suppression.sh` hung in a subagent and was cancelled at its timeout, and the edit went through (Observed Timeouts below).
3. **Under load, the latency comes from process creation, not from the hooks' own work.** In production, `stop-gate.sh` (29 processes per call) has a p95 of 16 s and a p99 of 26 s. That is 3 to 4 times a hook that starts almost nothing, measured on the same Stop events. `block-escape-hatches.sh` starts 84 processes on every Bash call. Its modelled production latency is a p50 of 9 s and a p99 of 61 s, rising to about 90 s with 8 or more agents.
4. **Director decision, 29 October 2026:** record this measurement; give both guards `"onFailure": "block"` and an explicit timeout; lighten the hooks that start many processes. The guards now have a **120 s** timeout and fail closed. `stop-gate.sh` starts **4 commands instead of 8** on its common path (Decisions Taken).

---

# Scope and Machine

**Hooks:** the two PreToolUse guards `block-escape-hatches.sh` (matcher `Bash`) and `block-inline-suppression.sh` (`Edit|Write|MultiEdit`), the Stop gate `stop-gate.sh`, and for comparison `session-start.sh`, `context-alert.sh`, `post-edit-lint.sh` and `dashboard-refresh.sh`.

**Machine:** the Director's workstation. Intel Core Ultra 7 355 (8 logical cores), 32 GB RAM, Windows 11 Home 26200, Microsoft Defender real-time protection on, Git 2.54.0.windows.1, bash 5.3.9 (MSYS 3.6.7), jq 1.8.1 (native WinGet build), Claude Code 2.1.312.

---

# The Timeout Actually in Force

The installed `.claude/settings.json` set `"timeout": 10` on `context-alert.sh` and `dashboard-refresh.sh` only. The guards, `stop-gate.sh` and `session-start.sh` had none.

The [hooks reference](https://code.claude.com/docs/en/hooks.md), read on 28 and 29 October 2026, says:

- `timeout` is in seconds. It defaults to **600** for a `command` hook, and to 30 on `UserPromptSubmit`.
- "On `PreToolUse`, a timed-out `command` [...] hook doesn't block the tool call, except for hooks whose failure blocks the action [...] so don't count on a stalled hook to act as a gate."
- `onFailure`: `"continue"` or `"block"`, Claude Code v2.1.295 or later. With `"block"`, a failure does what exit code 2 does on that event, so on PreToolUse it blocks the tool call. These are failures: the hook cannot start, it exits with a code other than 0 or 2, it reaches its timeout, or it prints JSON that cannot be parsed. Plain-text stdout is not a failure.
- `onFailure` "has no effect" on `Stop`, `SubagentStop`, `TaskCompleted` and `TeammateIdle`: "exit code 2 on these events sends Claude back to keep working, and Claude can't repair a hook that won't run". A timed-out hook is cancelled and its output discarded, so it gives no decision. The page does not describe a timed-out Stop hook separately. The general rule means the session ends, unchecked.
- "When an event fires, its matching hooks run in parallel." The framework's hooks share each event with the hooks of any plugin the user has installed.

So for the guards, the fail-open threshold was 600 s, not 10 s. The 10-second figure still applies to `context-alert.sh`, which really has it, and it is the issue's own hypothesis. Both thresholds are reported below.

---

# Method

**Production data.** These are the 416 Claude Code transcripts of this repository in `~/.claude/projects/<this repository>/`, from 3 September to 28 October 2026: the main session and every subagent, 801 MB, read only. Claude Code records each hook's `durationMs`: in `stop_hook_summary`, and in `hook_success` and `hook_cancelled` attachments, with `timedOut` and `timeoutMs`. **A PreToolUse hook that succeeds is not recorded** (one occurrence in the whole set), so the guards' production latency is modelled (below).

**Load.** For each event, the load is the number of this project's transcripts that wrote at least one line in the same minute. It is a proxy for the number of active agents. It does not count other projects on the machine or their CI, which ran at the same time.

**Controlled bench.** A PowerShell harness started each hook exactly as Claude Code does on Windows: `Git\bin\bash.exe -c "bash \"$CLAUDE_PROJECT_DIR/.../hook.sh\""` from a native parent, with a recorded payload on stdin, against a scratch clone of the repository. Each run sat in a Windows Job Object, so the harness counted every process the run created (the launcher, the MSYS bash, the script's bash, every fork and exec) and summed their CPU time. There were 610 runs, one at a time, with the hooks interleaved round-robin. Calibration hooks: a no-op, 20 forks, and 20 external commands. The bench ran from 11:53 to 12:08 UTC on 28 October, alongside the agents working that day. A sampler logged the machine every 10 s: CPU at 100 % in all 74 samples, run queue 64 on average (maximum 128), Defender (`MsMpEng`) at 127 % of one core, 18 bash, 7 node and 5 claude processes. **The bench is therefore a measurement under load. No idle bench was taken.** The closest thing to idle is production with one active agent (below).

**Model for the guards.** A Stop event runs `stop-gate.sh` and `dashboard-refresh.sh` in parallel. `dashboard-refresh.sh` starts no external process: it detaches a background bash and exits. Its duration is the floor, the launcher plus bash, measured by Claude Code in the same event as the gate. There are 758 such pairs. For a guard, the model takes each real Stop event and puts in its place `floor + (stop-gate − floor) × k`, where `k = (guard − no-op) / (stop-gate − no-op)` comes from the bench's medians. The stop-gate's own `k = 1` reproduces its production distribution by construction. A second `k`, from CPU time or from process counts, gives the spread.

---

# Results

## Production, All Loads (ms)

| Hook | n | p50 | p95 | p99 | max | > 10 s |
|---|---:|---:|---:|---:|---:|---:|
| `stop-gate.sh` (Stop, timeout 600 s) | 1,490 | 2,740 | 16,172 | 26,195 | 45,597 | 191 (12.8 %) |
| `session-start.sh` (SessionStart) | 32 | 3,010 | 10,012 | 16,871 | 16,871 | 2 (6.2 %) |
| `post-edit-lint.sh` (PostToolUse, a bash reference) | 4,882 | 1,586 | 12,916 | 19,543 | 201,802 | 369 (7.6 %) |
| `dashboard-refresh.sh` (Stop, timeout 10 s) | 790 | 927 | 4,625 | 8,889 | 20,407 | 7 (0.9 %) |
| `context-alert.sh` (timeout 10 s; recorded only on output or failure) | 7 | 12,784 | 18,463 | 18,463 | 18,463 | 6 |

## The Load Dependence

`stop-gate.sh` by number of active agents in the same minute (ms):

| Active agents | n | p50 | p95 | p99 | max | > 10 s |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 136 | 973 | 9,027 | 29,202 | 29,208 | 4.4 % |
| 2–3 | 643 | 2,155 | 11,513 | 19,541 | 29,522 | 6.4 % |
| 4–7 | 639 | 3,537 | 19,449 | 26,405 | 45,597 | 18.3 % |
| 8 and more | 72 | 7,624 | 20,505 | 29,964 | 29,964 | 37.5 % |

`post-edit-lint.sh` follows the same slope. Its p50 goes 674, 1,442, 2,873 and 4,415 ms; the share over 10 s goes 0.6, 5.5, 13.6 and 12.0 %.

By day, the same gate went from a p50 of about 300 to 600 ms and a maximum of 1,610 ms (8 to 11 September, one agent) to a p50 of 14,693 ms and 76.9 % over 10 s on 7 October, a heavy parallel day. On 21 October it was back to a p50 of 1,648 ms and nothing over 10 s.

## Same Stop Event: the Gate Against the Floor (ms)

| Active agents | pairs | stop-gate p50 / p95 | floor p50 / p95 | gap p50 / p95 | stop-gate > 10 s | floor > 10 s |
|---|---:|---|---|---|---:|---:|
| 1 | 52 | 1,730 / 10,009 | 539 / 3,462 | 1,293 / 5,610 | 5.8 % | 1.9 % |
| 2–3 | 279 | 2,966 / 13,212 | 822 / 3,991 | 2,132 / 10,377 | 8.2 % | 0.4 % |
| 4–7 | 368 | 3,487 / 14,507 | 991 / 4,739 | 2,393 / 10,802 | 14.7 % | 0.5 % |
| 8 and more | 59 | 7,544 / 20,505 | 2,048 / 7,424 | 5,298 / 13,408 | 37.3 % | 3.4 % |

Under the same conditions, the 29-process gate takes 3 to 4 times as long as the floor, and under heavy load it passes 10 s ten times as often. **The number of processes per call is the factor the framework controls.** The floor itself, about 4 processes, still passes 10 s in 0.4 to 3.4 % of events.

## Observed Timeouts

| Date (UTC) | Hook | Event | Where | Duration | Timeout |
|---|---|---|---|---:|---:|
| 20 Oct 07:36 | `dashboard-refresh.sh` | Stop | main session | 10,658 ms | 10 s |
| **27 Oct 08:53** | **`block-inline-suppression.sh`** | **PreToolUse** | subagent | 70,749,633 ms (19.6 h) | 600 s |
| 28 Oct 10:16 | `context-alert.sh` | PostToolBatch | subagent | 18,463 ms | 10 s |
| 28 Oct 10:22 (×2) | `context-alert.sh` | PostToolBatch | subagents | 12,777 / 12,784 ms | 10 s |
| 28 Oct 10:35 | `context-alert.sh` | PostToolBatch | subagent | 12,935 ms | 10 s |
| 28 Oct 10:45 | `context-alert.sh` | PostToolBatch | subagent | 10,870 ms | 10 s |
| 28 Oct 11:31 | `context-alert.sh` | UserPromptSubmit | main session | 13,393 ms | 10 s |

- **The only timeout of a guard was a hang.** The 19.6-hour duration probably includes the machine sleeping. The edit went through when the hook was cancelled.
- In a subagent, `context-alert.sh` exits as soon as it sees `agent_id` in the first 4,096 bytes, **without starting a single external process**. Its 11 to 18 s are therefore almost all process start-up under load: the launcher, the MSYS bash, the script's bash. None of it is the script's own work.
- The OMC plugin's hooks (node, timeout 3 s) run on the same events, in parallel with the framework's. Since 26 October, `pre-tool-enforcer.mjs` succeeded 3,293 times on PreToolUse and **timed out 1,653 times (33 %)**. The Stop event runs 4 node hooks beside the two framework hooks, with 211 timeouts. These hooks belong to the user's configuration, not to the framework. They compete for the same process creation. This was reported to the Director and is not addressed here.

## Controlled Bench, Under Load (ms)

| Hook | runs | processes per call | CPU per call (median) | p50 | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|---:|---:|
| no-op (calibration) | 60 | 4 | 78 | 201 | 473 | 740 | 740 |
| 20 forks (calibration) | 30 | 24 | 391 | 1,066 | 1,406 | 3,110 | 3,110 |
| 20 external commands (calibration) | 30 | 44 | 641 | 1,213 | 2,077 | 2,314 | 2,314 |
| `context-alert.sh` (three payloads) | 180 | 4 | 78–94 | 189–212 | 355–592 | 649–1,139 | 1,139 |
| `stop-gate.sh` | 60 | 29 | 516 | 1,032 | 1,614 | 1,848 | 1,848 |
| `block-inline-suppression.sh` | 100 | 55 (19 to 55) | 891 | 1,732 | 2,755 | 3,376 | 3,483 |
| `block-escape-hatches.sh` | 100 | 84 (84 to 220) | 1,703 | 3,117 | 5,547 | 6,951 | 8,200 |
| `session-start.sh` | 50 | 102 | 1,938 | 3,434 | 4,615 | 4,727 | 4,727 |

Every run exited 0. The calibration rows give the unit of cost. On MSYS, a fork is one process and an external command is two (a fork, then an exec). Each costs about 40 to 50 ms here, whether it is a fork or a command. The four-process floor costs 200 ms. A hook's latency follows its process count, not its logic.

## The Guards in Production, Modelled (ms)

| Hook (`k`) | Active agents | p50 | p95 | p99 | max | > 10 s | > 60 s |
|---|---|---:|---:|---:|---:|---:|---:|
| `block-escape-hatches.sh` (3.51; 3.71 by CPU) | all (757) | 9,039 | 42,594 | 60,541 | 88,308 | 45 % | 8 (1.1 %) |
| | 8 and more (59) | 21,193 | 50,398 | 88,308 | 88,308 | 81 % | 1 |
| | 8 and more, `k` by CPU | 22,303 | 53,079 | 92,957 | 92,957 | 81 % | 2 |
| `block-inline-suppression.sh` (1.84; 2.04 by processes) | all (757) | 5,267 | 24,255 | 35,410 | 49,489 | 27 % | 0 |
| | 8 and more (59) | 12,101 | 31,430 | 49,489 | 49,489 | 56 % | 0 |
| | 8 and more, `k` by processes | 13,187 | 34,641 | 54,138 | 54,138 | 58 % | 0 |

`block-escape-hatches.sh` runs on **every** Bash call, far more often than Stop. This is the heaviest per-call cost the framework puts on an agent. The 10 s line was never its real fail-open threshold, but its modelled p50 of 9 s is felt on every command.

---

# Decisions Taken

Director decision of 29 October 2026, carried out in WU-IAENG-410.

## The Guards Fail Closed, With a 120 s Timeout

`settings.example.json`, and through `install-hooks.sh` every installed `settings.json`, gives both PreToolUse guards `"timeout": 120` and `"onFailure": "block"`.

**Why `"onFailure": "block"`.** The guards already fail closed on input they cannot read (`hooks/README.md`, Design Rules). That covered every failure inside the script, but not a guard that hangs, cannot start, or dies with a code other than 0 or 2. Those failures let the tool call through. With `"block"`, they block it. This needs Claude Code 2.1.295 or later. An older Claude Code ignores the field, so its guard is cancelled at 120 s and the call goes through: sooner than the 600 s before, for a guard that hangs. On those versions, only a hang or an input slow enough to pass 120 s reaches that point, and no modelled event does.

**Why 120 s.** The timeout must sit above the guards' latency under the heaviest load measured, or a slow but healthy guard would block a legitimate call. It must also sit well below 600 s, or a hung guard holds the agent for ten minutes. The slowest guard is `block-escape-hatches.sh`. Its modelled p99 is 60.5 s over all loads and 88 to 93 s with 8 or more agents, and that is also the maximum over all 757 modelled events. 1.25 × 93 s is 116 s, which rounds up to **120 s**. No modelled event of either guard reaches it, so with 757 events the rate of false blocks is at most 0.4 % at 95 % confidence (rule of three). A hang now costs 2 minutes and a blocked call, where it used to cost 10 minutes and an unguarded call. One value serves both guards. `block-inline-suppression.sh` peaks at 54 s, so a separate value for it would protect nothing more. **The value has to be measured again** whenever a guard's process count changes (below, issue #385).

**What it changes for an adopter.** A guard that cannot start now blocks every call it guards. The most likely case is a Claude Code session started inside a git worktree whose framework submodule was never initialised (issue #368). Bash and Edit/Write calls in that session are then refused until the submodule is initialised, by hand. A subagent that Claude Code runs in a worktree is not affected: WU-IAENG-414 observed on 29 October 2026 that its hooks run with `$CLAUDE_PROJECT_DIR` set to the main checkout. This is the intended fail-closed behaviour: before, the same checkout ran with no guard at all, and nothing said so. `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` gives the fix.

**The upgrade does not double the guards.** An installed file holds the framework's earlier guard entries, without the two fields. `install-hooks.sh` recognises those entries exactly and adds the two fields in place, as WU-IAENG-373 does for an earlier matcher, instead of appending a second group. A second group would run each guard twice per call and double the very cost measured here. An entry that differs in any other way, such as a timeout of its own or `"onFailure": "continue"`, is the project's. It is left as it is, the framework's entry is added beside it, and the difference is reported as a near miss (`hooks/tests/dashboard.sh`, WU-IAENG-410 cases).

## The Stop Gate Gets Neither

`onFailure` has no effect on Stop, so it is not set there. A `stop-gate.sh` that reaches its timeout is cancelled, and the session ends unchecked. Its timeout stays at the 600 s default. The gate's production maximum was 45.6 s, so a lower value would only add stops that end unchecked. **Being fast is the gate's only protection against its own timeout**, so the gate was lightened (next section).

## The Stop Gate Starts Half the Commands

On its common path, a clean tree and a current `SESSION_STATE.md`, `stop-gate.sh` started 8 external commands: `cat`, `dirname`, `jq`, `git` 3 times and `date` twice. That is 29 processes with the launcher and the forks. It now starts 4: `cat`, `git status`, `date -r` and `git log`. The changes:

- `lib.sh` is found without `dirname`.
- `git rev-parse` runs only when `git status` fails. This is the same decision, because `git status` fails outside a work tree.
- The clock is bash's own (`printf '%(%s)T'`, bash 4.2 and later), with a fallback to `date`.
- The file's mtime and HEAD's time are read without a second subshell around them.
- The loop guard (`stop_hook_active`) is read only just before the hook blocks or reminds, so the path that says nothing starts no `jq`.

What the gate decides is unchanged. The tests show it: every existing stop-gate case passes, and five new cases check that the loop guard still silences every block and every reminder. A new budget check counts the commands started on the common path with recording stand-ins on `PATH`: no `jq`, at most 4 commands. It failed on the earlier hook (8 commands) and passes on this one.

**Measured.** The same harness ran on 29 October 2026 from 11:48 to 11:58 UTC, against a scratch project on that path with a synthetic 2 KB Stop payload. The earlier and the new gate alternated, so both met the same load. CPU was at 100 % for every run. The machine was more loaded than on 28 October: the no-op's p50 was 1,093 ms, against 201 ms then.

| On the same machine, interleaved | runs | processes per call | CPU per call (median) | p50 (ms) | p95 (ms) | p99 (ms) | > 10 s |
|---|---:|---:|---:|---:|---:|---:|---:|
| no-op (calibration, reads its stdin) | 40 | 6 | 156 | 1,093 | 1,532 | 1,966 | 0 |
| `stop-gate.sh` before | 80 | 29 | 734 | 3,449 | 7,898 | 11,863 | 3 (3.8 %) |
| `stop-gate.sh` after | 80 | 15 | 391 | 1,853 | 4,560 | 6,401 | 0 |

Processes per call fall by 48 %, CPU by 47 %, and the p50, p95 and p99 by 42 to 46 %. Above the no-op floor, the gate's own cost at p50 falls from 2,356 ms to 760 ms. Every run exited 0. The production numbers above are from before this change. The next measurement of production Stop events will show its effect there.

---

# Mitigations Not Taken Here

Ranked by the cost they would remove. Each needs its own Work Unit.

1. **`block-escape-hatches.sh`: 84 processes on every Bash call** (issue #385). Most of them are one `grep` per rule over the lexed command. Matching in bash itself would remove most of them. But this guard's matching *is* its security boundary, so the change needs the full escape-hatch corpus and a Security Engineer review. That puts it outside this Work Unit. It is also what keeps the guards' timeout at 120 s.
2. **`block-inline-suppression.sh`: 55 processes on every edit.** Same remedy, same review.
3. **`session-start.sh`: 102 processes**, once per session and per `/clear`. It runs rarely, so it is lower on the list.
4. **The plugin hooks.** Four node hooks on Stop and one on PreToolUse, which times out 33 % of the time. They belong to the user's configuration, not the framework's. The Director has been told.
5. **A machine-wide limit on parallel agents.** WU-IAENG-409 left this decision until after this measurement. The load table above is the input: the share of gate runs over 10 s is 4 to 6 % with up to 3 agents, 18 % with 4 to 7, and 38 % with 8 or more.

---

# Limits

- **One machine.** Windows with Git Bash and Defender's real-time scanning is the expensive case. On Linux and macOS a process costs a few milliseconds, and the same hooks are not slow.
- **The guards' production latency is modelled.** Claude Code does not record a PreToolUse hook that succeeds. The model assumes a guard's extra cost over the floor scales with load the way the gate's does. The two values of `k` show how sensitive the result is to that assumption.
- **The load measure is a proxy.** It counts this project's transcripts active in the same minute. It does not count other projects or CI.
- **No idle bench.** The machine was under load through the whole bench window. One active agent in production is the nearest idle figure: a p50 of 973 ms for the gate.
- **The bench ran one hook at a time.** The harness had a mode for concurrent runs. It was not used, because production already gives the behaviour under concurrency.

---

# Sources

- Claude Code hooks reference: <https://code.claude.com/docs/en/hooks.md> (timeouts, `onFailure`, parallel execution), read 28 and 29 October 2026, against Claude Code 2.1.312.
- Transcripts: `~/.claude/projects/<this repository>/*.jsonl` and their `subagents/` files, 3 September to 28 October 2026, read only. Fields used: `durationMs`, `timedOut` and `timeoutMs` of `stop_hook_summary`, `hook_success` and `hook_cancelled`.
- The working notes of the measurement, in French, are kept outside the repository as `.ia-engineering/handoff-2026-10-28-hook-latency.md`. The bench harness, its raw data and the model scripts are in the session's scratch directory. They are not committed, because they hold transcript-derived data (`Standards/DATA_PROTECTION_STANDARD.md`).
- Issue #351 (the question), #368 (the uninitialised submodule in a worktree), #385 (lightening `block-escape-hatches.sh`).

---

# Metadata

Owner: IA Engineering

Version: 0.0.14

Status: Draft

Category: Governance — Measurement

Severity: Advisory
