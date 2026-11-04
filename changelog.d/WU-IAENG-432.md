### Added

- `Templates/PROJECT_CLAUDE.md` (0.0.15) says how a project that already has a `CLAUDE.md` adopts the contract. It merges the template's block into its file, after the adoption commit, instead of replacing the file or pasting the template under it, and it keeps the project's build, test and run commands word for word.
  - One contract stays at the root. `.claude/CLAUDE.md` is moved there, since `session-start.sh` checks only the root file, and each of its relative `@` imports is rewritten to resolve from the root.
  - Each contradiction found in the instruction files is presented to the Director, and nothing changes until the Director chooses: a stricter project rule stays, the framework's rule replaces a looser one, or the looser one becomes a deviation. A deviation is held in the Work Unit Report and an Issue until `SESSION_STATE.md` is created.
  - With no Project Charter, the answers come from the existing file, the code and the Director.
  - A project that relies on `AGENTS.md` files imports each one, because Claude Code stops reading them once a `CLAUDE.md` exists.
  - `README.md` and `Workflows/ONBOARDING.md` (0.0.17) Step 1 item 2 point to the procedure (#446, WU-IAENG-432)
- An adopting project's `CLAUDE.md` is written by the DevOps Engineer, whom the Main Agent dispatches. Its commit is signed `Employee: DevOps Engineer`, with a `Work Unit:` line of its own, so every commit of the adoption has the same signer (Director decision, 4 November 2026). `README.md`, `Workflows/ONBOARDING.md` Step 1 and `Workflows/PROJECT_BOOTSTRAP.md` (0.0.16) Steps 4 and 7 say so (#379, WU-IAENG-432)

### Changed

- `Workflows/ONBOARDING.md` Step 1 item 3, `Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5, Step 7 and its Coverage Checklist, `Templates/SESSION_STATE.md` (0.0.15) and the Claude Code hooks README name `Adapters/scripts/create-session-state.sh` as the way to create `.ia-engineering/SESSION_STATE.md`, with the by-hand copy of the fenced block as the fallback. The helper's own test case for a submodule refusal is still open in the same issue (#253, WU-IAENG-432)

### Fixed

- `README.md` said to copy the whole of `Templates/PROJECT_CLAUDE.md` into `CLAUDE.md`. It now says to copy the fenced block's contents only, as the template's Template section does. The block's outer fence has four backticks, so the inner fence under `# Repository` no longer closes it early (#414, WU-IAENG-432)
- `Workflows/PROJECT_BOOTSTRAP.md` Step 4 said `install-skills.sh` adds only `/create-project`. It adds `/dashboard` too (#413, WU-IAENG-432)
- `Workflows/PROJECT_BOOTSTRAP.md` Step 4 item 5 justified the adoption commit's signer by "pipelines, hooks and tooling". It now cites CI pipelines and git hooks, the DevOps Engineer's role in `Core/EMPLOYEE_SELECTION.md`, and says that running the framework's installers is not building them (#208, WU-IAENG-432)
- In the Claude Code hooks README, the Line endings paragraph had split the `install-hooks.sh` install paragraph, so its second half read as if it described `.gitattributes`. The install paragraph is whole again, and Line endings follows it (#257, WU-IAENG-432)

### Notes

- A project whose `CLAUDE.md` is a copy of the whole `Templates/PROJECT_CLAUDE.md`, as `README.md` said before this version, replaces it with the fenced block's contents, filled in: everything from `# [Project Name]` to the last line before the closing fence. The template's Usage, Field Reference and Metadata sections are not part of the contract (#414, WU-IAENG-432)
