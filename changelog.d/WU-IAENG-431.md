### Changed

- `block-escape-hatches.sh` matches its rules with bash's own `[[ =~ ]]`, line by line as `grep` read them, instead of starting a `grep` per rule. It reads the tool name and the command with one `jq`, and skips the lexer for a command with none of the ten bytes the lexer rewrites. A plain `git status` started 35 external commands and now starts 2 (`cat` and `jq`); a command with a quote or a heredoc adds the lexer's `awk`. On Windows a call starts 9 to 15 processes instead of 80 to 216. Benched under load, the p50 and p95 fall from 6.9 s and 16.9 s to 0.9 s and 2.6 s; in the production model with 8 or more agents, from 21 s and 50 s to 3.7 s and 13.5 s (`Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md`). The rule patterns are unchanged and so is what they refuse; `tests/run.sh` holds the hook to that budget (#385, WU-IAENG-431)

### Security

- `block-escape-hatches.sh` refuses a command of more than 2,000 pipeline segments after expansion, so its work stays bounded on every Claude Code version, including one older than 2.1.295, where a guard that runs past its timeout lets the call through. The most segments in 4,504 real commands of this repository was 463 (SEC-IAENG-410-01, #385, WU-IAENG-431)
- `block-escape-hatches.sh` refuses the call when one of its rule patterns does not compile in the running shell; under `grep`, such a rule read as "no match" and switched itself off. A `tool_name` that is not a string is now judged, where it was allowed as another tool's call (#385, WU-IAENG-431)
- `block-escape-hatches.sh` removes every carriage return from the command before matching, as bash removes it before running (SEC-IAENG-431-01, #385, WU-IAENG-431)
- `block-escape-hatches.sh`'s rule classes match the same bytes as `grep` did: a byte from 0x80 to 0xFF is in no class, as under `grep` with `LC_ALL=C`, whatever the platform's regular expressions make of it (SEC-IAENG-431-02, #385, WU-IAENG-431)
