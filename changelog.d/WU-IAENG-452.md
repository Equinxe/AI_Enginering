### Added

- `session-start.sh` prints the parallel-agent cap in one line on every SessionStart event, after the Main Agent pointer. Its numbers are read from `Core/ORCHESTRATION.md`'s own paragraph (Dispatch Rules) by the shell, with no process: the cap of 6, the cap of 3 while any session on the machine runs v0.0.15 or earlier, and one fewer for each main session beyond the first, each said only while Core says it. A paragraph whose number cannot be read gives the pointer alone (#486)

### Changed

- `session-start.sh` has a budget, stated in `hooks/README.md` (Session Start Budget) and measured in `Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md` (0.0.20), The Session Start Hook Within a Budget. On `/clear` and compaction it reads again the pointers, `SESSION_STATE.md` (header, Next Step, Blocked On, freshness warnings), the cap and the repository state, prints the tier map and agents block the last full run kept while nothing the generator reads has changed (only a block with a verdict is kept: a run whose generator failed keeps nothing, so the next `/clear` asks it again), and runs neither the drift check nor the context-alert threshold check, which `startup` and `resume` still run (#515)
- Every SessionStart event starts fewer processes: one `awk` reads `SESSION_STATE.md` where a `grep`, a `sed` and two `awk` read it; the header's date, the month and the file's day are read in the shell; `git status` runs once and answers whether the project is a work tree; the tier map's values and the repository state are cut in the shell. `lib.sh` gains the by-name forms `iaeng_framework_root_to`, `iaeng_month_num_to` and `iaeng_ymd_from_header_date_to` (#515)
- `settings.example.json`, and the framework's own `.claude/settings.json`, give the SessionStart entry `"timeout": 120`, where the 600 s default held a session start that hung for ten minutes. `install-hooks.sh` adds the field in place to the framework's earlier entry, under either matcher, instead of appending a second group that would run the hook twice; it reports `updated: ... (added: timeout)`, with `matcher was [startup|resume|compact]` for the oldest entry (#515)

### Fixed

- On Linux, a CRLF `SESSION_STATE.md`'s `_Last updated:` line was printed with its trailing `_` and a carriage return; it is now printed as on Windows, without them (#515)

### Notes

- After upgrading, re-run `./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh` and commit `.claude/settings.json`: it gives the SessionStart entry its timeout in place. Until then `install-hooks.sh --check`, and `check-framework-drift.sh` without `--quick`, report the entry as absent, naming the in-place update (#515)
