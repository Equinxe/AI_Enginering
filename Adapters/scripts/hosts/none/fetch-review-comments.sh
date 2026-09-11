#!/usr/bin/env bash
# IA Engineering — hosts/none/fetch-review-comments.sh
#
# This host has no conversation to read. See Adapters/scripts/hosts/README.md.
#
# EXIT 3 — PARTIAL — and the code is the whole point. It creates the output
# directory, empty, and reports that nothing could be read. The caller then
# passes --fetch-incomplete, so check-review-recorded.sh says "nothing was
# established either way" rather than "no decision was recorded".
#
# Exiting 1 would look like a broken pipeline; exiting 0 with an empty
# directory would assert that the change set has no recorded review, which is
# a claim this host is in no position to make.

set -uo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <repo> <change-id> <out-dir>" >&2
  exit 1
fi

OUT_DIR="$3"
if ! mkdir -p "$OUT_DIR"; then
  echo "Could not create $OUT_DIR." >&2
  exit 1
fi

echo "host 'none' cannot read review comments; $OUT_DIR left empty." >&2
echo "  The absence of a recorded decision here means nothing was read, not" >&2
echo "  that nothing was recorded. Confirm the Code Reviewer's decision by" >&2
echo "  hand — Workflows/CODE_REVIEW.md." >&2
exit 3
