#!/usr/bin/env bash
# IA Engineering — check-work-units.sh
#
# Every non-merge commit in a range carries exactly one `Work Unit:` line at
# column 0, and the ID it names is registered in Registry/work-units.yml. A
# merge commit is held to the same rule only when it AUTHORS content (its tree
# differs from the automatic merge of its parents, or it has more than two
# parents); a clean merge needs no trailer, but a `Work Unit:` line present on
# any merge is validated regardless. Historical authored merges are
# grandfathered by sha in a constant inside this script (GRANDFATHERED_MERGES).
# Classifying needs git >= 2.40 (`git merge-tree --write-tree` with
# --attr-source); without it, or when a merge cannot be classified, the check
# fails closed. The classifier is merge-classify.sh, sourced from beside this
# script and shared with check-employee-trailers.sh, so the script must run
# from its real location: a copy or symlink without the helper beside it
# fails closed.
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
# Exit codes (Standards/CODE_QUALITY_STANDARD.md, The Check Convention, Shell
# Scripts rule 1):
#   0  every commit, and every authored merge, claims one registered Work Unit
#   1  a finding: a commit or authored merge with no claim, more than one, a
#      malformed one, or one the registry does not hold
#   2  could not evaluate, or a usage error: merge-classify.sh missing, no
#      registry or one that yields no ids, `git rev-list` failed, git too old
#      to classify merges, or a merge that could not be classified. A finding
#      elsewhere in the range does not lower it to 1: what was not evaluated
#      is reported as such.
# A range with no non-merge commits and only clean merges is a pass and says
# so — a back-merge carries no authored commits to attribute.
#
# The registry is searched at $IAENG_REGISTRY_WORK_UNITS, then
# Registry/work-units.yml relative to the working directory: this repository's
# own when run from the framework, the PROJECT's when run from a project that
# imported the framework (as ia-engineering/). The framework's registry is
# never read on behalf of a project (WU-IAENG-320). $IAENG_REGISTRY_WORK_UNITS,
# when it names an existing file, overrides that consumer rule: it is an
# explicit choice by the caller, and is read whatever it is. A registry it
# cannot find is a failure, not a pass: a project that
# has not adopted the Work Unit registry should remove the check rather than
# have it report success without checking anything (Adapters/README.md, The
# Check Convention, rule 1).

set -uo pipefail

# The merge classifier is shared with check-employee-trailers.sh. It sits beside
# this script, so BASH_SOURCE resolves it wherever the framework is checked out.
# A missing helper is a failure: continuing without it would pass every
# authored merge. `CDPATH=` keeps an exported CDPATH from redirecting the cd
# (and from printing the directory into the captured value).
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/merge-classify.sh" ]; then
  echo "check-work-units: ERROR: $SCRIPT_DIR/merge-classify.sh not found; failing closed." >&2
  exit 2
fi
# shellcheck source=merge-classify.sh
. "$SCRIPT_DIR/merge-classify.sh"

# Host-specific output. GitHub Actions renders `::error::` as an annotation on
# the Pull Request; every other host shows it as noise. The prefix is therefore
# applied only where it means something.
#
# This helper is repeated in each sibling check script rather than sourced
# from a shared file. Sourcing itself is not the obstacle: a sibling resolved
# through BASH_SOURCE, as merge-classify.sh is above, works wherever the
# framework is checked out and fails closed when missing. `err` stays
# duplicated because it differs per script (each prefixes its own name), and
# most check-*.sh scripts source nothing — making all of them depend on a
# shared file to save five lines would add a failure mode to every check for
# no gain in what any of them enforces.
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

# Whose registry is read. The Work Units a project executes are the PROJECT's;
# the framework's Registry/work-units.yml lists the framework's own. They are
# different sets, and reading the framework's from a consumer is wrong both
# ways (DEF-1 of the 2 Oct 2026 adoption test, issue #181): the adopter's own
# first Work Unit is "not found", and a commit claiming a framework id such as
# WU-IAENG-137 resolves although the project never performed it.
#
# So the framework's copy is never a candidate. In the framework repository
# the working directory IS the framework, and Registry/work-units.yml there is
# its own; in a consumer it is the project's file, at the same relative path.
# Whether this is a consumer is decided by identity (-ef: device and inode),
# not by comparing path spellings, for the reason install.sh gives.
FRAMEWORK_ROOT="$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)"
if [ "$FRAMEWORK_ROOT" -ef . ]; then
  CONSUMER=0
