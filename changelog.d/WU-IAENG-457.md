### Changed

- `install-hooks.sh` refuses a project whose `.claude` is a link. When `.claude` is a symbolic link or a Windows junction, a run used to write `settings.json` into the directory the link leads to, and `--check` reported nothing. A run now writes nothing (no directory, no temporary file, no `.gitattributes` line), exits 1, names where the link leads and gives the remedies. `--follow-claude-link` installs there, saying so on stderr. A link to Claude Code's user settings directory, `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, is refused with the flag too, and `--check` reports any linked `.claude` as a fault, so it exits 1. `install-skills.sh` applies the same rule, and takes the same flag, for `.claude`, `.claude/skills` and each `.claude/skills/<name>` it writes (part of #282, WU-IAENG-457)

### Fixed

- `install-hooks.sh` and `install-skills.sh` no longer append their line to a `.gitattributes` that is a symbolic link. The append wrote into the file the link leads to, or created one where a dangling link pointed, and git 2.32 and newer does not read such a `.gitattributes` anyway. The run now prints the line to add to a file of the project's own and exits 1, and `--check` reports a fault (part of #255, WU-IAENG-457)

### Notes

- A project that shares `.claude/` through a link on purpose now needs `--follow-claude-link` on each run of `install-hooks.sh` and `install-skills.sh`, and their `--check` (with the drift check at session start) reports the link until it is replaced by a directory of the project's own (WU-IAENG-457)
