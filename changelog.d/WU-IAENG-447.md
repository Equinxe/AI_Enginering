### Added

- `Workflows/RELEASE.md` An Adopting Project's First Release: before Step 1 a Work Unit creates `CHANGELOG.md` with an `## [Unreleased] - Bootstrap` section naming every Work Unit the release carries, and Step 2 creates `VERSION.md`; both shapes, a project that already has a `CHANGELOG.md`, a first release with more than one milestone, and what the first merge into `main` changes. `README.md`, `Workflows/ONBOARDING.md` and `Registry/README.md` point to it instead of to issue #469 (#469, WU-IAENG-447)

### Fixed

- `release.sh` run from an adopting project as `./ia-engineering/Adapters/scripts/release.sh` releases the project, not the framework's submodule: it reads the project's branch, `VERSION.md`, `CHANGELOG.md`, registry and CI, and runs `validate-framework.sh` inside the framework's directory; its host is found when it is run by a relative path from another directory (#469, WU-IAENG-447)
- `release.sh check` reads a project with no `VERSION.md` and no version section in `CHANGELOG.md` as before its first release instead of failing, holds a repository without `changelog.d/` to its `CHANGELOG.md` section, as `Workflows/RELEASE.md` Step 2 already allowed, and reports a missing `CHANGELOG.md` instead of stopping on an unset variable (#469, WU-IAENG-447)

### Notes

- An adopter pinned to v0.0.15 moves its pin to v0.0.16 before its first release: v0.0.15's `release.sh` reviews the framework's submodule, not the project (WU-IAENG-447)
