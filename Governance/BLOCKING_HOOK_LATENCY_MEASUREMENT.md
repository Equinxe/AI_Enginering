# Blocking Hook Latency Measurement

---

# Purpose

Issue #351 (peer K2) asked one question: **on Windows, with several agents working in parallel, how long do the framework's blocking hooks take, and how often do they run past the timeout after which Claude Code lets the action through?** This document is the measurement that answers it (WU-IAENG-410), and the record of what was changed because of it. It follows `Core/CONTEXT_BUDGET.md`'s rule: every number says where it comes from, and what is measured is kept apart from what is modelled.

The measurement was taken on 28 October 2026 and the decision was made on 29 October 2026.

**Verdict.**

1. **The premise was wrong.** The issue assumed a 10-second timeout. The two PreToolUse guards and the Stop gate had no `timeout` of their own, so Claude Code's default of **600 s** applied. A guard that hung was given ten minutes, and then the tool call went through.
2. **That fail-open happened once in production.** On 27 October, `block-inline-suppression.sh` hung in a subagent and was cancelled at its timeout, and the edit went through (Observed Timeouts below).
3. **Under load, the latency comes from process creation, not from the hooks' own work.** In production, `stop-gate.sh` (29 processes per call) has a p95 of 16 s and a p99 of 26 s. That is 3 to 4 times a hook that starts almost nothing, measured on the same Stop events. `block-escape-hatches.sh` starts 84 processes on every Bash call. Its modelled production latency is a p50 of 9 s and a p99 of 61 s, rising to about 90 s with 8 or more agents.
4. **Director decision, 29 October 2026:** record this measurement; give both guards `"onFailure": "block"` and an explicit timeout; lighten the hooks that start many processes. The guards now have a **120 s** timeout and fail closed. `stop-gate.sh` starts **4 commands instead of 8** on its common path. Benched under load, that is 15 processes per call instead of 29, and a p50 and p99 46 % lower (Decisions Taken).
5. **4 November 2026, WU-IAENG-431:** `block-escape-hatches.sh` matches its rules in bash and starts 9 to 15 processes per call instead of 80 to 216. Benched under load, its p50 and p95 fall to 13 % and 15 % of before. In the production model with 8 or more agents, they fall from 21 s and 50 s to 3.7 s and 13.5 s, and the slowest event from 88 s to 21 s. A command of more than 2,000 pipeline segments is now refused (The Escape-Hatch Guard Matches in Bash).
6. **17 November 2026, Director decision D3, completed on 18 November:** at most **6 subagents run at once per machine, Employees included**, counting the subagents of every Claude Code session on it, from the `develop` commit that merged WU-IAENG-431.
   - The cap is 3 while any session on the machine runs v0.0.15 or earlier.
   - Every main session beyond the first lowers the cap by one.
   - Every dispatch counts, reviews included.
   - At or above the cap a dispatch waits and the Director is told; the cap never refuses one.
   - With 6 calls at a time, on a machine at 100 % CPU but a lighter process-creation load than the heaviest measured, the slowest guard call took 9.8 s, 8 % of the timeout.
   - The cap is decided again after the edit guard is re-measured (Usage plan W2.3) (The Parallel-Agent Cap).
7. **19 and 24 November 2026, WU-IAENG-444:** `block-inline-suppression.sh` starts `cat`, one `jq` and one `grep` on a code edit, 14 processes per call instead of 52, and 18 when a path names `tests` or the pattern file. Interleaved with develop's at 6 calls at a time, on 200 real edits at the capped load, its p50 is 29.6 % of before, and its own cost above the no-op 22.8 %, against the third that W2.3 asks for. On 24 synthetic payloads at a light load, the same ratios were 23 % and 14 %. Every verdict is unchanged, but one: an edit of 65,536 to 65,663 bytes no longer waits for the 120 s timeout. Neither load reached the no-op p50 of 2 s that the cap decision needs, so this does not decide the cap (The Edit Guard Starts a Quarter of the Processes).

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

**Model for the guards.** A Stop event runs `stop-gate.sh` and `dashboard-refresh.sh` in parallel. `dashboard-refresh.sh` starts no external process: it detaches a background bash and exits. Its duration is the floor, the launcher plus bash, measured by Claude Code in the same event as the gate. There are 758 such pairs. In one of them the floor outlasted the gate (2,112 ms against 298 ms), and a negative gap cannot be scaled, so the model uses the other **757**. For a guard, the model takes each real Stop event and puts in its place `floor + (stop-gate − floor) × k`, where `k = (guard − no-op) / (stop-gate − no-op)` comes from the bench's medians. The stop-gate's own `k = 1` reproduces its production distribution by construction. A second `k`, from CPU time or from process counts, gives the spread.

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

