#!/usr/bin/env bash
# IA Engineering — check-work-units.sh
#
# Every non-merge commit in a range carries exactly one `Work Unit:` line at
# column 0, and the ID it names is registered in Registry/work-units.yml. A
# merge commit is held to the same rule only when it AUTHORS content (its tree
# differs from the automatic merge of its parents, or it has more than two
# parents); a clean merge needs no trailer. Historical authored merges are
# grandfathered by sha in a constant inside this script (GRANDFATHERED_MERGES).
# Classifying needs git >= 2.38 (`git merge-tree --write-tree`); without it,
# or when a merge cannot be classified, the check fails closed. The classifier
# is merge-classify.sh, sourced from beside this script and shared with
# check-employee-trailers.sh.
#
# WHY THIS IS A SCRIPT AND NOT A CI JOB BODY
#
# It used to live inline in Adapters/github-actions/pr-validation.yml, as one
# of 262 lines of shell embedded in that file. Three costs came with that, and
# the middle one is the reason this file exists:
#
#   1. It only ran on GitHub. Any other host — GitLab, Jenkins, Drone, a
#      self-hosted runner — had no way to invoke it without copying the logic.
#
#   2. IT COULD ONLY BE TESTED BY DEPLOYING IT. Verifying a change meant
#      pushing a branch and reading a log. That is what let a defect sit in the
#      sibling `pr-size` job until it deadlocked a release: the job refused
#      every Pull Request with an empty diff, which is correct for wrong refs
#      and wrong for a back-merge, and nobody could see the difference without
#      constructing a back-merge in production. Diagnosing it required
#      extracting the `run:` block out of the YAML with a separate program in
#      order to run it at all. A logic that cannot be tested without deploying
#      it is a logic that does not get tested.
#
#   3. An adopting project could not run it before pushing.
#
# The checks it performs are unchanged. Only their location is.
#
# USAGE
#
#   check-work-units.sh <base-ref> <head-ref>
#
# Exit 0 when every commit (and every authored merge) resolves, 1 when any does
# not, when a merge cannot be classified, or when the registry cannot be found.
# A range with no non-merge commits and only clean merges is a pass and says
# so — a back-merge carries no authored commits to attribute.
#
# The registry is searched at $IAENG_REGISTRY_WORK_UNITS, then
# Registry/work-units.yml, then ia-engineering/Registry/work-units.yml, so the
# script works both in this repository and in a project that imported it as a
# submodule. A registry it cannot find is a failure, not a pass: a project that
# has not adopted the Work Unit registry should remove the check rather than
# have it report success without checking anything (Adapters/README.md, The
# Check Convention, rule 1).

set -uo pipefail

# The merge classifier is shared with check-employee-trailers.sh. It sits beside
# this script, so BASH_SOURCE resolves it wherever the framework is checked out.
# A missing helper is a failure: continuing without it would pass every
# authored merge.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/merge-classify.sh" ]; then
  echo "check-work-units: ERROR: $SCRIPT_DIR/merge-classify.sh not found; failing closed." >&2
  exit 1
fi
# shellcheck source=merge-classify.sh
. "$SCRIPT_DIR/merge-classify.sh"

# Host-specific output. GitHub Actions renders `::error::` as an annotation on
# the Pull Request; every other host shows it as noise. The prefix is therefore
# applied only where it means something.
#
# This helper is repeated verbatim in the sibling check scripts rather than
# sourced from a shared file. That is deliberate: these scripts are invoked
# from a consumer project where the framework sits at an arbitrary path, and a
# `source` would need that path resolved correctly in every host's working
# directory. Five duplicated lines cost less than a sourcing bug that only
# appears in somebody else's repository.
err() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error::%s\n' "$1" >&2
  else
    printf 'check-work-units: ERROR: %s\n' "$1" >&2
  fi
}

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <base-ref> <head-ref>" >&2
  echo "  Checks every non-merge commit, and every authored merge, in <base-ref>..<head-ref>." >&2
  exit 2
fi

BASE_REF="$1"
HEAD_REF="$2"

REGISTRY=""
for candidate in \
  "${IAENG_REGISTRY_WORK_UNITS:-}" \
  "Registry/work-units.yml" \
  "ia-engineering/Registry/work-units.yml"
do
  if [ -n "$candidate" ] && [ -f "$candidate" ]; then
    REGISTRY="$candidate"
    break
  fi
done

if [ -z "$REGISTRY" ]; then
  err "Could not locate Registry/work-units.yml (looked at \$IAENG_REGISTRY_WORK_UNITS, Registry/, ia-engineering/Registry/). A project that has not adopted the Work Unit registry should remove this check rather than have it pass without checking anything."
  exit 1
fi

echo "Registry: $REGISTRY"

KNOWN="$(grep -E '^  - id: ' "$REGISTRY" | sed 's/^  - id: //' | tr -d '\r')"
KNOWN_COUNT="$(printf '%s\n' "$KNOWN" | grep -c . || true)"
echo "Registered Work Units: $KNOWN_COUNT"

# A registry that parses to nothing is a parsing failure, not an empty project.
# Every commit would then fail with an unhelpful message about an unregistered
# ID, when the real fault is the field shape the parser expects.
if [ "$KNOWN_COUNT" -eq 0 ]; then
  err "$REGISTRY yielded no Work Unit IDs. The parsing contract is a line of the exact form '  - id: <WU-ID>' (two spaces, dash, space). Failing rather than reporting every commit unregistered, which would describe the parser and not the commits."
  exit 1
fi

