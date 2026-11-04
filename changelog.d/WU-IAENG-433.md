### Fixed

- `setup-branch-protection.sh` refuses, and names, a default branch other than `main` or `develop`. It used to leave such a branch, `master` for example, unprotected and still report done (#447, WU-IAENG-433)
- On a private repository on GitHub Free, `setup-branch-protection.sh` says in plain words that GitHub refuses branch protection and rulesets, changes nothing and exits 1. It refuses a private repository that has neither `main` nor `develop` on GitHub yet, where no read can show whether the plan enforces a ruleset. `Governance/TROUBLESHOOTING.md` entry AD says that only the local hooks and the CI checks then enforce, that the checks cannot be required, and what they cost in Actions minutes (#448, WU-IAENG-433)

### Security

- `setup-branch-protection.sh` no longer lowers the protection of an existing repository. It used to replace each protection whole: a project's own required checks were dropped, its approvals set to 0, `enforce_admins` turned off, and the settings its body left out reset. It now reads every branch protection and the `release-branch-protection` ruleset before its first write. Required checks become the union of the project's and the framework's, and no count or setting is lowered. A read that fails stops the run with nothing changed (#447, WU-IAENG-433)

### Notes

- If you ran `setup-branch-protection.sh` from an earlier version on a repository that had protection of its own, that run replaced it. Check Settings > Branches and the `release-branch-protection` ruleset. Restore by hand what the run dropped or lowered: your own required checks, the required approvals, `enforce_admins`, push restrictions, and the review, linear-history and conversation-resolution settings. A run of this version keeps what it finds. It cannot restore what an earlier run removed
- `develop` now keeps `strict` (branches up to date before merging) where it is on. A run from v0.0.15 turned it off, and this version leaves it as it finds it. If a run from before v0.0.15 turned it on and you want the framework's default, turn it off by hand
- If your repository is private on GitHub Free, an earlier run stopped on GitHub's HTTP 403 and protected nothing. That is still the case: see `Governance/TROUBLESHOOTING.md` entry AD
