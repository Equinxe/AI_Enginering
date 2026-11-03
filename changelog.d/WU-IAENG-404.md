### Fixed

- `install.sh` reports the installed `pre-commit` hook as refusing a staged document only when the hook exits 1 with its probe document refused in its output. Any other non-zero exit is a fault naming the exit status and the hook's first line of output, and `install.sh` exits 1: the scanner's 2 when it could not evaluate, and the hook's own 1 when it cannot locate `data-policy-scan.sh` and has scanned nothing. Before, any non-zero exit was reported as a hook that refuses a staged document (#348, WU-IAENG-404)
