### Added

- `Templates/PROJECT_CLAUDE.md` (0.0.15) says how a project that already has a `CLAUDE.md` adopts the contract. It merges the template's block into its file instead of replacing it or pasting the template under it, and keeps its build, test and run commands word for word. It keeps one contract at the root (`.claude/CLAUDE.md` is moved there, since `session-start.sh` checks only the root file). It settles each contradiction with the Director: a stricter project rule stays, the framework's rule replaces a looser one, or the looser one becomes a deviation recorded in `SESSION_STATE.md`. With no Project Charter, it answers from the existing file, the code and the Director. A project with only an `AGENTS.md` imports it with `@AGENTS.md`, because Claude Code stops reading `AGENTS.md` once a `CLAUDE.md` exists. `README.md` and `Workflows/ONBOARDING.md` (0.0.17) Step 1 item 2 point to it (#446, WU-IAENG-432)
- The commit that adds an adopting project's `CLAUDE.md` is signed `Employee: DevOps Engineer`, with a Work Unit of its own, so every commit of the adoption has the same signer (Director decision, 4 November 2026). `README.md`, `Workflows/ONBOARDING.md` Step 1 and `Workflows/PROJECT_BOOTSTRAP.md` (0.0.16) Steps 4 and 7 say so (#379, WU-IAENG-432)

### Changed

- `Workflows/ONBOARDING.md` Step 1 item 3, `Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5, Step 7 and its Coverage Checklist, `Templates/SESSION_STATE.md` (0.0.15) and the Claude Code hooks README name `Adapters/scripts/create-session-state.sh` as the way to create `.ia-engineering/SESSION_STATE.md`, with the by-hand copy of the fenced block as the fallback. The helper's own test case for a submodule refusal is still open in the same issue (#253, WU-IAENG-432)

### Fixed

- `README.md` said to copy the whole of `Templates/PROJECT_CLAUDE.md` into `CLAUDE.md`. It now says to copy the fenced block's contents only, as the template's Template section does. The block's outer fence has four backticks, so the inner fence under `# Repository` no longer closes it early (#414, WU-IAENG-432)
- `Workflows/PROJECT_BOOTSTRAP.md` Step 4 said `install-skills.sh` adds only `/create-project`. It adds `/dashboard` too (#413, WU-IAENG-432)
- `Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5 justified the adoption commit's signer by "pipelines, hooks and tooling". It now cites CI pipelines and git hooks, the DevOps Engineer's role in `Core/EMPLOYEE_SELECTION.md`, and says that running the framework's installers is not building them (#208, WU-IAENG-432)
- In the Claude Code hooks README, the Line endings paragraph had split the `install-hooks.sh` install paragraph, so its second half read as if it described `.gitattributes`. The install paragraph is whole again, and Line endings follows it (#257, WU-IAENG-432)

### Notes

- A project whose `CLAUDE.md` is a copy of the whole `Templates/PROJECT_CLAUDE.md`, as `README.md` said before this version, replaces it with the fenced block's contents, filled in: everything from `# [Project Name]` to the last line before the closing fence. The template's Usage, Field Reference and Metadata sections are not part of the contract (#414, WU-IAENG-432)
