### Fixed

- `merge_classify_automatic` (`merge-classify.sh`) pins `merge.renameLimit=7000`, git's merge default. A low local `merge.renameLimit`, or the `diff.renameLimit` it falls back to, no longer turns an honest merge into a conflict that the approval carry-over check refuses and `merge_classify` calls `authored` (issue #237) (#249, WU-IAENG-351)

### Changed

- The approval carry-over record names the base commit and the blob ids of `check-approval-carry-over.sh` and `merge-classify.sh`, so an auditor can rerun the same checker against the same base. It is still one 7-bit ASCII line, with its prefix unchanged (issue #240) (#249, WU-IAENG-351)

### Security

- The approval carry-over check no longer lets local git state change its verdict (Security Engineer review of #249, Medium findings F1 to F4). `merge_classify_automatic` always merges with git's built-in 3-way driver, so no `merge.default` or `merge.<name>.driver` is read; before, a local `union` or custom driver could pass a hand resolution as git's own merge, and ran its command. The check refuses a non-empty `info/grafts` or `GIT_GRAFT_FILE` and reads no commit-graph, either of which could show a single-parent commit as a merge (#249, WU-IAENG-351)
