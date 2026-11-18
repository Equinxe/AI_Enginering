#!/usr/bin/env bash
# IA Engineering — check-pr-size.sh
#
# A change set stays within the review limit: additions plus deletions across
# the files a reviewer must actually READ (Standards/PULL_REQUEST_STANDARD.md,
# Reviewability).
#
# WHY THE LIMIT EXISTS
#
# A review is a reading. Past a certain size it becomes a skim, and a skim that
# approves what it did not read is worth less than no approval, because it is
# trusted. Excluded from the count:
#
#   - files marked `linguist-generated` in .gitattributes, which is the hosting
#     platform's own convention for "collapsed in the diff view because no
#     human reads it" — lockfiles, snapshots, built assets, generated clients.
#     Declared in a committed file, so the exclusion list is itself reviewed;
#   - binary files, which have no line count.
#
# THIS FILE EXISTS BECAUSE THE LOGIC WAS UNTESTABLE WHERE IT LIVED
#
# It was 90-odd lines inside Adapters/github-actions/pr-validation.yml. Two
# defects reached production there, and neither was findable by reading:
#
#   The loop was fed by process substitution, which hid `git diff`'s failure
#   from `set -euo pipefail`. With an unfetchable base SHA the loop saw no
#   input, counted zero lines, and this REQUIRED check printed "Within the
#   review limit" and exited 0 (WU-IAENG-198).
#
#   It then refused every change set whose diff listed no files. That is right
#   when the refs are wrong and wrong for a back-merge, which changes no files
#   by construction — so this check and Workflows/RELEASE.md Step 8 deadlocked
#   the v0.0.12 release against each other (WU-IAENG-220). Diagnosing it
#   required writing a separate program to lift the `run:` block out of the
#   YAML so it could be executed at all.
#
# Both are pinned as cases in Adapters/scripts/tests/run.sh now.
#
# USAGE
#
#   check-pr-size.sh <base-ref> <head-ref>
#
#   IAENG_PR_LIMIT    review limit in lines (default 1500)
#   IAENG_PR_LABELS   comma-separated labels on the change set, supplied by the
#                     host adapter. `size/approved` among them is the Director's
#                     override.
#
# THE OVERRIDE IS A LABEL, NOT TEXT. Applying a label requires write permission
# on the repository; pasting a sentence into a description requires nothing.
# A host with no label concept simply supplies none, and the override is then
# unavailable — the change set must be split. That is a real reduction in what
# the check can offer off-platform, and it is stated rather than papered over
# with a weaker substitute.
#
# EXIT CODES (Standards/CODE_QUALITY_STANDARD.md, The Check Convention, Shell
# Scripts rule 1)
#   0  within the limit, a back-merge, or over it with `size/approved`
#   1  a finding: over the limit without `size/approved`
#   2  could not evaluate, or a usage error: the merge base, `git diff` or
#      `git rev-list` failed, or the diff lists no files while the range holds
#      no commits or a non-merge commit. The size was never measured.

set -uo pipefail

# See check-work-units.sh for why this helper is duplicated rather than sourced.
err() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error::%s\n' "$1" >&2
  else
    printf 'check-pr-size: ERROR: %s\n' "$1" >&2
  fi
}

note() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::notice::%s\n' "$1"
  else
    printf 'check-pr-size: %s\n' "$1"
  fi
}

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <base-ref> <head-ref>" >&2
  echo "  IAENG_PR_LIMIT (default 1500), IAENG_PR_LABELS (comma-separated)." >&2
  exit 2
fi

BASE_REF="$1"
HEAD_REF="$2"
LIMIT="${IAENG_PR_LIMIT:-1500}"
LABELS="${IAENG_PR_LABELS:-}"

# THE RANGE IS THE MERGE BASE, not the base branch tip. A two-dot diff against
# the tip also contains the inverse of commits this change never touched once
# the base branch advances: the count is then wrong in both directions and a
# change set can be blocked by someone else's churn.
if ! MERGE_BASE="$(git merge-base "$BASE_REF" "$HEAD_REF")"; then
  err "Could not compute the merge base of $BASE_REF and $HEAD_REF. The size was therefore never measured; failing rather than reporting a size of zero."
  exit 2
fi

