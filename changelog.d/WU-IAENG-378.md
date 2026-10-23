### Added

- Changelog fragments. A Work Unit's Pull Request adds `changelog.d/<Work Unit id>.md` instead of editing `CHANGELOG.md`, so two Pull Requests no longer conflict on the same category. A fragment holds Keep a Changelog headings with bullets, or the single line `No changelog entry: <reason>`. `changelog.d/README.md` gives the format, and `Adapters/scripts/changelog-fragment.awk` is the one parser of it, used by both scripts below
- `release.sh assemble` (`Workflows/RELEASE.md` Step 2) folds the fragments into the `[Unreleased]` section of `CHANGELOG.md`, by category then Work Unit id, below the bullets already there, adds the Work Unit id to any bullet without it, writes exemptions as hidden comments, and deletes the fragments. It commits nothing, and refuses with nothing changed if any fragment is malformed or anything else is in `changelog.d/`
- `validate-framework.sh` section 23: every fragment is named after a registered Work Unit and uses only the six Keep a Changelog headings. On a Pull Request to this repository it also warns, without failing, about a Work Unit trailer with no fragment and no edit of `CHANGELOG.md`

### Changed

- `release.sh check` condition 5 is checked mechanically: every Work Unit registered against the milestone has a fragment, or is named in the final parenthesised group of a line of the milestone's `CHANGELOG.md` section. Before, the check only looked at the section's presence and size. A fragment left over after the assembly fails. `Workflows/RELEASE.md` Steps 1 and 2 and `Workflows/CODE_REVIEW.md` Step 6 now refer to the fragment
- The path-reference check (validator section 9) skips the fragments, for the reason it skips `CHANGELOG.md`, and the repository-layout check skips `changelog.d/`