if ! COMMITS="$(git rev-list --no-merges "${BASE_REF}..${HEAD_REF}")"; then
  err "git rev-list failed over ${BASE_REF}..${HEAD_REF}. No commit was examined, so nothing was established; failing rather than reporting zero problems."
  exit 1
fi

# Merge commits are classified, not skipped: a merge that AUTHORS content (its
# tree differs from the automatic merge of its parents, or it has more than two
# parents) is held to the same rule as any commit. A clean merge needs no
# trailer. PT2-03 of the 1 Oct 2026 exercise: with `--no-merges` alone, an
# authored merge adding content carried no Work Unit and passed.
if ! MERGES="$(git rev-list --merges "${BASE_REF}..${HEAD_REF}")"; then
  err "git rev-list --merges failed over ${BASE_REF}..${HEAD_REF}; failing rather than skipping merges unexamined."
  exit 1
fi

fail=0

# Historical authored merges without a Work Unit are grandfathered by sha in
# the constant below. It lives in THIS script, not in a data file, on purpose:
# the required check runs from the PR's own tree, so a data file could be
# edited by the very PR it is meant to judge (SEC-IAENG-307-01). Exempting a
# merge means editing the check's source, which is what review of a control
# change is for. The list is closed: never add a new merge.
# Found by running this check over v0.0.13..origin/develop (WU-IAENG-313); they
# are the same two merges check-employee-trailers.sh grandfathers, and for the
# same reason: they predate the rule and carry neither trailer.
#   3babf69d... merge of origin/develop into feat/commit-type-perf
#   93c850a7... merge of origin/develop into perf/generate-agents-single-pass
readonly GRANDFATHERED_MERGES="3babf69d9664ddb590acd7381a99fa90d1e40f70 93c850a754a26a050b621d52ac1881645d21be5f"

# check_commit <sha> <what>
# Exactly one `Work Unit:` line at column 0, naming a registered ID. Sets
# fail=1 on any defect. <what> is "Commit" or "Merge" for the messages.
check_commit() {
  local sha="$1" what="$2" WU_LINES WU_COUNT wu_line WU
  WU_LINES="$(git log -1 --format=%B "$sha" | grep -E '^Work Unit: ' || true)"

  if [ -z "$WU_LINES" ]; then
    err "$what $sha carries no 'Work Unit: <WU-ID>' trailer. Per CLAUDE.md one Work Unit is one commit, and per Templates/WORK_UNIT.md every change must trace to a Work Unit. A Work Unit ID in the Pull Request description does not substitute: a description can be reworded after review, a trailer cannot."
    fail=1
    return 0
  fi

  WU_COUNT="$(printf '%s\n' "$WU_LINES" | grep -c . || true)"
  if [ "$WU_COUNT" -gt 1 ]; then
    err "$what $sha carries $WU_COUNT 'Work Unit:' lines at column 0. One Work Unit is one commit (Standards/COMMIT_STANDARD.md), and downstream readers rely on there being exactly one. If one is an EXAMPLE quoted in the body — a deferral note, a reference to earlier work — indent it so it does not start at column 0."
    fail=1
    return 0
  fi

  while IFS= read -r wu_line; do
    [ -n "$wu_line" ] || continue
    WU="$(printf '%s' "${wu_line#Work Unit: }" | tr -d '\r')"
    # here-string, not `printf | grep -q`: a long-lived project's Work Unit
    # registry can exceed the pipe buffer, and grep -q short-circuiting it would
    # SIGPIPE the producer — pipefail returns that, and a registered Work Unit
    # reads as unregistered. TROUBLESHOOTING X.
    if grep -qxF "$WU" <<< "$KNOWN"; then
      echo "  $sha -> $WU (resolved)"
    else
      err "$what $sha claims '$WU', which is not in $REGISTRY. Either it is a typo, or the Work Unit was never registered. Register it in the same commit that performs the work — see the registry's own header for the field shape. If this line is an EXAMPLE quoted in the message body, indent it so it does not start at column 0."
      fail=1
    fi
  done < <(printf '%s\n' "$WU_LINES")
}

if [ -z "$COMMITS" ]; then
  echo "No non-merge commits to check."
else
  echo "Commits to check: $(printf '%s\n' "$COMMITS" | grep -c .)"
fi

for sha in $COMMITS; do
  check_commit "$sha" Commit
done

# --- Merge commits ---------------------------------------------------------
# The classifier is merge-classify.sh (sourced; shared with
# check-employee-trailers.sh), built on `git merge-tree --write-tree` (git >=
# 2.38). If it cannot run the merge is unclassified and the check FAILS:
# passing on an unclassifiable merge is the check-that-passes-without-
# evaluating shape.
if [ -n "$MERGES" ]; then
  echo "Merge commits to classify: $(printf '%s\n' "$MERGES" | grep -c .)"

  if ! merge_classify_git_ok; then
    err "git $(git version) cannot classify merge commits: 'git merge-tree --write-tree' needs git 2.38 or newer. Failing closed rather than passing merges unclassified."
    exit 1
  fi

  for sha in $MERGES; do
    KIND="$(merge_classify "$sha")"
    if [ "${KIND#error}" != "$KIND" ]; then
      err "Merge $sha could not be classified (${KIND#error: }). Failing closed rather than passing an unclassified merge."
      fail=1
      continue
    fi

    if [ "$KIND" = clean ]; then
      echo "  $sha -> merge, no content of its own"
    elif [[ " $GRANDFATHERED_MERGES " == *" $sha "* ]]; then
      echo "  $sha -> authored merge, grandfathered (GRANDFATHERED_MERGES in this script)"
    else
      check_commit "$sha" Merge
    fi
  done
fi

exit "$fail"
