### Added

- `.ia-engineering/statusline-own` in a project makes `context-statusline.sh` print its own line there in place of the chained one: neither the user's `statusLine` nor a `--chain` command is read or run, so a chained HUD is replaced in that project alone. Deleting the file restores the chaining. Nothing is written to switch, `~/.claude/settings.json` included, the `.pct` is still written for the context alert, and the off switch wins over it (#390, WU-IAENG-421)
- `hooks/context-thresholds.sh` holds the context alert's rule for its two steps (the alert, 60 % by default; the last call, the alert + 10). `context-alert.sh` and `context-statusline.sh` both source it, so the line and the alert cannot disagree; the alert's behaviour is unchanged (#390, WU-IAENG-421)

### Changed

- The status line's own line shows the model; the context as a percentage and as the input tokens in the window out of its size (`ctx 64% 642k/1M`); the weekly quota with its local reset time and the time a steady pace reaches 100 % (`wk 77%! (reset Thu 11:23, cap ~Wed 23:14)`, or `no cap`, or `capped`); and the branch read from the repository's `HEAD` with builtins, with the Work Unit id its name carries first (`WU-421 feat/...`). It shows no count of running agents: nothing Claude Code exposes gives one reliably, as `hooks/README.md` explains (#390, WU-IAENG-421)
- The line's colours follow the context alert's two steps, on by default: yellow from the alert, bold red and a `!` from the last call, for the context and the weekly quota alike; the weekly quota is also red when a cap comes before its reset. Before, only the context turned yellow, and only when `IAENG_CTX_ALERT_PCT` was set. `NO_COLOR` removes the colours and keeps the `!` (#390, WU-IAENG-421)
- A render whose percentage has not moved no longer rewrites the `.pct`, and starts no `find` and no `mv` (#390, WU-IAENG-421)

### Removed

- The 5-hour quota (`| 5h <n>%`) is no longer shown: the Director's plan has none (#390, WU-IAENG-421)

### Fixed

- `context-alert.sh` and `context-statusline.sh` name their own directory as the other hooks do (`hooks/README.md`, Design Rules, Load from the hook's own directory): from `$0` when it holds a `/` or `\`, else from `BASH_SOURCE`. Named by a path with backslashes only, they sourced `context-dir.sh` from the working directory. `tests/own-dir.sh` now runs the status line in each of its invocation forms (#362, WU-IAENG-421)

### Notes

- To have the framework's line in place of your chained status line in one project, create `.ia-engineering/statusline-own` there; delete it to go back. In an adopting project, add `.ia-engineering/statusline-own` to `.gitignore`, which `install.sh` does not do, or a commit would switch the line for every clone (WU-IAENG-421)