else
  CONSUMER=1
fi

REGISTRY=""
for candidate in \
  "${IAENG_REGISTRY_WORK_UNITS:-}" \
  "Registry/work-units.yml"
do
  if [ -n "$candidate" ] && [ -f "$candidate" ]; then
    REGISTRY="$candidate"
    break
  fi
done

if [ -z "$REGISTRY" ]; then
  if [ "$CONSUMER" -eq 1 ]; then
    err "This project has no Work Unit registry. Create Registry/work-units.yml at the project root (setup-project-bootstrap.sh writes a starter) and register each Work Unit in the commit that performs it. The framework's own ia-engineering/Registry/work-units.yml is deliberately NOT read: it lists the framework's Work Units, not this project's. A project that does not want the check should remove it rather than have it pass without checking anything."
  else
    err "Could not locate Registry/work-units.yml (looked at \$IAENG_REGISTRY_WORK_UNITS and Registry/). A project that has not adopted the Work Unit registry should remove this check rather than have it pass without checking anything."
  fi
  exit 2
fi

echo "Registry: $REGISTRY"

# A carriage return is removed only where it ends a line (a CRLF checkout),
# never every one: one inside an id is data, and deleting it would register an
# id YAML does not read (Standards/CODE_QUALITY_STANDARD.md, The Check
# Convention, Shell Scripts rule 3; WU-IAENG-389, issue #325).
KNOWN="$(grep -E '^  - id: ' "$REGISTRY" | sed $'s/^  - id: //; s/\r$//')"
KNOWN_COUNT="$(printf '%s\n' "$KNOWN" | grep -c . || true)"
echo "Registered Work Units: $KNOWN_COUNT"

# A registry that parses to nothing is a parsing failure, not an empty project.
# Every commit would then fail with an unhelpful message about an unregistered
# ID, when the real fault is the field shape the parser expects.
#
# The exception is a registry that declares an empty list (`work_units: []` or
# a bare `work_units:` key, as the bootstrap's starter does): that is a project
# which has registered nothing yet, and every commit then fails with the true
# reason, that its Work Unit is unregistered.
if [ "$KNOWN_COUNT" -eq 0 ] \
   && { ! grep -qE '^work_units:[[:space:]]*(\[\])?[[:space:]]*$' "$REGISTRY" \
        || grep -qE '^[[:space:]]*-[[:space:]]*id:' "$REGISTRY"; }; then
  err "$REGISTRY yielded no Work Unit IDs. The parsing contract is a line of the exact form '  - id: <WU-ID>' (two spaces, dash, space). Failing rather than reporting every commit unregistered, which would describe the parser and not the commits."
  exit 2
fi

if ! COMMITS="$(git rev-list --no-merges "${BASE_REF}..${HEAD_REF}")"; then
  err "git rev-list failed over ${BASE_REF}..${HEAD_REF}. No commit was examined, so nothing was established; failing rather than reporting zero problems."
  exit 2
fi

# Merge commits are classified, not skipped: a merge that AUTHORS content (its
# tree differs from the automatic merge of its parents, or it has more than two
# parents) is held to the same rule as any commit. A clean merge needs no
# trailer. PT2-03 of the 1 Oct 2026 exercise: with `--no-merges` alone, an
# authored merge adding content carried no Work Unit and passed.
if ! MERGES="$(git rev-list --merges "${BASE_REF}..${HEAD_REF}")"; then
  err "git rev-list --merges failed over ${BASE_REF}..${HEAD_REF}; failing rather than skipping merges unexamined."
  exit 2
fi

fail=0
# Set when a merge could not be classified: the run then exits 2, whatever
# else it found (the header's exit codes).
unevaluated=0

