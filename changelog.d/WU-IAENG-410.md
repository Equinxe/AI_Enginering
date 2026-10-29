### Security

- The two guard hooks now fail closed when they fail, not only when they cannot read their input. `settings.example.json` gives `block-escape-hatches.sh` and `block-inline-suppression.sh` `"onFailure": "block"` and a 120 s `timeout`. A guard that hangs, cannot start, or exits with a code other than 0 or 2 now blocks the Bash call or the edit it guards (Claude Code 2.1.295 or later). Before, it had no timeout of its own: the 600 s default held the agent for ten minutes, and then the call went through unguarded. That happened once in production, on 27 October 2026, to an edit. 120 s is 1.25 times the slowest guard's worst p99 under load on Windows, so a healthy guard does not trip it. The Stop gate gets neither field: `onFailure` has no effect on Stop (#351, WU-IAENG-410)

### Added

- `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md`: how long the hooks take on Windows under parallel agents, from 1,490 production runs of the Stop gate, 758 paired Stop events and a 610-run bench that counts every process. Under load, a hook's latency is its process count: the Stop gate (29 processes) has a p95 of 16 s and a p99 of 26 s in production. `block-escape-hatches.sh` (84 processes per Bash call) has a modelled p50 of 9 s and a p99 of 61 s. The document also gives the 600 s default the issue had missed, the timeouts observed, and the mitigations ranked, with lightening `block-escape-hatches.sh` next (#385) (#351, WU-IAENG-410)
- `Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md` entry C: every Bash command or edit refused without an `iaeng: BLOCKED` reason, which is what a guard that cannot start now does, for example in a checkout whose framework submodule was never initialised (#351, WU-IAENG-410)

### Changed

- `stop-gate.sh` starts 4 commands instead of 8 on the path most stops take, a clean tree and a current `SESSION_STATE.md`. It reads the loop guard only before it blocks or reminds, finds `lib.sh` without `dirname`, runs `git rev-parse` only when `git status` fails, and uses bash's own clock. Benched under load against the earlier gate, it creates 15 processes per call instead of 29, and its p50 and p99 fall by 46 %. What it decides is unchanged. `hooks/tests/run.sh` checks that the loop guard still silences every block and reminder, and holds the common path to its budget: no `jq`, at most 4 commands (#351, WU-IAENG-410)
- `install-hooks.sh` adds the two new fields in place to the framework's earlier guard entries, as it already updated an earlier matcher (WU-IAENG-373), instead of appending a second group that would run each guard twice per call. A guard entry with a field of its own, such as `"timeout": 1` or `"onFailure": "continue"`, is the project's: it is left as it is and reported as a near miss (#351, WU-IAENG-410)

### Notes

- Re-run `ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh` from the project root, then commit `.claude/settings.json`. The run prints `updated: PreToolUse [Bash]: block-escape-hatches.sh  (added: timeout, onFailure)` and the same for the edit guard. Until then, `install-hooks.sh --check` reports both guards as absent and names the update a run makes. The guards fail closed only on Claude Code 2.1.295 or later. An older version ignores `onFailure` and lets the call through at 120 s (#351, WU-IAENG-410)