**Why 120 s.** The timeout must sit above the guards' latency under the heaviest load measured, or a slow but healthy guard would block a legitimate call. It must also sit well below 600 s, or a hung guard holds the agent for ten minutes. The slowest guard is `block-escape-hatches.sh`. Its modelled p99 is 60.5 s over all loads and 88 to 93 s with 8 or more agents, and that is also the maximum over all 757 modelled events. 1.25 × 93 s is 116 s, which rounds up to **120 s**. No modelled event of either guard reaches it. Under the model, with 757 events, that bounds the rate of false blocks at 0.4 % at 95 % confidence (rule of three). The bound holds only as far as the model does: the events are Stop events scaled by a fixed `k`, not observed guard runs (Limits). A hang now costs 2 minutes and a blocked call, where it used to cost 10 minutes and an unguarded call. One value serves both guards. `block-inline-suppression.sh` peaks at 54 s, so a separate value for it would protect nothing more. **The value has to be measured again** whenever a guard's process count changes (below, issue #385). It was, on 4 November 2026, for `block-escape-hatches.sh` (The 120 s Timeout, below).

**What it changes for an adopter.** A guard that cannot start now blocks every call it guards. The most likely case is a Claude Code session started inside a git worktree whose framework submodule was never initialised (issue #368). Bash and Edit/Write calls in that session are then refused until the submodule is initialised, by hand. A subagent that Claude Code runs in a worktree is not affected: WU-IAENG-414 observed on 29 October 2026 that its hooks run with `$CLAUDE_PROJECT_DIR` set to the main checkout. This is the intended fail-closed behaviour: before, the same checkout ran with no guard at all, and nothing said so. `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` gives the fix.

**The upgrade does not double the guards.** An installed file holds the framework's earlier guard entries, without the two fields. `install-hooks.sh` recognises those entries exactly and adds the two fields in place, as WU-IAENG-373 does for an earlier matcher, instead of appending a second group. A second group would run each guard twice per call and double the very cost measured here. An entry that differs in any other way, such as a timeout of its own or `"onFailure": "continue"`, is the project's. It is left as it is, the framework's entry is added beside it, and the difference is reported as a near miss (`hooks/tests/dashboard.sh`, WU-IAENG-410 cases).

## The Stop Gate Gets Neither

`onFailure` has no effect on Stop, so it is not set there. A `stop-gate.sh` that reaches its timeout is cancelled, and the session ends unchecked. Its timeout stays at the 600 s default. The gate's production maximum was 45.6 s, so a lower value would only add stops that end unchecked. **Being fast is the gate's only protection against its own timeout**, so the gate was lightened (next section).

## The Stop Gate Starts Half the Commands

On its common path, a clean tree and a current `SESSION_STATE.md`, `stop-gate.sh` started 8 external commands: `cat`, `dirname`, `jq`, `git` 3 times and `date` twice. That is 29 processes with the launcher and the forks. It now starts 4: `cat`, `git status`, `date -r` and `git log`. The changes:

- `lib.sh` is found without `dirname`.
- `git rev-parse` runs only when `git status` fails. This is the same decision, because `git status` fails outside a work tree.
- The clock is bash's own (`printf '%(%s)T'`, bash 4.2 and later), with a fallback to `date`.
- The file's mtime, HEAD's time and the clock are read through by-name forms of `lib.sh`'s helpers, which set a variable instead of printing one, so no second subshell wraps them. The printing forms `session-start.sh` uses are written on top of them, so each rule lives once.
- The loop guard (`stop_hook_active`) is read only just before the hook blocks or reminds, so the path that says nothing starts no `jq`.

What the gate decides is unchanged. The tests show it: every existing stop-gate case passes on the earlier hook and on this one. New cases pin what the refactor moved: the loop guard still silences every block and every reminder; outside a git directory the gate says nothing; a bare repository still reaches the state check; and a mtime that is not a non-negative integer (one before 1970) gives "could not determine", not a block. A new budget check counts the commands started on the common path, with recording stand-ins on `PATH`: `git` counted, no `jq`, at most 4. It fails on the earlier hook and passes on this one. It also fails when nothing was counted, so a stand-in directory that never reached `PATH` (a drive-letter `TMPDIR` on Windows) cannot pass it (code review of PR #388).

**Measured.** The same harness ran on 29 October 2026 from 11:48 to 11:58 UTC, against a scratch project on that path with a synthetic 2 KB Stop payload. The earlier and the new gate alternated, so both met the same load. CPU was at 100 % for every run. The machine was more loaded than on 28 October: the no-op's p50 was 1,093 ms, against 201 ms then.

| On the same machine, interleaved | runs | processes per call | CPU per call (median) | p50 (ms) | p95 (ms) | p99 (ms) | > 10 s |
|---|---:|---:|---:|---:|---:|---:|---:|
| no-op (calibration, reads its stdin) | 40 | 6 | 156 | 1,093 | 1,532 | 1,966 | 0 |
| `stop-gate.sh` before | 80 | 29 | 734 | 3,449 | 7,898 | 11,863 | 3 (3.8 %) |
| `stop-gate.sh` after | 80 | 15 | 391 | 1,853 | 4,560 | 6,401 | 0 |

Processes per call fall by 48 %, CPU by 47 %, and the p50, p95 and p99 by 42 to 46 %. Above the no-op floor, the gate's own cost at p50 falls from 2,356 ms to 760 ms. Every run exited 0. The production numbers above are from before this change. The next measurement of production Stop events will show its effect there.

## The Escape-Hatch Guard Matches in Bash (WU-IAENG-431)

Issue #385, Usage plan item W1.4, measured on 4 November 2026. `block-escape-hatches.sh` started 80 to 216 processes on every Bash call (84 at the median on 28 October): one `grep` per rule, two `jq`, a `cat`, an `awk`, and the forks around them. Its rules are now matched by bash itself:

- Each rule's pattern is tested with bash's `[[ =~ ]]`, which is POSIX extended regular expressions as `grep -E` is, one line of the lexed command at a time, as `grep` read a here-string. The patterns are the same text. Case is folded with `nocasematch` where `grep -i` folded it.
- One `jq` reads the tool name and the command, where `iaeng_field` started one per field.
- A carriage return is removed from the command before matching, as bash removes it before running (SEC-IAENG-431-01, from the Security review of PR #463).
- The rule classes match the same bytes as `grep` did: in the copy of a line that is matched, a byte from 0x80 to 0xFF is replaced by one that no pattern names and no class holds, as no class held it under `grep` with `LC_ALL=C` (SEC-IAENG-431-02, same review).
- A command with none of the ten bytes the lexer rewrites (a backslash, `$`, a backtick, either quote, `<`, `{`, `\001` to `\003`) skips the lexer, which would print it back unchanged.
- The two per-segment loops (`core.hooksPath`, approval labels) start no process per segment.
- The one `grep` left is `grep -o` in the `git -c commit.gpgsign` value check, reached only by a command that names that option.

Two refusals are new: a command of more than 2,000 pipeline segments (below), and a rule pattern the running shell cannot compile, which under `grep` read as "no match" and switched the rule off.

### What a Call Starts

Counted by the harness's Job Object, on the 100 recorded Bash payloads of the bench (the no-op is 4: the launcher and the two shells). The bench ran the hook at 1e0796a, before the carriage-return removal; that removal starts no process and can only send fewer commands to the lexer, since a CR was one of the bytes that sent a command there.

| Command kind | payloads | before | after |
|---|---:|---:|---:|
| none of the bytes the lexer rewrites (the lexer is skipped) | 31 | 80 (80 to 122) | 9 |
| one of them at least (the lexer runs) | 67 | 80 (80 to 216) | 12 (12 to 15) |
| a `gh` label edit with a quoted value (the lexer runs twice) | 2 | 106 to 110 | 12 to 15 |

The fourth round adds one process per reader, the bash that feeds it through a pipe: on the same 100 payloads, 9 became 10, 12 became 14 and 15 became 18 (Here-strings of 64 KiB, below).

Counted with recording stand-ins on `PATH` instead, `git status` started 35 external commands (`awk` once, `cat` once, `grep` 31 times, `jq` twice) and starts 2 (`cat`, `jq`). `tests/run.sh` holds the hook to that budget, per kind of command.

### Measured, Before and After Interleaved

The harness of 28 October, unchanged but for one column naming each run's project directory, so develop's hook (75765ba) and this one ran in the same session. Same 100 recorded Bash payloads. 600 runs from 14:35 to 15:08 UTC, the no-op, the hook before and the hook after round-robin, one at a time; then 250 runs with 8 at a time, 15:08 to 15:11 UTC. The machine was the same workstation, with this repository's other agents working throughout. A sampler logged it every 10 s, 180 samples: CPU at 93 % on average and at 100 % in 24, a run queue of 88 on average (231 at most), about 520 processes, Defender at 98 % of one core, and on average 54 bash (the bench's own included), 7 node and 4 claude processes. The no-op's p50 was 389 ms, against 201 ms on 28 October and 1,093 ms on 29 October.

| One call at a time | runs | processes per call | CPU per call (median) | p50 (ms) | p95 (ms) | p99 (ms) | max (ms) | > 10 s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| no-op (calibration) | 200 | 4 | 78 | 389 | 1,259 | 1,998 | 2,661 | 0 |
| `block-escape-hatches.sh` before | 200 | 80 (80 to 216) | 1,906 | 6,915 | 16,934 | 23,166 | 36,277 | 58 (29 %) |
| `block-escape-hatches.sh` after | 200 | 12 (9 to 15) | 219 | 930 | 2,584 | 4,279 | 4,371 | 0 |

| 8 calls at a time | runs | p50 (ms) | p95 (ms) | p99 (ms) | max (ms) | > 10 s |
|---|---:|---:|---:|---:|---:|---:|
| no-op (calibration) | 50 | 558 | 1,096 | 1,463 | 1,463 | 0 |
| `block-escape-hatches.sh` before | 100 | 8,898 | 16,309 | 18,776 | 28,360 | 35 (35 %) |
| `block-escape-hatches.sh` after | 100 | 1,380 | 3,082 | 3,594 | 3,870 | 0 |

One call at a time, the p50 falls to 13 % of before, the p95 to 15 %, the CPU to 11 % and the processes to 15 %. Above the no-op floor, the hook's own cost at p50 falls from 6,525 ms to 540 ms. With 8 at a time, the p50 and p95 fall to 16 % and 19 %; those 8 were a mix of the three, so the new hook's calls also met the old hook's load. Every run exited 0.

### The Production Model, Re-applied

The model above, unchanged: each of the 757 production Stop events, with the guard in place of the gate, `floor + (stop-gate − floor) × k`. The 29-process gate `k` is defined against is gone from develop, so the new `k` is the published one scaled by this run's medians: `k_after = 3.51 × (after − no-op) / (before − no-op)` = **0.291**, and 0.286 by CPU from the published 3.71. The model with `k = 3.51` reproduces the published rows exactly.

| `block-escape-hatches.sh` | Active agents | p50 | p95 | p99 | max | > 10 s | > 60 s |
|---|---|---:|---:|---:|---:|---:|---:|
| before (`k` 3.51) | all (757) | 9,039 | 42,594 | 60,541 | 88,308 | 45 % | 8 (1.1 %) |
| | 8 and more (59) | 21,193 | 50,398 | 88,308 | 88,308 | 81 % | 1 |
| after (`k` 0.291) | all (757) | 1,628 | 7,262 | 12,742 | 22,152 | 1.8 % | 0 |
| | 8 and more (59) | 3,696 | 13,483 | 21,031 | 21,031 | 6.8 % | 0 |
| after, `k` by CPU (0.286) | 8 and more (59) | 3,657 | 13,367 | 20,989 | 20,989 | 6.8 % | 0 |

Over all loads, the p50 and p95 fall from 9.0 s and 42.6 s to 1.6 s and 7.3 s, 18 % and 17 % of before. With 8 or more agents, they fall from 21.2 s and 50.4 s to 3.7 s and 13.5 s, 17 % and 27 %. The Usage plan asked for a third or less (W1.4). The slowest modelled event falls from 88 s to 22 s.

### The 120 s Timeout (SEC-IAENG-410-02)

The 120 s timeout was set from the modelled p99 of a median-cost call, 84 processes, while the 28 October bench saw calls of up to 220, which the margin did not cover. After this change the bench's calls start 9 to 15 processes, and the slowest modelled event with 8 or more agents is 21 s, under a fifth of the timeout. The timeout stays at 120 s: it also bounds a guard that hangs, and `block-inline-suppression.sh` (55 processes, a modelled maximum of 54 s) shares it. Lowering it is a separate decision, after that guard is lightened too (Usage plan W2.3).

### The Segment Cap (SEC-IAENG-410-01)

The hook now refuses a command of more than **2,000 pipeline segments** after expansion: the lexed text split on `;`, `&`, `|` and line breaks. Before, the `core.hooksPath` and approval-label loops ran at least one `grep` per segment, unbounded, so a long chain could pass the 120 s timeout, and on a Claude Code older than 2.1.295 the call then went through. The cap is in the script, so it holds on every version. It bounds the number of segments, not time: a long line is bounded by the hook's work being linear in its length, which `tests/run.sh` checks on a 256 KB line (below). Past the guard's 120 s timeout the version decides: Claude Code 2.1.295 or later refuses the call, an earlier one lets it through.

Its value comes from the 4,504 real Bash commands of this repository recorded on 28 October, split as the hook splits them: a median of 5 segments, a 99th percentile of 34, a 99.9th of 137, a maximum of 463 (a brace expansion that multiplied a 1,235-character command). None had more than 1,000. 2,000 is four times the maximum.

Large inputs, timed on the loaded machine of this measurement, one run each:

| Input | Size after the lexer | Before | After |
|---|---:|---:|---:|
| 16 brace groups of 32 alternatives (the lexer's own bounds) | 493 KB | 17.1 s | 11.0 s |
| `git` and 20,000 long options on one line | 100 KB | 15.7 s | 3.9 s |
| 2,000 lines of `git log x` | 20 KB | 16.7 s | 8.9 s |
| `echo` and 25,000 words | 239 KB | 22.4 s | 5.5 s |
| 2,000 segments, each a `gh` call, the last a `core.hooksPath` read | 10 KB | not run (2 to 8 processes per segment) | 8.3 s |
| 2,000 lines, each a `gh` segment, at the cap | 10 KB | not run | 2.5 s |

Most of the brace-expansion case is the lexer's own time, which this change does not touch.

**Non-ASCII input (SEC-IAENG-431-03).** The second round's first mapping of bytes above 0x7F (at 6745846) ran on every line at every rule, and its cost grew faster than the input, so on one long line of non-ASCII text that head passed the 120 s timeout. The third round maps each text once, in one linear pass, before it is split. One line of U+00E9 repeated, then `; git push --force`, on Windows, one run each, every run refused for the push:

| Line | develop | 6745846 | third round |
|---|---:|---:|---:|
| 16 KB | 8.7 s, 5.3 s | 2.2 s | 1.4 s |
| 128 KB | 10.2 s, 8.5 s | 31.3 s | 6.3 s |
| 256 KB | 2.9 s, 8.7 s | 121.4 s | 4.0 s |

Develop was timed twice, beside each of the other two, on a machine whose load moved between runs. With the third round, no input tried runs longer than on develop. `tests/run.sh` requires the 256 KB line to be judged and refused within 30 s, the budget the Security review set; at 6745846 that check fails.

**Here-strings of 64 KiB (fourth round).** On Git for Windows, a text of 65,536 to 65,663 bytes given through a here-string never finishes (the Security and code reviews of PR #463). Measured on 17 November with `read`, `tr` and `awk`, each under a 10 s timeout: texts of 65,536, 65,600, 65,662 and 65,663 bytes never finished; 65,534, 65,535 and 65,700 bytes finished within a second. The same texts through a pipe from `printf` finished at every size. Develop's hook, and this one up to 12ef8d0, passed the payload, the command and the stripped text through here-strings, so a command of that size held the call until the guard's 120 s timeout. The fourth round passes no text through a here-string: the texts are split in bash, by word splitting, and `jq`, both lexer `awk`s, `tr` and `grep -o` read from a pipe. `tests/run.sh` judges two commands of 65,580 bytes, one allowed that reaches every reader with a text inside the window and one refused, each within 30 s:

| 65,580-byte command | develop | 12ef8d0 | fourth round |
|---|---:|---:|---:|
| allowed, every reader | stopped at 30 s | stopped at 30 s | 1.9 s, allowed |
| `git push --force; echo …` | stopped at 30 s | stopped at 30 s | 0.7 s, refused |

A pipe costs one more process per reader, the bash that runs `printf`. The harness of the table above, on the same 100 payloads, 12ef8d0 and the fourth round interleaved on a lighter load (no-op p50 111 ms one at a time, 252 ms 8 at a time):

| | processes per call | one at a time, p50 / p95 (ms) | 8 at a time, p50 / p95 (ms) |
|---|---|---:|---:|
| 12ef8d0 | 9, 12 or 15 | 263 / 830 | 550 / 889 |
| fourth round | 10, 14 or 18 | 323 / 763 | 589 / 972 |

One process is added for a plain command, two with the lexer, three with its KEEPQ mode, where the change from develop removed 70 or more per call. One run each, on a load lighter than the table above; develop was not re-run.

### What the Rules Decide Is Unchanged

The guard's matching is its security boundary, so the change was checked four ways.

- **The case corpus.** Every row of `tests/escape-hatch-cases.tsv` keeps its verdict, and its reason where the row names one. Sixty-nine rows are added: one for each fast-path byte that can change a verdict and that a text file can hold, two for a separator inside a quoted global-option value (`git -c 'k=a;b' push --force`, a real push the rules must still read), three plain commands, sixteen commands holding a byte above 0x7F, written raw or decoded by the lexer from `$'...'` (SEC-IAENG-431-02 and the QA review's DEF-IAENG-463-01), each judged as develop judged it, refused or allowed, one where case folding must end with the check that asked for it (the QA review's mutant M4), and one where the approval-label rules read one segment at a time (the code review's F2). Thirteen more change a verdict on purpose: a git global option with an empty-looking value no longer hides the subcommand. Develop and 12ef8d0 allow twelve of them; the thirteenth, the space form of `--git-dir`, was already refused and pins it. Twenty-four pin the read exemptions (`git stash list|show`, the `core.hooksPath` reads), which read the global options as develop did (SEC-IAENG-431-05, and the code review's F14): seventeen where `-C`, `-c` or the `=` form of a long option is written with no value, or with an empty, whitespace-only or quoted-empty one, so that the word after it would earn the exemption if read as the subcommand, refused on develop too, and seven where an option with its value still earns it. The last two are lone quoted paths, which lex to nothing but a line break and are allowed, as on develop (the code review's F10). `tests/run.sh` holds the cases the file cannot: the control bytes, the carriage returns, multi-line commands, the payload's first line.
- **Develop's hook against this one, command by command.** The same payload went to both, and their exit codes and first refusal lines were compared. All 686 corpus commands of develop: identical. 693 real commands of this repository (every fourth of the 2,335 that name a guarded command, an option the rules read or a line break, 106 of them multi-line, and every twentieth of the rest): identical. 400 generated commands without a CR: identical. The generated commands come from the rules' own vocabulary (git and its global options, every guarded subcommand and flag, the config keys and variables, `rm`, the `gh` label forms), joined by every separator, with quotes, escapes, brace groups, heredocs and control bytes mixed in. These were run at 1e0796a; the second round changes nothing for a command with no CR and no byte above 0x7F.
- **Carriage returns and non-ASCII bytes (Security review of PR #463).** A carriage return is removed before matching, as bash removes it before running (SEC-IAENG-431-01): on 200 corpus commands with CRs inserted, alone or before a line feed, the hook judges each command exactly as develop judges it without its CRs (200 of 200). The rule classes match the same bytes as `grep` did (SEC-IAENG-431-02): `tests/run.sh` compares the hook's own matcher with `grep` on every byte value for every class the rules use, and on 200 corpus commands with a space turned into U+00A0 or a non-ASCII letter inserted, the hook and develop agree (200 of 200).
- **Mutation.** Each new fast path and early exit was changed one line at a time, and the committed checks run against each copy. First round, 32 mutants, 32 caught: the bytes of the fast path one by one, the fast path always and never taken, five ways out of the payload's first line, the matcher reading the whole text or the first line only, case folded for every rule or none, the compile refusal, the cap off or at 2,000 or 2,001, the segment split without `|`, the per-segment loop over lines, the line split also at `;` `&` `|`, the command cut at its last line, the raw-command check reading the lexed text, and the lexer's limit marker ignored. Second round, 17 mutants, 17 caught: the carriage return kept or only the first one removed, the non-ASCII bytes left unmapped or mapped to a space, on the fast path's changed line its ten bytes one by one and the fast path always and never taken, and the QA review's M4, case folding left on after a match. For nine of the ten bytes the mutant also lets a refused command through. A `\003` cannot change a verdict, since no rule names `}`; the budget check, which counts the lexer's `awk`, catches it. Two mutants are caught on Windows only, where what they break exists: removing the CR jq writes after the payload's first line, and leaving non-ASCII bytes unmapped (on Linux, the C library puts no such byte in a class). Fourth round, 11 mutants, 11 caught: a here-string put back for each of the five readers and for the splitting, each caught by the 65,580-byte check on Windows, where the window exists; G back as it was, and its value made mandatory again for `=`, for `-c` and for `-C` alone, each caught by the case file; and the KEEPQ view mapped after its split (the code review's Z7), caught on every platform by a check that names `\006` itself. Fifth round, 10 mutants, 10 caught, each by a case of that round: G back in each of the three read exemptions (SEC-IAENG-431-05), the `grep -o` of the `commit.gpgsign` check with its exit status ignored, its empty output accepted or its check removed, the `&&` before the `tr` marker made `;` (the code review's W4), the lexer's exit status ignored, its end mark not required, and a command that lexes to nothing refused again. Sixth round, 13 mutants, 13 caught: GX with the value of `-c`, of `-C` or of the `=` form made optional again (the code review's X1, X3 and X2), and the fifth round's ten, run again. X2 passed every row of the fifth round that names stash or hooksPath; thirteen of the sixth round's rows catch it.

### Limits of This Re-measurement

- One run on one loaded machine, a lighter load than on 28 October. The ratios are the result; the absolute values move with the load. The Performance Engineer re-measured in review, three times from 4 to 17 November: with 8 calls at a time, the p50 is 13 to 17 % of before (The Parallel-Agent Cap, below).
- The model's new `k` is a ratio of this run's medians applied to the published `k`, not a measurement against the 29-process gate. The Performance Engineer measured it directly against that gate in review: 0.297 (The Parallel-Agent Cap, below).
- Claude Code still records no PreToolUse hook that succeeds, so the effect in production is modelled, as before.
- Linux and macOS were not measured. There, `[[ =~ ]]` is the C library's regular expression engine, not grep's; the case corpus runs on Linux in the Hook Tests job. macOS, with its bash 3.2, was not tested at all.

## The Parallel-Agent Cap

Director decision D3 of 17 November 2026, Usage plan item W1.5, carried out in WU-IAENG-435. On 18 November 2026, the Director completed it on the review of that Work Unit, carried out in WU-IAENG-443:

- At most **6 subagents run at once per machine, Employees included**. This holds from the `develop` commit that merged PR #463 (2e5341b), and so from v0.0.16.
- At most **3** while any session on the machine runs v0.0.15 or earlier, whose `block-escape-hatches.sh` starts 80 or more processes per call. The lowest cap binds, because no measurement supports a mixed allowance: the old guard's calls are the ones that passed 120 s (Why 6 With PR #463, below).
- **Every main session open on the machine beyond the first lowers the cap by one.** The measurement counts transcripts, main sessions included (Method), so one main session and 6 subagents are 7 in its terms, and a second main session would make 8, where the edit guard doubles (Why 6 With PR #463).
- The cap is **machine-wide**. The subagents of every Claude Code session on the machine count toward it, a framework session's as much as an adopting project's. What slows a guard is process creation, and every session on the machine shares it (The Load Dependence, above).
- **Every dispatch counts**, whatever the size of the plan: a Work Unit, a review, a validation, a search. A dispatch counts as 1 plus the subagents its Employee Brief allows the Employee to start. An Employee starts none unless its Employee Brief allows it.
- The Main Agent counts its own subagents, plus the main sessions and subagents the Director reports. A pole of `Workflows/AUTONOMOUS_DELIVERY.md` counts against the share of the cap its Pole Brief gives it.
- **At or above the cap, a dispatch waits**, and the Main Agent tells the Director what waits and on which count. If no counted subagent is its own, it asks the Director to say when the count falls. A queue whose every dispatchable Work Unit waits is held, a state of its own. The cap delays a dispatch and never refuses one.

`Core/ORCHESTRATION.md` (Step 4, Dispatch Rules, Parallel-agent cap; and the Queue — held layer) gives the cap to every Main Agent, the framework's own included. The Director approved those lines word for word. `Templates/PROJECT_CLAUDE.md` (Main Agent) points an adopting project's Main Agent to that rule, in the contract it reads first. `Templates/EMPLOYEE_BRIEF.md` and `Templates/POLE_BRIEF.md` carry the number of subagents an Employee may start and a pole's share. `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` entry C states the cap, 3 with v0.0.15 included.

### Why 3 With v0.0.15

The Director left a machine limit until after this measurement (Mitigations Not Taken Here, item 5). The load tables count agents as transcripts active in the same minute, main sessions included (Method). With up to 3 of them, the 29-process gate passed 10 s in 4 to 6 % of production events, against 18 % with 4 to 7 (The Load Dependence). A cap of 3 subagents and its main session are 4 transcripts, in the 4 to 7 bin, not in the bin of 3 or fewer. The escape-hatch guard before WU-IAENG-431, modelled with 3 agents or fewer, has a p50 of 7.7 s and a p95 of 34 s per Bash call. The Security Engineer's sign-off of the v0.0.15 release (PR #452) sets the same limit as a pilot condition: "Run at most 3 agents in parallel". No v0.0.15 document carries it.

### Why 6 With PR #463: the Measurement

The Performance Engineer re-measured PR #463 three times in review, with an independent harness and the method of this document. Every process of a run was counted through a Job Object, and develop's guard and the PR's ran interleaved, so that both met the same load. Each round ran 8 hook calls at a time. The payloads were 100 real Bash commands of this repository, recorded from 29 October to 4 November, and the 100 of the 28 October bench. They are not committed, for the reason given in Sources.

| 8 calls at a time (ms) | PR head | PR runs | no-op p50 | develop's guard p50 / p95 | PR's guard p50 / p95 | ratio p50 / p95 | PR's slowest |
|---|---|---:|---:|---|---|---|---:|
| 4 November | `1e0796a` | 288 | 1,426 | 26,356 / 47,314 | 3,426 / 5,946 | 13.0 % / 12.6 % | 8,108 |
| 16 November | `6745846` | 200 | 961 | 17,544 / 40,568 | 2,672 / 6,259 | 15.2 % / 15.4 % | 11,105 |
| 17 November | `445fcfc` | 77 | 4,041 | 75,011 / 123,876 | 12,651 / 17,994 | 16.9 % / 14.5 % | 22,495 |

The heads after `445fcfc`, up to the merged `23b3b84`, add no process and no loop, so the 17 November figures carry to them. With 8 calls at a time, the new guard's p50 is 13 to 17 % of the old one's. The 17 November round met the heaviest load measured so far. There, the old guard passed the 120 s timeout: its p95 was 123.9 s, and the harness cut one run at 130 s. The new guard's slowest run took 22.5 s, 19 % of the timeout.

The first round also measured `k` directly against the 29-process gate (`90be675`): **0.297** by wall time (bootstrap 90 % interval 0.215 to 0.402), and 0.286 by CPU. The model at 0.297 is within about 1 % of The Production Model, Re-applied. In that model, with 6 to 7 agents, the new escape-hatch guard has a p50 of 2.4 s and a p95 of 7.3 s.

**The binding guard is now `block-inline-suppression.sh`.** It still starts 55 processes per edit (model, `k` 1.84). Its modelled p50 is 4.5 s with 3 agents or fewer, 4.8 s with 5 or fewer, 6.2 s at exactly 6 and 6.9 s at exactly 7. At 6 and 7, 40 to 41 % of its calls pass 10 s. With 8 or more it doubles: a p50 of 12.1 s, a p95 of 31 s, and 56 % of calls over 10 s. **With its main session, a cap of 6 subagents is 7 agents in the model's terms: the last bin below that jump, with no margin left for a second main session.** That bin is also the thinnest measured: 41 production events at exactly 7 and 59 at 8 or more, against 657 of the 757 at 6 or fewer. Each main session beyond the first therefore lowers the cap by one.

Guard wait per dispatch, as the modelled mean latency times a dispatch's median of 78 Bash calls and about 47 edits. The rows count transcripts, main sessions included. A cap of 6 subagents with one main session is 7, the "6 to 7" row. A cap of 3 with one main session is 4: after the two "3 or fewer" rows, which differ by guard and not by agents, and within the "6 or fewer" row. The guard before WU-IAENG-431, which v0.0.15 runs, has no row above 3. The table is not cut at exactly 4. The Performance Engineer's run of 24 November cuts the model at exactly 4 and exactly 7, with the edit guard before and after WU-IAENG-444 (The Edit Guard Starts a Quarter of the Processes, Re-measured on Real Edits at the Capped Load, below).

| Agents (transcripts) | Escape-hatch guard | Guard wait per dispatch |
|---|---|---:|
| 3 or fewer | before WU-IAENG-431 | 19.8 min |
| 3 or fewer | after | 7.8 min |
| 6 or fewer | after | 8.9 min |
| 6 to 7 | after | 11.3 min |
| 8 or more | after | 16.8 min, most of it the edit guard |

### Checked at 6 Calls at a Time, on One Load

The Performance Engineer took this measurement on 18 November 2026, from 10:50:17 to 10:51:39 UTC, for this decision. It checks the margin to the timeout at one load. It does not confirm the cap for every load (below). It ran on `develop` at 2e5341b, whose escape-hatch guard is blob `40518f7` and edit guard blob `276d8bb`.

- **Harness.** A shorter harness, written for this check. It has no Job Object, so it gives no process count and no CPU. Each call is started as Claude Code starts it on Windows, `Git\bin\bash.exe -c "bash \"$CLAUDE_PROJECT_DIR/.../<hook>\""`, with the payload on a stdin pipe. The hooks of 2e5341b were exported to a scratch directory. A queue fed 6 workers, so that 6 calls were in flight at all times. For each payload, the queue held the escape-hatch guard, the edit guard and, one payload in two, the no-op, in an order rotated per payload. There were 180 runs, three passes over the payloads.
- **Synthetic payloads.** There were 24 Bash commands of the shapes the framework's sessions run: `git`, `gh`, `grep`, `sed`, a loop, a heredoc, quotes and `$`, and one `git push --force`. There were also 24 edits of one TypeScript line. No recorded command was used.
- **Load.** A sampler logged the machine every 10 s and took 7 samples. CPU was at 100 % in all 7. The run queue averaged 82 (maximum 100), with about 537 processes and 4.4 GB of free RAM. There were on average 48 bash processes (the bench's own included), 10 node and 5 claude. Defender's CPU could not be read. The no-op's p50 was 574 ms. 8 at a time, it was 961 ms on 16 November and 4.0 s on 17 November. So the CPU was saturated, but process creation was less contended than in the 17 November round.

| 6 calls at a time, `develop` 2e5341b (ms) | runs | p50 | p95 | max | > 10 s | max against 120 s |
|---|---:|---:|---:|---:|---:|---:|
| no-op (calibration, reads its stdin with a builtin) | 36 | 574 | 925 | 991 | 0 | — |
| `block-escape-hatches.sh` | 72 | 1,151 | 2,928 | 3,759 | 0 | 3 % |
| `block-inline-suppression.sh` | 72 | 4,805 | 7,989 | 9,831 | 0 | 8 % |

Every run exited as expected. All exited 0, except the 3 runs of the `git push --force` payload, which the escape-hatch guard refused with its force-push rule (exit 2). No run was cut. **At this load, with 6 calls at a time, both guards stay well under the 120 s timeout.** The slowest of 144 guard calls took 9.8 s, and it was an edit guard call.

What this check does not show:

- **The load was light on process creation.** The no-op's p50 was 574 ms, against 4,041 ms 8 at a time on 17 November.
- **Only hooks ran.** 6 calls at the same instant are harsher than 6 agents in hook concurrency only. Six real agents also run git, builds, tests and node beside their hooks.
- **The edit guard under the heaviest load is unknown.** Between 17 November (8 at a time) and this check, the escape-hatch guard's p50 differs 11.0-fold and its maximum 6.0-fold. Scaled by those ratios, which is not a measurement, the edit guard would reach about 50 to 60 s under a 17-November load. The production model gives it a maximum of 49 to 54 s with 8 or more agents (The Guards in Production, Modelled).
- Either way, the binding guard was never measured under the heaviest load. W2.3's measurement does that (below).

### Condition for Raising or Lifting the Cap

The cap stays at 6 until the edit guard, now the binding one, is measured again under load in Usage plan item W2.3.

- **The measurement.** It uses this document's method, with the no-op and both guards interleaved, at 6 calls at a time and at 8. It runs on a load whose no-op p50 is 2 s or more, so that the binding guard is measured under heavy load. It re-runs the model at exactly 4 and exactly 7 transcripts, the caps of 3 and 6 with their main session. It is the measurement W2.3 already starts with.
- **The Performance Engineer's threshold.** A fixed number of seconds is passed or failed by the day's load: the no-op's p50 has ranged from 201 ms to 4,041 ms in this document. The test is therefore floor-relative, at 6 calls at a time. W2.3 closes on that measurement, with no code change, when both of these hold:
  - the edit guard's own cost above the interleaved no-op is 1 s or less at p50;
  - on the heavy load, no call of either guard passes 60 s, half the timeout.

  Otherwise the measurement is taken again on the lightened guard. The Usage plan's W2.3 acceptance states an absolute 1 s p50 and is to be aligned with this test by its owner.
- **The decision.** From that measurement, the Performance Engineer recommends keeping, raising or lifting the cap, and the Director decides, as for D3.
- **Until then.** No higher cap has a measurement behind it: with 8 agents or more, the edit guard's modelled p50 doubles. A change that adds processes to either guard re-opens the decision as well.

### Limits of the Cap

- **Main sessions count as agents of the model.** Each main session beyond the first lowers the cap by one, so that the machine stays at 7 transcripts at most, inside the measured range. A main session that waits for its Employees makes few hook calls, but its share of the load was not measured on its own: counting it as a full agent errs on the safe side.
- **A Main Agent sees only its own subagents.** It counts the main sessions and subagents of other sessions only when the Director reports them. The cap holds machine-wide only as far as those reports do. A pole sees neither, which is why it counts against a fixed share of the cap.
- **Nested subagents are counted as their brief declares them.** A dispatch counts as 1 plus the subagents its Employee Brief allows. An Employee that starts more than its brief allows breaks the cap without the Main Agent seeing it.
- **The check at 6 was short.** It is one run of 82 s, at one load, on one machine, Windows only. Linux and macOS start processes far more cheaply (Limits, below).
- **Session start does not print the cap.** The Director's review of `develop` at 67ad444 asked, in the second part of its finding 13, that `session-start.sh` print the cap where every session sees it. The triage deferred that part to a Platform Engineer Work Unit timed with W2.3, and WU-IAENG-444 does not take it: it changes no hook but the edit guard. It stays deferred, filed as issue #486. Until then the cap reaches a Main Agent through `Core/ORCHESTRATION.md` and the project's `CLAUDE.md`, which point to it.

## The Edit Guard Starts a Quarter of the Processes (WU-IAENG-444)

Usage plan item W2.3, measured on 19 November 2026 on `develop` at 2cbee05, whose edit guard is blob `276d8bb`. The plan's acceptance asks for the p50 to fall to a third or less. Finding 11 of the Director's review of 67ad444 asked that the test be a ratio or relative to the floor, not an absolute second, because the day's load moves every absolute value (The Parallel-Agent Cap, above). So the criterion is two ratios, both taken from calls interleaved with develop's at 6 at a time, which meet the same load:

- the new guard's p50 is a third or less of develop's;
- its own cost above the interleaved no-op is a third or less of develop's own cost at p50.

### What a Call Starts

`block-inline-suppression.sh` started five `jq` (the object check, three fields, the text), one `grep` per row of `Adapters/scripts/suppression-patterns.tsv` (five rows), and, on Windows, three or four `cygpath` with the command substitutions around them. It now starts:

- **One `jq`**, which makes the same object check and prints the tool name, the file path, the cwd and the text, separated by `\037`. A field that is not a string or null, or that holds a `\037` or a line break, a `tool_input` that is not an object or null, or a text value that is an array or an object sends the payload to the code before WU-IAENG-444, unchanged.
- **One `grep`**, given every pattern with `-e`. It exits 1 only when no pattern matches any line, which is when every per-row `grep` would have exited 1, so the edit is allowed there. A match, a pattern it cannot compile, a malformed row or no row goes to the per-row loop, which refuses as before and names the row that fired. A refusal therefore adds the per-row `grep`s up to that row.
- **No `cygpath` on an ordinary edit.** The path exemptions, the pattern file and `tests/`, can apply only to a path whose canonical form ends in the pattern file's name or holds a `tests` segment. `cygpath` changes only a path's prefix and separators, so those names must already be in the file path, in the payload's cwd, or, without one, in the working directory. When none of them names either, the conversion is not made. When one does, a single `cygpath` converts every path, where one was started per path and per base. The skip could miss an exemption only under a mount whose POSIX target itself names `tests` or the pattern file, and then the edit is refused, never wrongly allowed.

Counted with recording stand-ins first on `PATH`, a clean code edit started `cat`, five `jq`, five `grep` and three `cygpath` (four with a cwd), and a documentation edit `cat` and three `jq`. Now a code edit starts `cat`, one `jq` and one `grep`; a documentation edit, `cat` and one `jq`; and an edit whose path names `tests` or the pattern file adds one `cygpath`. `tests/run.sh` holds the hook to that budget.

Counted by a Job Object per run, every process included, on the 24 payloads below (the no-op is 5 in this harness):

| Payload kind | payloads | develop | WU-IAENG-444 |
|---|---:|---:|---:|
| code edit, allowed | 20 | 52 | 14 |
| documentation edit (exempt by name) | 2 | 18 | 11 |
| code edit, refused | 2 | 44 to 50 | 17 to 26 |
| code edit whose path, cwd or working directory names `tests` or the pattern file | — | 52 | 18 |

None of the 24 payloads names `tests` or the pattern file. The last row is the Performance Engineer's count on real edits, 51 and 17 in a harness that counts one process fewer (Re-measured on Real Edits at the Capped Load, below). In commands, such an edit starts one `cygpath` more than a plain code edit; in processes, it starts 4 more. On real edits, 16 to 18 % name `tests`, most of them an agent editing a `tests/run.sh` in a worktree, and their p50 ratio to develop is 32 to 33 %, at the third (P3 of the Performance review of PR #487).

### Measured, Before and After Interleaved

A harness written for this Work Unit, of the method above. Each call is started as Claude Code starts it on Windows, `Git\bin\bash.exe -c "bash \"<hook>\""`, the payload on stdin, in its own Job Object, which counts every process and sums its CPU. Each call's stdout and stderr are pipes, drained, as Claude Code's are. **A first run took both hooks down their no-`jq` path, where `iaeng_field` reads fields with `sed`.** It counted 45 processes for develop and 22 for this guard, with ratios of 59 % at p50, and those runs are discarded. That run gave each call's stdout and stderr the NUL device, but the NUL device does not reproduce it. With stdout and stderr on NUL and stdin a pipe, the Performance Engineer counted the `jq` path's processes for both hooks, as with pipes; with stdin on NUL as well, both hooks refused an empty payload, in 9 and 6 processes. The cause of that run's no-`jq` path is not established (P4 of the Performance review of PR #487). A harness gives its calls pipes, as Claude Code does.

The 24 payloads are synthetic, as on 18 November: Edits, Writes and a MultiEdit of TypeScript, Python, Go, shell, YAML, Rust and JavaScript, from one line to 120, two of them documentation and two refused. No recorded payload was used. The no-op, develop's guard and this one ran round-robin, the order rotated per payload. A sampler logged the machine every 10 s during the 6-at-a-time run, 13 samples: CPU 37 to 74 %, a run queue of 0 to 21, about 470 processes, 11 to 32 bash (the bench's own included), 4 node and 4 claude. **The load was light.**

| One call at a time, 10:59 to 11:01 UTC | runs | processes per call | CPU per call (median, ms) | p50 (ms) | p95 (ms) | max (ms) |
|---|---:|---:|---:|---:|---:|---:|
| no-op (calibration, reads its stdin with a builtin) | 24 | 5 | 78 | 249 | 519 | 737 |
| `block-inline-suppression.sh`, develop 2cbee05 | 24 | 52 (18 to 52) | 1,031 | 1,885 | 2,425 | 2,568 |
| `block-inline-suppression.sh`, WU-IAENG-444 | 24 | 14 (11 to 26) | 296 | 595 | 1,285 | 1,741 |

| 6 calls at a time, 11:01:16 to 11:02:31 UTC | runs | p50 (ms) | p95 (ms) | max (ms) | > 10 s |
|---|---:|---:|---:|---:|---:|
| no-op | 72 | 400 | 1,092 | 1,546 | 0 |
| `block-inline-suppression.sh`, develop 2cbee05 | 72 | 4,108 | 5,860 | 6,619 | 0 |
| `block-inline-suppression.sh`, WU-IAENG-444 | 72 | 930 | 2,576 | 3,621 | 0 |

**Result, 6 calls at a time, on these synthetic payloads at a light load.** The p50 falls to **23 %** of develop's (930 ms against 4,108 ms). Above the no-op, the guard's own cost at p50 falls from 3,708 ms to 530 ms, **14 %**. Both are within the third the criterion asks. The p95 falls to 44 %, and the slowest call took 3.6 s. One call at a time, the p50 is 32 % of develop's, and the own cost 21 %. Every run exited as expected: 0, and 2 for the two refused payloads, the same for both guards. These ratios are lower than on real edits, 29.6 % and 22.8 % (below): the synthetic set holds 2 documentation edits in 24 and no path naming `tests`, where real edits hold 28 to 40 % and 16 to 18 %, and both gain less than a plain code edit (P1 of the Performance review of PR #487).

### Re-measured on Real Edits at the Capped Load

The Performance Engineer re-measured this guard in review of PR #487, on 24 November 2026 from 09:22 to 09:41 UTC, with an independent harness and this document's method. Develop was at 785212d, whose edit guard is blob `276d8bb`; the PR head was 5ab4988, whose edit guard is blob `b9a8e83`. The fix of the PR's review round 1 declares a variable apart from its assignment: it starts no process and adds no loop, so these figures carry to it.

- **Harness.** The harness of the PR #463 re-measurements: a Job Object per call, stdin, stdout and stderr anonymous pipes, stdout and stderr drained. The no-op, develop's guard and this one ran round-robin per payload, the order rotated, and a queue kept N calls in flight. It counts one process fewer than the harness above: its no-op is 4, a code edit 51 for develop and 13 for this guard.
- **Payloads, not committed** (Sources). 100 Edit, Write and MultiEdit calls drawn at random, with a fixed seed, from the 1,503 in this repository's transcripts since 10 November: 63 shell, 28 documentation and 9 other code, 16 paths naming `tests`. And the 100 recorded edits of the 28 October bench: 54 shell, 40 documentation and 6 other code, 18 naming `tests`. No text falls in the 64 KiB window.
- **Runs.** 1,200: both sets, at 6 and at 8 calls at a time.
- **Load.** A sampler logged the machine every 10 s, 89 samples: CPU at 69 % on average (31 to 95), a run queue of 21 on average (85 at most), about 540 processes, of them 84 bash, 6 node and 5 claude, and Defender at 85 % of one core.
- **Statistics.** Percentiles are nearest-rank. The ratio intervals come from 4,000 bootstrap resamples (90 %).

| Both sets, 200 runs per row (ms) | processes per call | p50 | p95 | p99 | max | > 10 s |
|---|---|---:|---:|---:|---:|---:|
| 6 at a time: no-op | 4 | 1,104 | 2,401 | 3,063 | 3,379 | 0 |
| 6 at a time: develop | 51 (17 for documentation) | 12,594 | 20,491 | 21,069 | 21,978 | 124 |
| 6 at a time: WU-IAENG-444 | 13 (10 for documentation, 17 for a path naming `tests`) | 3,729 | 6,650 | 7,898 | 10,665 | 1 |
| 8 at a time: no-op | 4 | 1,282 | 2,695 | 3,169 | 3,445 | 0 |
| 8 at a time: develop | 51 | 14,356 | 18,344 | 19,480 | 20,574 | 133 |
| 8 at a time: WU-IAENG-444 | 13 | 4,118 | 6,138 | 7,214 | 10,329 | 1 |

| Against develop | p50 ratio (90 % interval) | own cost above the no-op at p50 (90 % interval) | p95 ratio |
|---|---|---|---:|
| 6 at a time | **29.6 %** (27.2 to 31.9) | 22.8 % (20.2 to 25.0): 2,625 against 11,490 ms | 32.5 % |
| 8 at a time | **28.7 %** (27.2 to 30.2) | 21.7 % (19.9 to 23.2): 2,836 against 13,075 ms | 33.5 % |

By kind of edit, 6 at a time (8 at a time within a point): a plain code edit (13 processes) is at 25.8 % of develop at p50 and 19.7 % in own cost; a code edit whose path names `tests` (17) at 32.4 % and 26.8 %; a documentation edit (10 processes against develop's 17) at 62.9 % and 52.2 %. Each set alone gives 28.2 to 30.1 %, and over 2-minute quarters at 6 at a time the ratio ranged from 27 to 35 %.

**The W2.3 acceptance is met.** At 6 at a time the p50 ratio has a 1 % bootstrap probability of being above a third. The margin is thinner than on the synthetic set, for the mix of edits above. All 400 paired calls gave the same exit code and the same first refusal line: 2 refused, 398 allowed. No call of either guard passed 60 s; this guard's slowest took 10.7 s, 9 % of the 120 s timeout.

**The cap's measurement is still owed.** The no-op's p50 was 1.1 s at 6 at a time and 1.3 s at 8, under the 2 s or more that The Condition for Raising or Lifting the Cap sets, and no load was added to the shared workstation. At this load, the guard's own cost at p50 is 2,625 ms, against the 1 s of the Condition's first test; no call passed 60 s, its second. Nothing here supports raising the cap above 6. For the cap decision's owner, the Performance Engineer notes that each process above the no-op cost 244 to 292 ms at p50 at this load, so an own cost of 1 s leaves room for 3 or 4 processes, where `cat`, `jq` and `grep` take 9 in Job Object terms: the first test may need to become a test on the model.

**The production model, re-run at exactly 4 and exactly 7 transcripts.** The model, `floor + (stop-gate − floor) × k` over the 757 Stop pairs, reproduces this document's figures exactly at `k` 1.84. This guard's `k` is 1.84 × 0.228 = **0.42** (0.37 to 0.46, from the own-cost interval).

| Transcripts | events | develop p50 / p95 / max / > 10 s | WU-IAENG-444 p50 / p95 / max / > 10 s |
|---|---:|---|---|
| exactly 4 (a cap of 3 and its main session) | 185 | 5,071 / 23,933 / 36,704 / 28.1 % | 1,854 / 9,025 / 14,630 / 4.3 % |
| exactly 7 (a cap of 6 and its main session) | 41 | 6,856 / 17,921 / 19,625 / 41.5 % | 3,404 / 6,220 / 7,243 / 0 % |
| 8 or more | 59 | 12,101 / 31,430 / 49,489 / 55.9 % | 4,396 / 16,481 / 22,124 / 8.5 % |
| all | 757 | 5,267 / 24,255 / 49,489 / 26.7 % | 1,931 / 8,660 / 22,926 / 3.6 % |

Guard wait per dispatch, the escape-hatch guard at `k` 0.297 over 78 Bash calls plus the edit guard over 47 edits, before and after: 9.5 and 5.5 min at exactly 4 transcripts, 10.3 and 6.1 min at exactly 7, 16.8 and 10.1 min at 8 or more. Per dispatch, the escape-hatch guard's share now exceeds the edit guard's, 3.6 min against 2.5 min at 7. Per call, the edit guard is still the slower of the two, at `k` 0.42 against 0.297. The bin at exactly 7 holds 41 events.

### What the Rules Decide Is Unchanged

- **Develop's guard against this one, payload by payload.** Both ran side by side in one hooks directory, so that both found the same pattern file and `tests/` directory, on 332 synthetic payloads: every alternative of every row in every tool and position, upper case, clean code, every documentation suffix, the pattern file and `tests/` in POSIX, Windows, relative, `..`, CR and line-break spellings, tool names, file paths, cwds and `tool_input`s of every JSON type, text values of every type, `\001`, `\037` and NUL bytes, CRLF texts, and payloads that are not one object. All 332 have the same exit code and the same refusal text: 203 refused, 125 allowed. The four payloads that hold a NUL make bash print its own "ignored null byte" warning in both, at a different line of each script.
- **The Security review of PR #487** judged 710 payloads of its own with both guards side by side, 18 of them with no `jq` on `PATH`. Two differed, both a file path with a CR inside a segment, before its last: a Write to `<hooks>/tests<CR>/x.sh`, with and without a cwd, holding a directive, which develop refused and the PR head allowed (F1). `canon_three` declared its list of paths as `local args=("$FILE")`, and Git for Windows' bash 5.3.9 drops a CR from a value given to a compound assignment inside `local` or `declare`. So the one `cygpath`'s CR guard never saw that CR, `cygpath` converted the path without it, and the path landed in `tests/`. The same held for a CR in any segment of a path naming `tests` or the pattern file. The cwd was not affected, because it is added with `+=`, which keeps the CR. `args` is now declared, then assigned. A plain assignment keeps the CR, as `+=` does, and no other compound assignment inside `local` or `declare` in the hooks is given a value. The Security Engineer verified that fix on the two payloads and on four exemption payloads, all judged as develop judges them. Its exploitability was low: Win32 refuses a control character in a file name, so the edit would not have been written, and Linux and macOS have no `cygpath`. It was still a wrong allow by a control, against this Work Unit's own invariant.
- **`tests/run.sh`** gains 28 checks, which make 55 on the edit guard:
  - one refusal per row, named by its label;
  - a MultiEdit's texts each start their own line;
  - an upper-case directive, and a `\037` in the text after a directive, each refused by its row (F2 of the Security review of PR #487);
  - a path's trailing line break, and a `\037` inside a path, judged as before;
  - the pattern file's path, and a cwd of `tests/`, each with a trailing CR, judged as before on each platform;
  - a path into `tests<CR>/`, with no cwd and with one, and the pattern file's name under `scripts<CR>/`, each code on every platform (F1);
  - a bare name resolved against a cwd, and against the working directory, inside `tests/`;
  - a row that does not compile, a row without a TAB and a row with an empty pattern, each refused;
  - two texts of 65,600 bytes;
  - the process budget, six ways.

  On develop, the six budget checks and the two 65,600-byte checks fail, and the other 47 pass.
- **Mutation.** Each fast path and each of its guards was changed one line at a time, and the committed edit-guard checks were run against each copy. 31 mutants, 30 caught:
  - **The one `jq`:** never taken; always parsed; without the one-object check; without its line guard, or the guard missing the line feed or the `\037`; the texts joined without a line break. Seven mutants, seven caught.
  - **The one `cygpath`:** never taken; without its CR and line-feed guard, or without the CR alone; the base taken from the file's line; the pattern file and the hooks directory swapped. Five caught. At the PR head, the guard's two mutants were caught only by a cwd of `tests/` followed by a CR, and this section put that down to `cygpath` dropping the CR of a path that exists. It was F1's declaration that dropped the file path's CR, before `cygpath` saw it. With F1 fixed, the two mutants were run again on the real tree, and each is caught by both trailing-CR checks, the pattern file's path and the cwd: `cygpath` keeps a trailing CR, which the per-path command substitution strips.
  - **The exemption gate:** always closed; always open; the file path without `tests`, or without the pattern file's name; the cwd not read; the working directory not read. Six caught.
  - **The one `grep`:** never taken; its exit 2 read as clean; the last pattern only; the first pattern only; a malformed row or an empty pattern kept on the fast path; the here-string put back. Seven caught.
  - **The per-row loop:** the here-string put back; the `printf`'s status read as `grep`'s. Two caught.
  - **Not caught: the one `cygpath`'s line-count check removed.** It is equivalent on every input the guard lets through: with no CR or line feed in any path, `cygpath` prints one line per path. It stays as a defence. Were `cygpath` ever to print fewer lines, the lines would shift, and the file's own line could be compared as the pattern file's, which would be a wrong allow. The check sends that case to the per-path conversion instead.
  - **Review round 1, three more, three caught,** each run against the five new checks and the two trailing-CR checks, not the whole suite. The one `grep` without `-i`, and the text split at the last `\037` instead of the first: the Security review's own mutants, which no committed check caught (F2). Each is caught by its new check. And F1's declaration put back, `local args=("$FILE")`, the PR head itself: it is caught by the three new F1 checks, which fail on that head and pass on develop and on the fix. Those three do not catch the CR guard's mutants, since `cygpath` keeps a CR inside a segment and `tests<CR>` stays code without the guard; the trailing-CR checks catch those.

**One verdict changes, on purpose.** A text of 65,536 to 65,663 bytes went to `grep` through a here-string, which never finishes on Git for Windows in that window (Here-strings of 64 KiB, above). Such an edit waited for the guard's 120 s timeout. Claude Code 2.1.295 or later then refused it; an earlier version let it through unchecked. The text now goes to `grep` through a pipe, and `grep`'s own status is read from `PIPESTATUS`, so the `SIGPIPE` that `pipefail` once read as "no match" (TROUBLESHOOTING X) cannot recur. On a clean text of 65,600 bytes, develop's guard was still running when stopped at 40 s; the new one allowed it in 1.1 s.

### Limits of This Measurement

- **The load was light.** The no-op's p50 was 400 ms at 6 at a time in the author's run, and 1.1 s in the Performance Engineer's, against the 2 s or more that The Condition for Raising or Lifting the Cap sets for the measurement that decides the cap. That measurement is still owed, on the guard this Work Unit leaves. The absolute values move with the load, and the ratios with the mix of edits: 23 % on the synthetic set, 29.6 % on real edits (Re-measured on Real Edits at the Capped Load).
- **The production model is re-applied by the Performance Engineer's run only.** Its inputs are transcript-derived and were not in the author's session (Sources). The edit guard's `k` measured there is 0.42 (0.37 to 0.46); this section no longer estimates it from the synthetic run (P2 of the Performance review of PR #487).
- **One run each, one machine, Windows only.** On Linux there is no `cygpath`, and the conversion starts no process either way.

---

# Mitigations Not Taken Here

Ranked by the cost they would remove. Each needs its own Work Unit.

1. **`block-escape-hatches.sh`: 84 processes on every Bash call** (issue #385). Taken since, in WU-IAENG-431: see The Escape-Hatch Guard Matches in Bash, above.
2. **`block-inline-suppression.sh`: 55 processes on every edit.** Taken since, in WU-IAENG-444: see The Edit Guard Starts a Quarter of the Processes, above.
3. **`session-start.sh`: 102 processes**, once per session and per `/clear`. It runs rarely, so it is lower on the list.
4. **The plugin hooks.** Four node hooks on Stop and one on PreToolUse, which times out 33 % of the time. They belong to the user's configuration, not the framework's. The Director has been told.
5. **A machine-wide limit on parallel agents.** WU-IAENG-409 left this decision until after this measurement. The load table above is the input: the share of gate runs over 10 s is 4 to 6 % with up to 3 agents, 18 % with 4 to 7, and 38 % with 8 or more. Taken since, as Director decision D3: see The Parallel-Agent Cap, above.

---

# Limits

- **One machine.** Windows with Git Bash and Defender's real-time scanning is the expensive case. Linux and macOS were not measured. A fork and an exec cost far less there than under MSYS, so the same hooks are expected to be much faster, but no number here says how much.
- **The guards' production latency is modelled.** Claude Code does not record a PreToolUse hook that succeeds. The model assumes a guard's extra cost over the floor scales with load the way the gate's does. The two values of `k` show how sensitive the result is to that assumption.
- **The load measure is a proxy.** It counts this project's transcripts active in the same minute. It does not count other projects or CI.
- **No idle bench.** The machine was under load through the whole bench window. One active agent in production is the nearest idle figure: a p50 of 973 ms for the gate.
- **The bench ran one hook at a time.** The harness had a mode for concurrent runs. It was not used, because production already gives the behaviour under concurrency.

---

# Sources

- Claude Code hooks reference: <https://code.claude.com/docs/en/hooks.md> (timeouts, `onFailure`, parallel execution), read 28 and 29 October 2026, against Claude Code 2.1.312.
- Transcripts: `~/.claude/projects/<this repository>/*.jsonl` and their `subagents/` files, 3 September to 28 October 2026, read only. Fields used: `durationMs`, `timedOut` and `timeoutMs` of `stop_hook_summary`, `hook_success` and `hook_cancelled`.
- The working notes of the measurement, in French, are not committed: they are `.ia-engineering/handoff-2026-10-28-hook-latency.md`, in the gitignored state directory. The bench harness, its raw data and the model scripts are in the session's scratch directory. They are not committed, because they hold transcript-derived data (`Standards/DATA_PROTECTION_STANDARD.md`).
- Issue #351 (the question), #368 (the uninitialised submodule in a worktree), #385 (lightening `block-escape-hatches.sh`).
- The re-measurement of 4 November 2026 (WU-IAENG-431) used the same harness, the same 100 recorded Bash payloads and the same production Stop events, copied to that session's scratch directory, and is not committed for the same reason. Its differential and mutation scripts are there too; `tests/run.sh` holds what is committed of them.
- The Performance Engineer's re-measurements of PR #463 are in its comments of 4, 16 and 17 November 2026. Their harness and raw data stay in that session's scratch directory, for the same reason.
- The Performance Engineer's re-measurement of PR #487 (WU-IAENG-444) and the Security review of that PR are in their comments of 24 November 2026. Their harnesses, payloads, corpus and raw data stay in those sessions' scratch directories, for the same reason.
- Director decision D3 of 17 November 2026 is Usage plan item W1.5. The 6-at-a-time confirmation of 18 November 2026 (WU-IAENG-435) used synthetic payloads only. Its harness, payloads and runs are in that session's scratch directory and are not committed.
- The Director's code review of `develop` at 67ad444 (18 November 2026) raised 15 findings on the cap. The Performance Engineer triaged them, and the Director chose the completed rule, which WU-IAENG-443 carries out. The triage is in that session's scratch directory.

---

# Metadata

Owner: IA Engineering

Version: 0.0.19

Status: Draft

Category: Governance — Measurement

Severity: Advisory
