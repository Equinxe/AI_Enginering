### Added

- `README.md` Getting Started has a "Which model runs which task" step. On a real project the model follows the task (Director decision, 28 Oct 2026): Lightweight Execution on `haiku`, Standard Execution on `sonnet`, Strategic Judgment on `opus`, and Frontier on `fable`, with the Director's approval each time. The project records this in `.ia-engineering/tier-map` and regenerates its agents. The step says what happens without the file: the generator's defaults apply and nobody chose them. It shows how to check the mapping in force (`generate-agents.sh --print-tier-map`, the session-start hook's `Tier map in force`, `--check`), and explains why the map uses aliases and not full model IDs (#365, WU-IAENG-417)

### Fixed

- `README.md` Getting Started lists what an adopter needs first: `git`, `bash` (Git Bash on Windows), `jq` for `install-hooks.sh`, and `gh` for `setup-branch-protection.sh` (#365, WU-IAENG-417)
- `README.md`: `install-skills.sh` adds `/create-project` and `/dashboard`, not `/create-project` alone (#365, WU-IAENG-417)
- `README.md`: the `.gitmodules` "LF will be replaced by CRLF" warning that `git submodule add` prints on Windows is expected, and nothing needs doing (#365, WU-IAENG-417)
- `README.md`: an adopter completes `.ia-engineering/risk-map.yml` in one of the first Work Units. Until all eight categories are mapped or declared absent, the **Risk Map (advisory)** check is red on every Pull Request (#365, WU-IAENG-417)
- `Workflows/FEATURE_DEVELOPMENT.md` (0.0.16) Step 4 item 2: in a project that imported the framework, a Work Unit's `milestone:` is the project's own release or iteration label, because the project has no `VERSION.md` (#365, WU-IAENG-417)
- `Templates/PROJECT_CLAUDE.md` (0.0.14): a fresh clone fetches the framework submodule (`git submodule update --init`, or `--recurse-submodules`) before it re-runs `install.sh`, which lives in that submodule (#365, WU-IAENG-417)

### Notes

- A project with no `.ia-engineering/tier-map` keeps the generator's default models. To choose the model per task, create the file as `README.md` "Which model runs which task" shows, then re-run `generate-agents.sh` (WU-IAENG-417)
- A project `CLAUDE.md` copied from an earlier `Templates/PROJECT_CLAUDE.md` still says to re-run `install.sh` in every fresh clone without fetching the submodule first. Add `git submodule update --init` before it by hand (WU-IAENG-417)
