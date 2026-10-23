# Changelog Fragments

One file per Work Unit holds that Work Unit's `CHANGELOG.md` entry until the release. A Work Unit's Pull Request adds its fragment here and does not edit `CHANGELOG.md`.

Two Pull Requests that each append a line to the same `CHANGELOG.md` category conflict, and a conflict resolved by hand voids the approvals already given on the Pull Request. Two Pull Requests that each add their own file never conflict. The Release Manager study of 23 October 2026 (option 1) chose this design; towncrier, changesets and GitLab's `changelogs/unreleased/` work the same way.

---

## The File

- **Name:** the Work Unit id, then `.md`: `WU-IAENG-378.md`. The id must be registered in `Registry/work-units.yml`. One fragment per Work Unit; a Work Unit with several Pull Requests adds it in one of them.
- **Content:** one or more [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) headings, each with at least one bullet. Only these six headings are allowed, written exactly so:

  `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`

- **Bullets:** each starts with `- ` at the start of the line. A bullet may continue on lines indented by a space or a tab. No other text, no other heading level.
- **The Work Unit id:** each bullet ends with its id in parentheses, as every `CHANGELOG.md` line does, for example `(#262, WU-IAENG-353)`. Leave it out and it is added at assembly: ` (WU-IAENG-378)`.

```markdown
### Added

- `release.sh assemble` folds the changelog fragments into `CHANGELOG.md` at the version bump

### Fixed

- The validator no longer reads a fragment's historical paths as broken references
```

A Work Unit that changes nothing a reader of the changelog needs to know still gets a fragment, with this single line and a reason:

```markdown
No changelog entry: bookkeeping only, no behaviour or document a reader relies on changed
```

The reason is required. A missing fragment and a deliberate "no entry" look the same otherwise, and the release check exists to tell them apart.

---

## What Checks It

| When | What | On failure |
|---|---|---|
| Every Pull Request and push | `Adapters/scripts/validate-framework.sh` section 23: every file here other than this README is named after a registered Work Unit, and its content is one of the two forms above | The Framework Validation check fails |
| A Pull Request to this repository | Section 23's early warning: a Work Unit trailer in the Pull Request with no fragment here and no edit of `CHANGELOG.md` | A warning annotation, never a failure |
| Release, Step 1 | `Adapters/scripts/release.sh check`, condition 5: every Work Unit registered against the milestone has a fragment here, or is already named in the milestone's `CHANGELOG.md` section | The release is blocked |
| Release, Step 2 | `Adapters/scripts/release.sh assemble` | Refuses, and changes nothing, if any fragment is malformed |

The format is defined once, in `Adapters/scripts/changelog-fragment.awk`; the validator and the assembler both use it.

---

## At the Release

`Workflows/RELEASE.md` Step 2 runs `Adapters/scripts/release.sh assemble` on the version-bump branch. It:

1. Folds every fragment into the `## [Unreleased]` section of `CHANGELOG.md`, heading by heading in Keep a Changelog's order. The bullets already in a heading stay first, then the fragments' bullets in Work Unit order. A heading that is not one of the six, such as `### Notes`, keeps its text and comes after the six.
2. Writes each exemption as a comment at the end of the section, `<!-- No changelog entry (WU-IAENG-NNN): reason -->`. It is hidden in the published notes but remains in the file for the release check.
3. Deletes the fragments it assembled. It commits nothing: the Release Manager renames `[Unreleased]` to the version and commits `CHANGELOG.md` and the deletions in the same bump commit.

The bullets written straight into `CHANGELOG.md` before fragments existed stay where they are; the assembler adds the fragments below them.