# THE DIFF IS CAPTURED BEFORE IT IS COUNTED, and its failure is fatal. Feeding
# the loop from process substitution hid this failure from `set -euo pipefail`,
# and the check reported success having measured nothing.
#
# --no-renames because `git diff --numstat` writes a rename as `d/{old => new}`,
# which `git check-attr` reads literally and reports as unspecified — a renamed
# generated file was counted as reviewable. The add/delete counts it produces
# instead are also the ones a reviewer actually reads.
if ! NUMSTAT="$(git diff --numstat --no-renames "$MERGE_BASE" "$HEAD_REF")"; then
  err "git diff failed between $MERGE_BASE and $HEAD_REF. The size was never measured; failing rather than reporting a size of zero."
  exit 2
fi

TOTAL=0; FILES=0; GENERATED=0; BINARY=0
while IFS="$(printf '\t')" read -r added deleted path; do
  [ -n "$path" ] || continue
  FILES=$((FILES + 1))
  if [ "$added" = "-" ]; then
    BINARY=$((BINARY + 1)); continue
  fi
  attr="$(git check-attr linguist-generated -- "$path" | sed 's/.*: //')"
  if [ "$attr" = "set" ] || [ "$attr" = "true" ]; then
    GENERATED=$((GENERATED + 1)); continue
  fi
  TOTAL=$((TOTAL + added + deleted))
done <<EOF
$NUMSTAT
EOF

# A DIFF OF ZERO FILES HAS TWO CAUSES AND THEY ARE NOT THE SAME THING.
#
# Wrong refs, a force-push, a cross-fork head the runner could not fetch:
# nothing was measured, and reporting a size of zero would be this codebase's
# own named defect class. That fails.
#
# A back-merge measures zero because there is genuinely nothing to review.
# Workflows/RELEASE.md Step 8 carries the release branch's history back through
# a change set whose only content is a merge commit. It changes no files by
# construction, and refusing it deadlocked the release process against itself.
#
# The two are told apart by the COMMITS, not the files. No commits at all is
# the broken-refs case. All commits being merges is the back-merge. A range
# holding an ordinary commit that changed nothing is neither, and still fails.
if [ "$FILES" -eq 0 ]; then
  if ! RANGE_COMMITS="$(git rev-list --count "$MERGE_BASE..$HEAD_REF")"; then
    err "git rev-list failed over $MERGE_BASE..$HEAD_REF, so the reason for the empty diff was never established. Failing rather than guessing which of the two it was."
    exit 2
  fi
  if ! NONMERGE_COMMITS="$(git rev-list --count --no-merges "$MERGE_BASE..$HEAD_REF")"; then
    err "git rev-list --no-merges failed over $MERGE_BASE..$HEAD_REF, so the reason for the empty diff was never established. Failing rather than guessing which of the two it was."
    exit 2
  fi

  if [ "$RANGE_COMMITS" -eq 0 ]; then
    err "The diff between $MERGE_BASE and $HEAD_REF lists no changed files, and the range holds no commits either. Nothing was measured — check the base and head refs."
    exit 2
  fi
  if [ "$NONMERGE_COMMITS" -gt 0 ]; then
    err "The diff between $MERGE_BASE and $HEAD_REF lists no changed files, yet $NONMERGE_COMMITS of its $RANGE_COMMITS commits are not merges. A non-merge commit that changes nothing is not a back-merge; check the base and head refs, or drop the empty commits."
    exit 2
  fi
  note "No file changes, and the range holds $RANGE_COMMITS commit(s), every one a merge — a back-merge (Workflows/RELEASE.md Step 8). There is nothing for a reviewer to read, so the review limit does not apply."
  exit 0
fi

echo "Merge base: $MERGE_BASE"
echo "Files changed: $FILES ($GENERATED generated, $BINARY binary — excluded)"
echo "Lines to review: $TOTAL (limit $LIMIT)"

if [ "$TOTAL" -le "$LIMIT" ]; then
  echo "Within the review limit."
  exit 0
fi

if grep -qxF 'size/approved' <<< "${LABELS//,/$'\n'}"; then
  note "$TOTAL lines exceed the $LIMIT-line review limit, and the Director has applied 'size/approved'. Passing on that decision — it is recorded by the label's audit trail."
  exit 0
fi

err "This change set is $TOTAL lines outside generated files; the review limit is $LIMIT (Standards/PULL_REQUEST_STANDARD.md, Reviewability). Split it into Work Units that can each be read, or — if the size is genuinely irreducible — the Director applies the 'size/approved' label. Files that no human reads (lockfiles, snapshots, built output) are excluded when marked 'linguist-generated' in .gitattributes."
exit 1
