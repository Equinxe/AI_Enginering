#!/usr/bin/env bash
# IA Engineering — hosts/github/ci-conclusion.sh
#
# Prints the conclusion of the most recent completed CI run on a branch:
# `success`, or whatever GitHub called the failure. Nothing else on stdout.
#
# See Adapters/scripts/hosts/README.md for the contract. This FETCHES ONLY:
# whether a non-success conclusion blocks a release is Workflows/RELEASE.md
# Step 1's rule, and it lives in release.sh, the same for every forge.
#
# USAGE
#
#   ci-conclusion.sh <branch>
#
# Exit 0 with the conclusion on stdout; 1 when it could not be established.
# NO RUNS AT ALL IS EXIT 1, not an empty success. A branch CI has never seen
# has not passed — it has not been tested, and reporting that as green is the
# defect class this framework catalogues everywhere else.

set -uo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <branch>" >&2
  exit 1
fi

BRANCH="$1"

if ! command -v gh > /dev/null 2>&1; then
  echo "gh is not installed, so the CI conclusion could not be read. Install the GitHub CLI, or declare .ia-engineering/host as 'none' and verify CI by hand." >&2
  exit 1
fi

if ! runs="$(gh run list --branch "$BRANCH" --limit 1 --json conclusion,status 2>&1)"; then
  echo "Could not read CI runs for '$BRANCH' — $runs" >&2
  exit 1
fi

conclusion="$(printf '%s' "$runs" | grep -o '"conclusion":"[^"]*"' | head -1 | sed 's/.*:"//; s/"$//')"
status="$(printf '%s' "$runs" | grep -o '"status":"[^"]*"' | head -1 | sed 's/.*:"//; s/"$//')"

if [ -z "$status" ]; then
  echo "No CI runs found for '$BRANCH'. A branch CI has never seen has not passed; it has not been tested." >&2
  exit 1
fi

# A run still going is not a conclusion. Reporting the previous run's verdict,
# or an empty one, would answer a question about a different commit.
if [ "$status" != "completed" ]; then
  echo "The latest CI run on '$BRANCH' is '$status', not completed. There is no conclusion to report yet." >&2
  exit 1
fi

if [ -z "$conclusion" ]; then
  echo "The latest CI run on '$BRANCH' reports status 'completed' with no conclusion, which should not happen. Failing rather than inventing one." >&2
  exit 1
fi

printf '%s\n' "$conclusion"
