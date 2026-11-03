### Added

- The script suite checks that `setup-branch-protection.sh` off GitHub makes no `gh` call, as its "Nothing was changed" says, and that `strict_for()` refuses a branch with no decided strict value. No run of the script reaches that refusal, so the suite extracts the function and calls it alone (#329, WU-IAENG-407)

### Fixed

- `Workflows/RELEASE.md` Step 8 and `Workflows/HOTFIX.md` Step 9 no longer read as if `develop` requires branches to be up to date. The warning against a back-merge Pull Request with `main` as its head now names where it applies: by default only `main` and `release/*` require it, and `develop` does where a project turns the setting on or where `setup-branch-protection.sh` was last run from a version before v0.0.15. The instruction is unchanged (#329, WU-IAENG-407)
