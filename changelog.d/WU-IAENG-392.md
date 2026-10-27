### Added

- `validate-framework.sh` compares every step title in `Registry/workflows.yml` with its document's `## Step N —` heading, in order and byte for byte. A renamed heading, a qualifier added to the Registry, or two steps swapped at the same count now fail. Before, only the step count was checked, which is how Release Step 8 kept "when the release branch diverged" for seven weeks while the count stayed right. The check reports how many workflows and steps it compared, and it fails when it compared none. It also refuses a `step:` value whose bytes YAML would read differently, such as a block scalar, a single-quoted value, or an unquoted title containing `: ` (#332, WU-IAENG-392)

### Changed

- Each `step:` value in `Registry/workflows.yml` is now its document's heading text, copied exactly: 51 of the 80 values were rewritten and their qualifiers removed. What a step requires is stated only in its Workflow document, as the Registry's header already said (Director decision of 27 Oct 2026, option A). The Registry's header and `Registry/README.md` state the rule and the line shape the validator reads (#332, WU-IAENG-392)

### Fixed

- Code Review Step 9 in the Registry read "Author response, then re-request review", which dropped the document's condition "(if changes requested)". It now reads as the heading (#332, WU-IAENG-392)
