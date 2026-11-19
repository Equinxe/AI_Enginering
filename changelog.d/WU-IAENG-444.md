### Changed

- `block-inline-suppression.sh`, the edit guard, starts about a quarter of the processes it started on every Edit, Write and MultiEdit: 14 instead of 52 for a code edit on Windows. One `jq` reads every field, where five did. One `grep` gets every pattern of `Adapters/scripts/suppression-patterns.tsv`, where one ran per row. No `cygpath` runs unless the edit's path, its cwd or the working directory names `tests` or the pattern file, the only paths an exemption can apply to; then one converts every path, where three or four did. A refusal still names the row that fired. Anything the fast paths cannot judge exactly as before goes to the code that judged it before. Interleaved with develop's guard at 6 calls at a time, its p50 is 23 % of before (Usage plan item W2.3, WU-IAENG-444)
- `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md` (0.0.19) records the edit guard's measurement before and after, its ratio criterion and the result. It corrects where a cap of 3 with its main session falls in the guard-wait table, and records that `session-start.sh` printing the cap stays deferred (WU-IAENG-444)

### Fixed

- The edit guard gave its text to `grep` through a here-string, which never finishes on Git for Windows for 65,536 to 65,663 bytes, so an edit of that size waited for the guard's 120 s timeout. On Claude Code 2.1.295 or later the edit was then refused; on an earlier version it went through unchecked. The text now reaches `grep` through a pipe, and `tests/run.sh` requires a clean and a refused text of 65,600 bytes to be judged within 30 s (WU-IAENG-444)
