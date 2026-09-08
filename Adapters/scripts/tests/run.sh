#!/usr/bin/env bash
# IA Engineering — behaviour tests for the portable check scripts.
#
# WHAT THIS EXISTS FOR
#
# The checks under Adapters/scripts/check-*.sh used to be shell embedded in a
# CI workflow file, where the only way to exercise them was to push a branch
# and read a log. That is how a defect survived in the `pr-size` check until it
# deadlocked a release: it refused every Pull Request whose diff listed no
# files, which is right when the refs are wrong and wrong for a back-merge, and
# telling those apart required constructing a back-merge in production.
#
# Every case here builds a REAL git repository and runs the REAL script against
# it. Nothing is mocked and nothing is reimplemented: if a case passes, the
# shipped script did the thing.
#
# ADD A CASE FOR EVERY DEFECT. A check that was wrong once and is now right,
# with no case pinning it, is a check that will be wrong again the next time
# someone edits it.
#
# USAGE
#
#   Adapters/scripts/tests/run.sh [--verbose]
#
# Exit 0 when every case passes, 1 otherwise. Prints the denominator, because
# a suite that reports "all passed" without saying how many is not evidence
# (Adapters/README.md, The Check Convention, rule 3).

set -uo pipefail

VERBOSE=""
[ "${1:-}" = "--verbose" ] && VERBOSE=1

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TOTAL=0
FAILED=0
LAST_OUTPUT=""

# ---------------------------------------------------------------- helpers ---

# Builds an empty git repository and leaves the shell inside it.
new_repo() {
  local d="$WORK/$1"
  rm -rf "$d"
  mkdir -p "$d"
  cd "$d" || exit 1
  git init -q -b main .
  git config user.email test@example.invalid
  git config user.name "Test Runner"
  git config commit.gpgsign false
  # Fixtures are throwaway; line-ending translation only produces noise
  # that buries a real failure in the output.
  git config core.autocrlf false
  git config core.safecrlf false
  echo seed > seed.txt
  git add seed.txt
  git commit -q -m "seed"
}

# Writes a Work Unit registry with the given IDs, in the exact field shape the
# parsing contract requires.
write_wu_registry() {
  mkdir -p Registry
  {
    echo "work_units:"
    for id in "$@"; do
      echo "  - id: $id"
      echo "    employee: Release Manager"
      echo "    title: a registered Work Unit"
      echo "    milestone: Testing"
    done
  } > Registry/work-units.yml
}

# commit_with <subject> <trailer-block...>  — each extra argument is a line
# appended verbatim after a blank line, so a caller can place a trailer at
# column 0 or indent it to make it an example.
commit_with() {
  local subject="$1"; shift
  local msg="$subject"
  msg="$msg
"
  local line
  for line in "$@"; do
    msg="$msg
$line"
  done
  echo "$RANDOM.$RANDOM" > "f$(date +%s%N).txt"
  git add -A
  git commit -q -m "$msg"
}

# expect <expected-exit> <description> -- <command...>
expect() {
  local want="$1"; shift
  local desc="$1"; shift
  [ "$1" = "--" ] && shift
  TOTAL=$((TOTAL + 1))
  LAST_OUTPUT="$("$@" 2>&1)"
  local got=$?
  if [ "$got" = "$want" ]; then
    [ -n "$VERBOSE" ] && printf '   ok   %s\n' "$desc"
    return 0
  fi
  printf '   FAIL %s\n' "$desc"
  printf '        expected exit %s, got %s\n' "$want" "$got"
  printf '%s\n' "$LAST_OUTPUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
  return 1
}

# Asserts the previous command's output contained a string. Used where the exit
# code alone cannot distinguish "passed for the right reason" from "passed".
expect_output() {
  TOTAL=$((TOTAL + 1))
  if printf '%s' "$LAST_OUTPUT" | grep -qF "$1"; then
    [ -n "$VERBOSE" ] && printf '   ok   output contains: %s\n' "$1"
    return 0
  fi
  printf '   FAIL output does not contain: %s\n' "$1"
  printf '%s\n' "$LAST_OUTPUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
  return 1
}

section() { printf '\n== %s\n' "$1"; }

# ------------------------------------------------- check-work-units.sh ------

CHECK_WU="$SCRIPTS/check-work-units.sh"

section "check-work-units.sh"

new_repo wu-basic
write_wu_registry WU-TEST-001 WU-TEST-002
git add -A && git commit -q -m "registry

