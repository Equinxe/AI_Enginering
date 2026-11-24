### Changed

- Each agent `generate-agents.sh` writes in an adopting project records, in its header, the framework commit it was generated from (`Framework: <commit>`). Session start's quick check compares it with the commit in use and reports an agent recording another commit, or none, as stale, so an upgrade that changes only `Employees/` is detected at the next session with no command to type. An agent that records a commit while git gives none for the framework is said in a clause of its own, not as an upgrade. `--check` reports a difference in that line alone, its absence included, as `framework commit only`. The framework repository's own agents record no commit and are unchanged (Director decision, 18 November 2026; #471)
- `install.sh` keeps a project's own `.github/PULL_REQUEST_TEMPLATE.md`: one that differs from the Adapter is recorded `kept` and never overwritten, `--force` included, and is no longer a problem, so `setup-project-bootstrap.sh` no longer exits 1 on it. While the template lacks one of the framework's parts (the `Work Unit:` line, Merge danger, How to test, the Falsifiability item), the run prints one `>` action and `--check` one `todo` record, neither of them drift. The full `check-framework-drift.sh` still reports an unchanged copy of an earlier framework template as stale (Director decision, 18 November 2026; #472)
- `setup-project-bootstrap.sh --help` reaches Usage first and leaves out the script's change history (#367)

### Fixed

- Session start told a project with no `CLAUDE.md` that it had not completed `Workflows/PROJECT_BOOTSTRAP.md` Phase B, which an existing project that adopts does not have. It now names what fills `CLAUDE.md` in a new project and in an existing one (#367)
- Session start copied the template's placeholders of a new `SESSION_STATE.md` as the Next Step to take, and the Blocked On placeholder as a blocker. A section shaped as the placeholder, one bracketed text, is now read as not filled in, its first line shown so that an entry written in brackets is never hidden (#367)
- The `create-session-state.sh` command that session start and the Stop gate print, and the drift line's command, run as printed from the project root when its path holds a space: the path from the project root, quoted when it needs it (#417)
- The session-start drift line said "so that guard is silently off" of every hook command whose script is missing. It now gives the outcome that applies, from the entry's `"onFailure"` and its event: with `"block"` on PreToolUse, Claude Code refuses every call the guard guards, and the line says the Director then runs its command from a terminal with `TROUBLESHOOTING.md` entry C; on another event, what exit code 2 does there, the event named. `check-framework-drift.sh` writes the same outcome in its record (#415)
- The said-once and background-run files the session-start drift check keeps in the user cache are removed after 30 days without a change, so they no longer pile up from every project that ever ran; the check's own kept result, one pair of files per project, stays (#367)
- The diff command `install.sh` prints for a project's own pull request template runs as printed when the framework's path holds a space (#417, #472)
- `install.sh`'s closing block put the note about the committed `.claude/settings.json` under Runtime skills; it is under Runtime hooks, which writes that file (#367)
- `Workflows/ONBOARDING.md` (0.0.19) Step 1 says what fills `CLAUDE.md` in a project with no Project Charter and no Stack Decision ADR, and The adoption route says that a project's own pull request template is kept (#367, #472)

### Notes

- After upgrading, regenerate the Employees' agents with `./ia-engineering/Adapters/ai-runtimes/generate-agents.sh`: session start reports every agent written before this version as stale until they record the framework commit (#471)
- A project with a pull request template of its own keeps it. Copy into it by hand the framework's parts that `install.sh --check` lists, from `ia-engineering/Adapters/github/PULL_REQUEST_TEMPLATE.md` (#472)
