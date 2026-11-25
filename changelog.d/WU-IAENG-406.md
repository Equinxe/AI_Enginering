### Fixed

- The `commit-msg` hook refused every commit, with exit 1 and no message, when the project roster `.ia-engineering/Registry/employees.yml` listed no names, a valid trailer naming a framework Employee included. A project roster that lists no names now adds no Domain Employee, as an absent one adds none, and the framework roster alone validates, as the `Employee Trailer` check already did; a refused name is told that the project roster lists no names. A framework roster that lists no names, and a roster the hook cannot read, are refused with a message naming the file, where the hook stopped silently. The choice is documented in `Registry/README.md`, Project Roster Extension (#443)

### Changed

- `commit-msg`, `pre-commit`, `pre-push`, `setup-branch-protection.sh` and `setup-project-bootstrap.sh` state in their header why `set -e` gives a correct fail-closed verdict there, and the Claude Code hooks' `lib.sh` says that it sets `-uo pipefail` and `LC_ALL=C` for the hooks that source it, and why not `-e` (The Check Convention, Shell Scripts rule 2; #328)
