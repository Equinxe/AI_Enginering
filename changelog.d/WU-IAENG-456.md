### Added

- `check-framework-drift.sh --accept <path>` records a reviewed edit the project keeps in a framework-installed file (one of its CI workflows, for example) as accepted, in the committed `.ia-engineering/drift-accepted.tsv`, with the hash of the framework's file and of the project's. It records a file only when the installers manage it and the full check calls it `modified`; a file that is current, absent, stale, expected to differ or not managed is refused. While both files keep the hashes recorded, the file is `accepted`: not to act on, `--strict` exits `0` for it, the summary counts it (`1 accepted`), and session start prints one `N accepted` line where it printed the same line to act on at every session. The entry lapses when either file changes, and the file is drift again, its remedy and session start saying the acceptance lapsed. The hashes drop the carriage return that ends a line, so CRLF and LF clones agree. Documented in `Adapters/README.md`, Accepted Drift (#420, WU-IAENG-456)

### Changed

- `session-start.sh` builds its drift line's file lists without a subshell (`d_list` sets its result by name), and reads the accepted and lapsed records in the shell: the drift block starts no process it did not start before (#420, WU-IAENG-456)

### Security

- An acceptance never covers what decides whether the git hooks or the Claude Code hooks run: `core.hooksPath`, `.git/`, the framework's git hooks, `.claude/settings.json` and `.claude/settings.local.json` (the Claude Code hook entries, the two `PreToolUse` guards among them), `.claude/hooks/`, a hook entry, the framework's Claude Code hooks, and the framework's own directory. `--accept` refuses them, without regard to case, and an entry written by hand for one is never applied: it is reported `refused`, to act on (#420, WU-IAENG-456)
