### Fixed

- `usage-dashboard.sh` counts what it used to miss (issue #205). A commit whose `Employee:` trailer git does not parse is attributed from its first column-0 `Employee:` line, the line CI validates; 17 commits of this repository were uncounted before. The Engineer step sums every Employee who committed or registered a Work Unit, not a fixed list of eight. Main Agent and Director steps show as framework roles, no longer "not on roster" or NEVER exercised. A fork or helper an Employee started is credited to that Employee, no longer listed as a dispatch without one (#247, WU-IAENG-346)

### Added

- The usage dashboard shows a Measurement windows table (the range, the whole history and the retained transcripts) and two top-2 tiles, the share of attributed commits held by the two busiest Employees. When the project's `CLAUDE.md` lists Active Employees, an idle Employee outside the list reads "not active here" instead of NEVER USED. After new commits on top of the cached HEAD, only those go through the git log passes, while the registries and the range are re-read every time (issue #231); a rewritten history, a changed shallow boundary, a malformed cached row or a newer script reads the whole history again (#247, WU-IAENG-346)
