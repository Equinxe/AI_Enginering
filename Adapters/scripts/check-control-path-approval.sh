#!/usr/bin/env bash
# IA Engineering — check-control-path-approval.sh
#
# The decision of the Control Path Guard
# (Adapters/github-actions/control-path-guard.yml): does this Pull Request
# event pass, given the files the PR changes and who applied which label?
# Exit 0 to pass, non-zero to fail. Every verdict prints the message the
# workflow printed when this logic was inline shell in it (WU-IAENG-361).
#
# EXIT CODES (Standards/CODE_QUALITY_STANDARD.md, The Check Convention, Shell
# Scripts rule 1). The workflow fails on any non-zero code; the two below tell
# a reader which kind of failure it was.
#   0  pass: no control path is touched, or the Director's approval is the
#      event being judged (step 8)
#   1  a finding: control paths are touched and this event is not the
#      Director's approval (step 8)
#   2  could not evaluate: steps 1 to 7, and any command that failed (`gh`,
#      `jq`, the matcher). Nothing about the PR was established.
#
# WHY A SCRIPT. While it was `run:` shell in the workflow it was not linted and
# could only be exercised by deploying it (Adapters/README.md, the
# scripts/tests/run.sh row). Here shellcheck reads it and
# Adapters/scripts/tests/run.sh runs it against a stubbed `gh`.
#
# TRUST MODEL - UNCHANGED BY THE EXTRACTION. The workflow runs on
# pull_request_target and executes this file from the BASE checkout, beside
# check-control-paths.sh, never from the PR head. A PR that edits this file is
# judged by the base's copy, and Adapters/scripts/ is a control path, so the
# edit is itself flagged. It never checks out, reads or runs PR code: it reads
# the PR through the API, and file names and labels are data only.
#
# INPUTS, all from the environment (the workflow's `env:` block). Untrusted
# values reach this script only this way, never through ${{ }} in shell.
#
#   REPO            owner/name
#   PR_NUMBER       the pull request number
#   CHANGED_FILES   the event's pull_request.changed_files (an integer)
#   ACTION          the event action (opened, synchronize, labeled, ...)
#   LABEL_ADDED     the label of a labeled/unlabeled event, else empty
#   SENDER          the login that caused the event
#   DIRECTOR_LOGIN  vars.IAENG_DIRECTOR_LOGIN; empty or unset fails closed
#   EVENT_HEAD      the event's pull_request.head.sha
#   LABELS_JSON     JSON array of the PR's label names on the event
#   APPROVAL_LABEL  the approval label, control-change/approved
#   GH_TOKEN        read by gh; read-only (contents, pull-requests)
#
# THE DECISION, in order; the first that applies is the verdict:
#   1. CHANGED_FILES is not an integer, or REPO, PR_NUMBER or APPROVAL_LABEL is
#      empty: fail closed, exit 2 (the only messages the inline version did not
#      have; a GitHub event always carries them, so no real run reaches them).
#   2. 3000 changed files or more: the API cannot list them all; exit 2.
#   3. EVENT_HEAD is not a full SHA: exit 2.
#   4. The PR head, read from the API, differs from EVENT_HEAD before the
#      listing, or after it: exit 2 - a listing is meaningful for one commit
#      only.
#   5. The number of files listed differs from CHANGED_FILES: exit 2.
#   6. check-control-paths.sh -z on every filename and previous_filename:
#      exit 0 passes; any exit but 0 or 1 fails closed, exit 2.
#   7. Control paths are touched and DIRECTOR_LOGIN is empty: exit 2, no
#      approval can be recognised.
#   8. Pass only when this event IS the Director applying the approval label:
#      ACTION=labeled, LABEL_ADDED=APPROVAL_LABEL, SENDER=DIRECTOR_LOGIN, and
#      the label is on the PR. Any other event - a push, any other label added
#      or removed - is judged without the label, so the approval is the LAST
#      event on this head or it is void: exit 1.
#
# BACKWARD COMPATIBILITY IS A CONSTRAINT. GitHub runs a pull_request_target
# workflow from the DEFAULT branch, while this script is checked out at the
# PR's base SHA, so the two can be different versions. The interface - the
# environment names above, exit 0 to pass and non-zero to fail - must keep
# working in both directions across releases. A base that predates this script
# fails closed in the workflow's locate step.
#
# `set -e` is kept from the inline version on purpose, as the backstop the
# Check Convention's Shell Scripts rule 2 allows: any command whose failure is
# not tested explicitly below stops the run, and the ERR trap turns that stop
# into exit 2, so a failing command can never read as the finding's 1. The
# `gh` and `jq` calls are tested explicitly as well, to say which one failed.

set -euo pipefail
trap 'echo "::error::A command failed (exit $?) before the guard could judge this event. Failing closed."; exit 2' ERR

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DIRECTOR_LOGIN="${DIRECTOR_LOGIN:-}"
ACTION="${ACTION:-}"
LABEL_ADDED="${LABEL_ADDED:-}"
SENDER="${SENDER:-}"
EVENT_HEAD="${EVENT_HEAD:-}"
LABELS_JSON="${LABELS_JSON:-[]}"

