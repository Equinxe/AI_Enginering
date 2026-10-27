### Fixed

- `release.sh publish` now lists `Workflows/RELEASE.md` Step 11, the release retrospective run by the Scrum Master, among the steps left after publishing; it listed Steps 8 to 10 only. The suite checks the wording against `RELEASE.md` itself (#306, WU-IAENG-388)
- `Registry/workflows.yml` Release step 8 says the back-merge to `develop` is always required, as `Workflows/RELEASE.md` Step 8 does; it said "when the release branch diverged" (#306, WU-IAENG-388)