Work Unit: WU-TEST-001"
BASE="$(git rev-parse HEAD)"

commit_with "feat: a registered Work Unit" "Work Unit: WU-TEST-002" "" "Employee: Release Manager"
expect 0 "a registered Work Unit resolves" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "(resolved)"

new_repo wu-missing
write_wu_registry WU-TEST-001
git add -A && git commit -q -m "registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: no trailer at all"
expect 1 "a commit with no Work Unit trailer fails" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "carries no 'Work Unit: <WU-ID>' trailer"

new_repo wu-unregistered
write_wu_registry WU-TEST-001
git add -A && git commit -q -m "registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: claims an unknown ID" "Work Unit: WU-TEST-999"
expect 1 "an unregistered Work Unit ID fails" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "WU-TEST-999"

new_repo wu-double
write_wu_registry WU-TEST-001 WU-TEST-002
git add -A && git commit -q -m "registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: two claims" "Work Unit: WU-TEST-001" "Work Unit: WU-TEST-002"
expect 1 "two Work Unit lines at column 0 fail" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "One Work Unit is one commit"

# The escape hatch the error message itself offers must actually work, or the
# advice is wrong. An indented line is prose, not a claim.
new_repo wu-indented-example
write_wu_registry WU-TEST-001
git add -A && git commit -q -m "registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: quotes an earlier Work Unit as an example" \
  "Deferred from an earlier change, which said:" \
  "    Work Unit: WU-TEST-777" \
  "" \
  "Work Unit: WU-TEST-001"
expect 0 "an indented Work Unit line is prose, not a second claim" -- bash "$CHECK_WU" "$BASE" HEAD

# A back-merge carries no authored commits. Refusing it is what deadlocked the
# v0.0.12 release in the sibling pr-size check.
# The shape is the real one: the base already CONTAINS the authored commit,
# and the head is ahead of it only by the merge that brought it there. A base
# taken before the authored commit is a different situation entirely — it has
# a commit to check — and getting that wrong makes the case test nothing.
new_repo wu-merge-only
write_wu_registry WU-TEST-001
git add -A && git commit -q -m "registry"
git checkout -qb develop
echo side > side.txt && git add -A && git commit -q -m "authored work

Work Unit: WU-TEST-001"
git checkout -q main
git merge -q --no-ff develop -m "Merge develop into main"
BASE="$(git rev-parse develop)"
expect 0 "a range of merges only is a pass, not a silence" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "No non-merge commits to check."

new_repo wu-no-registry
BASE="$(git rev-parse HEAD)"
commit_with "feat: anything" "Work Unit: WU-TEST-001"
expect 1 "an absent registry fails closed" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "Could not locate Registry/work-units.yml"

# A registry that parses to nothing must name the parser, not blame the
# commits. Reporting every commit unregistered describes the wrong thing —
# the class recorded as TROUBLESHOOTING entry T.
new_repo wu-unparseable-registry
mkdir -p Registry
printf 'work_units:\n- id: WU-TEST-001\n' > Registry/work-units.yml
git add -A && git commit -q -m "registry with the wrong indentation"
BASE="$(git rev-parse HEAD)"
commit_with "feat: anything" "Work Unit: WU-TEST-001"
expect 1 "a registry that parses to zero IDs fails as a parsing fault" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "parsing contract"

new_repo wu-one-bad-of-three
write_wu_registry WU-TEST-001 WU-TEST-002
git add -A && git commit -q -m "registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: first"  "Work Unit: WU-TEST-001"
commit_with "feat: second" "Work Unit: WU-TEST-404"
commit_with "feat: third"  "Work Unit: WU-TEST-002"
expect 1 "one unregistered commit among three fails the range" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "WU-TEST-404"

new_repo wu-bad-refs
write_wu_registry WU-TEST-001
git add -A && git commit -q -m "registry"
expect 1 "an unresolvable range fails rather than reporting zero problems" -- bash "$CHECK_WU" "does-not-exist" HEAD

expect 2 "wrong argument count is a usage error, not a pass" -- bash "$CHECK_WU"

# --------------------------------------------------------------- verdict ----

cd "$HERE" || exit 1
printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'Result: %s checks passed.\n' "$TOTAL"
  exit 0
fi
printf 'Result: %s of %s checks FAILED.\n' "$FAILED" "$TOTAL"
exit 1
