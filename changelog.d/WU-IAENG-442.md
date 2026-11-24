### Changed

- `data-policy-scan.sh --history` reads paths NUL-delimited (`git log -z`), as `--staged` and `--tree` already did (WU-IAENG-442)
- `data-policy-scan.sh` sanitises reported paths in every mode: a path and its line number are printed on one line, each control character as a space, with the record sanitiser the installers use (WU-IAENG-442)
- `data-policy-scan.sh --history` normalises merge-authored names before tabulation, so a finding in a file a merge adds is reported under its whole name (WU-IAENG-442)
