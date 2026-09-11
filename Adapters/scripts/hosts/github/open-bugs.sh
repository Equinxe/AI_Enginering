#!/usr/bin/env bash
# IA Engineering — hosts/github/open-bugs.sh
#
# Lists open issues labelled `bug`, one per line, as "#<number> <title>".
# See Adapters/scripts/hosts/README.md for the contract: this FETCHES ONLY.
#
# Whether any of them blocks a release is Workflows/RELEASE.md Step 1
# condition 3, which is REPORTED AND NOT FAILED on purpose: whether an open
# issue is critical or high is a judgment, and a script that guessed would
# either block real releases or wave through real blockers.
#
# Exit 0 whether or not any exist. An empty list is a real answer here.
# Exit 1 only when the tracker could not be read at all — that is not the same
# as having no blockers, and the caller must be able to tell the difference.

set -uo pipefail

if ! command -v gh > /dev/null 2>&1; then
  echo "gh is not installed, so open defects could not be listed." >&2
  exit 1
fi

if ! out="$(gh issue list --state open --label bug --limit 100 \
              --json number,title \
              --template '{{range .}}#{{.number}} {{.title}}{{"\n"}}{{end}}' 2>&1)"; then
  echo "Could not read the issue tracker — $out" >&2
  exit 1
fi

printf '%s' "$out"