# 1. Inputs the decision cannot be drawn without. `[ x -ge 3000 ]` on a
# non-integer is an error, and inside `if` an error reads as false: the size
# and count guards below would be skipped, not failed.
for var in REPO PR_NUMBER APPROVAL_LABEL; do
  if [ -z "${!var:-}" ]; then
    echo "::error::$var is not set; the guard cannot judge this event. Failing closed."
    exit 2
  fi
done
if ! printf '%s' "${CHANGED_FILES:-}" | grep -qE '^[0-9]+$'; then
  echo "::error::CHANGED_FILES is not a file count; the guard cannot judge this event. Failing closed."
  exit 2
fi

if ! tmp="$(mktemp -d)"; then
  echo "::error::Could not create a scratch directory; the guard cannot judge this event. Failing closed."
  exit 2
fi
trap 'rm -rf "$tmp"' EXIT

# 2. The files endpoint lists at most 3000 files. A PR at or past that
# cannot be fully listed, and a partial list is not a clean bill.
if [ "$CHANGED_FILES" -ge 3000 ]; then
  echo "::error::This PR changes $CHANGED_FILES files; the API lists at most 3000, so it cannot be checked for control paths. Split it, or the Director reviews it by hand and applies '$APPROVAL_LABEL'."
  exit 2
fi

# 3-4. The event's head SHA must be a full SHA and must still be the PR's
# head before AND after the listing: an approval and a listing are
# only meaningful for one commit.
if ! printf '%s' "$EVENT_HEAD" | grep -qE '^[0-9a-f]{40}$'; then
  echo "::error::The event carries no valid head SHA. Failing closed."
  exit 2
fi
if ! head_before="$(gh api "repos/$REPO/pulls/$PR_NUMBER" --jq .head.sha)"; then
  echo "::error::The API did not return the PR head. Failing closed."
  exit 2
fi
if [ "$head_before" != "$EVENT_HEAD" ]; then
  echo "::error::The PR head moved since this event ($EVENT_HEAD -> $head_before). Failing closed; a newer event will re-run the guard."
  exit 2
fi

if ! gh api "repos/$REPO/pulls/$PR_NUMBER/files" --paginate > "$tmp/files.json"; then
  echo "::error::The API did not list the PR's files. Failing closed."
  exit 2
fi

if ! head_after="$(gh api "repos/$REPO/pulls/$PR_NUMBER" --jq .head.sha)"; then
  echo "::error::The API did not return the PR head after the listing. Failing closed."
  exit 2
fi
if [ "$head_after" != "$EVENT_HEAD" ]; then
  echo "::error::The PR head moved while its files were being listed ($EVENT_HEAD -> $head_after). Failing closed."
  exit 2
fi

# 5. Guard against a truncated or short listing (fail closed).
if ! listed="$(jq -s 'map(length) | add // 0' "$tmp/files.json")"; then
  echo "::error::The file listing could not be read as JSON. Failing closed."
  exit 2
fi
if [ "$listed" -ne "$CHANGED_FILES" ]; then
  echo "::error::The API listed $listed files but the PR reports $CHANGED_FILES. Refusing to guess."
  exit 2
fi

# 6. NUL-delimited: a name may hold a newline. Both sides of a rename are
# listed, so moving a file OUT of a control path is caught too.
if ! jq -j '.[] | (.filename, (.previous_filename // empty)) | . + "\u0000"' \
  "$tmp/files.json" > "$tmp/paths.z"; then
  echo "::error::The file names could not be read from the listing. Failing closed."
  exit 2
fi

# Its exit code is a verdict to read, not a failure: `|| rc=$?` keeps it from
# both `set -e` and the ERR trap, which `set +e` alone would not.
rc=0
"$SCRIPT_DIR/check-control-paths.sh" -z < "$tmp/paths.z" > "$tmp/report.txt" || rc=$?
# The report holds file names; print it as data, not as workflow commands.
sed 's/::/: :/g' "$tmp/report.txt"

if [ "$rc" -eq 0 ]; then
  echo "No control path is touched."
  exit 0
fi
if [ "$rc" -ne 1 ]; then
  echo "::error::check-control-paths.sh failed (exit $rc). Failing closed."
  exit 2
fi

# 7.
if [ -z "$DIRECTOR_LOGIN" ]; then
  echo "::error::This PR touches control paths (listed above), and the repository variable IAENG_DIRECTOR_LOGIN is not set, so no approval can be recognised. The Director sets it to their login. Failing closed."
  exit 2
fi

# 8.
approved=false
if [ "$ACTION" = "labeled" ] && [ "$LABEL_ADDED" = "$APPROVAL_LABEL" ] \
   && [ "$SENDER" = "$DIRECTOR_LOGIN" ] \
   && printf '%s' "$LABELS_JSON" | jq -e --arg l "$APPROVAL_LABEL" 'index($l) != null' > /dev/null; then
  approved=true
fi

if [ "$approved" = true ]; then
  echo "::notice::Control paths are touched and the Director ($DIRECTOR_LOGIN) has just applied '$APPROVAL_LABEL' to this head. Passing."
  exit 0
fi
echo "::error::This PR touches control paths (listed above): files that define the checks it is judged by. It needs '$APPROVAL_LABEL' applied by the Director ($DIRECTOR_LOGIN) as the LAST event on this head; any later label change or push voids it (remove and re-add the label)."
exit 1
