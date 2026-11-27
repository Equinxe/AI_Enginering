### Changed

- `install-hooks.sh` refuses a project whose `.claude` is a link. When `.claude` is a symbolic link or a Windows junction, a run used to write `settings.json` into the directory the link leads to, and `--check` reported nothing. A run now writes nothing (no directory, no temporary file, no `.gitattributes` line), exits 1, names where the link leads and gives the remedies. `--follow-claude-link` installs there, saying so on stderr. A link to Claude Code's user settings directory, `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` or `$HOME/.claude`, or a link that leads to no directory, is refused with the flag too, and `--check` reports any linked `.claude` as a fault, so it exits 1. `install-skills.sh` applies the same rule, and takes the same flag, for `.claude`, `.claude/skills` and each `.claude/skills/<name>` it writes; with the flag too, it refuses a link into the user settings directory's `skills/` (part of #282, WU-IAENG-457)

### Fixed

- `install-hooks.sh` and `install-skills.sh` no longer append their line to a `.gitattributes` that is a symbolic link, nor count the line present when the file such a link leads to holds it. The append wrote into the file the link leads to, or created one where a dangling link pointed, and git 2.32 and newer does not read such a `.gitattributes` at all. The run now prints the line to add to a file of the project's own and exits 1, and `--check` reports a fault (part of #255, WU-IAENG-457)

### Notes

- A project that shares `.claude/` through a link on purpose now needs `--follow-claude-link` on each run of `install-hooks.sh` and `install-skills.sh`, and their `--check` (with the drift check at session start) reports the link until it is replaced by a directory of the project's own. A project whose `.gitattributes` is a symbolic link gets exit 1 from both installers, and a fault from their `--check`, until the link is replaced by a file of its own (WU-IAENG-457)
