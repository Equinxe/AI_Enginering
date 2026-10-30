### Added

- `check-work-units.sh --message <file>` applies the `Work Unit Exists` rule to one commit message before it is a commit, against `Registry/work-units.yml` as staged (the index, including the temporary one `git commit <paths>` uses). A registry that is in the working tree but not staged is refused, with the `git add` to run. It exits 1 for a finding about the claim and 2 when it could not evaluate, and when `IAENG_REGISTRY_WORK_UNITS` replaces the staged registry it says so on stderr (#364, WU-IAENG-415)

### Fixed

- The `commit-msg` hook checks that a `Work Unit:` trailer names a Work Unit registered in the project's `Registry/work-units.yml` as staged, through `check-work-units.sh --message`, so the rule is the CI check's own. It refuses an id that is unregistered, a malformed id, and a claim it cannot evaluate: no registry, a registry left unstaged, an unreadable one, or no `check-work-units.sh` in the hook's own framework (beside it, or `IAENG_FRAMEWORK`; never the working tree). Before, it only counted the lines, so an unregistered Work Unit was committed locally, and the adoption commit, which goes to `main` without a Pull Request, was never read by the trailer checks. A claim on a clean merge is checked too. A message with no `Work Unit:` line still passes the hook; only the CI check requires one (#364, WU-IAENG-415)
- README Contributing and the adoption-commit step (README and `Workflows/PROJECT_BOOTSTRAP.md` Step 4), `Standards/COMMIT_STANDARD.md`, `Adapters/README.md` and `Registry/README.md` say what the hook and the CI check each enforce (#364, WU-IAENG-415)

### Notes

- Register a Work Unit in the commit that claims it, or in an earlier one. The hook reads the registry as staged, while the CI check reads it at the Pull Request's head, so a commit whose registry entry only arrives in a later commit of the same Pull Request is now refused locally. A `commit-msg` hook copied into `.git/hooks`, instead of wired through `core.hooksPath`, finds the check only through `IAENG_FRAMEWORK`, and refuses a claim without it: the hook never runs a script from the working tree (WU-IAENG-415)
