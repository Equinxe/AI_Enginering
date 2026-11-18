### Changed

- `install-hooks.sh` validates the shape of `.claude/settings.json` more strictly. The file must be strict JSON in the shape the Claude Code settings schema gives `hooks`: under each event a list of matcher groups, and each group an object whose `hooks` is a list. A byte order mark, a value JSON does not have (`NaN`, `Infinity`, a number such as `+1`, `01` or `.5`), and an event or group out of that shape are refused like a comment is: the file is left as it is, the run exits 1 and names the reason and its remedy, and `--check` reports the same reason as a fault (WU-IAENG-441)
- `install-hooks.sh` writes atomically on every path. A new file and `--force` are written to a temporary file beside `.claude/settings.json`, checked, then renamed over it, as a merge already was. A symbolic link at that path is refused on every path, `--force` included, and `--check` reports one that points at no file as a fault instead of an absent file (WU-IAENG-441)

### Notes

- After the upgrade, `install-hooks.sh`, and its `--check` that `check-framework-drift.sh` runs, may refuse a `.claude/settings.json` that an earlier version accepted. The message names what to correct: a byte order mark, a value such as `NaN`, or an event or group under `hooks` that is not a list. Correct it and re-run (WU-IAENG-441)