# Historical authored merges without a Work Unit are grandfathered by sha in
# the constant below. It lives in THIS script, not in a data file, on purpose:
# the required check runs from the PR's own tree, so a data file could be
# edited by the very PR it is meant to judge (SEC-IAENG-307-01). Exempting a
# merge means editing the check's source, which is what review of a control
# change is for. The list is closed: never add a new merge.
# Found by running this check over v0.0.13..origin/develop (WU-IAENG-313). The
# first two are the merges check-employee-trailers.sh grandfathers, for the
# same reason: they predate the rule and carry neither trailer. The third is
# grandfathered here only, because its Employee claim is valid; its Work Unit
# claim is not, and the any-merge claim validation (SEC-IAENG-313-02) would
# otherwise refuse it. A grandfathered merge is skipped entirely, claim
# included: it is history, not a claim this check vouches for.
#   3babf69d... merge of origin/develop into feat/commit-type-perf
#   93c850a7... merge of origin/develop into perf/generate-agents-single-pass
#   d097e2ed... v0.0.13 back-merge (11 Sep 2026) carries a cosmetic Work Unit: WU-IAENG-259 that was never registered; Registry forbids historical backfill
readonly GRANDFATHERED_MERGES="3babf69d9664ddb590acd7381a99fa90d1e40f70 93c850a754a26a050b621d52ac1881645d21be5f d097e2ed66e3e2c45454725664b20abd94b07968"

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
    # Line-end carriage return only (rule 3, above): one inside the value
    # stays, and the shape test below refuses it.
    WU="${wu_line#Work Unit: }"
    WU="${WU%$'\r'}"
    # An empty or malformed claim never resolves. With an empty registry (the
    # bootstrap's starter) KNOWN is empty, and `grep -qxF ""` matches the
    # here-string's single empty line, so a bare `Work Unit: ` line passed
    # (SEC-IAENG-320-01). The shape is Templates/WORK_UNIT.md's
    # `WU-<project>-<number>`, the same one PR Compliance matches.
    if ! [[ "$WU" =~ ^WU-[A-Za-z0-9]+-[0-9]+$ ]]; then
      err "$what $sha has a 'Work Unit:' line whose value '$WU' is empty or not a Work Unit id. The form is WU-<project>-<number> (Templates/WORK_UNIT.md), for example WU-SHOP-042."
      fail=1
      continue
    fi
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
# check-employee-trailers.sh), built on `git merge-tree --write-tree` with
# --attr-source pinned (git >= 2.40). If it cannot run the merge is
# unclassified and the check FAILS: passing on an unclassifiable merge is the
# check-that-passes-without-evaluating shape.
#
# A `Work Unit:` line at column 0 that IS present on any merge is validated
# whatever the classification (SEC-IAENG-313-02), as check-employee-trailers.sh
# validates any Employee line present: a claim in the history is read
# downstream, so an unregistered one is a defect even on a merge that needed
# none.
if [ -n "$MERGES" ]; then
  echo "Merge commits to classify: $(printf '%s\n' "$MERGES" | grep -c .)"

  if ! merge_classify_git_ok; then
    err "git $(git version) cannot classify merge commits: 'git merge-tree --write-tree' with --attr-source needs git 2.40 or newer. Failing closed rather than passing merges unclassified."
    exit 2
  fi

  for sha in $MERGES; do
    # Exact-sha match against the in-source constant, before anything else: a
    # grandfathered merge is history, so neither its trailer nor its absence is
    # judged.
    if [[ " $GRANDFATHERED_MERGES " == *" $sha "* ]]; then
      echo "  $sha -> merge, grandfathered (GRANDFATHERED_MERGES in this script)"
      continue
    fi

    # here-string, not a pipe into grep -q: see check_commit.
    if grep -qE '^Work Unit: ' <<< "$(git log -1 --format=%B "$sha")"; then
      check_commit "$sha" Merge
      continue
    fi

    KIND="$(merge_classify "$sha")"
    if [ "${KIND#error}" != "$KIND" ]; then
      err "Merge $sha could not be classified (${KIND#error: }). Failing closed rather than passing an unclassified merge."
      unevaluated=1
      continue
    fi

    if [ "$KIND" = clean ]; then
      echo "  $sha -> merge, no content of its own"
    else
      check_commit "$sha" Merge
    fi
  done
fi

[ "$unevaluated" -eq 0 ] || exit 2
exit "$fail"
