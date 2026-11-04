### Fixed

- An Employee dispatched in a linked git worktree of an adopting project (Claude Code `isolation: worktree`) reads the framework files its definition names. In a worktree the framework submodule is an empty directory, and the generated agents named framework files by their path from the framework root, which resolved from no directory of an adopter: 741 of 741 paths unresolved on `develop` 75765ba, the Code Reviewer's and QA's included. `generate-agents.sh` now gives an adopting project's agents a "Where the Framework Is" section. It names the main checkout's framework root as an absolute path, the root the git hooks already run from, written as `C:/...` under Git Bash. The framework repository's own agents are unchanged (#449, WU-IAENG-430)
- `generate-agents.sh --check` reports an agent generated in another clone, or before the project moved, as `framework location only` or `mapping and framework location`, and says how many name another root. It no longer reports them as out of date with `Employees/` (#449, WU-IAENG-430)
- `Templates/PROJECT_CLAUDE.md` no longer leaves a worktree's empty `ia-engineering/` unexplained, and `Templates/EMPLOYEE_BRIEF.md` (0.0.12) names framework documents by their path from the framework root, which the Employee reads under the root its definition names (#449, WU-IAENG-430)

### Notes

- In an adopting project, re-run `./ia-engineering/Adapters/ai-runtimes/generate-agents.sh` from the main checkout, so that every agent names the framework root. Re-run it after moving the project. Agents generated before this release name no root: an Employee in a worktree cannot read the framework from them, and `--check` reports them as out of date (#449, WU-IAENG-430)
