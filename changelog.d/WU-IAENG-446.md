### Fixed

- `data-policy-scan.sh` reports a secret under its file's own name in `--staged` and `--history`. A name holding a control character, a double quote or a backslash was reported under git's quoted diff header, `"b/conf\rx.txt"` for example. The scanner now reads the name back from the header and prints it with the record sanitiser, each control character as a space (#484, WU-IAENG-446)
- `data-policy-scan.sh` reports the same path whatever the user's `diff.noprefix`, `diff.mnemonicPrefix` or `diff.dstPrefix` says. With `diff.noprefix`, a secret under `b/x.conf` was reported as `x.conf` (WU-IAENG-446)
