### Security

- A refusal from the commit-msg hook, `check-employee-trailers.sh`, `check-work-units.sh` or `check-risk-map.sh` now prints a carriage return inside the refused value as `\r`, in the local message and in the GitHub annotation alike. Printed raw, it sent the cursor back to the start of the line, the rest of the message overwrote the beginning, and the byte that caused the refusal was not visible. Only the message changes: the comparisons still read the raw bytes. The other control bytes are #427 (#337, WU-IAENG-395)
