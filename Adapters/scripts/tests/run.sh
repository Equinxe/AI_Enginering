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
# (Adapters/README.md, The Check Convention, rule 3). A check that is skipped
# for a genuine platform limitation is reported too (WU-IAENG-300): it is
# never folded into "passed" and never silently absent from the total.

set -uo pipefail

VERBOSE=""
[ "${1:-}" = "--verbose" ] && VERBOSE=1

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TOTAL=0
FAILED=0
SKIPPED=0
SKIP_REASONS=""
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

# Writes an Employee roster with the given names, in the parsing contract's
# exact field shape.
write_employee_roster() {
  local target="${ROSTER_TARGET:-Registry/employees.yml}"
  mkdir -p "$(dirname "$target")"
  {
    echo "employees:"
    local n
    for n in "$@"; do
      echo "  - name: $n"
      echo "    category: Management"
    done
  } > "$target"
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
  # `--` is load bearing: an expected string beginning with a dash is read as
  # an option otherwise, and the assertion fails with a grep usage error
  # instead of comparing anything. That is TROUBLESHOOTING entry T, met here
  # by a test asserting on the output "  <sha> -> DevOps Engineer".
  if grep -qF -- "$1" <<< "$LAST_OUTPUT"; then
    [ -n "$VERBOSE" ] && printf '   ok   output contains: %s\n' "$1"
    return 0
  fi
  printf '   FAIL output does not contain: %s\n' "$1"
  printf '%s\n' "$LAST_OUTPUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
  return 1
}

# skip <n> <reason...> — records that <n> checks were not executed, and why,
# instead of leaving TOTAL exactly as a full run would (WU-IAENG-300: a
# platform where `ln -s` fails used to print a bare SKIP line that touched no
# counter, so "N checks passed" quietly meant a smaller N than a full run —
# a skip absorbed into the denominator instead of visible in it).
#
# This framework's own CI runs on Linux, where `ln -s` always succeeds, so a
# skip firing there is not a platform limitation, it is the fix under test
# breaking in the one environment that must never let it slide. Under
# CI=true a skip is therefore counted as a failure instead of trusted; on
# every other platform — including a contributor's un-elevated Windows
# checkout, which is the case this exists for — it is reported and excluded
# from both TOTAL and FAILED, exactly as before.
skip() {
  local n="$1"; shift
  local reason="$*"
  if [ "${CI:-}" = "true" ]; then
    TOTAL=$((TOTAL + n))
    FAILED=$((FAILED + n))
    printf '   FAIL (skip refused under CI=true) %s\n' "$reason"
    return 1
  fi
  SKIPPED=$((SKIPPED + n))
  SKIP_REASONS="${SKIP_REASONS:+$SKIP_REASONS; }$reason"
  printf '   SKIP (%s skipped) %s\n' "$n" "$reason"
  return 0
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

# Workflows/ONBOARDING.md "Adopting into an already-started project", reality 2:
# the check judges the change set under review, not prior history. A commit made
# before the project adopted the framework carries no Work Unit trailer, and is
# NOT judged when the range begins at the adoption commit — which is exactly why
# the guidance is to submit adoption from the adoption commit, not the repository
# root. Both directions are pinned so a refactor that widened the range would
# name itself: the untrailered ancestor passes when excluded, fails when included.
new_repo wu-adoption
echo seed > seed.txt && git add -A && git commit -q -m "initial project state"
PRE="$(git rev-parse HEAD)"
echo legacy > legacy.txt && git add -A && git commit -q -m "existing work, before the framework"
write_wu_registry WU-TEST-001
git add -A && git commit -q -m "adopt IA Engineering

Work Unit: WU-TEST-001"
ADOPT="$(git rev-parse HEAD)"
commit_with "feat: first work after adoption" "Work Unit: WU-TEST-001"
expect 0 "an untrailered commit before the adoption base is not judged" -- bash "$CHECK_WU" "$ADOPT" HEAD
expect 1 "the same untrailered commit IS judged when the range includes it" -- bash "$CHECK_WU" "$PRE" HEAD
expect_output "carries no"

new_repo wu-no-registry
BASE="$(git rev-parse HEAD)"
commit_with "feat: anything" "Work Unit: WU-TEST-001"
expect 1 "an absent registry fails closed" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "This project has no Work Unit registry"

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

# ------------------------------------------ check-employee-trailers.sh ------

CHECK_EMP="$SCRIPTS/check-employee-trailers.sh"

section "check-employee-trailers.sh"

new_repo emp-basic
write_employee_roster "Release Manager" "DevOps Engineer"
git add -A && git commit -q -m "roster"
BASE="$(git rev-parse HEAD)"
commit_with "feat: attributed to a real Employee" "Employee: DevOps Engineer"
expect 0 "a roster name resolves" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "-> DevOps Engineer"

new_repo emp-missing
write_employee_roster "Release Manager"
git add -A && git commit -q -m "roster"
BASE="$(git rev-parse HEAD)"
commit_with "feat: nobody claims it"
expect 1 "a commit with no Employee trailer fails" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "missing an 'Employee: <Name>' trailer"

# The whole reason the roster is a closed list: a tool label is not an
# Employee, and accepting one would make Dispatch Discipline unenforceable.
new_repo emp-tool-label
write_employee_roster "Release Manager" "DevOps Engineer"
git add -A && git commit -q -m "roster"
BASE="$(git rev-parse HEAD)"
commit_with "feat: attributed to a tool" "Employee: executor"
expect 1 "a generic tool label is refused" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "is not a valid Employee name"

new_repo emp-indented-example
write_employee_roster "Release Manager"
git add -A && git commit -q -m "roster"
BASE="$(git rev-parse HEAD)"
commit_with "feat: quotes a bad trailer as an example"   "The rejected commit had said:"   "    Employee: executor"   ""   "Employee: Release Manager"
expect 0 "an indented Employee line is prose, not a claim" -- bash "$CHECK_EMP" "$BASE" HEAD

new_repo emp-merge-only
write_employee_roster "Release Manager"
git add -A && git commit -q -m "roster"
git checkout -qb develop
echo work > w.txt && git add -A && git commit -q -m "authored work

Employee: Release Manager"
git checkout -q main
git merge -q --no-ff develop -m "Merge develop into main"
BASE="$(git rev-parse develop)"
expect 0 "a merge-only range passes and says so" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "No non-merge commits to validate."

# Workflows/ONBOARDING.md "Adopting into an already-started project", reality 2:
# the same property for the Employee trailer. A commit made before adoption has
# no Employee trailer and is not judged when the range starts at the adoption
# commit; the identical commit fails once the range reaches back past it. Pinning
# both directions makes the adoption guidance a checked fact, not a promise.
new_repo emp-adoption
echo seed > seed.txt && git add -A && git commit -q -m "initial project state"
PRE="$(git rev-parse HEAD)"
echo legacy > legacy.txt && git add -A && git commit -q -m "existing work, before the framework"
write_employee_roster "Release Manager" "DevOps Engineer"
git add -A && git commit -q -m "adopt IA Engineering

Employee: DevOps Engineer"
ADOPT="$(git rev-parse HEAD)"
commit_with "feat: first work after adoption" "Employee: DevOps Engineer"
expect 0 "an untrailered commit before the adoption base is not judged" -- bash "$CHECK_EMP" "$ADOPT" HEAD
expect 1 "the same untrailered commit IS judged when the range includes it" -- bash "$CHECK_EMP" "$PRE" HEAD
expect_output "missing an 'Employee: <Name>' trailer"

new_repo emp-no-roster
BASE="$(git rev-parse HEAD)"
commit_with "feat: anything" "Employee: Release Manager"
expect 1 "an absent roster fails closed" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "Could not locate Registry/employees.yml"

new_repo emp-unparseable-roster
mkdir -p Registry
printf 'employees:
- name: Release Manager
' > Registry/employees.yml
git add -A && git commit -q -m "roster with the wrong indentation"
BASE="$(git rev-parse HEAD)"
commit_with "feat: anything" "Employee: Release Manager"
expect 1 "a roster that parses to zero names fails as a parsing fault" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "parsing contract"

# A Domain Employee is a real Employee for its project and unknown to the
# framework. Refusing it would make Templates/DOMAIN_EMPLOYEE.md unusable.
new_repo emp-domain
write_employee_roster "Release Manager"
ROSTER_TARGET=".ia-engineering/Registry/employees.yml" write_employee_roster "Claims Adjudicator"
git add -A && git commit -q -m "framework roster plus a project roster"
BASE="$(git rev-parse HEAD)"
commit_with "feat: work by a Domain Employee" "Employee: Claims Adjudicator"
expect 0 "a Domain Employee from the project roster resolves" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "1 Domain Employee(s)"

new_repo emp-domain-absent
write_employee_roster "Release Manager"
git add -A && git commit -q -m "framework roster only"
BASE="$(git rev-parse HEAD)"
commit_with "feat: claims a Domain Employee nobody registered" "Employee: Claims Adjudicator"
expect 1 "an unregistered Domain Employee is still refused" -- bash "$CHECK_EMP" "$BASE" HEAD

# A typo in the path must not degrade into "framework roster only", which
# would refuse every Domain Employee while reporting a clean configuration.
new_repo emp-bad-project-roster-path
write_employee_roster "Release Manager"
git add -A && git commit -q -m "roster"
BASE="$(git rev-parse HEAD)"
commit_with "feat: anything" "Employee: Release Manager"
expect 1 "a missing IAENG_PROJECT_ROSTER path fails rather than narrowing silently" --   env IAENG_PROJECT_ROSTER=nope/employees.yml bash "$CHECK_EMP" "$BASE" HEAD
expect_output "no such file exists"

expect 2 "wrong argument count is a usage error" -- bash "$CHECK_EMP"

# ------------------------------------------------- check-pr-size.sh ---------

CHECK_SIZE="$SCRIPTS/check-pr-size.sh"

section "check-pr-size.sh"

new_repo size-small
BASE="$(git rev-parse HEAD)"
echo more >> seed.txt && git commit -qam "a small change"
expect 0 "an ordinary change under the limit passes" -- bash "$CHECK_SIZE" "$BASE" HEAD
expect_output "Within the review limit."

new_repo size-over
BASE="$(git rev-parse HEAD)"
i=0; while [ $i -lt 2000 ]; do echo "line $i" >> seed.txt; i=$((i + 1)); done
git commit -qam "a large change"
expect 1 "an oversized change fails without the override" -- bash "$CHECK_SIZE" "$BASE" HEAD
expect_output "review limit is 1500"

expect 0 "size/approved among several labels is the override" --   env IAENG_PR_LABELS="needs-docs,size/approved" bash "$CHECK_SIZE" "$BASE" HEAD
expect_output "the Director has applied 'size/approved'"

# A label that merely CONTAINS the override string is not the override. An
# exact match is what makes the label an authorisation rather than a hint.
expect 1 "a label merely containing the override string is not the override" --   env IAENG_PR_LABELS="size/approved-later" bash "$CHECK_SIZE" "$BASE" HEAD

# The limit is configurable, so a project can tighten or relax it deliberately
# rather than by editing the script.
expect 0 "IAENG_PR_LIMIT is honoured, so a project can set its own" --   env IAENG_PR_LIMIT=5000 bash "$CHECK_SIZE" "$BASE" HEAD

# WU-IAENG-220. The shape is the real one: the base already contains the
# authored commit and the head is ahead only by the merge that brought it.
new_repo size-backmerge
git checkout -qb develop
echo b > b.txt && git add -A && git commit -qm "authored work B"
git checkout -q main
git merge -q --no-ff develop -m "Merge develop into main"
git checkout -q develop
echo c > c.txt && git add -A && git commit -qm "further work C"
BASE="$(git rev-parse develop)"
expect 0 "a back-merge passes: nothing to read is not nothing measured" -- bash "$CHECK_SIZE" "$BASE" main
expect_output "every one a merge"

new_repo size-empty-range
BASE="$(git rev-parse HEAD)"
expect 1 "identical refs fail: no commits and no files means nothing measured" -- bash "$CHECK_SIZE" "$BASE" HEAD
expect_output "no commits either"

new_repo size-empty-commit
BASE="$(git rev-parse HEAD)"
git commit -q --allow-empty -m "an empty non-merge commit"
expect 1 "an empty non-merge commit fails: it is not a back-merge" -- bash "$CHECK_SIZE" "$BASE" HEAD
expect_output "not merges"

new_repo size-merge-plus-empty
git checkout -qb side
echo s > s.txt && git add -A && git commit -qm "side"
git checkout -q main
git merge -q --no-ff side -m "merge side"
BASE="$(git rev-parse HEAD)"
git commit -q --allow-empty -m "an empty commit after the merge"
expect 1 "a merge plus an empty commit still fails" -- bash "$CHECK_SIZE" "$BASE" HEAD

# WU-IAENG-198. An unresolvable ref must not be counted as zero lines: the
# inline version printed "Within the review limit" and exited 0.
new_repo size-bad-ref
expect 1 "an unresolvable base fails rather than measuring zero" -- bash "$CHECK_SIZE" "does-not-exist" HEAD

# linguist-generated files are excluded from the count, and the exclusion is
# declared in a committed file so it is itself reviewable.
new_repo size-generated
printf 'built.txt linguist-generated=true\n' > .gitattributes
git add -A && git commit -qm "declare the generated file"
BASE="$(git rev-parse HEAD)"
i=0; while [ $i -lt 2000 ]; do echo "generated $i" >> built.txt; i=$((i + 1)); done
git add -A && git commit -qm "regenerate"
expect 0 "2000 lines in a linguist-generated file do not count" -- bash "$CHECK_SIZE" "$BASE" HEAD
expect_output "1 generated"

expect 2 "wrong argument count is a usage error" -- bash "$CHECK_SIZE"

# ------------------------------------------ check-review-recorded.sh --------

CHECK_REVIEW="$SCRIPTS/check-review-recorded.sh"

# comment <dir> <n> <author> <body-line...>
comment() {
  local dir="$1" n="$2" author="$3"; shift 3
  mkdir -p "$dir"
  {
    echo "author: $author"
    local l
    for l in "$@"; do echo "$l"; done
  } > "$dir/$n.txt"
}

section "check-review-recorded.sh"

CDIR="$WORK/comments-approved"
rm -rf "$CDIR"
comment "$CDIR" 1 alice "Looks reasonable to me."
comment "$CDIR" 2 bob "Reviewed against the Standards." "" "Decision: approved" "Denominator: 14 of 14 files read."
expect 0 "a recorded decision is found" -- bash "$CHECK_REVIEW" "$CDIR"
expect_output "decision found in 2.txt"
expect_output "Comments examined: 2"

CDIR="$WORK/comments-none"
rm -rf "$CDIR"
comment "$CDIR" 1 alice "Looks reasonable to me."
comment "$CDIR" 2 bob "Some nitpicks below."
expect 1 "no decision among real comments fails" -- bash "$CHECK_REVIEW" "$CDIR"
expect_output "No recorded Code Reviewer decision"

# Zero comments must not read as zero problems. The denominator is what tells
# "none found" from "nothing was looked at".
CDIR="$WORK/comments-empty"
rm -rf "$CDIR"; mkdir -p "$CDIR"
expect 1 "an empty comment set fails and reports its denominator" -- bash "$CHECK_REVIEW" "$CDIR"
expect_output "Comments examined: 0"

# A directory the host never created means the fetch did not run. Blaming the
# change set for a broken pipeline is the failure this distinguishes.
expect 1 "a missing directory is a pipeline fault, not an unreviewed change" --   bash "$CHECK_REVIEW" "$WORK/comments-never-created"
expect_output "fetch did not run"

# "Could not read everything" is not "nothing was recorded".
CDIR="$WORK/comments-partial"
rm -rf "$CDIR"
comment "$CDIR" 1 alice "Only some sources could be read."
expect 1 "an incomplete fetch says nothing was established either way" --   bash "$CHECK_REVIEW" "$CDIR" --fetch-incomplete
expect_output "NOT the same as an unreviewed change set"

# ...but a decision found in what WAS read still counts: the check is satisfied
# by evidence, and more evidence could not unfind it.
CDIR="$WORK/comments-partial-found"
rm -rf "$CDIR"
comment "$CDIR" 1 reviewbot "Decision: approved"
expect 0 "an incomplete fetch that still found a decision passes" --   bash "$CHECK_REVIEW" "$CDIR" --fetch-incomplete

# The author filter is applied HERE, so a host that fetched everything cannot
# leave the script claiming a mode it is not enforcing.
CDIR="$WORK/comments-author-filter"
rm -rf "$CDIR"
comment "$CDIR" 1 the-author "Decision: approved"
comment "$CDIR" 2 someone-else "Looks fine."
expect 1 "in independent mode, a decision from the wrong author does not count" --   env IAENG_REVIEW_BOT_LOGIN=reviewbot bash "$CHECK_REVIEW" "$CDIR"
expect_output "skipped for author: 2"
expect 0 "the same corpus passes when any author counts" -- bash "$CHECK_REVIEW" "$CDIR"

CDIR="$WORK/comments-right-author"
rm -rf "$CDIR"
comment "$CDIR" 1 the-author "Looks fine."
comment "$CDIR" 2 reviewbot "Decision: approved"
expect 0 "in independent mode, the configured login's decision counts" --   env IAENG_REVIEW_BOT_LOGIN=reviewbot bash "$CHECK_REVIEW" "$CDIR"

# A body cannot declare its own author: the header is line 1 and a body starts
# at line 2. Without this the author filter would be decoration.
CDIR="$WORK/comments-forged"
rm -rf "$CDIR"
comment "$CDIR" 1 mallory "author: reviewbot" "Decision: approved"
expect 1 "a body impersonating an author header is not attributed to it" --   env IAENG_REVIEW_BOT_LOGIN=reviewbot bash "$CHECK_REVIEW" "$CDIR"
expect_output "skipped for author: 1"

# An unattributable file fails rather than being counted as anonymous, which
# would let it satisfy an author-filtered check.
CDIR="$WORK/comments-no-header"
rm -rf "$CDIR"; mkdir -p "$CDIR"
printf 'Decision: approved\n' > "$CDIR/1.txt"
expect 1 "a file with no author header fails closed" -- bash "$CHECK_REVIEW" "$CDIR"
expect_output "cannot be attributed"

# The decision block is matched case-insensitively and tolerates leading
# whitespace, because it is quoted from a template into prose.
CDIR="$WORK/comments-case"
rm -rf "$CDIR"
comment "$CDIR" 1 bob "  decision:   APPROVED"
expect 0 "the decision line is matched case-insensitively and indented" -- bash "$CHECK_REVIEW" "$CDIR"

expect 2 "no directory argument is a usage error" -- bash "$CHECK_REVIEW"
expect 2 "an unknown option is a usage error" -- bash "$CHECK_REVIEW" "$CDIR" --nope

# ------------------------------------------------- resolve-stack.sh ---------

RESOLVE="$SCRIPTS/resolve-stack.sh"

# project <name> <files...> — a bare directory with the given empty files.
project() {
  local d="$WORK/$1"; shift
  rm -rf "$d"; mkdir -p "$d"
  local f
  for f in "$@"; do
    mkdir -p "$d/$(dirname "$f")"
    : > "$d/$f"
  done
  printf '%s' "$d"
}

# expect_stack <expected> <description> <project-dir> [env...]
expect_stack() {
  local want="$1" desc="$2" dir="$3"; shift 3
  TOTAL=$((TOTAL + 1))
  local got
  got="$(bash "$RESOLVE" "$dir" 2>/dev/null)"
  if [ "$got" = "$want" ]; then
    [ -n "$VERBOSE" ] && printf '   ok   %s -> %s\n' "$desc" "$got"
  else
    printf '   FAIL %s: expected %s, got %s\n' "$desc" "$want" "$got"
    FAILED=$((FAILED + 1))
  fi
}

section "resolve-stack.sh"

expect_stack node    "package.json infers node"        "$(project rs-node package.json)"
expect_stack python  "pyproject.toml infers python"    "$(project rs-py pyproject.toml)"
expect_stack python  "requirements.txt infers python"  "$(project rs-req requirements.txt)"
expect_stack go      "go.mod infers go"                "$(project rs-go go.mod)"
expect_stack jvm     "pom.xml infers jvm"              "$(project rs-mvn pom.xml)"
expect_stack jvm     "build.gradle.kts infers jvm"     "$(project rs-gradle build.gradle.kts)"
expect_stack generic "no manifest infers generic"      "$(project rs-bare)"

# The whole reason the declaration exists: a manifest can belong to more than
# one stack, and only a declaration can say which.
D="$(project rs-declared package.json)"
mkdir -p "$D/.ia-engineering"; printf 'generic\n' > "$D/.ia-engineering/stack"
expect_stack generic "a declaration beats the manifest it contradicts" "$D"

# Trailing whitespace and a CR from a Windows checkout must not change the
# answer. The file is written by a script and read on another platform.
D="$(project rs-crlf)"
mkdir -p "$D/.ia-engineering"; printf 'go  \n' > "$D/.ia-engineering/stack"
expect_stack go "surrounding whitespace and CR are ignored" "$D"

# A typo must not degrade into sniffing: that would build a different stack
# and report success for one nobody chose.
D="$(project rs-typo package.json)"
mkdir -p "$D/.ia-engineering"; printf 'nod\n' > "$D/.ia-engineering/stack"
expect 1 "an unknown declared stack fails rather than falling back" -- bash "$RESOLVE" "$D"
expect_output "is not one of"

D="$(project rs-empty package.json)"
mkdir -p "$D/.ia-engineering"; : > "$D/.ia-engineering/stack"
expect 1 "an empty declaration is not a declaration" -- bash "$RESOLVE" "$D"
expect_output "empty"

expect 1 "a missing project directory fails" -- bash "$RESOLVE" "$WORK/rs-nowhere"

# stdout carries the stack and nothing else, so the caller can use it directly.
D="$(project rs-clean go.mod)"
TOTAL=$((TOTAL + 1))
OUT="$(bash "$RESOLVE" "$D" 2>/dev/null)"
if [ "$OUT" = "go" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   stdout is the stack alone, explanations on stderr\n'
else
  printf '   FAIL stdout must carry only the stack, got: %s\n' "$OUT"
  FAILED=$((FAILED + 1))
fi

# --- the three stacks added in WU-IAENG-231 ---

expect_stack php    "composer.json infers php"    "$(project rs-php composer.json)"
expect_stack dotnet "a .csproj infers dotnet"     "$(project rs-cs App.csproj)"
expect_stack dotnet "a .sln infers dotnet"        "$(project rs-sln App.sln)"

# The declaration is the ONLY way to reach `web`, because nothing in a file
# name separates a static site from a Node server.
D="$(project rs-web package.json)"
mkdir -p "$D/.ia-engineering"; printf 'web\n' > "$D/.ia-engineering/stack"
expect_stack web "web is reachable by declaration over a package.json" "$D"

# Ambiguity is asked about, not ranked. A Laravel app is the real case.
D="$(project rs-laravel composer.json package.json)"
expect 1 "two matching manifests fail rather than picking one" -- bash "$RESOLVE" "$D"
expect_output "matches 2 stacks"
expect_output "composer.json and package.json"

D="$(project rs-three composer.json package.json go.mod)"
expect 1 "three matching manifests fail and name all three" -- bash "$RESOLVE" "$D"
expect_output "matches 3 stacks"

# ...and the declaration is what resolves it, which is the remedy the message
# offers. If that did not work the advice would be false.
D="$(project rs-laravel-declared composer.json package.json)"
mkdir -p "$D/.ia-engineering"; printf 'php\n' > "$D/.ia-engineering/stack"
expect_stack php "a declaration settles an otherwise ambiguous project" "$D"

# ------------------------------------------------- resolve-host.sh ----------

RESOLVE_HOST="$SCRIPTS/resolve-host.sh"

# host_project <name> [remote-url] — a git repo, optionally with an origin.
host_project() {
  local d="$WORK/$1"; shift
  rm -rf "$d"; mkdir -p "$d"
  ( cd "$d" && git init -q -b main . && git config user.email t@t && git config user.name T
    if [ -n "${1:-}" ]; then git remote add origin "$1"; fi ) >/dev/null 2>&1
  printf '%s' "$d"
}

expect_host() {
  local want="$1" desc="$2" dir="$3"
  TOTAL=$((TOTAL + 1))
  local got
  got="$(bash "$RESOLVE_HOST" "$dir" 2>/dev/null)"
  if [ "$got" = "$want" ]; then
    [ -n "$VERBOSE" ] && printf '   ok   %s -> %s\n' "$desc" "$got"
  else
    printf '   FAIL %s: expected %s, got %s\n' "$desc" "$want" "$got"
    FAILED=$((FAILED + 1))
  fi
}

section "resolve-host.sh"

expect_host github "an https github.com remote detects github"   "$(host_project rh-https https://github.com/acme/thing.git)"
expect_host github "an ssh github.com remote detects github"   "$(host_project rh-ssh git@github.com:acme/thing.git)"

# `none` is a real answer, not a failure: no remote at all is a bare or local
# project, and the host-dependent steps must say what to do by hand.
expect_host none "no origin remote resolves to none" "$(host_project rh-noremote)"

# A SELF-HOSTED DOMAIN IS NOT GUESSED. github.example.com may be a GitHub
# Enterprise server or a GitLab named unhelpfully, and calling the wrong API
# against a real server is worse than saying nothing.
expect_host none "a self-hosted domain is not guessed from its name"   "$(host_project rh-selfhosted https://github.example.com/acme/thing.git)"
expect_host none "an unrecognised forge resolves to none"   "$(host_project rh-other https://git.acme.internal/acme/thing.git)"

# ...and a declaration is how such a project says which forge it really is.
D="$(host_project rh-declared https://git.acme.internal/acme/thing.git)"
mkdir -p "$D/.ia-engineering"; printf 'github\n' > "$D/.ia-engineering/host"
expect_host github "a declaration names a self-hosted forge detection cannot" "$D"

# A declaration also overrides a detection that would have been right, which
# is what lets a GitHub-hosted project opt out of the API entirely.
D="$(host_project rh-optout https://github.com/acme/thing.git)"
mkdir -p "$D/.ia-engineering"; printf 'none\n' > "$D/.ia-engineering/host"
expect_host none "a declaration of none overrides successful detection" "$D"

D="$(host_project rh-crlf https://git.acme.internal/x.git)"
mkdir -p "$D/.ia-engineering"; printf 'github  \n' > "$D/.ia-engineering/host"
expect_host github "surrounding whitespace and CR are ignored" "$D"

D="$(host_project rh-typo https://github.com/acme/thing.git)"
mkdir -p "$D/.ia-engineering"; printf 'gitlab\n' > "$D/.ia-engineering/host"
expect 1 "an unknown declared host fails rather than falling back to detection" -- bash "$RESOLVE_HOST" "$D"
expect_output "is not one of"

D="$(host_project rh-emptydecl https://github.com/acme/thing.git)"
mkdir -p "$D/.ia-engineering"; : > "$D/.ia-engineering/host"
expect 1 "an empty declaration is not a declaration" -- bash "$RESOLVE_HOST" "$D"
expect_output "empty"

expect 1 "a missing project directory fails" -- bash "$RESOLVE_HOST" "$WORK/rh-nowhere"

# ------------------------------------------------- hosts/none/ -------------

# The `none` host is the whole reason the seam is more than indirection: it is
# what an unsupported forge gets, and it is fully testable here. Every case
# below asserts that it refuses to pretend.

NONE="$SCRIPTS/hosts/none"

section "hosts/none/"

expect 1 "ci-conclusion refuses rather than reporting a green it cannot see" -- bash "$NONE/ci-conclusion.sh" develop
expect_output "cannot read a CI conclusion"
expect_output "Confirm by hand"

# Exit 3, not 0. Exiting 0 with nothing on stdout made release.sh report "no
# open issues labelled bug" — an absence nobody established. Not 1 either:
# Step 1 condition 3 is reported and not failed, and failing would add a gate
# the workflow never had.
expect 3 "open-bugs reports it could not look, without blocking and without lying" -- bash "$NONE/open-bugs.sh"
expect_output "cannot list open defects"

expect 1 "create-release refuses: a tag with no notes is an incomplete release" -- bash "$NONE/create-release.sh" v9.9.9 "v9.9.9 — Demo" /tmp/notes.md
expect_output "Step 7 is NOT complete"
expect_output "/tmp/notes.md"

# WU-IAENG-322: the closing text of `release.sh publish` once said the Step 8
# back-merge was needed only if a fix landed on the release branch. Workflows/
# RELEASE.md Step 8 says it is always required (Step 6 leaves a merge commit
# on main that develop never sees). Extract the shipped heredoc, not a copy.
sed -n "/^  cat <<.REMAINING.\$/,/^REMAINING\$/p" "$SCRIPTS/release.sh" | tr -s ' \n' '  ' > "$WORK/publish-closing.txt"
expect 0 "publish closing text: Step 8 back-merge is stated as always required" -- \
  grep -qF -- "Back-merge to develop via Pull Request. ALWAYS required, on every release" "$WORK/publish-closing.txt"
expect 1 "publish closing text no longer says the back-merge is conditional" -- \
  grep -qF -- "Not needed when the release branch never diverged" "$WORK/publish-closing.txt"

# Exit 3 again, and it must leave the directory behind: check-review-recorded
# treats an ABSENT directory as a broken pipeline and an EMPTY one as "read,
# nothing there". Only the second is true here.
D="$WORK/none-comments"
rm -rf "$D"
expect 3 "fetch-review-comments reports partial rather than empty" -- bash "$NONE/fetch-review-comments.sh" acme/thing 1 "$D"
TOTAL=$((TOTAL + 1))
if [ -d "$D" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   it leaves the directory behind, empty\n'
else
  printf '   FAIL the comments directory must exist and be empty, not absent\n'
  FAILED=$((FAILED + 1))
fi

# ...and the caller reads that correctly: an empty directory plus
# --fetch-incomplete is "nothing established", never "no decision recorded".
expect 1 "an empty corpus with --fetch-incomplete establishes nothing" -- bash "$SCRIPTS/check-review-recorded.sh" "$D" --fetch-incomplete
expect_output "NOT the same as an unreviewed change set"

# Every host implements every operation. A missing file is a silently skipped
# control, so the set is compared rather than assumed.
section "hosts/ — every host implements every operation"

for op in ci-conclusion open-bugs create-release fetch-review-comments; do
  for h in github none; do
    TOTAL=$((TOTAL + 1))
    if [ -x "$SCRIPTS/hosts/$h/$op.sh" ]; then
      [ -n "$VERBOSE" ] && printf '   ok   hosts/%s/%s.sh present and executable\n' "$h" "$op"
    else
      printf '   FAIL hosts/%s/%s.sh is missing or not executable\n' "$h" "$op"
      FAILED=$((FAILED + 1))
    fi
  done
done

# ------------------------------------------------- check-risk-map.sh --------

CHECK_MAP="$SCRIPTS/check-risk-map.sh"

# A Risk Map is wrong easily and SILENTLY: it classifies something important as
# ordinary and everything downstream then behaves correctly on a false input.
# Templates/RISK_MAP.md lists five ways that happens; these cases are the first four
# plus the states the check must tell apart.

# risk_project — a fixture with a sensitive area, a routine area, and an
# ordinary one, so a map can be right or wrong about each.
risk_project() {
  new_repo "$1"
  mkdir -p src/auth docs .ia-engineering
  echo a > src/auth/login.js
  echo b > src/app.js
  echo c > docs/guide.md
  git add -A && git commit -q -m "seed the fixture"
}

sound_risk_map() {
  cat > .ia-engineering/risk-map.yml <<'RMAP'
version: 1
zones:
  - pattern: "src/auth/*"
    level: sensitive
    category: authentication
    reason: decides who the caller is
  - pattern: "docs/*"
    level: routine
    reason: nothing reads it at runtime
  - pattern: "*"
    level: standard
    reason: the documented default
absent:
  - category: authorization
    reason: no roles
  - category: personal_data
    reason: no user data
  - category: payments_and_spend
    reason: no billing and no billed model call
  - category: cryptography_and_secrets
    reason: no secrets
  - category: migrations_and_data_integrity
    reason: no store
  - category: infrastructure_and_ci
    reason: no CI in this fixture
  - category: core_architecture
    reason: one module
RMAP
  git add -A
}

section "check-risk-map.sh"

risk_project rm-sound; sound_risk_map
expect 0 "a sound map is reported sound" -- bash "$CHECK_MAP" .
expect_output "Risk Map is sound"

# An unmapped project is UNCLASSIFIED, not safe: every path would fall back to
# standard and the sensitive ones would lose what the project requires of them,
# with nothing reporting the loss.
risk_project rm-absent
expect 1 "no map at all fails, and says unclassified rather than safe" -- bash "$CHECK_MAP" .
expect_output "UNCLASSIFIED, not safe"

# An unreadable map is not an empty one. Treating it as empty would classify the
# whole project as unmapped without ever saying the file could not be read.
risk_project rm-garbled
printf 'zones: []\n' > .ia-engineering/risk-map.yml && git add -A
expect 1 "a map that parses to zero zones fails as a parsing fault" -- bash "$CHECK_MAP" .
expect_output "parsing contract"

# Trap 4 — a pattern matching nothing reassures without keeping anything.
risk_project rm-dead; sound_risk_map
sed -i 's|- pattern: "docs/\*"|- pattern: "nowhere/*"|' .ia-engineering/risk-map.yml && git add -A
expect 1 "a dead pattern fails" -- bash "$CHECK_MAP" .
expect_output "matches no tracked file"

# A zone whose only match is present-but-UNTRACKED is not a dead zone — it is
# the state every adopter is in the first time they run this, right after
# bootstrap installs the workflows/Dockerfile/map and before anything is
# committed. The advice must be "commit it", not trap 4's "remove it". The
# fixture points a zone at a file that exists on disk and is deliberately not
# staged; the genuinely-dead case above is the contrast.
risk_project rm-untracked; sound_risk_map
sed -i 's|- pattern: "docs/\*"|- pattern: "staged-later/*"|' .ia-engineering/risk-map.yml
mkdir -p staged-later; echo report > staged-later/report.md   # exists, deliberately NOT staged
git add .ia-engineering/risk-map.yml                          # stage the map edit only
expect 1 "a zone matching a present-but-untracked file says stage it, not remove it" -- bash "$CHECK_MAP" .
expect_output "not tracked yet"

# Trap 3 — verified by computing the level of every tracked file, never by
# re-reading the list. A core module fallen through a removed catch-all is
# invisible any other way.
risk_project rm-uncovered; sound_risk_map
sed -i '/- pattern: "\*"/,+2d' .ia-engineering/risk-map.yml && git add -A
expect 1 "removing the catch-all leaves files unclassified" -- bash "$CHECK_MAP" .
expect_output "match no zone"

# A sensitive entry with no category is what makes coverage uncheckable.
risk_project rm-nocat; sound_risk_map
sed -i '/category: authentication/d' .ia-engineering/risk-map.yml && git add -A
expect 1 "sensitive without a category fails" -- bash "$CHECK_MAP" .
expect_output "names no category"

risk_project rm-badcat; sound_risk_map
sed -i 's/category: authentication/category: invented_category/' .ia-engineering/risk-map.yml && git add -A
expect 1 "a category outside the closed list fails" -- bash "$CHECK_MAP" .
expect_output "closed list"

# A category left unmentioned is switched off silently, so it must be either
# mapped to paths or declared absent.
risk_project rm-uncovered-cat; sound_risk_map
sed -i '/category: core_architecture/,+1d' .ia-engineering/risk-map.yml && git add -A
expect 1 "a category neither mapped nor declared absent fails" -- bash "$CHECK_MAP" .
expect_output "switched off silently"

risk_project rm-noreason; sound_risk_map
sed -i '/reason: nothing reads it at runtime/d' .ia-engineering/risk-map.yml && git add -A
expect 1 "a zone with no reason fails" -- bash "$CHECK_MAP" .
expect_output "has no reason"

# THE COLUMN-SHIFT REGRESSION. A tab is an IFS whitespace character, so `read`
# collapses a run of them even with IFS set to a tab alone. A zone with no
# category emitted two tabs, they became one, every later column shifted left,
# and every routine zone was reported as having no reason — the check was wrong
# about the map and said so confidently. This case pins that: the fixture's
# routine and standard zones carry no category, and the map must still be sound.
risk_project rm-nocategory-columns; sound_risk_map
expect 0 "zones without a category do not shift the later columns" -- bash "$CHECK_MAP" .
expect_output "Risk Map is sound"

# --range: the mechanical trigger the framework was missing. The RISK: record
# already existed in Standards/RISK_STANDARD.md; nothing required it.
risk_project rm-range; sound_risk_map
git commit -q -m "map"
RM_BASE="$(git rev-parse HEAD)"
echo changed > src/auth/login.js && git commit -qam "touch the auth module"
expect 1 "a sensitive change with no RISK record fails" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .
expect_output "no well-formed RISK: record"

echo more >> src/auth/login.js
git commit -qam "touch it again, with a record

RISK: changes the identity check | tier=High | mitigation=reviewed | decided_by=Director"
expect 0 "the same change with a RISK record passes" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

risk_project rm-range-routine; sound_risk_map
git commit -q -m "map"
RM_BASE="$(git rev-parse HEAD)"
echo more >> docs/guide.md && git commit -qam "documentation only"
expect 0 "a routine-only change needs no record" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .
expect_output "highest change zone: routine"

# TROUBLESHOOTING X — the range's commit messages exceed the 64 KB pipe buffer
# and the RISK record is on an early (newest) commit. `git log | grep -q` would
# short-circuit git, git would take SIGPIPE, and pipefail would report the
# record ABSENT while it is right there — blocking a valid sensitive change.
# This case fails against that bug and passes against the here-string fix.
risk_project rm-range-bigmsg; sound_risk_map
git commit -q -m "map"
RM_BASE="$(git rev-parse HEAD)"
echo changed > src/auth/login.js
{
  echo "touch the auth module"
  echo
  echo "RISK: changes the identity check | tier=High | mitigation=reviewed | decided_by=Director"
  echo
  # ~1 MB of body. The threshold where git log's output actually SIGPIPEs the
  # old code was measured at ~620 KB on the development machine (Git Bash) and
  # is 64 KB on a Linux runner, so 30k filler lines reproduces comfortably on
  # both. Below ~40 KB the old code passed here, which is why the first draft
  # of this case proved nothing — it was measured, not guessed.
  yes "filler line to push git log output past the pipe buffer" | head -n 30000
} > "$WORK/bigmsg.txt"
git commit -q -aF "$WORK/bigmsg.txt"
expect 0 "a sensitive change with an early RISK record in a >64KB range still passes" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .
expect_output "RISK: record is present"

# PT2-06 — the record must BE a record, not a mention of one. The gate used to
# accept any line that began with optional whitespace and `RISK:`, so an
# indented or quoted example satisfied it: the opposite of what
# check-work-units.sh and check-employee-trailers.sh tell authors, who are told
# to indent an example so that it does not count.
risk_project rm-range-record; sound_risk_map
git commit -q -m "map"
RM_BASE="$(git rev-parse HEAD)"
echo changed > src/auth/login.js
git commit -qam "touch the auth module, quoting the format

The record format is:

    RISK: changes the identity check | tier=High | mitigation=reviewed | decided_by=Director"
expect 1 "an indented RISK example does not satisfy the gate" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .
expect_output "no well-formed RISK: record"

echo more >> src/auth/login.js
git commit -qam "touch it again, record without a tier

RISK: changes the identity check | mitigation=reviewed | decided_by=Director"
expect 1 "a column-0 RISK line with no tier does not satisfy the gate" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

echo more >> src/auth/login.js
git commit -qam "touch it again, record with an invalid tier

RISK: changes the identity check | tier=Severe | mitigation=reviewed | decided_by=Director"
expect 1 "a RISK line whose tier is not in the closed list does not satisfy the gate" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

echo more >> src/auth/login.js
git commit -qam "touch it again, record without a decider

RISK: changes the identity check | tier=High | mitigation=reviewed"
expect 1 "a RISK line with no decided_by does not satisfy the gate" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

# The field names are whole words with values (Code Reviewer, PR #175). A
# matcher that looked for the substring `tier=` accepted `notier=low`, and one
# that let any non-letter end the tier value accepted `tier=High-ish`; a field
# matched for presence alone accepted `mitigation=` with nothing after it.
echo more >> src/auth/login.js
git commit -qam "touch it again, a field name that merely ends in tier=

RISK: changes the identity check | notier=Low | mitigation=reviewed | decided_by=Director"
expect 1 "notier= is not the tier= field" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

echo more >> src/auth/login.js
git commit -qam "touch it again, a tier value that only starts with a valid one

RISK: changes the identity check | tier=High-ish | mitigation=reviewed | decided_by=Director"
expect 1 "tier=High-ish is not a tier in the closed list" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

echo more >> src/auth/login.js
git commit -qam "touch it again, an empty mitigation

RISK: changes the identity check | tier=High | mitigation= | decided_by=Director"
expect 1 "an empty mitigation= does not satisfy the gate" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

echo more >> src/auth/login.js
git commit -qam "touch it again, an empty decider

RISK: changes the identity check | tier=High | mitigation=reviewed | decided_by="
expect 1 "an empty decided_by= does not satisfy the gate" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .

echo more >> src/auth/login.js
git commit -qam "touch it again, a well-formed record wrapped over two lines

RISK: changes the identity check | tier=High |
mitigation=reviewed | decided_by=Director"
expect 0 "a well-formed column-0 RISK record, wrapped, satisfies the gate" -- bash "$CHECK_MAP" --range "$RM_BASE" HEAD .
expect_output "RISK: record is present"

# PT2-05 — the range is diffed from the merge base. The endpoint diff
# `git diff <base> <head>` also contains the inverse of whatever the base branch
# gained after the fork point: a sensitive file the base moved on was
# attributed to a Pull Request that never touched it.
risk_project rm-range-forked; sound_risk_map
git commit -q -m "map"
RM_MAIN="$(git rev-parse --abbrev-ref HEAD)"
git switch -q -c feature-docs
echo changed > docs/guide.md && git commit -qam "documentation only, on the feature branch"
git switch -q "$RM_MAIN"
echo advanced > src/auth/login.js && git commit -qam "the base branch moves a sensitive file on, after the fork point"
expect 0 "a sensitive file the base advanced after the fork is not attributed to the change" -- bash "$CHECK_MAP" --range "$RM_MAIN" feature-docs .
expect_output "highest change zone: routine"

# ...and a file the change itself touched is still classified.
git switch -q feature-docs
echo changed > src/auth/login.js && git commit -qam "the feature branch touches the sensitive file itself"
expect 1 "a sensitive file the change itself touched is still classified" -- bash "$CHECK_MAP" --range "$RM_MAIN" feature-docs .
expect_output "Sensitive paths touched: src/auth/login.js"

# ...and the under-report in the other direction: the base makes the SAME edit
# to the sensitive file after the fork, so the endpoint diff shows no change to
# it at all and the change set's own sensitive edit went unclassified.
risk_project rm-range-hidden; sound_risk_map
git commit -q -m "map"
RM_MAIN="$(git rev-parse --abbrev-ref HEAD)"
git switch -q -c feature-auth
echo same-edit > src/auth/login.js && git commit -qam "the feature branch touches the sensitive file"
git switch -q "$RM_MAIN"
echo same-edit > src/auth/login.js && git commit -qam "the base branch lands the identical edit after the fork point"
expect 1 "a sensitive edit the base has since duplicated is still attributed to the change" -- bash "$CHECK_MAP" --range "$RM_MAIN" feature-auth .
expect_output "Sensitive paths touched: src/auth/login.js"

expect 2 "an unknown option is a usage error" -- bash "$CHECK_MAP" --nope .

# ------------------------------------------- setup-project-bootstrap.sh -----

section "setup-project-bootstrap.sh — the stack it records"

# --dry-run so nothing is installed: this asserts the declaration, not the
# whole bootstrap, and a dry run is the only shape that can be asserted here
# without a git remote and a full project.
D="$(project bs-dry)"
TOTAL=$((TOTAL + 1))
OUT="$(cd "$D" && bash "$SCRIPTS/setup-project-bootstrap.sh" go --dry-run 2>&1)"
if grep -qF -- "[dry-run] write .ia-engineering/stack containing 'go'" <<< "$OUT"; then
  [ -n "$VERBOSE" ] && printf '   ok   the bootstrap says it will record the stack\n'
else
  printf '   FAIL the bootstrap did not announce writing the stack declaration\n'
  printf '%s\n' "$OUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
fi

TOTAL=$((TOTAL + 1))
if [ -f "$D/.ia-engineering/stack" ]; then
  printf '   FAIL --dry-run wrote the declaration; a dry run must change nothing\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   --dry-run wrote nothing\n'
fi

# The starter Risk Map is announced under --dry-run and, like everything else
# in a dry run, not written.
TOTAL=$((TOTAL + 1))
if grep -qF -- "[dry-run] write .ia-engineering/risk-map.yml" <<< "$OUT"; then
  [ -n "$VERBOSE" ] && printf '   ok   the bootstrap announces the starter Risk Map\n'
else
  printf '   FAIL the bootstrap did not announce the starter Risk Map\n'
  FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
if [ -f "$D/.ia-engineering/risk-map.yml" ]; then
  printf '   FAIL --dry-run wrote the Risk Map; a dry run must change nothing\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   --dry-run wrote no Risk Map\n'
fi

# THE STARTER MUST BE HONEST ABOUT WHAT IT DID NOT DO. Written into a real
# fixture, it must (a) parse, (b) classify the installed files as intended, and
# (c) FAIL the check — naming the categories the bootstrap refused to declare
# absent on the project's behalf. A starter that passed would have guessed.
# Run the REAL bootstrap in a real project, so the test cannot drift from the
# script it checks: whatever the starter map actually is, this is it.
new_repo bs-starter-map
echo x > README.md && git add -A && git commit -q -m "seed"
bash "$SCRIPTS/setup-project-bootstrap.sh" node >/dev/null 2>&1 || true
git add -A >/dev/null 2>&1

TOTAL=$((TOTAL + 1))
if [ -f .ia-engineering/risk-map.yml ]; then
  [ -n "$VERBOSE" ] && printf '   ok   the bootstrap wrote a starter Risk Map\n'
else
  printf '   FAIL the bootstrap wrote no Risk Map\n'; FAILED=$((FAILED + 1))
fi

# The starter fails the check — but ONLY for the honest reason. It names the
# categories the bootstrap refused to declare absent on the project's behalf,
# and it must NOT contain any structural fault: no dead entry, no unclassified
# file. The starter's own crime, caught this way: it once mapped install.sh's
# files, which the stack half does not guarantee, so the map arrived with dead
# entries the moment install.sh had not run.
expect 1 "the starter is honestly incomplete: unaccounted categories are named" -- \
  bash "$SCRIPTS/check-risk-map.sh" .
expect_output "neither mapped to a path nor declared absent"
TOTAL=$((TOTAL + 1))
if grep -qE "matches no tracked file|match no zone" <<< "$LAST_OUTPUT"; then
  printf '   FAIL the starter map ships a dead entry or an unclassified file\n'
  printf '%s\n' "$LAST_OUTPUT" | grep -E "matches no tracked file|match no zone" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   the starter has no dead entry and no unclassified file — only category gaps\n'
fi

# The Dockerfile the stack half installed classifies sensitive.
# Capture, THEN grep. `grep -q` in a pipeline closes the pipe on first match,
# the producer takes SIGPIPE, and `set -o pipefail` reports that as the
# pipeline's failure — so `if producer | grep -q` goes false on a real match
# whenever the producer still had output to write. Captured first, there is no
# pipe to break.
TOTAL=$((TOTAL + 1))
EXPLAIN_OUT="$(bash "$SCRIPTS/check-risk-map.sh" --explain . 2>/dev/null)"
if grep -qE '^Dockerfile sensitive$' <<< "$EXPLAIN_OUT"; then
  [ -n "$VERBOSE" ] && printf '   ok   the starter classifies the installed Dockerfile as sensitive\n'
else
  printf '   FAIL the starter did not classify Dockerfile as sensitive\n'; FAILED=$((FAILED + 1))
fi

# ADOPTION INTO AN EXISTING PROJECT: a file the project already has at one of
# the bootstrap's install paths is its own work, and is left untouched without
# --force. Greenfield never hits this; an already-started project would lose
# real work silently, which is what the Dockerfile guard already prevented and
# what copy_into now does for the workflows too.
new_repo bs-existing-file
mkdir -p .github/workflows
printf 'name: the project own ci-build-test\n' > .github/workflows/ci-build-test.yml
git add -A && git commit -q -m "an existing project with a colliding filename"
before_md5="$(md5sum .github/workflows/ci-build-test.yml | cut -d' ' -f1)"
bash "$SCRIPTS/setup-project-bootstrap.sh" node >/dev/null 2>&1 || true
TOTAL=$((TOTAL + 1))
if [ "$(md5sum .github/workflows/ci-build-test.yml | cut -d' ' -f1)" = "$before_md5" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   an existing ci-build-test.yml is preserved without --force\n'
else
  printf '   FAIL the bootstrap overwrote the project own ci-build-test.yml\n'; FAILED=$((FAILED + 1))
fi
bash "$SCRIPTS/setup-project-bootstrap.sh" node --force >/dev/null 2>&1 || true
TOTAL=$((TOTAL + 1))
if [ "$(md5sum .github/workflows/ci-build-test.yml | cut -d' ' -f1)" != "$before_md5" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   --force replaces it\n'
else
  printf '   FAIL --force did not replace the file\n'; FAILED=$((FAILED + 1))
fi

# --------------------------------------------- install.sh (WU-IAENG-296) ----
#
# install.sh refuses to run unless the FRAMEWORK directory is inside the
# PROJECT (Workflows/ONBOARDING.md Step 1: submodule, copied reference, or
# LINKED directory) -- so these cases link the real framework into a
# throwaway project with `ln -s` rather than copying ~15,000 lines of
# framework source into a fixture. Some Windows configurations refuse to
# create a symlink/junction at all (no admin rights, Developer Mode off);
# when `ln -s` itself fails here, the case is recorded with `skip` (reported,
# excluded from TOTAL and FAILED) rather than reporting a false pass or fail
# for an environment limitation the fix under test cannot control. See
# `skip`'s definition for why CI=true does not get this leniency.

section "install.sh — adopter ignore rules and framework-only eol rules (WU-IAENG-296)"

FRAMEWORK_ROOT="$(cd "$SCRIPTS/../.." && pwd)"

new_repo inst-adopter
if ln -s "$FRAMEWORK_ROOT" ia-engineering 2>/dev/null; then
  bash ./ia-engineering/Adapters/scripts/install.sh >/dev/null 2>&1

  TOTAL=$((TOTAL + 1))
  if grep -qxF ".claude/agents/" .gitignore 2>/dev/null; then
    [ -n "$VERBOSE" ] && printf '   ok   adopter .gitignore ignores .claude/agents/ (generate-agents.sh output)\n'
  else
    printf '   FAIL adopter .gitignore does not ignore .claude/agents/\n'
    FAILED=$((FAILED + 1))
  fi

  TOTAL=$((TOTAL + 1))
  if grep -qxF ".claude/worktrees/" .gitignore 2>/dev/null; then
    [ -n "$VERBOSE" ] && printf '   ok   adopter .gitignore ignores .claude/worktrees/ (isolated subagent worktrees)\n'
  else
    printf '   FAIL adopter .gitignore does not ignore .claude/worktrees/\n'
    FAILED=$((FAILED + 1))
  fi

  TOTAL=$((TOTAL + 1))
  if grep -qxF ".ia-engineering/usage/" .gitignore 2>/dev/null; then
    [ -n "$VERBOSE" ] && printf '   ok   adopter .gitignore ignores .ia-engineering/usage/ (usage-dashboard.sh output)\n'
  else
    printf '   FAIL adopter .gitignore does not ignore .ia-engineering/usage/\n'
    FAILED=$((FAILED + 1))
  fi

  TOTAL=$((TOTAL + 1))
  if [ -f .gitattributes ] && grep -qF '/Adapters/**' .gitattributes; then
    printf '   FAIL adopter .gitattributes carries the framework-only /Adapters/** rule\n'
    FAILED=$((FAILED + 1))
  elif [ -f .gitattributes ] && grep -qF '/Registry/**' .gitattributes; then
    printf '   FAIL adopter .gitattributes carries the framework-only /Registry/** rule\n'
    FAILED=$((FAILED + 1))
  else
    [ -n "$VERBOSE" ] && printf '   ok   adopter .gitattributes carries no /Adapters/** or /Registry/** rule\n'
  fi

  TOTAL=$((TOTAL + 1))
  if [ -f .gitattributes ] && grep -qF '/.github/**' .gitattributes; then
    [ -n "$VERBOSE" ] && printf '   ok   adopter .gitattributes still gets the /.github/** rule\n'
  else
    printf '   FAIL adopter .gitattributes is missing the /.github/** rule\n'
    FAILED=$((FAILED + 1))
  fi

  # The framework repository's OWN .gitattributes governs itself and is not
  # rewritten by an adopter install — it must already carry the framework-only
  # rules that the adopter above correctly did not get.
  TOTAL=$((TOTAL + 1))
  if grep -qF '/Adapters/**' "$FRAMEWORK_ROOT/.gitattributes" \
     && grep -qF '/Registry/**' "$FRAMEWORK_ROOT/.gitattributes"; then
    [ -n "$VERBOSE" ] && printf '   ok   the framework own .gitattributes carries /Adapters/** and /Registry/**\n'
  else
    printf '   FAIL the framework own .gitattributes is missing /Adapters/** or /Registry/**\n'
    FAILED=$((FAILED + 1))
  fi
else
  skip 5 "install.sh adopter ignore/eol rules: ln -s failed on this platform (no admin rights / Developer Mode off) -- not a fix defect."
fi

# ------------------------------------ setup-project-bootstrap.sh symlink ----
#
# WU-IAENG-296 defect 4: the branch-protection hint used to resolve through a
# linked (symlink/junction) framework directory via `realpath
# --relative-to=.`, which CANONICALIZES both sides and so printed the link's
# physical target ("../<physical-target>/...") instead of the link name the
# project actually sees ("./ia-engineering/..."). Same `ln -s` availability
# caveat as above, recorded the same way with `skip`.

section "setup-project-bootstrap.sh — link-safe bootstrap hint (WU-IAENG-296)"

new_repo bs-symlink
if ln -s "$FRAMEWORK_ROOT" ia-engineering 2>/dev/null; then
  OUT="$(bash ./ia-engineering/Adapters/scripts/setup-project-bootstrap.sh generic --dry-run 2>&1)"

  TOTAL=$((TOTAL + 1))
  if grep -qF -- "./ia-engineering/Adapters/scripts/setup-branch-protection.sh" <<< "$OUT"; then
    [ -n "$VERBOSE" ] && printf '   ok   the branch-protection hint stays under the link name\n'
  else
    printf '   FAIL the branch-protection hint did not stay under the link name\n'
    printf '%s\n' "$OUT" | grep -i "branch protection" | sed 's/^/        | /'
    FAILED=$((FAILED + 1))
  fi

  TOTAL=$((TOTAL + 1))
  if grep -qE -- '\.\./[^ ]*Adapters/scripts/setup-branch-protection\.sh' <<< "$OUT"; then
    printf '   FAIL the branch-protection hint resolved through the link to a physical path\n'
    printf '%s\n' "$OUT" | grep -i "branch protection" | sed 's/^/        | /'
    FAILED=$((FAILED + 1))
  else
    [ -n "$VERBOSE" ] && printf '   ok   the branch-protection hint did not resolve to a ../physical-target path\n'
  fi
else
  skip 2 "setup-project-bootstrap.sh link-safe hint: ln -s failed on this platform (no admin rights / Developer Mode off) -- not a fix defect."
fi

# ------------------------------------------------- generate-agents.sh -------
#
# generate-agents.sh lives under Adapters/ai-runtimes/, a sibling of
# Adapters/scripts/ — not one of the check-*.sh scripts this suite otherwise
# exercises. It reads the FRAMEWORK's own Registry/employees.yml (that path
# is not overridable), so every case below points --project at a throwaway
# directory and reads what was generated there, rather than trying to
# construct a fake roster.

GEN="$SCRIPTS/../ai-runtimes/generate-agents.sh"

# Extracts the YAML frontmatter body (between the two `---` delimiters) of a
# generated agent file, so a case can assert on `model:`/`effort:` without
# also matching the same words if they appear in the Employee's prose body.
frontmatter() {
  awk '/^---$/{n++; next} n==1' "$1"
}

section "generate-agents.sh — Frontier key, per-tier effort (WU-IAENG-293)"

# Frontier defaults to fable and appears in the printed tiers: summary the
# Main Agent reads for a per-dispatch Tier Override — but it is never an
# Employee's default tier (Core/CAPABILITY_TIERS.md), so it must never be
# written as any generated agent's `model:`.
D="$(project ga-frontier-default)"
TOTAL=$((TOTAL + 1))
OUT="$(bash "$GEN" --project "$D" --dry-run 2>&1)"
if grep -qF -- "Frontier via Tier Override, Director approval each time -> fable" <<< "$OUT"; then
  [ -n "$VERBOSE" ] && printf '   ok   Frontier defaults to fable in the printed tiers summary\n'
else
  printf '   FAIL the tiers summary does not show Frontier -> fable\n'
  printf '%s\n' "$OUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
fi

D="$(project ga-frontier-written)"
bash "$GEN" --project "$D" >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if grep -rlF "model: fable" "$D/.claude/agents" >/dev/null 2>&1; then
  printf '   FAIL fable was written as an Employee model: — Frontier must never be a default\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   no generated agent has model: fable\n'
fi

# A custom --map frontier=X changes only the printed mapping. No Employee's
# tier ever resolves to Frontier, so no generated file can show it either.
D="$(project ga-frontier-map)"
TOTAL=$((TOTAL + 1))
OUT="$(bash "$GEN" --project "$D" --dry-run --map "frontier=my-frontier-model" 2>&1)"
if grep -qF -- "Frontier via Tier Override, Director approval each time -> my-frontier-model" <<< "$OUT"; then
  [ -n "$VERBOSE" ] && printf '   ok   --map frontier=X overrides the printed mapping\n'
else
  printf '   FAIL --map frontier=X did not change the printed mapping\n'
  printf '%s\n' "$OUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
fi

# Per-tier effort (Director decision, 25 Sep 2026): Strategic Judgment gets
# effort: high by default; Standard Execution inherits — no effort: field at
# all, not an empty one.
D="$(project ga-effort-default)"
bash "$GEN" --project "$D" >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if grep -qx "effort: high" <<< "$(frontmatter "$D/.claude/agents/software-architect.md")"; then
  [ -n "$VERBOSE" ] && printf '   ok   Strategic Judgment (Software Architect) emits effort: high\n'
else
  printf '   FAIL Software Architect frontmatter has no effort: high\n'
  FAILED=$((FAILED + 1))
fi

TOTAL=$((TOTAL + 1))
if grep -q "^effort:" <<< "$(frontmatter "$D/.claude/agents/devops-engineer.md")"; then
  printf '   FAIL Standard Execution (DevOps Engineer) must inherit — no effort: field\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   Standard Execution (DevOps Engineer) has no effort: field (inherits)\n'
fi

# --effort-map overrides the default, mirroring --map.
D="$(project ga-effort-map)"
bash "$GEN" --project "$D" --effort-map "standard=medium,strategic=xhigh" >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if grep -qx "effort: medium" <<< "$(frontmatter "$D/.claude/agents/devops-engineer.md")"; then
  [ -n "$VERBOSE" ] && printf '   ok   --effort-map standard=medium is honoured\n'
else
  printf '   FAIL --effort-map standard=medium was not applied to a Standard Execution Employee\n'
  FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
if grep -qx "effort: xhigh" <<< "$(frontmatter "$D/.claude/agents/software-architect.md")"; then
  [ -n "$VERBOSE" ] && printf '   ok   --effort-map strategic=xhigh is honoured\n'
else
  printf '   FAIL --effort-map strategic=xhigh was not applied to a Strategic Judgment Employee\n'
  FAILED=$((FAILED + 1))
fi

# An invalid effort level is rejected, never silently accepted.
D="$(project ga-effort-invalid)"
expect 2 "an invalid --effort-map value is rejected" -- \
  bash "$GEN" --project "$D" --dry-run --effort-map "standard=bogus"
expect_output "Accepted: low, medium, high, xhigh, max"

# A bare key with no "=" is pattern-matched like --map, so it falls straight
# to the "Unrecognised" error rather than being read as key=value=strategic
# and rejected two lines later with the less clear "Invalid" message.
expect 2 "a bare --effort-map key with no '=' is rejected as unrecognised" -- \
  bash "$GEN" --project "$D" --dry-run --effort-map "strategic"
expect_output "Unrecognised --effort-map entry: strategic"

# An explicit empty override ("strategic=") is a valid way to ask for
# inherit, distinct from an unrecognised value.
D="$(project ga-effort-empty)"
bash "$GEN" --project "$D" --effort-map "strategic=" >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if grep -q "^effort:" <<< "$(frontmatter "$D/.claude/agents/software-architect.md")"; then
  printf '   FAIL --effort-map strategic= (empty) must clear the effort: field\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   --effort-map strategic= (empty) clears the effort: field\n'
fi

# --check stays idempotent against a tree generated with the new fields —
# the whole point of --check is to catch drift, not report drift of its own.
D="$(project ga-check-idempotent)"
bash "$GEN" --project "$D" >/dev/null 2>&1
expect 0 "--check is idempotent against a tree generated with effort: fields" -- \
  bash "$GEN" --project "$D" --check

section "generate-agents.sh — single-pass section extraction edge cases (WU-IAENG-301)"

# A missing LAST wanted section (Failure Modes) used to shrink SECTION_BODIES
# by one element relative to SECTION_NAMES: `read -a` drops a TRAILING empty
# field the same way `IFS=, read -a arr <<< "a,b,"` yields two elements, not
# three. Every consumer indexes SECTION_BODIES and SECTION_NAMES in lockstep,
# so the missing element was read as UNBOUND under `set -u` and aborted the
# whole run instead of just omitting one heading from one generated file.
# Reachable through an adopter's own Domain Employee file — a PROJECT_ROSTER
# entry, exactly the shape built here, not the framework's own roster.
D="$(project ga-missing-last-section)"
mkdir -p "$D/CustomEmployees"
cat > "$D/CustomEmployees/TEST_EMPLOYEE.md" <<'EMPLOYEE'
# Mission

The Test Employee does testing.

# Responsibilities

- Test things.

# Authority

May test.

# Standards Applied

- None.

# Inputs

- Test cases.

# Process

1. Test.

# Outputs

- Results.

# Output Format

Plain text.

# Definition of Done

Tests pass.

# Escalation Rules

Escalate on failure.
EMPLOYEE
mkdir -p "$D/.ia-engineering/Registry"
cat > "$D/.ia-engineering/Registry/employees.yml" <<'ROSTER'
employees:
  - name: Test Employee
    file: CustomEmployees/TEST_EMPLOYEE.md
    category: Testing
    tier: Standard Execution
ROSTER
expect 0 "an Employee file whose last section (Failure Modes) is missing does not abort" -- \
  bash "$GEN" --project "$D"
TOTAL=$((TOTAL + 1))
if [ -f "$D/.claude/agents/test-employee.md" ] && ! grep -qF "## Failure Modes" "$D/.claude/agents/test-employee.md"; then
  [ -n "$VERBOSE" ] && printf '   ok   the missing Failure Modes heading is simply omitted, not padded empty\n'
else
  printf '   FAIL expected test-employee.md to exist with no "## Failure Modes" heading\n'
  FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
if grep -qF "## Escalation Rules" "$D/.claude/agents/test-employee.md" 2>/dev/null; then
  [ -n "$VERBOSE" ] && printf '   ok   the section before the missing one (Escalation Rules) is still present\n'
else
  printf '   FAIL Escalation Rules is missing — the whole tail of sections may have been dropped\n'
  FAILED=$((FAILED + 1))
fi

# A repeated top-level heading must contribute only its FIRST occurrence,
# exactly like the old section_of(): it started "inside" on the first
# exact-text match and EXITED entirely at the very next "# " line, so a
# repeated heading later in the same file never contributed anything — old
# section_of() had already returned by the time it was reached.
D="$(project ga-duplicate-heading)"
mkdir -p "$D/CustomEmployees"
cat > "$D/CustomEmployees/TEST_EMPLOYEE.md" <<'EMPLOYEE'
# Mission

First Mission body.

# Responsibilities

- Test things.

# Mission

Second Mission body should be ignored.

# Authority

May test.
EMPLOYEE
mkdir -p "$D/.ia-engineering/Registry"
cat > "$D/.ia-engineering/Registry/employees.yml" <<'ROSTER'
employees:
  - name: Test Employee
    file: CustomEmployees/TEST_EMPLOYEE.md
    category: Testing
    tier: Standard Execution
ROSTER
bash "$GEN" --project "$D" >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if grep -qF "Second Mission body should be ignored." "$D/.claude/agents/test-employee.md" 2>/dev/null; then
  printf '   FAIL a second occurrence of a heading contributed content — first-occurrence-only is broken\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   a second occurrence of "# Mission" contributes nothing\n'
fi
TOTAL=$((TOTAL + 1))
if grep -qF "First Mission body." "$D/.claude/agents/test-employee.md" 2>/dev/null; then
  [ -n "$VERBOSE" ] && printf '   ok   the first occurrence of "# Mission" is still captured\n'
else
  printf '   FAIL the first occurrence of "# Mission" is missing entirely\n'
  FAILED=$((FAILED + 1))
fi

section "generate-agents.sh — the project's own tier-map (WU-IAENG-327)"

# Before WU-IAENG-327 a project's mapping lived only in --map: the documented
# command, run without it, reverted every Employee to the target defaults, and
# --check blamed Employees/ for what was a mapping difference. The first case
# below is the one that failed on develop: the file was not read at all.

# fm_line <file> <key> — the value of one frontmatter key, or empty.
fm_line() { frontmatter "$1" | sed -n "s/^$2: //p"; }

write_tier_map() {
  mkdir -p "$1/.ia-engineering"
  printf '%s\n' "# test tier-map" "$2" "$3" > "$1/.ia-engineering/tier-map"
}

D="$(project ga-tiermap-honoured)"
write_tier_map "$D" "map=strategic=s-model,standard=e-model,lightweight=l-model,frontier=f-model" \
  "effort-map=strategic=max,standard=low,lightweight=,frontier="
expect 0 "a project tier-map is read by a plain generation" -- bash "$GEN" --project "$D"
expect_output "mapping: file ("
TOTAL=$((TOTAL + 1))
if [ "$(fm_line "$D/.claude/agents/devops-engineer.md" model)" = "e-model" ] \
  && [ "$(fm_line "$D/.claude/agents/devops-engineer.md" effort)" = "low" ] \
  && [ "$(fm_line "$D/.claude/agents/software-architect.md" model)" = "s-model" ] \
  && [ "$(fm_line "$D/.claude/agents/software-architect.md" effort)" = "max" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   the tier-map models and efforts are written into the agents\n'
else
  printf '   FAIL the tier-map was not honoured (DevOps Engineer: %s/%s, Software Architect: %s/%s)\n' \
    "$(fm_line "$D/.claude/agents/devops-engineer.md" model)" "$(fm_line "$D/.claude/agents/devops-engineer.md" effort)" \
    "$(fm_line "$D/.claude/agents/software-architect.md" model)" "$(fm_line "$D/.claude/agents/software-architect.md" effort)"
  FAILED=$((FAILED + 1))
fi
# Frontier stays override-only even when the file names it.
TOTAL=$((TOTAL + 1))
if grep -rlF "model: f-model" "$D/.claude/agents" >/dev/null 2>&1; then
  printf '   FAIL the tier-map frontier= value was written as an Employee model:\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   the tier-map frontier= value is never an Employee model:\n'
fi
expect 0 "--check honours the tier-map: a tree generated from it is current" -- \
  bash "$GEN" --project "$D" --check

# A CRLF checkout of the file must read the same as an LF one.
D="$(project ga-tiermap-crlf)"
mkdir -p "$D/.ia-engineering"
printf 'map=standard=crlf-model\r\neffort-map=standard=medium\r\n' > "$D/.ia-engineering/tier-map"
bash "$GEN" --project "$D" >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [ "$(fm_line "$D/.claude/agents/devops-engineer.md" model)" = "crlf-model" ] \
  && [ "$(fm_line "$D/.claude/agents/devops-engineer.md" effort)" = "medium" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   a CRLF tier-map is honoured\n'
else
  printf '   FAIL a CRLF tier-map was not honoured\n'
  FAILED=$((FAILED + 1))
fi

# Flags win, per tier: --map standard= overrides that tier only, the file
# still supplies strategic.
D="$(project ga-tiermap-flags)"
write_tier_map "$D" "map=strategic=file-strategic,standard=file-standard" "effort-map=standard=low"
expect 0 "flags override the tier-map" -- \
  bash "$GEN" --project "$D" --map standard=flag-standard --effort-map standard=high
expect_output "mapping: flags (over "
TOTAL=$((TOTAL + 1))
if [ "$(fm_line "$D/.claude/agents/devops-engineer.md" model)" = "flag-standard" ] \
  && [ "$(fm_line "$D/.claude/agents/devops-engineer.md" effort)" = "high" ] \
  && [ "$(fm_line "$D/.claude/agents/software-architect.md" model)" = "file-strategic" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   flags win per tier; the file still supplies the tiers no flag names\n'
else
  printf '   FAIL flag/file precedence is wrong (standard: %s, strategic: %s)\n' \
    "$(fm_line "$D/.claude/agents/devops-engineer.md" model)" "$(fm_line "$D/.claude/agents/software-architect.md" model)"
  FAILED=$((FAILED + 1))
fi

# Absent file: the target defaults, said so.
D="$(project ga-tiermap-absent)"
expect 0 "no tier-map: the target defaults apply" -- bash "$GEN" --project "$D"
expect_output "mapping: defaults"
TOTAL=$((TOTAL + 1))
if [ "$(fm_line "$D/.claude/agents/devops-engineer.md" model)" = "sonnet" ] \
  && [ "$(fm_line "$D/.claude/agents/software-architect.md" model)" = "opus" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   without a tier-map the defaults (opus/sonnet) are written\n'
else
  printf '   FAIL without a tier-map the defaults were not written\n'
  FAILED=$((FAILED + 1))
fi

# A malformed file is refused with exit 2, never half-read.
D="$(project ga-tiermap-malformed)"
write_tier_map "$D" "model=standard=x" ""
expect 2 "an unknown tier-map key is refused" -- bash "$GEN" --project "$D" --dry-run
expect_output "line 2 is not understood: 'model=standard=x'"
write_tier_map "$D" "map=standard=x" "just some words"
expect 2 "a tier-map line with no key= is refused" -- bash "$GEN" --project "$D" --dry-run
expect_output "line 3 is not understood"
write_tier_map "$D" "map=bogus=x" ""
expect 2 "an unknown tier inside map= is refused" -- bash "$GEN" --project "$D" --dry-run
# The value errors name the line too, not only the file (review finding m1).
expect_output "/.ia-engineering/tier-map line 2) entry: bogus=x"
write_tier_map "$D" "map=standard=a" "effort-map=standard=turbo"
expect 2 "an invalid effort inside effort-map= is refused" -- bash "$GEN" --project "$D" --dry-run
expect_output "Accepted: low, medium, high, xhigh, max"
expect_output "/.ia-engineering/tier-map line 3) value in 'standard=turbo'"
write_tier_map "$D" "map=standard=a" "map=standard=b"
expect 2 "a tier-map key given twice is refused" -- bash "$GEN" --project "$D" --dry-run
expect_output "'map=' is given twice"

# --check: a mapping difference is named as one, not blamed on Employees/.
D="$(project ga-tiermap-check-drift)"
bash "$GEN" --project "$D" >/dev/null 2>&1
write_tier_map "$D" "map=standard=other-model" ""
expect 1 "--check reports drift after the tier-map changes" -- bash "$GEN" --project "$D" --check
expect_output "differ in the tier mapping only"
expect_output "(mapping only: on disk sonnet, effort: inherit; resolved other-model, effort: inherit)"
TOTAL=$((TOTAL + 1))
if grep -qF "out of date with Employees/" <<< "$LAST_OUTPUT"; then
  printf '   FAIL --check blamed Employees/ for a mapping-only drift\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   --check does not blame Employees/ for a mapping-only drift\n'
fi
# ...and a real content drift is still reported as one.
printf 'hand edit\n' >> "$D/.claude/agents/backend-engineer.md"
expect 1 "--check still reports a content drift as out of date with Employees/" -- \
  bash "$GEN" --project "$D" --check
expect_output "1 out of date with Employees/ or the roster, or missing."

# An effort-only drift shows the effort on both sides; with the model alone it
# printed the same model twice and no difference (review finding M1, part 2).
D="$(project ga-tiermap-effort-drift)"
bash "$GEN" --project "$D" >/dev/null 2>&1
write_tier_map "$D" "effort-map=standard=low" ""
expect 1 "--check reports an effort-only drift" -- bash "$GEN" --project "$D" --check
expect_output "(mapping only: on disk sonnet, effort: inherit; resolved sonnet, effort: low)"

# A ROSTER tier change is not a mapping change, even when the mapping gives
# both tiers the same model and effort (review finding M1). Reproduced with a
# Domain Employee, the only roster a test can edit: Standard Execution, then
# Strategic Judgment, under a tier-map mapping both tiers identically.
D="$(project ga-tiermap-roster-tier)"
mkdir -p "$D/CustomEmployees" "$D/.ia-engineering/Registry"
printf '%s\n' "# Mission" "" "The Tier Employee tests tiers." > "$D/CustomEmployees/TIER_EMPLOYEE.md"
write_tier_map "$D" "map=strategic=same-model,standard=same-model" "effort-map=strategic=,standard="
printf '%s\n' "employees:" "  - name: Tier Employee" "    file: CustomEmployees/TIER_EMPLOYEE.md" \
  "    category: Testing" "    tier: Standard Execution" > "$D/.ia-engineering/Registry/employees.yml"
bash "$GEN" --project "$D" >/dev/null 2>&1
printf '%s\n' "employees:" "  - name: Tier Employee" "    file: CustomEmployees/TIER_EMPLOYEE.md" \
  "    category: Testing" "    tier: Strategic Judgment" > "$D/.ia-engineering/Registry/employees.yml"
expect 1 "--check reports a roster tier change" -- bash "$GEN" --project "$D" --check
expect_output "1 out of date with Employees/ or the roster, or missing."
TOTAL=$((TOTAL + 1))
if grep -qF "mapping only" <<< "$LAST_OUTPUT"; then
  printf '   FAIL a roster tier change was reported as a mapping-only drift\n'
  printf '%s\n' "$LAST_OUTPUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   a roster tier change is not reported as mapping only\n'
fi

# A UTF-8 BOM on line 1 (Windows PowerShell 5.1 writes one) is not part of the
# first key (review finding m2).
D="$(project ga-tiermap-bom)"
mkdir -p "$D/.ia-engineering"
printf '\xef\xbb\xbfmap=standard=bom-model\n' > "$D/.ia-engineering/tier-map"
expect 0 "a tier-map starting with a UTF-8 BOM is read" -- bash "$GEN" --project "$D"
TOTAL=$((TOTAL + 1))
if [ "$(fm_line "$D/.claude/agents/devops-engineer.md" model)" = "bom-model" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   a BOM-prefixed first line is honoured\n'
else
  printf '   FAIL a BOM-prefixed first line was not honoured\n'
  FAILED=$((FAILED + 1))
fi

section "generate-agents.sh --print-tier-map — the mapping a session reads (WU-IAENG-336)"

# Issue #212: the Lightweight and Frontier values were printed only in a
# generation's summary, so a session applying a Tier Override had no model to
# pass and invented one ("sonnet" in a project mapping every tier to
# claude-opus-5-5). --print-tier-map resolves the mapping the way a generation
# does and prints it for session-start.sh; these cases pin that it is the SAME
# resolution (file, defaults, per-tier flags, refusals) and that it writes
# nothing.

D="$(project ga-printmap-file)"
write_tier_map "$D" "map=strategic=s-model,standard=e-model,lightweight=l-model,frontier=f-model" \
  "effort-map=strategic=max,standard=low,lightweight=,frontier="
expect 0 "--print-tier-map prints a project's tier-map" -- bash "$GEN" --project "$D" --print-tier-map
expect_output "# mapping: file ("
expect_output "map=strategic=s-model,standard=e-model,lightweight=l-model,frontier=f-model"
expect_output "effort-map=strategic=max,standard=low,lightweight=,frontier="
TOTAL=$((TOTAL + 1))
if [ -e "$D/.claude" ]; then
  printf '   FAIL --print-tier-map wrote into the project (%s exists)\n' "$D/.claude"
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   --print-tier-map writes nothing\n'
fi

# Its output is itself a tier-map: fed back in, it resolves to the same lines.
PRINTED="$LAST_OUTPUT"
D2="$(project ga-printmap-roundtrip)"
mkdir -p "$D2/.ia-engineering"
printf '%s\n' "$PRINTED" > "$D2/.ia-engineering/tier-map"
expect 0 "--print-tier-map output is a valid tier-map" -- bash "$GEN" --project "$D2" --print-tier-map
TOTAL=$((TOTAL + 1))
if [ "$(grep -v '^#' <<< "$LAST_OUTPUT")" = "$(grep -v '^#' <<< "$PRINTED")" ]; then
  [ -n "$VERBOSE" ] && printf '   ok   the printed mapping round-trips through a tier-map file\n'
else
  printf '   FAIL the printed mapping did not round-trip:\n'
  printf '%s\n--- vs ---\n%s\n' "$PRINTED" "$LAST_OUTPUT" | sed 's/^/        | /'
  FAILED=$((FAILED + 1))
fi

# Absent file: the target defaults, said so, and every tier named.
D="$(project ga-printmap-defaults)"
expect 0 "--print-tier-map without a tier-map prints the target defaults" -- \
  bash "$GEN" --project "$D" --print-tier-map
expect_output "# mapping: defaults (target claude-code"
expect_output "map=strategic=opus,standard=sonnet,lightweight=haiku,frontier=fable"

# The issue's own project: every tier on one model. Lightweight must print it,
# not the target's default and not any other alias.
D="$(project ga-printmap-issue-212)"
write_tier_map "$D" "map=strategic=claude-opus-5-5,standard=claude-opus-5-5,lightweight=claude-opus-5-5,frontier=fable" \
  "effort-map=strategic=high,standard=,lightweight=,frontier="
expect 0 "--print-tier-map on the issue #212 mapping" -- bash "$GEN" --project "$D" --print-tier-map
expect_output "lightweight=claude-opus-5-5,"

# Flags still win per tier over the file.
D="$(project ga-printmap-flags)"
write_tier_map "$D" "map=strategic=file-s,standard=file-e,lightweight=file-l,frontier=file-f" ""
expect 0 "--print-tier-map applies a flag over the file, per tier" -- \
  bash "$GEN" --project "$D" --print-tier-map --map lightweight=flag-l
expect_output "# mapping: flags (over "
expect_output "map=strategic=file-s,standard=file-e,lightweight=flag-l,frontier=file-f"

# A malformed file is refused exactly as a generation refuses it: a session
# must be told the map is broken, never handed a half-read one.
D="$(project ga-printmap-malformed)"
write_tier_map "$D" "map=bogus=x" ""
expect 2 "--print-tier-map refuses a malformed tier-map" -- bash "$GEN" --project "$D" --print-tier-map
expect_output "/.ia-engineering/tier-map line 2) entry: bogus=x"

# It never stands in for --check or --dry-run, which it does not perform.
D="$(project ga-printmap-combined)"
expect 2 "--print-tier-map with --check is refused" -- bash "$GEN" --project "$D" --print-tier-map --check
expect_output "cannot be combined with --check or --dry-run"
expect 2 "--print-tier-map with --dry-run is refused" -- bash "$GEN" --project "$D" --dry-run --print-tier-map
expect_output "cannot be combined with --check or --dry-run"

# ------------------------------------------------- git-hooks/commit-msg -----
#
# WU-IAENG-304 added `perf` as an accepted Conventional Commits type but
# shipped no case that runs commit-msg itself. The row it added to
# escape-hatch-cases.tsv ("allow git commit -m \"perf(db): optimize query
# performance\"") exercises a DIFFERENT hook — the PreToolUse escape-hatch
# guard that blocks --no-verify/--force-shaped Bash commands — and only
# proves a perf(...) commit message does not trip that lexer. It is kept:
# harmless, and a real (if narrow) regression pin for that hook, but it
# proves nothing about commit-msg's own type regex. These cases close that
# gap by running the real commit-msg script against real message files, in a
# real repo, per this file's header ("build a REAL repo and run the REAL
# script").

section "git-hooks/commit-msg — accepted commit types (WU-IAENG-304)"

HOOK="$SCRIPTS/../git-hooks/commit-msg"

# commit-msg resolves the Employee roster from REPO_ROOT/Registry/employees.yml
# (Adapters/git-hooks/commit-msg, "Locate the Employee roster"), so the
# throwaway repo needs one, exactly like check-employee-trailer.sh's cases
# above.
new_repo commit-msg-types
write_employee_roster "Test Employee"
git add -A && git commit -q -m "roster"

cat > msg-perf.txt <<'MSG'
perf(cache): avoid a redundant lookup on the hot path

Work Unit: WU-TEST-001

Employee: Test Employee
MSG
expect 0 "perf(scope): ... with a valid trailer block is accepted" -- \
  bash "$HOOK" msg-perf.txt

cat > msg-fix.txt <<'MSG'
fix(cache): correct an off-by-one on eviction

Work Unit: WU-TEST-001

Employee: Test Employee
MSG
expect 0 "fix(scope): ... (baseline, pre-existing type) is still accepted" -- \
  bash "$HOOK" msg-fix.txt

cat > msg-bad-type.txt <<'MSG'
style(cache): reformat

Work Unit: WU-TEST-001

Employee: Test Employee
MSG
expect 1 "an unrecognised type (style) is rejected" -- \
  bash "$HOOK" msg-bad-type.txt
expect_output "type is one of: feat, fix, docs, refactor, perf, test, chore"

# ------------------------------- merge attribution: commit-msg (WU-IAENG-307) --
#
# A merge is exempt from the subject rule always, and from the Employee trailer
# only while it authors nothing (PT-02 of the #112 exercise). Each case builds a
# real merge in progress and runs the real hook against its message file.

section "git-hooks/commit-msg — merge attribution (WU-IAENG-307)"

# mk_merge_repo <name> — repo with a roster and a `side` branch one commit ahead.
mk_merge_repo() {
  new_repo "$1"
  write_employee_roster "Test Employee"
  git add -A && git commit -q -m "roster"
  git checkout -qb side
  echo side > side.txt && git add -A && git commit -q -m "side work"
  git checkout -q main
  echo main > main.txt && git add -A && git commit -q -m "main work"
}

mk_merge_repo cm-merge-clean
git merge -q --no-commit --no-ff side
printf "Merge branch 'side'\n" > msg-merge.txt
expect 0 "a clean merge with no trailer is accepted" -- bash "$HOOK" msg-merge.txt

mk_merge_repo cm-merge-authored
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
printf "Merge branch 'side'\n" > msg-merge.txt
expect 1 "an authored merge with no trailer is rejected" -- bash "$HOOK" msg-merge.txt
expect_output "missing 'Employee: <Name>' trailer"

printf "Merge branch 'side'\n\nEmployee: Test Employee\n" > msg-merge.txt
expect 0 "an authored merge with a valid trailer is accepted" -- bash "$HOOK" msg-merge.txt

# Classifier unavailable locally: warn and defer to CI, do not block.
printf "Merge branch 'side'\n" > msg-merge.txt
REAL_GIT="$(command -v git)"
mkdir -p "$WORK/shim-hook"
cat > "$WORK/shim-hook/git" <<SHIM
#!/usr/bin/env bash
if [ "\$1" = "merge-tree" ]; then exit 128; fi
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$WORK/shim-hook/git"
expect 0 "an unclassifiable merge warns and is left to CI" -- env PATH="$WORK/shim-hook:$PATH" bash "$HOOK" msg-merge.txt
expect_output "cannot classify this merge locally"

# ----------------------- merge attribution: check-employee-trailers.sh --------

section "check-employee-trailers.sh — merge attribution (WU-IAENG-307)"

# mk_emp_merge_repo <name> — roster committed, then main and `side` diverge.
# BASE is the roster commit. Leaves the shell on main, ready to merge side.
mk_emp_merge_repo() {
  new_repo "$1"
  write_employee_roster "Release Manager" "DevOps Engineer"
  git add -A && git commit -q -m "roster"
  BASE="$(git rev-parse HEAD)"
  git checkout -qb side
  echo side > side.txt && git add -A && git commit -q -m "side work

Employee: DevOps Engineer"
  git checkout -q main
  echo main > main.txt && git add -A && git commit -q -m "main work

Employee: DevOps Engineer"
}

mk_emp_merge_repo mrg-clean
git merge -q --no-ff side -m "Merge branch 'side'"
expect 0 "a clean merge with no trailer passes" -- bash "$CHECK_EMP" "$BASE" HEAD

mk_emp_merge_repo mrg-authored
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'"
expect 1 "an authored merge with no trailer fails" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "carries no Employee trailer"

mk_emp_merge_repo mrg-authored-ok
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'

Employee: DevOps Engineer"
expect 0 "an authored merge with a valid trailer passes" -- bash "$CHECK_EMP" "$BASE" HEAD

# Conflict: both branches edit the same file differently.
mk_emp_conflict() {
  new_repo "$1"
  write_employee_roster "Release Manager" "DevOps Engineer"
  echo base > c.txt
  git add -A && git commit -q -m "roster"
  BASE="$(git rev-parse HEAD)"
  git checkout -qb side
  echo side > c.txt && git add -A && git commit -q -m "side edit

Employee: DevOps Engineer"
  git checkout -q main
  echo main > c.txt && git add -A && git commit -q -m "main edit

Employee: DevOps Engineer"
  git merge --no-commit --no-ff side > /dev/null 2>&1
  echo resolved > c.txt && git add c.txt
}

mk_emp_conflict mrg-conflict
git commit -q -m "Merge branch 'side'"
expect 1 "a conflict-resolved merge with no trailer fails" -- bash "$CHECK_EMP" "$BASE" HEAD

mk_emp_conflict mrg-conflict-ok
git commit -q -m "Merge branch 'side'

Employee: DevOps Engineer"
expect 0 "a conflict-resolved merge with a trailer passes" -- bash "$CHECK_EMP" "$BASE" HEAD

# A claim that is present is always checked, even on a merge that needs none.
mk_emp_merge_repo mrg-clean-bad
git merge -q --no-ff side -m "Merge branch 'side'

Employee: executor"
expect 1 "a clean merge carrying an invalid Employee fails" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "is not a valid Employee name"

mk_emp_merge_repo mrg-octopus
git checkout -qb side2 "$BASE"
echo s2 > side2.txt && git add -A && git commit -q -m "side2 work

Employee: DevOps Engineer"
git checkout -q main
git merge -q --no-ff side side2 -m "Merge branches 'side', 'side2'" > /dev/null 2>&1
expect 1 "a clean octopus merge with no trailer fails (never classified)" -- bash "$CHECK_EMP" "$BASE" HEAD

mk_emp_merge_repo mrg-ours
git merge -q -s ours --no-ff side -m "Merge branch 'side'"
expect 1 "a -s ours merge that discards changes, no trailer, fails" -- bash "$CHECK_EMP" "$BASE" HEAD

# SEC-IAENG-307-01: the grandfather list is a constant inside the script. The
# check runs from the PR's own tree, so any data file in that tree is
# attacker-editable and must NOT be able to exempt a merge. The two real
# grandfathered shas are exercised by running the check over v0.0.13..develop
# (recorded in the PR), since fixture shas cannot be predicted.
mk_emp_merge_repo mrg-exception-ignored
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'"
mkdir -p Registry ia-engineering/Registry
echo "$(git rev-parse HEAD) planted by the PR under test" > Registry/merge-attribution-exceptions.txt
cp Registry/merge-attribution-exceptions.txt ia-engineering/Registry/
expect 1 "an exceptions file planted in the tree does not exempt a merge" -- \
  env IAENG_MERGE_EXCEPTIONS=Registry/merge-attribution-exceptions.txt bash "$CHECK_EMP" "$BASE" HEAD
expect_output "carries no Employee trailer"

# Fail closed on a git too old to classify.
mk_emp_merge_repo mrg-old-git
git merge -q --no-ff side -m "Merge branch 'side'"
REAL_GIT="$(command -v git)"
mkdir -p "$WORK/shim-old"
cat > "$WORK/shim-old/git" <<SHIM
#!/usr/bin/env bash
if [ "\$1" = "version" ]; then echo "git version 2.39.5"; exit 0; fi
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$WORK/shim-old/git"
# 2.39, not anything older: it has merge-tree --write-tree but not
# --attr-source, so it pins the floor the attribute pin raised to 2.40
# (SEC-IAENG-313-01).
expect 1 "git older than 2.40 fails closed" -- env PATH="$WORK/shim-old:$PATH" bash "$CHECK_EMP" "$BASE" HEAD
expect_output "cannot classify"
expect_output "2.40"

# Fail closed: a git whose merge-tree errors must not turn into a pass.
mk_emp_merge_repo mrg-shim
git merge -q --no-ff side -m "Merge branch 'side'"
REAL_GIT="$(command -v git)"
mkdir -p "$WORK/shim"
cat > "$WORK/shim/git" <<SHIM
#!/usr/bin/env bash
# Any argument, not just \$1: the classifier calls
# 'git --attr-source=<tree> merge-tree', so merge-tree is not first.
for a in "\$@"; do [ "\$a" = "merge-tree" ] && exit 128; done
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$WORK/shim/git"
expect 1 "a merge the classifier cannot run on fails closed" -- env PATH="$WORK/shim:$PATH" bash "$CHECK_EMP" "$BASE" HEAD
expect_output "could not be classified"

# ----------------------- merge attribution: check-work-units.sh ---------------

section "check-work-units.sh — merge attribution (WU-IAENG-313, PT2-03)"

# mk_wu_merge_repo <name> — registry committed, then main and `side` diverge,
# each with a registered Work Unit trailer. BASE is the registry commit.
# Leaves the shell on main, ready to merge side.
mk_wu_merge_repo() {
  new_repo "$1"
  write_wu_registry WU-TEST-001 WU-TEST-002
  git add -A && git commit -q -m "registry"
  BASE="$(git rev-parse HEAD)"
  git checkout -qb side
  echo side > side.txt && git add -A && git commit -q -m "side work

Work Unit: WU-TEST-001"
  git checkout -q main
  echo main > main.txt && git add -A && git commit -q -m "main work

Work Unit: WU-TEST-001"
}

mk_wu_merge_repo wmrg-clean
git merge -q --no-ff side -m "Merge branch 'side'"
expect 0 "a clean merge with no Work Unit trailer passes" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "merge, no content of its own"

# This is the PT2-03 repro: before WU-IAENG-313 the script ran
# `git rev-list --no-merges`, never saw the merge, and exited 0 here.
mk_wu_merge_repo wmrg-authored
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'"
expect 1 "an authored merge with no Work Unit trailer fails" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "Merge "
expect_output "carries no 'Work Unit: <WU-ID>' trailer"

mk_wu_merge_repo wmrg-authored-ok
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'

Work Unit: WU-TEST-002"
expect 0 "an authored merge with a registered Work Unit trailer passes" -- bash "$CHECK_WU" "$BASE" HEAD

mk_wu_merge_repo wmrg-authored-unregistered
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'

Work Unit: WU-TEST-999"
expect 1 "an authored merge naming an unregistered Work Unit fails" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "WU-TEST-999"

new_repo wmrg-conflict
write_wu_registry WU-TEST-001
echo base > c.txt
git add -A && git commit -q -m "registry"
BASE="$(git rev-parse HEAD)"
git checkout -qb side
echo side > c.txt && git add -A && git commit -q -m "side edit

Work Unit: WU-TEST-001"
git checkout -q main
echo main > c.txt && git add -A && git commit -q -m "main edit

Work Unit: WU-TEST-001"
git merge --no-commit --no-ff side > /dev/null 2>&1
echo resolved > c.txt && git add c.txt
git commit -q -m "Merge branch 'side'"
expect 1 "a conflict-resolved merge with no Work Unit trailer fails" -- bash "$CHECK_WU" "$BASE" HEAD

mk_wu_merge_repo wmrg-octopus
git checkout -qb side2 "$BASE"
echo s2 > side2.txt && git add -A && git commit -q -m "side2 work

Work Unit: WU-TEST-001"
git checkout -q main
git merge -q --no-ff side side2 -m "Merge branches 'side', 'side2'" > /dev/null 2>&1
expect 1 "a clean octopus merge with no Work Unit trailer fails (never classified)" -- bash "$CHECK_WU" "$BASE" HEAD

mk_wu_merge_repo wmrg-ours
git merge -q -s ours --no-ff side -m "Merge branch 'side'"
expect 1 "a -s ours merge, no Work Unit trailer, fails" -- bash "$CHECK_WU" "$BASE" HEAD

# Fail closed on a git too old to classify.
mk_wu_merge_repo wmrg-old-git
git merge -q --no-ff side -m "Merge branch 'side'"
expect 1 "git older than 2.40 fails closed (work units)" -- env PATH="$WORK/shim-old:$PATH" bash "$CHECK_WU" "$BASE" HEAD
expect_output "cannot classify"
expect_output "2.40"

# Fail closed: a git whose merge-tree errors must not turn into a pass.
mk_wu_merge_repo wmrg-shim
git merge -q --no-ff side -m "Merge branch 'side'"
expect 1 "a merge the classifier cannot run on fails closed (work units)" -- env PATH="$WORK/shim:$PATH" bash "$CHECK_WU" "$BASE" HEAD
expect_output "could not be classified"

# The grandfather list is a constant inside the script, never a data file
# (SEC-IAENG-307-01). Fixture shas cannot be predicted, so the mechanism is
# exercised on a COPY of the scripts whose constant names the fixture merge.
# The two real grandfathered shas are exercised by running the check over
# v0.0.13..develop, recorded in the PR.
mk_wu_merge_repo wmrg-grandfathered
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'"
GF_SHA="$(git rev-parse HEAD)"
mkdir -p "$WORK/gf-scripts"
cp "$CHECK_WU" "$SCRIPTS/merge-classify.sh" "$WORK/gf-scripts/"
sed -i "s/^readonly GRANDFATHERED_MERGES=\"/readonly GRANDFATHERED_MERGES=\"$GF_SHA /" "$WORK/gf-scripts/check-work-units.sh"
expect 0 "a grandfathered authored merge passes" -- bash "$WORK/gf-scripts/check-work-units.sh" "$BASE" HEAD
expect_output "grandfathered"
expect 1 "the same merge fails without the constant naming it" -- bash "$CHECK_WU" "$BASE" HEAD

# A grandfathered merge is skipped before the any-merge claim validation: its
# Work Unit line is history, not a claim the check vouches for (d097e2ed, the
# v0.0.13 back-merge, claims a never-registered WU-IAENG-259).
mk_wu_merge_repo wmrg-grandfathered-claim
git merge -q --no-ff side -m "Merge branch 'side'

Work Unit: WU-TEST-999"
GFC_SHA="$(git rev-parse HEAD)"
mkdir -p "$WORK/gfc-scripts"
cp "$CHECK_WU" "$SCRIPTS/merge-classify.sh" "$WORK/gfc-scripts/"
sed -i "s/^readonly GRANDFATHERED_MERGES=\"/readonly GRANDFATHERED_MERGES=\"$GFC_SHA /" "$WORK/gfc-scripts/check-work-units.sh"
expect 0 "a grandfathered merge's unregistered Work Unit claim is not judged" -- bash "$WORK/gfc-scripts/check-work-units.sh" "$BASE" HEAD
expect_output "grandfathered"
expect 1 "the same claim fails without the constant naming it" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "WU-TEST-999"

# The shipped list is exactly these three shas: widening it is a control
# change that must name itself here.
GF_SHIPPED="$(sed -n 's/^readonly GRANDFATHERED_MERGES="\(.*\)"$/\1/p' "$CHECK_WU" | tr ' ' '\n' | sort | tr '\n' ' ')"
expect 0 "check-work-units.sh grandfathers exactly the three known merges" -- \
  test "$GF_SHIPPED" = "3babf69d9664ddb590acd7381a99fa90d1e40f70 93c850a754a26a050b621d52ac1881645d21be5f d097e2ed66e3e2c45454725664b20abd94b07968 "

# A data file planted in the tree must not exempt a merge.
mkdir -p Registry ia-engineering/Registry
echo "$GF_SHA planted by the PR under test" > Registry/merge-attribution-exceptions.txt
cp Registry/merge-attribution-exceptions.txt ia-engineering/Registry/
expect 1 "an exceptions file planted in the tree does not exempt a merge (work units)" -- \
  env IAENG_MERGE_EXCEPTIONS=Registry/merge-attribution-exceptions.txt bash "$CHECK_WU" "$BASE" HEAD

# The classifier is sourced; its absence must fail closed, not pass.
mkdir -p "$WORK/no-helper"
cp "$CHECK_WU" "$WORK/no-helper/"
expect 1 "a missing merge-classify.sh fails closed (work units)" -- bash "$WORK/no-helper/check-work-units.sh" "$BASE" HEAD
expect_output "merge-classify.sh not found"
cp "$CHECK_EMP" "$WORK/no-helper/"
expect 1 "a missing merge-classify.sh fails closed (employee trailers)" -- bash "$WORK/no-helper/check-employee-trailers.sh" "$BASE" HEAD
expect_output "merge-classify.sh not found"

# SEC-IAENG-313-02: a Work Unit claim present on a merge is validated whatever
# the classification, as an Employee claim is. A clean merge needs no trailer,
# but one naming an unregistered Work Unit is a false record in the history.
mk_wu_merge_repo wmrg-clean-unregistered
git merge -q --no-ff side -m "Merge branch 'side'

Work Unit: WU-TEST-999"
expect 1 "a clean merge naming an unregistered Work Unit fails" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "WU-TEST-999"

mk_wu_merge_repo wmrg-clean-registered
git merge -q --no-ff side -m "Merge branch 'side'

Work Unit: WU-TEST-002"
expect 0 "a clean merge naming a registered Work Unit passes" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "WU-TEST-002 (resolved)"

# SEC-IAENG-313-01: the automatic merge must not read merge drivers from the
# tree under review. With `* merge=union` committed, git resolves the conflict
# by concatenation; an unpinned merge-tree reproduces that same tree and calls
# the merge clean. Pinned to the empty tree's attributes, it conflicts, and the
# merge is authored — as a hand resolution of that shape is.
mk_union_merge_repo() {
  new_repo "$1"
  write_wu_registry WU-TEST-001
  write_employee_roster "DevOps Engineer"
  echo '* merge=union' > .gitattributes
  echo base > c.txt
  git add -A && git commit -q -m "registry"
  BASE="$(git rev-parse HEAD)"
  git checkout -qb side
  echo side > c.txt && git add -A && git commit -q -m "side edit

Work Unit: WU-TEST-001
Employee: DevOps Engineer"
  git checkout -q main
  echo main > c.txt && git add -A && git commit -q -m "main edit

Work Unit: WU-TEST-001
Employee: DevOps Engineer"
  git merge --no-commit --no-ff side > /dev/null 2>&1
  git add -A
  git commit -q -m "Merge branch 'side'"
}

mk_union_merge_repo wmrg-union
expect 1 "a union-attribute merge is classified authored (work units)" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "carries no 'Work Unit: <WU-ID>' trailer"
expect 1 "a union-attribute merge is classified authored (employee trailers)" -- bash "$CHECK_EMP" "$BASE" HEAD
expect_output "carries no Employee trailer"

# A range whose only commit is an authored merge: nothing non-merge to check,
# which the script says, and the merge is still held to the rule. The base is
# the merged branch's tip, so the merge is the sole commit in the range.
new_repo wmrg-merge-only-authored
write_wu_registry WU-TEST-001
git add -A && git commit -q -m "registry"
git checkout -qb develop
echo side > side.txt && git add -A && git commit -q -m "authored work

Work Unit: WU-TEST-001"
git checkout -q main
git merge -q --no-commit --no-ff develop
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge develop into main"
BASE="$(git rev-parse develop)"
expect 1 "a range of one authored merge and no other commit fails" -- bash "$CHECK_WU" "$BASE" HEAD
expect_output "No non-merge commits to check."
expect_output "carries no 'Work Unit: <WU-ID>' trailer"

# CDPATH: with an exported CDPATH, a bare `cd <relative-dir>` resolves through
# it and PRINTS the directory, which a $(cd ... && pwd) capture then holds
# twice — the helper is "not found" and a correct check fails. Invoked by a
# relative path, exactly as a host's job step would.
mk_wu_merge_repo wmrg-cdpath
git merge -q --no-ff side -m "Merge branch 'side'"
mkdir -p tools
cp "$CHECK_WU" "$SCRIPTS/merge-classify.sh" tools/
expect 0 "CDPATH=. with a relative invocation still finds the helper (work units)" -- \
  env CDPATH=. bash tools/check-work-units.sh "$BASE" HEAD
expect_output "merge, no content of its own"

mk_emp_merge_repo mrg-cdpath
git merge -q --no-ff side -m "Merge branch 'side'"
mkdir -p tools
cp "$CHECK_EMP" "$SCRIPTS/merge-classify.sh" tools/
expect 0 "CDPATH=. with a relative invocation still finds the helper (employee trailers)" -- \
  env CDPATH=. bash tools/check-employee-trailers.sh "$BASE" HEAD
expect_output "merge, no content of its own"

# ------------------------------------------ check-inline-suppression.sh -------

CHECK_SUP="$SCRIPTS/check-inline-suppression.sh"

section "check-inline-suppression.sh"

# Directive strings are BUILT BY CONCATENATION. This file is itself a code file
# in the diff of the Pull Request that adds it, and the check it tests scans
# added lines: a literal directive here would be a finding against its own test.
# (The hook's test corpus under hooks/tests/ is exempt by path; this file is
# not, and that is deliberate — code is never exempt.)
D_NOQA="$(printf '%s%s' '#' ' noqa')"
D_NOQA_UPPER="$(printf '%s' "$D_NOQA" | tr '[:lower:]' '[:upper:]')"
D_ESLINT="$(printf '%s%s' '// eslint' '-disable-next-line no-console')"
D_SKIP="$(printf '%s%s' 'it.' 'skip("does a thing", () => {})')"
D_SHELLCHECK="$(printf '%s%s' '# shellcheck' ' disable=SC2034')"
TAB="$(printf '\t')"

# expect_output_absent <string> — the mirror of expect_output.
expect_output_absent() {
  TOTAL=$((TOTAL + 1))
  if grep -qF -- "$1" <<< "$LAST_OUTPUT"; then
    printf '   FAIL output unexpectedly contains: %s\n' "$1"
    printf '%s\n' "$LAST_OUTPUT" | sed 's/^/        | /'
    FAILED=$((FAILED + 1))
    return 1
  fi
  [ -n "$VERBOSE" ] && printf '   ok   output does not contain: %s\n' "$1"
  return 0
}

# sup_repo <name>  — a repository whose HEAD is the base of the change under test.
sup_repo() { new_repo "$1"; SBASE="$(git rev-parse HEAD)"; }

# sup_commit <path> <content>  — writes the file (parents created) and commits it.
sup_commit() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  git add -A
  git commit -q -m "change $1"
}

sup_repo sup-clean
sup_commit a.py 'x = 1'
expect 0 "a change with no directive is clean" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "clean"
expect_output "1 added line(s)"
expect_output "against 5 pattern(s)"

sup_repo sup-flag
sup_commit a.py "x = 1  $D_NOQA"
expect 1 "a directive on an added line is a finding" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "a.py:1: python-lint-suppression:"

sup_repo sup-lineno
sup_commit a.py "$(printf 'a = 1\nb = 2\nc = 3  %s\nd = 4' "$D_NOQA")"
expect 1 "the reported line number is the line in the new file" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "a.py:3: "

sup_repo sup-case
sup_commit a.py "x = 1  $D_NOQA_UPPER"
expect 1 "matching is case-insensitive" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-js
sup_commit src/app.ts "$D_ESLINT"
expect 1 "a directive from another row of the pattern file is reported with that row's label" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "src/app.ts:1: js-ts-suppression:"

sup_repo sup-shell
sup_commit tools/x.sh "$D_SHELLCHECK"
expect 1 "a shell-lint directive is a finding" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "other-suppression"

sup_repo sup-skip
sup_commit spec/a.test.js "$D_SKIP"
expect 1 "a skipped test is a finding" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "skipped-or-focused-test"

sup_repo sup-md
sup_commit README.md "Do not write $D_NOQA in code."
expect 0 "documentation quoting a directive is exempt" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "1 exempt"

sup_repo sup-finalext
sup_commit notes.md.py "x = 1  $D_NOQA"
expect 1 "the extension exemption reads the FINAL extension: notes.md.py is code" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-hooktests
sup_commit Adapters/ai-runtimes/claude-code/hooks/tests/cases.sh "x = 1  $D_NOQA"
expect 0 "a file under hooks/tests/ is exempt" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-patternfile
sup_commit Adapters/scripts/suppression-patterns.tsv "python-lint-suppression${TAB}$D_NOQA"
expect 0 "the pattern file itself is exempt" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-generated
printf 'gen.js linguist-generated=true\n' > .gitattributes
printf '%s\n' "$D_ESLINT" > gen.js
git add -A && git commit -q -m "generated file"
expect 0 "a linguist-generated file is exempt" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-removed
sup_commit a.py "x = 1  $D_NOQA"
SBASE="$(git rev-parse HEAD)"
sup_commit b.py 'y = 2'
sup_commit a.py 'x = 1'
expect 0 "a directive already present, or removed, is not an added line" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-evilmerge
git switch -q -c side
sup_commit side.txt 'side'
git switch -q main
sup_commit main.txt 'main'
SBASE="$(git rev-parse HEAD)"
git merge -q --no-commit --no-ff side
printf '%s\n' "x = 1  $D_NOQA" > evil.py
git add evil.py
git commit -q -m "Merge branch 'side'"
expect 1 "content authored in a merge commit is scanned (merge-base diff)" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "evil.py:1: "

sup_repo sup-big
{ printf '%s\n' "x = 1  $D_NOQA"; yes 'filler line padding padding padding padding' | head -n 30000; } > big.py
git add -A && git commit -q -m "big file"
expect 1 "a directive on line 1 of a payload larger than the pipe buffer is still found" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-truncate
LONG="$(printf 'Z%.0s' $(seq 1 400))"
sup_commit a.py "x = 1  $D_NOQA $LONG"
expect 1 "a long line is reported truncated" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output_absent "$(printf 'Z%.0s' $(seq 1 250))"

sup_repo sup-allow
mkdir -p .ia-engineering
printf '^a\\.py$%s%s%s%s\n' "$TAB" 'x = 1' "$TAB" 'the tool reports a false positive that configuration cannot scope' > .ia-engineering/suppression.allow
sup_commit a.py "x = 1  $D_NOQA"
expect 0 "a finding matched by an allow entry with a reason is allowed" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "1 allowed"

sup_repo sup-allow-noreason
mkdir -p .ia-engineering
printf '^a\\.py$%s%s%s\n' "$TAB" 'x = 1' "$TAB" > .ia-engineering/suppression.allow
sup_commit a.py "x = 1  $D_NOQA"
expect 1 "an allow entry with an empty reason is invalid and fails the check" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "empty reason"

sup_repo sup-allow-twofields
mkdir -p .ia-engineering
printf '^a\\.py$%s%s\n' "$TAB" 'x = 1' > .ia-engineering/suppression.allow
sup_commit a.py "x = 1  $D_NOQA"
expect 1 "an allow entry with fewer than three fields is invalid" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "fewer than three fields"

sup_repo sup-allow-otherpath
mkdir -p .ia-engineering
printf '^other\\.py$%s%s%s%s\n' "$TAB" 'x = 1' "$TAB" 'a reason for a different file' > .ia-engineering/suppression.allow
sup_commit a.py "x = 1  $D_NOQA"
expect 1 "an allow entry whose path expression does not match allows nothing" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-badref
expect 1 "an unresolvable ref fails: nothing was established" -- bash "$CHECK_SUP" "$SBASE" no-such-ref
expect_output "nothing was established"

sup_repo sup-staged
printf '%s\n' "x = 1  $D_NOQA" > a.py
git add a.py
expect 1 "--staged reports a directive in the index" -- bash "$CHECK_SUP" --staged
expect_output "a.py:1: python-lint-suppression:"
git reset -q
rm -f a.py
printf 'x = 1\n' > b.py
git add b.py
expect 0 "--staged is clean when the index holds no directive" -- bash "$CHECK_SUP" --staged

sup_repo sup-nopatterns
mkdir -p "$WORK/sup-noscripts"
cp "$CHECK_SUP" "$WORK/sup-noscripts/"
sup_commit a.py 'x = 1'
expect 1 "a missing pattern file fails closed" -- bash "$WORK/sup-noscripts/check-inline-suppression.sh" "$SBASE" HEAD
expect_output "is missing"

# --- Review findings (SEC-01..07, CR): each case below failed before its fix. ----

# plumb <mode> <path> <content>  — puts a blob in the index at <path> without a
# working-tree file, so a path git allows and a filesystem may not (a newline in
# the name, a symlink on a host without them) is testable everywhere.
plumb() {
  local sha
  sha="$(printf '%s\n' "$3" | git hash-object -w --stdin)"
  git update-index --add --cacheinfo "$1" "$sha" "$2"
}

# SEC-01 (High): the exempt list was newline-separated, so a file NAMED
# "<real path>\n<x>.md" exempted the real file as well. Any newline in a path is
# now refused: a list that cannot represent a name has established nothing.
sup_repo sup-newline
# git on Windows refuses such a name in the index, so the tree is built with
# mktree and committed with commit-tree; no working-tree file is involved.
NL_SHA="$(printf 'x = 1  %s\n' "$D_NOQA" | git hash-object -w --stdin)"
NL_CLEAN="$(printf 'y = 2\n' | git hash-object -w --stdin)"
NL_TREE="$(printf '100644 blob %s\treal.py\x00100644 blob %s\treal.py\nz.md\x00' "$NL_SHA" "$NL_CLEAN" | git mktree -z)"
git update-ref refs/heads/main "$(git commit-tree "$NL_TREE" -p HEAD -m 'newline in a path')"
expect 1 "SEC-01: a path containing a newline is refused, not used to exempt another file" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "newline"

# SEC-02 (High): a file git classifies as binary (a NUL byte, or -diff /
# binary in .gitattributes) prints "Binary files differ" and no lines, so its
# directive was never scanned. --text makes git print the lines.
sup_repo sup-binary-nul
{ printf 'x = 1  %s\n' "$D_NOQA"; printf '\0\0\0\n'; } > bin.py
git add -A && git commit -q -m "binary by NUL"
expect 1 "SEC-02: a file with a NUL byte is scanned as text" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "bin.py:1: "

sup_repo sup-binary-attr
printf '*.dat -diff\n' > .gitattributes
printf 'x = 1  %s\n' "$D_NOQA" > a.dat
git add -A && git commit -q -m "binary by attribute"
expect 1 "SEC-02: a file marked -diff in .gitattributes is scanned as text" -- bash "$CHECK_SUP" "$SBASE" HEAD

# SEC-03 (High): a type change (symlink -> regular file) is diff-filter T, which
# the filter did not list.
sup_repo sup-typechange
plumb 120000 a.py "target.txt"
git commit -q -m "a symlink"
SBASE="$(git rev-parse HEAD)"
plumb 100644 a.py "x = 1  $D_NOQA"
plumb 100644 b.py "y = 2"
git commit -q -m "symlink becomes a file"
expect 1 "SEC-03: a symlink replaced by a regular file is scanned" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "a.py:1: "

# SEC-04 (Medium): */hooks/tests/* exempted ANY hooks/tests directory. Only the
# framework's own corpus is exempt, in-tree or under an adopter's ia-engineering/.
sup_repo sup-hooktests-anywhere
sup_commit src/hooks/tests/x.sh "x = 1  $D_NOQA"
expect 1 "SEC-04: an unrelated src/hooks/tests/ directory is not exempt" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-hooktests-submodule
sup_commit ia-engineering/Adapters/ai-runtimes/claude-code/hooks/tests/x.sh "x = 1  $D_NOQA"
expect 0 "SEC-04: the framework's corpus under ia-engineering/ stays exempt" -- bash "$CHECK_SUP" "$SBASE" HEAD

sup_repo sup-patternfile-elsewhere
sup_commit evil/Adapters/scripts/suppression-patterns.tsv "python-lint-suppression${TAB}$D_NOQA"
expect 1 "SEC-04: a file that merely ends in the pattern file's path is not exempt" -- bash "$CHECK_SUP" "$SBASE" HEAD

# SEC-05 (Low): git appends a TAB to the "+++ b/<path>" header when the path
# contains a space, which became part of the reported (and allow-matched) path.
sup_repo sup-space
sup_commit "my file.py" "x = 1  $D_NOQA"
expect 1 "SEC-05: a path with a space is reported without a trailing TAB" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "my file.py:1: "

# SEC-07 (Low): an allow entry must not be a blanket. A path expression is
# anchored ^...$, and neither expression may match the empty string.
sup_repo sup-allow-blanket
mkdir -p .ia-engineering
printf '.%s.%sa reason\n' "$TAB" "$TAB" > .ia-engineering/suppression.allow
sup_commit a.py "x = 1  $D_NOQA"
expect 1 "SEC-07: an allow entry of . TAB . excuses nothing and is invalid" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "anchored"

sup_repo sup-allow-unanchored
mkdir -p .ia-engineering
printf 'a\\.py%sx = 1%sa reason\n' "$TAB" "$TAB" > .ia-engineering/suppression.allow
sup_commit a.py "x = 1  $D_NOQA"
expect 1 "SEC-07: an allow path expression that is not anchored is invalid" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "anchored"

sup_repo sup-allow-emptymatch
mkdir -p .ia-engineering
printf '^a\\.py$%s.*%sa reason\n' "$TAB" "$TAB" > .ia-engineering/suppression.allow
sup_commit a.py "x = 1  $D_NOQA"
expect 1 "SEC-07: an allow line expression that matches the empty string is invalid" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "empty string"

# Tripwire: one positive sample per row of the REAL pattern file. A pattern that
# was mistyped into something that never matches is otherwise a control that
# passes every test written against a different, working pattern.
sample_for() {
  case "$1" in
    python-lint-suppression)  printf 'x = 1  %s' "$D_NOQA" ;;
    js-ts-suppression)        printf '%s' "$D_ESLINT" ;;
    other-suppression)        printf '%s' "$D_SHELLCHECK" ;;
    skipped-or-focused-test)  printf '%s' "$D_SKIP" ;;
    swallowed-exception)      printf 'except:' ;;
    *) return 1 ;;
  esac
}
sup_repo sup-tripwire
TW_MISSING=""
while IFS= read -r row || [ -n "$row" ]; do
  case "$row" in ''|'#'*) continue ;; esac
  lbl="${row%%"$TAB"*}"
  if s="$(sample_for "$lbl")"; then printf '%s\n' "$s" > "tw_$lbl.py"; else TW_MISSING="$TW_MISSING $lbl"; fi
done < "$SCRIPTS/suppression-patterns.tsv"
git add -A && git commit -q -m "one sample per pattern"
expect 0 "tripwire: every row of the real pattern file has a sample here (add one with the row)" -- test -z "$TW_MISSING"
expect 1 "tripwire: the samples are found" -- bash "$CHECK_SUP" "$SBASE" HEAD
while IFS= read -r row || [ -n "$row" ]; do
  case "$row" in ''|'#'*) continue ;; esac
  lbl="${row%%"$TAB"*}"
  expect_output "tw_$lbl.py:1: $lbl:"
done < "$SCRIPTS/suppression-patterns.tsv"

# Code review: the exits nobody had a case for.
sup_repo sup-backmerge
git switch -q -c side
git switch -q main
sup_commit m.txt 'main moves on'
git switch -q side
git merge -q --no-ff main -m "Merge main into side"
expect 0 "a back-merge (empty diff, no non-merge commit) passes and says why" -- bash "$CHECK_SUP" main HEAD
expect_output "lists no files"

sup_repo sup-emptycommit
git commit -q --allow-empty -m "changes nothing"
expect 1 "a non-merge commit that changed nothing fails closed" -- bash "$CHECK_SUP" "$SBASE" HEAD
expect_output "lists no files"

expect 2 "no arguments is a usage error" -- bash "$CHECK_SUP"
expect 2 "one argument is a usage error" -- bash "$CHECK_SUP" onlyone
expect 2 "--staged with an extra argument is a usage error" -- bash "$CHECK_SUP" --staged extra

sup_repo sup-badpatterns
mkdir -p "$WORK/sup-emptypat" "$WORK/sup-malformedpat"
cp "$CHECK_SUP" "$WORK/sup-emptypat/"
cp "$CHECK_SUP" "$WORK/sup-malformedpat/"
printf '# nothing but a comment\n\n' > "$WORK/sup-emptypat/suppression-patterns.tsv"
printf 'label-without-a-tab\n' > "$WORK/sup-malformedpat/suppression-patterns.tsv"
sup_commit a.py 'x = 1'
expect 1 "a pattern file with no rows fails closed" -- bash "$WORK/sup-emptypat/check-inline-suppression.sh" "$SBASE" HEAD
expect_output "holds no patterns"
expect 1 "a pattern row without a TAB fails closed" -- bash "$WORK/sup-malformedpat/check-inline-suppression.sh" "$SBASE" HEAD
expect_output "without a TAB"

# The allow file is committed knowledge, and .ia-engineering/* is ignored. Without
# the exception an allow entry would sit on one machine and CI would never see it.
expect 1 "the allow file is not gitignored (exception in .gitignore)" -- git -C "$SCRIPTS/../.." check-ignore -q .ia-engineering/suppression.allow

section "data-policy-scan.sh — merge-authored content and binary-classified files (WU-IAENG-312)"

DPS="$SCRIPTS/data-policy-scan.sh"
# Secret-shaped strings are BUILT BY CONCATENATION: the repo's own scanners and
# hooks refuse the literal shape, and this file is in the diff they scan.
DP_AWS="$(printf '%s%s' 'AKIA' 'ABCDEFGHIJKLMNOP')"
DP_SECRET_LINE="aws_access_key_id = $DP_AWS"

# dp_conflict_repo <name> [<.gitattributes line>] — base, then feat and main
# both rewrite app.conf, then `git merge feat` on main stops with a conflict.
# BASE is the shared ancestor. The optional attribute line is committed in base.
dp_conflict_repo() {
  new_repo "$1"
  printf 'mode=base\n' > app.conf
  [ -z "${2:-}" ] || printf '%s\n' "$2" > .gitattributes
  git add -A && git commit -qm "base"
  BASE="$(git rev-parse HEAD)"
  git checkout -qb feat
  printf 'mode=feat\n' > app.conf
  git commit -qam "feat edits app.conf"
  git checkout -q main
  printf 'mode=main\n' > app.conf
  git commit -qam "main edits app.conf"
  git merge feat >/dev/null 2>&1 || true
}

# PT2-01: the secret is written only in the merge resolution.
dp_conflict_repo dp-evil-resolution
printf '%s\n' "$DP_SECRET_LINE" > app.conf
git add app.conf && git commit -qm "Merge feat (resolved)"
expect 1 "PT2-01: a secret written in a conflict resolution is refused in --history" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "app.conf:1"
expect_output "aws-access-key-id"
expect_output_absent "$DP_AWS"

dp_conflict_repo dp-ordinary-control
git merge --abort
printf '%s\n' "$DP_SECRET_LINE" > app.conf
git commit -qam "ordinary commit with the same line"
expect 1 "control: the same line as an ordinary commit is refused" -- bash "$DPS" --history "$BASE..HEAD"

# A merge that adds a NEW file the conflict-free way: `merge --no-commit`, then
# write into the index before committing.
new_repo dp-evil-newfile
BASE="$(git rev-parse HEAD)"
git checkout -qb feat
echo f > f.txt && git add -A && git commit -qm "feat"
git checkout -q main
echo m > m.txt && git add -A && git commit -qm "main"
git merge --no-commit --no-ff feat >/dev/null 2>&1
printf '%s\n' "$DP_SECRET_LINE" > smuggled.conf
git add smuggled.conf && git commit -qm "Merge feat"
expect 1 "PT2-01: a line in a file the merge itself adds is refused" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "smuggled.conf:1"

# A PATH the merge itself adds, whose blob already exists on the excluded side
# (an empty file: the empty blob exists from the first empty file onwards).
# The object walk never lists it, and `log --name-only` skips merges unless
# told how to diff them — so the path was classified by neither source.
new_repo dp-evil-path-only
: > placeholder.txt
git add -A && git commit -qm "an empty file, so the empty blob exists"
BASE="$(git rev-parse HEAD)"
git checkout -qb feat
echo f > f.txt && git add -A && git commit -qm "feat"
git checkout -q main
echo m > m.txt && git add -A && git commit -qm "main"
git merge --no-commit --no-ff feat >/dev/null 2>&1
: > .env
git add .env && git commit -qm "Merge feat"
expect 1 "PT2-01: a refused path the merge itself adds (pre-existing blob) is refused" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "REFUSED  .env"

# Pre-commit path: a conflicted merge's staged resolution is an ordinary
# `diff --cached` against HEAD, so it was already scanned. Pinned, not assumed.
dp_conflict_repo dp-staged-resolution
printf '%s\n' "$DP_SECRET_LINE" > app.conf
git add app.conf
expect 1 "a conflicted merge's staged resolution is refused by --staged" -- bash "$DPS" --staged
expect_output "app.conf"

# Controls: an evil merge with clean content stays clean, and says what it read.
dp_conflict_repo dp-clean-resolution
printf 'mode=resolved\n' > app.conf
git add app.conf && git commit -qm "Merge feat (resolved)"
expect 0 "an authored merge with clean content is clean" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "clean"
# Denominator: one line from each side's commit plus the one the merge authored.
expect_output "3 added line(s)"

# Lines the merge merely carries are not re-scanned: an allowed secret-shaped
# line on the feature side, merged without conflict, stays clean.
new_repo dp-carried-allowed
mkdir -p .ia-engineering
printf 'content:%s\n' 'aws_access_key_id = AKIA[A-Z]{16}' > .ia-engineering/data-policy.allow
git add -A && git commit -qm "allow file"
BASE="$(git rev-parse HEAD)"
git checkout -qb feat
printf '%s\n' "$DP_SECRET_LINE" > example.conf
git add -A && git commit -qm "feat adds an allowed example line"
git checkout -q main
echo m > m.txt && git add -A && git commit -qm "main"
git merge -q --no-ff feat -m "Merge feat"
expect 0 "an allowed line carried in by a clean merge is not refused" -- bash "$DPS" --history "$BASE..HEAD"

# The content allow-list still applies to merge-authored lines.
dp_conflict_repo dp-evil-allowed
mkdir -p .ia-engineering
printf 'content:%s\n' 'aws_access_key_id = AKIA[A-Z]{16}' > .ia-engineering/data-policy.allow
printf '%s\n' "$DP_SECRET_LINE" > app.conf
git add -A && git commit -qm "Merge feat (resolved)"
expect 0 "the content allow file still exempts a merge-authored line" -- bash "$DPS" --history "$BASE..HEAD"

# develop merged into a feature branch: a flagged line develop gained AFTER the
# branch point arrives through the merge's second parent. It is added relative
# to the first parent, so first-parent would re-read it; it is present in the
# second parent, so the dense rule does not. The range excludes develop, where
# the line was accepted. The first-parent patch is shown to contain the line,
# so the control discriminates between the two rules rather than passing under
# both.
new_repo dp-develop-into-feature
git checkout -qb develop
echo d > d.txt && git add -A && git commit -qm "develop before the branch point"
git checkout -qb feature
echo x > x.txt && git add -A && git commit -qm "feature work"
git checkout -q develop
printf '%s\n' "$DP_SECRET_LINE" > legacy.conf
git add -A && git commit -qm "develop moves on, with a line accepted there"
git checkout -q feature
BASE="$(git rev-parse develop)"
git merge -q --no-ff develop -m "Merge develop into feature"
FIRST_PARENT_PATCH="$(git log --diff-merges=first-parent -p --format= "$BASE..HEAD")"
expect 0 "first-parent WOULD re-read the line develop gained after the branch point" -- grep -qF -- "$DP_AWS" <<< "$FIRST_PARENT_PATCH"
expect 0 "develop merged into a feature branch does not re-read develop's lines" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "1 added line(s)"

# A resolution that takes one side verbatim authors nothing: the two sides'
# lines are the whole denominator.
dp_conflict_repo dp-pick-one-side
git checkout -q --theirs app.conf && git add app.conf && git commit -qm "Merge feat (takes feat)"
expect 0 "a resolution that takes one side verbatim is clean and authors nothing" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "2 added line(s)"

# A back-merge (every commit a merge) keeps its named exception.
new_repo dp-backmerge
git checkout -qb develop
echo b > b.txt && git add -A && git commit -qm "authored work B"
git checkout -q main
git merge -q --no-ff develop -m "Merge develop into main"
git checkout -q develop
echo c > c.txt && git add -A && git commit -qm "further work C"
expect 0 "a back-merge range still passes" -- bash "$DPS" --history "develop..main"
expect_output "every one a merge"

# PT2-02: a path marked -diff makes git print "Binary files differ".
new_repo dp-nodiff-attr
BASE="$(git rev-parse HEAD)"
printf 'settings.conf -diff\n' > .gitattributes
printf '%s\n' "$DP_SECRET_LINE" > settings.conf
git add -A && git commit -qm "add settings"
expect 1 "PT2-02: a secret in a -diff path is refused in --history" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "settings.conf:1"
git reset -q --soft "$BASE"
git reset -q
git add -A
expect 1 "PT2-02: a secret in a -diff path is refused by --staged" -- bash "$DPS" --staged
expect_output "settings.conf:1"

# A NUL byte makes git's own heuristic call the file binary.
new_repo dp-nul-binary
BASE="$(git rev-parse HEAD)"
{ printf 'head\0tail\n'; printf '%s\n' "$DP_SECRET_LINE"; } > blob.conf
git add -A && git commit -qm "nul-bearing file"
expect 1 "PT2-02: a secret in a NUL-bearing file is refused in --history" -- bash "$DPS" --history "$BASE..HEAD"

# A genuinely binary file must not crash the scan or be falsely refused.
new_repo dp-real-binary
BASE="$(git rev-parse HEAD)"
printf '\211PNG\r\n\032\n\0\0\0\rIHDR\0\0\0\1\0\0\0\1\010\6\0\0\0\37\25\304\211\0\0\0\nIDAT\170\234c\0\1\0\0\5\0\1\r\n-\264\0\0\0\0IEND\256B`\202' > pixel.png
git add -A && git commit -qm "add a png"
expect 0 "a real PNG is neither refused nor a crash under --text (history)" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "clean"
git reset -q --soft "$BASE"
git reset -q
git add -A
expect 0 "a real PNG is neither refused nor a crash under --text (staged)" -- bash "$DPS" --staged
# WU-IAENG-328: the diff of a NUL-bearing file went through a command
# substitution that printed bash's "ignored null byte in input" warning. The
# NULs are now deleted first: same text scanned, no warning.
DP_NUL_OUT="$LAST_OUTPUT"
expect 1 "a staged binary prints no 'ignored null byte' warning" -- \
  grep -qF "null byte" <<< "$DP_NUL_OUT"
git commit -qm "add a png"
expect 0 "a binary in --history is clean too" -- bash "$DPS" --history "$BASE..HEAD"
DP_NUL_OUT="$LAST_OUTPUT"
expect 1 "a binary in --history prints no 'ignored null byte' warning" -- \
  grep -qF "null byte" <<< "$DP_NUL_OUT"

# SEC-176-01: git's own combined diff ignores --text, so a secret resolved into
# a path marked -diff or binary, or into a NUL-bearing file, printed "Binary
# files differ" and was never scanned. The merge's own lines are now read from
# per-parent diffs, which honour --text.
dp_conflict_repo dp-merge-nodiff-attr 'app.conf -diff'
printf '%s\n' "$DP_SECRET_LINE" > app.conf
git add app.conf && git commit -qm "Merge feat (resolved)"
expect 1 "SEC-176-01: a secret resolved into a -diff path is refused" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "app.conf:1"

dp_conflict_repo dp-merge-binary-attr 'app.conf binary'
printf '%s\n' "$DP_SECRET_LINE" > app.conf
git add app.conf && git commit -qm "Merge feat (resolved)"
expect 1 "SEC-176-01: a secret resolved into a binary-attributed path is refused" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "app.conf:1"

dp_conflict_repo dp-merge-nul
{ printf 'head\0tail\n'; printf '%s\n' "$DP_SECRET_LINE"; } > app.conf
git add app.conf && git commit -qm "Merge feat (resolved)"
expect 1 "SEC-176-01: a secret resolved into a NUL-bearing file is refused" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "app.conf:2"
# WU-IAENG-328: the merge-authored path is quiet about the NUL byte too.
DP_NUL_OUT="$LAST_OUTPUT"
expect 1 "a NUL-bearing merge resolution prints no 'ignored null byte' warning" -- \
  grep -qF "null byte" <<< "$DP_NUL_OUT"

# SEC-176-02: an added line whose text begins "++ " reads "+++ " in the diff
# and was taken for a path header — never scanned, and every later line
# attributed to a path that does not exist. It is also counted.
new_repo dp-plusplus
BASE="$(git rev-parse HEAD)"
printf '++ %s\n' "$DP_SECRET_LINE" > notes.conf
git add -A && git commit -qm "a line that begins with ++"
expect 1 "SEC-176-02: an added line beginning with ++ is scanned in --history" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "notes.conf:1"
expect_output "1 added line(s)"
git reset -q --soft "$BASE"
git reset -q
git add -A
expect 1 "SEC-176-02: an added line beginning with ++ is scanned by --staged" -- bash "$DPS" --staged
expect_output "notes.conf:1"

# SEC-176-03: a symlink replaced by a regular file is a type change (filter
# T), which ACMR excluded — the staged scan listed "0 path(s)" and read no
# line. The symlink is written to the index directly, so the case does not
# depend on the platform supporting symlinks.
new_repo dp-typechange
LINK_BLOB="$(printf 'target.txt' | git hash-object -w --stdin)"
git update-index --add --cacheinfo "120000,$LINK_BLOB,link.conf"
git commit -qm "a symlink"
BASE="$(git rev-parse HEAD)"
printf '%s\n' "$DP_SECRET_LINE" > link.conf
FILE_BLOB="$(git hash-object -w link.conf)"
git update-index --add --cacheinfo "100644,$FILE_BLOB,link.conf"
expect 1 "SEC-176-03: a symlink replaced by a regular file with a secret is refused by --staged" -- bash "$DPS" --staged
expect_output "link.conf:1"
git commit -qm "the symlink becomes a file"
expect 1 "SEC-176-03: the same type change is refused in --history" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "link.conf:1"

# An octopus merge (three parents) that adds a file of its own.
new_repo dp-octopus
BASE="$(git rev-parse HEAD)"
git checkout -qb a && echo a > a.txt && git add -A && git commit -qm "a"
git checkout -q main && git checkout -qb b && echo b > b.txt && git add -A && git commit -qm "b"
git checkout -q main
git merge --no-commit --no-ff a b >/dev/null 2>&1
printf '%s\n' "$DP_SECRET_LINE" > oct.conf
git add oct.conf && git commit -qm "Octopus merge"
expect 1 "a secret in a file an octopus merge adds is refused" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "oct.conf:1"

# dp_multihunk_repo <name> — both sides rewrite three separated lines of
# app.conf, so the resolution has three places to pick a side or write anew.
dp_multihunk_repo() {
  new_repo "$1"
  printf 'a=base\nkeep\nb=base\nkeep2\nc=base\n' > app.conf
  git add -A && git commit -qm "base"
  BASE="$(git rev-parse HEAD)"
  git checkout -qb feat
  printf 'a=feat\nkeep\nb=feat\nkeep2\nc=feat\n' > app.conf
  git commit -qam "feat"
  git checkout -q main
  printf 'a=main\nkeep\nb=main\nkeep2\nc=main\n' > app.conf
  git commit -qam "main"
  git merge feat >/dev/null 2>&1 || true
}

# Picks main for a, feat for b and c: nothing is the merge's own.
dp_multihunk_repo dp-multihunk-picks
printf 'a=main\nkeep\nb=feat\nkeep2\nc=feat\n' > app.conf
git add app.conf && git commit -qm "Merge feat (picks sides)"
expect 0 "a multi-hunk resolution that picks a side in every hunk is clean" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "6 added line(s)"

# Picks main for a, writes a new line for b, feat for c: one line is the
# merge's own, and it is reported at its line in the result.
dp_multihunk_repo dp-multihunk-authored
printf 'a=main\nkeep\n%s\nkeep2\nc=feat\n' "$DP_SECRET_LINE" > app.conf
git add app.conf && git commit -qm "Merge feat (one new line)"
expect 1 "a multi-hunk resolution with one new line is refused at that line" -- bash "$DPS" --history "$BASE..HEAD"
expect_output "app.conf:3"
expect_output "7 added line(s)"

# ------------- pr-validation.yml — graders cannot be reconfigured by a PR -----
# WU-IAENG-310. The required checks run inside the PR's own checkout, so a
# grader that resolves its configuration from that tree can be reconfigured by
# the change it grades. These are content guards on the workflow (the Adapter
# and this repository's installed copy), so the hardenings cannot regress
# silently. They assert INVARIANTS over every code line (comments are stripped
# first, so a comment cannot satisfy or trip a guard): every shellcheck call
# carries --norc, every npx call is the pinned, isolated one.
#
# Literals containing a dollar sign come from a quoted heredoc rather than a
# single-quoted string, so shellcheck (which grades this file) sees no
# expansion to warn about and no suppression directive is needed.

PRV_NPX_LITERAL="$(cat <<'LITERAL'
(cd "$GRADER_DIR" && npx --yes -q "js-yaml@${JS_YAML_VERSION}"
LITERAL
)"
PRV_TRAP_LITERAL="$(cat <<'LITERAL'
trap 'rm -rf "$GRADER_DIR"' EXIT
LITERAL
)"
PRV_MKTEMP_LITERAL="$(cat <<'LITERAL'
GRADER_DIR="$(mktemp -d)"
LITERAL
)"
PRV_CACHE_LITERAL="$(cat <<'LITERAL'
export NPM_CONFIG_CACHE="$GRADER_DIR/npm-cache"
LITERAL
)"
PRV_LOOP_LITERAL="$(cat <<'LITERAL'
for f in "${YAML_FILES[@]}"; do
LITERAL
)"

# prv_code <file> — the workflow with comment lines and trailing comments removed.
prv_code() {
  sed -E -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*//' "$1"
}

# prv_line_of <file> <literal> — line number of the first code line containing it.
prv_line_of() {
  prv_code "$1" | grep -nF -m1 -- "$2" | cut -d: -f1
}

# prv_guard <file> — exit 0 when every grader-isolation invariant holds,
# otherwise print what is broken and exit 1.
prv_guard() {
  local file="$1" bad=0 n line loop_at at sc_calls
  sc_calls="$(prv_code "$file" | grep -E '(^|[;&|(])[[:space:]]*shellcheck([[:space:]]|$)')"
  if [ -z "$sc_calls" ]; then
    echo "no shellcheck invocation found"; bad=1
  fi
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      *--norc*) ;;
      *) if ! grep -Eq '^[[:space:]]*shellcheck --version[[:space:]]*$' <<< "$line"; then
           echo "shellcheck call without --norc: $line"; bad=1
         fi ;;
    esac
  done <<< "$sc_calls"
  if ! grep -q -- '--norc -x' <<< "$sc_calls"; then
    echo "the grading shellcheck call is missing"; bad=1
  fi

  n="$(prv_code "$file" | grep -c 'npx')"
  if [ "$n" -lt 1 ]; then
    echo "no npx invocation found"; bad=1
  fi
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      *"$PRV_NPX_LITERAL"*) ;;
      *) echo "npx call is not the pinned, isolated one: $line"; bad=1 ;;
    esac
  done < <(prv_code "$file" | grep 'npx')

  if ! grep -Eq '^[[:space:]]*JS_YAML_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' <<< "$(prv_code "$file")"; then
    echo "JS_YAML_VERSION is not an exact x.y.z"; bad=1
  fi
  if ! grep -qF -- "$PRV_MKTEMP_LITERAL" <<< "$(prv_code "$file")"; then
    echo "grader directory is not created with mktemp -d"; bad=1
  fi
  if ! grep -qF -- "$PRV_TRAP_LITERAL" <<< "$(prv_code "$file")"; then
    echo "no trap removing the grader directory"; bad=1
  fi
  loop_at="$(prv_line_of "$file" "$PRV_LOOP_LITERAL")"
  for at in 'export NPM_CONFIG_USERCONFIG=/dev/null' "$PRV_CACHE_LITERAL"; do
    n="$(prv_line_of "$file" "$at")"
    if [ -z "$n" ] || [ -z "$loop_at" ] || [ "$n" -ge "$loop_at" ]; then
      echo "missing, or not before the parse loop: $at"; bad=1
    fi
  done
  return "$bad"
}

# prv_expect <expected-exit> <description> <file> — like expect, but calls
# prv_guard directly (shellcheck cannot see a function named only as an
# argument to expect, and reports it as never invoked).
prv_expect() {
  local want="$1" desc="$2" file="$3" got
  TOTAL=$((TOTAL + 1))
  LAST_OUTPUT="$(prv_guard "$file" 2>&1)"
  got=$?
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

for PRV in "$SCRIPTS/../github-actions/pr-validation.yml" "$SCRIPTS/../../.github/workflows/pr-validation.yml"; do
  PRV_NAME="${PRV#"$SCRIPTS"/../}"
  prv_expect 0 "$PRV_NAME: grader-isolation invariants hold" "$PRV"
done

# Mutation cases: the same guard, fed a workflow with one hardening undone, must
# fail. Without these the guard could pass on anything.
PRV_SRC="$SCRIPTS/../github-actions/pr-validation.yml"
mkdir -p "$WORK/prv-mut"
prv_mutant() { # <name> <sed args...>
  local name="$1"; shift
  sed -E "$@" "$PRV_SRC" > "$WORK/prv-mut/$name.yml"
}
prv_mutant no-norc         -e 's/shellcheck --norc/shellcheck/'
prv_mutant unpinned-latest -e 's/js-yaml@[$]\{JS_YAML_VERSION\}/js-yaml@latest/'
prv_mutant unpinned-major  -e 's/^([[:space:]]*JS_YAML_VERSION=")[0-9.]+"/\14"/'
prv_mutant cd-elsewhere    -e 's/GRADER_DIR" && npx/PWD" \&\& npx/'
prv_mutant no-userconfig   -e '/export NPM_CONFIG_USERCONFIG/d'
prv_mutant no-cache        -e '/export NPM_CONFIG_CACHE/d'
prv_mutant no-trap         -e '/^[[:space:]]*trap /d'
prv_mutant no-mktemp       -e 's/mktemp -d/pwd/'
{ cat "$PRV_SRC"; printf '          shellcheck -x extra.sh\n'; } > "$WORK/prv-mut/bare-second-call.yml"
{ cat "$PRV_SRC"; printf '          npx --yes -q js-yaml extra.yml\n'; } > "$WORK/prv-mut/bare-npx.yml"
# --norc kept only in a comment: the guard must not be satisfied by it.
{ sed -E 's/shellcheck --norc/shellcheck/' "$PRV_SRC"; printf '          # shellcheck --norc -x is only mentioned in a comment\n'; } > "$WORK/prv-mut/comment-only.yml"
for m in no-norc unpinned-latest unpinned-major cd-elsewhere no-userconfig no-cache no-trap no-mktemp bare-second-call bare-npx comment-only; do
  prv_expect 1 "guard rejects the mutant: $m" "$WORK/prv-mut/$m.yml"
done

# ------------- workflows — a checkout needs contents: read (WU-IAENG-317) -----
# Declaring a permissions block sets every unlisted scope to none, so a job that
# declares one, checks out, and omits `contents: read` cannot read its own
# repository: actions/checkout fails with "repository not found" on a private
# repository (issue 180). A job with no block of its own inherits the workflow
# level block, if any. Comments are stripped first.

# wfp_guard <file> — print each offending job and return 1, else return 0.
wfp_guard() {
  sed -E -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*//' "$1" | awk '
    function flush() {
      if (job == "") return
      has = jp ? 1 : wh
      ok = jp ? jc : wc
      if (co && has && !ok) {
        print "job " job ": checks out but its permissions lack contents: read"
        bad = 1
      }
    }
    /^permissions:/ { wh = 1; scope = "w"; next }
    /^[A-Za-z]/ { scope = ""; injobs = ($0 ~ /^jobs:/) ; next }
    injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
      flush(); job = $1; sub(/:$/, "", job); jp = 0; jc = 0; co = 0; scope = "j"; next
    }
    /^    permissions:/ { jp = 1; scope = "jp"; next }
    /^    [A-Za-z_-]+:/ { scope = "j" }
    scope == "w" && /^  contents:[[:space:]]*(read|write)/ { wc = 1 }
    scope == "jp" && /^      contents:[[:space:]]*(read|write)/ { jc = 1 }
    /actions\/checkout/ { co = 1 }
    END { flush(); exit bad }
  '
}

# wfp_expect <expected-exit> <description> <file> — like prv_expect.
wfp_expect() {
  local want="$1" desc="$2" file="$3" got
  TOTAL=$((TOTAL + 1))
  LAST_OUTPUT="$(wfp_guard "$file" 2>&1)"
  got=$?
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

for WFP in "$SCRIPTS"/../github-actions/*.yml "$SCRIPTS"/../../.github/workflows/*.yml; do
  WFP_NAME="${WFP#"$SCRIPTS"/../}"
  wfp_expect 0 "$WFP_NAME: every job that checks out and declares permissions grants contents: read" "$WFP"
done

# Mutation cases: the shape of the develop workflow before the fix (the
# review-recorded job without contents: read), and a workflow-level block
# without it. The guard must reject both, or it could pass on anything.
mkdir -p "$WORK/wfp-mut"
sed -E '/^  review-recorded:/,/^    steps:/{/contents: read/d}' "$SCRIPTS/../github-actions/pr-validation.yml" > "$WORK/wfp-mut/job-without-contents.yml"
printf 'permissions:\n  issues: read\n\njobs:\n  a:\n    steps:\n      - uses: actions/checkout@v4\n' > "$WORK/wfp-mut/workflow-level-without-contents.yml"
wfp_expect 1 "guard rejects the mutant: a job block without contents: read" "$WORK/wfp-mut/job-without-contents.yml"
wfp_expect 1 "guard rejects the mutant: an inherited workflow block without contents: read" "$WORK/wfp-mut/workflow-level-without-contents.yml"
if [ "$(wfp_guard "$WORK/wfp-mut/job-without-contents.yml")" != "job review-recorded: checks out but its permissions lack contents: read" ]; then
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL the guard names the offending job\n'
fi

# ------------------------------------- check-control-paths.sh (WU-IAENG-309) --

CHECK_CP="$SCRIPTS/check-control-paths.sh"

# CP_RUN <printf-%b-text-of-the-path-list> [-z]
CP_RUN=(bash -c "printf '%b' \"\$1\" | bash '$CHECK_CP' \"\${@:2}\"" _)

section "check-control-paths.sh — the pull_request_target guard's path matcher (WU-IAENG-309)"

expect 0 "ordinary source and docs paths are not control paths" -- "${CP_RUN[@]}" 'src/app.c\nREADME.md\ndocs/a.md\n'
expect_output "none of the 3"
expect 0 "an empty change list passes" -- "${CP_RUN[@]}" ''
expect 1 "a workflow file is a control path" -- "${CP_RUN[@]}" 'src/a.c\n.github/workflows/pr-validation.yml\n'
expect_output "control path touched: .github/workflows/pr-validation.yml"
expect 1 "the Adapter copy of a workflow is a control path" -- "${CP_RUN[@]}" 'Adapters/github-actions/data-policy.yml\n'
expect 1 "a git hook is a control path" -- "${CP_RUN[@]}" 'Adapters/git-hooks/commit-msg\n'
expect 1 "a check script is a control path" -- "${CP_RUN[@]}" 'Adapters/scripts/check-employee-trailers.sh\n'
expect 1 "a check script test is a control path" -- "${CP_RUN[@]}" 'Adapters/scripts/tests/run.sh\n'
expect 1 "the suppression pattern file is a control path" -- "${CP_RUN[@]}" 'Adapters/scripts/suppression-patterns.tsv\n'
expect 1 "a runtime hook at depth is a control path" -- "${CP_RUN[@]}" 'Adapters/ai-runtimes/claude-code/hooks/tests/x.tsv\n'
expect 0 "a runtime file outside hooks/ is not" -- "${CP_RUN[@]}" 'Adapters/ai-runtimes/claude-code/README.md\n'
expect 1 ".claude/settings.json is a control path" -- "${CP_RUN[@]}" '.claude/settings.json\n'
expect 1 "the roster is a control path" -- "${CP_RUN[@]}" 'Registry/employees.yml\n'
expect 0 "another registry file is not" -- "${CP_RUN[@]}" 'Registry/work-units.yml\n'
expect 1 "an allow file is a control path" -- "${CP_RUN[@]}" '.ia-engineering/suppression.allow\n'
expect 1 "the risk map is a control path" -- "${CP_RUN[@]}" '.ia-engineering/risk-map.yml\n'
expect 1 "the root ignore file is a control path" -- "${CP_RUN[@]}" '.gitignore\n'
expect 1 "the root attributes file is a control path" -- "${CP_RUN[@]}" '.gitattributes\n'
expect 1 "an attributes file at depth is a control path" -- "${CP_RUN[@]}" 'vendor/lib/deep/.gitattributes\n'
expect 1 "docs/CODEOWNERS is a control path" -- "${CP_RUN[@]}" 'docs/CODEOWNERS\n'
expect 1 "a .shellcheckrc at the root is a control path" -- "${CP_RUN[@]}" '.shellcheckrc\n'
expect 1 "a .shellcheckrc at depth is a control path" -- "${CP_RUN[@]}" 'Adapters/x/y/.shellcheckrc\n'
expect 1 "an .npmrc at the root is a control path" -- "${CP_RUN[@]}" '.npmrc\n'
expect 1 "an .npmrc at depth is a control path" -- "${CP_RUN[@]}" 'tools/web/.npmrc\n'
expect 1 "the root package.json is a control path" -- "${CP_RUN[@]}" 'package.json\n'
expect 1 "package-lock.json is a control path" -- "${CP_RUN[@]}" 'package-lock.json\n'
expect 1 "node_modules content is a control path" -- "${CP_RUN[@]}" 'node_modules/.bin/x\n'
expect 0 "a nested package.json is not" -- "${CP_RUN[@]}" 'examples/app/package.json\n'
expect 1 "a runtime settings example is a control path" -- "${CP_RUN[@]}" 'Adapters/ai-runtimes/claude-code/settings.example.json\n'
expect 1 "a runtime install-hooks.sh is a control path" -- "${CP_RUN[@]}" 'Adapters/ai-runtimes/claude-code/install-hooks.sh\n'
expect 1 "generate-agents.sh is a control path" -- "${CP_RUN[@]}" 'Adapters/ai-runtimes/generate-agents.sh\n'
expect 0 ".claude/agents stays out of the list" -- "${CP_RUN[@]}" '.claude/agents/x.md\n.claude/commands/y.md\n'
expect 1 ".gitmodules is a control path"-- "${CP_RUN[@]}" '.gitmodules\n'
expect 1 "the ia-engineering gitlink is a control path" -- "${CP_RUN[@]}" 'ia-engineering\n'
expect 0 "a file merely inside a similarly named directory is not the gitlink" -- "${CP_RUN[@]}" 'docs/ia-engineering\nia-engineering-notes.md\n'
expect 1 "matching is case-insensitive (fail closed)" -- "${CP_RUN[@]}" '.GitHub/Workflows/x.yml\n'
expect 1 "a name with a space is matched, not split" -- "${CP_RUN[@]}" 'Adapters/scripts/a b.sh\n'
expect 1 "a leading-dash name under a control path is matched" -- "${CP_RUN[@]}" 'Adapters/scripts/-rf\n'
expect 0 "a leading-dash ordinary name is inert" -- "${CP_RUN[@]}" '-rf\n'
expect 1 "a .. component is refused, not trusted" -- "${CP_RUN[@]}" 'src/../Adapters/scripts/x\n'
expect 1 "an absolute path is refused" -- "${CP_RUN[@]}" '/etc/passwd\n'
expect 1 "a ./ component is refused" -- "${CP_RUN[@]}" './src/a.c\n'
# The NUL-delimited form is what the workflow feeds: a newline inside a name
# must not split it into a second, control-looking, path.
expect 0 "a newline inside a name does not fabricate a control path (-z)" -- "${CP_RUN[@]}" 'src/x\n.github/workflows/y\0' -z
expect_output "none of the 1"
expect 1 "a newline before a real control path still flags it (-z)" -- "${CP_RUN[@]}" 'a\nb\0.github/workflows/y\0' -z
expect 1 "one control path among many NUL-delimited names (-z)" -- "${CP_RUN[@]}" 'a b\0-x\0Adapters/git-hooks/pre-push\0c\0' -z
expect 2 "an unknown option is a usage error" -- "${CP_RUN[@]}" 'a\n' --bogus

# ------------------------- adopter registry and install (WU-IAENG-320) --------
#
# DEF-1/12/13/14 of the 2 Oct 2026 adoption test (issue #181). A consumer
# project carries the framework under ia-engineering/; the Work Unit Exists
# check must read the PROJECT's registry and never the framework's.

section "check-work-units.sh — a consumer reads its own registry (WU-IAENG-320, DEF-1)"

# mk_consumer <name> — a project whose ia-engineering/ holds the check and its
# helper (a copy, not a link, so the case runs where `ln -s` does not), plus a
# framework registry that lists a framework-only id. Leaves the shell inside it.
mk_consumer() {
  new_repo "$1"
  mkdir -p ia-engineering/Adapters/scripts ia-engineering/Registry
  cp "$CHECK_WU" "$SCRIPTS/merge-classify.sh" ia-engineering/Adapters/scripts/
  printf 'work_units:\n  - id: WU-FRAMEWORK-137\n    employee: Release Manager\n    title: framework only\n    milestone: Testing\n' \
    > ia-engineering/Registry/work-units.yml
}
CONSUMER_WU="ia-engineering/Adapters/scripts/check-work-units.sh"

mk_consumer cons-own
write_wu_registry WU-QA-1 WU-QA-2
git add -A && git commit -q -m "registry

Work Unit: WU-QA-1"
BASE="$(git rev-parse HEAD)"
commit_with "feat: the project's own Work Unit" "Work Unit: WU-QA-2"
expect 0 "a consumer commit claiming a Work Unit in the PROJECT registry passes" -- bash "$CONSUMER_WU" "$BASE" HEAD
expect_output "(resolved)"

mk_consumer cons-fw-only
write_wu_registry WU-QA-1
git add -A && git commit -q -m "registry

Work Unit: WU-QA-1"
BASE="$(git rev-parse HEAD)"
commit_with "feat: claims a framework-only id" "Work Unit: WU-FRAMEWORK-137"
expect 1 "a consumer commit claiming a framework-only id fails" -- bash "$CONSUMER_WU" "$BASE" HEAD
expect_output "WU-FRAMEWORK-137"

mk_consumer cons-no-registry
git add -A && git commit -q -m "no project registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: claims a framework id with no project registry" "Work Unit: WU-FRAMEWORK-137"
expect 1 "a consumer with no project registry fails, never falling back to the framework's" -- bash "$CONSUMER_WU" "$BASE" HEAD
expect_output "This project has no Work Unit registry"
expect_output "Registry/work-units.yml"

# The starter the bootstrap writes is an EMPTY list. It must not read as a
# parsing failure: the commit that registers the first Work Unit adds an entry
# in the same change, and a commit that registers nothing fails for the true
# reason, an unregistered id.
mk_consumer cons-empty
mkdir -p Registry && printf 'work_units:\n' > Registry/work-units.yml
git add -A && git commit -q -m "starter registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: nothing registered yet" "Work Unit: WU-QA-1"
expect 1 "an empty starter registry reports the unregistered id, not a parsing failure" -- bash "$CONSUMER_WU" "$BASE" HEAD
expect_output "claims 'WU-QA-1', which is not in"

# SEC-IAENG-320-01: with an empty registry, a bare `Work Unit: ` line (written
# with --cleanup=verbatim, which keeps the trailing space) used to PASS, because
# an empty value matched the empty line of an empty registry. An empty or
# malformed id never resolves.
BASE="$(git rev-parse HEAD)"
echo "$RANDOM" > empty-wu.txt && git add -A
git commit -q --cleanup=verbatim -m "feat: bare trailer

Work Unit: "
expect 1 "a bare 'Work Unit: ' line fails against an empty registry" -- bash "$CONSUMER_WU" "$BASE" HEAD
expect_output "is empty or not a Work Unit id"

mk_consumer cons-malformed
mkdir -p Registry && printf 'work_units:\n  - id: WU-QA-1\n' > Registry/work-units.yml
git add -A && git commit -q -m "registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: malformed id" "Work Unit: not-an-id"
expect 1 "a malformed Work Unit id fails" -- bash "$CONSUMER_WU" "$BASE" HEAD
expect_output "is empty or not a Work Unit id"

# The non-consumer branch: the framework root (cwd == the script's framework)
# with no registry reports the plain message, not the consumer one.
new_repo fw-no-registry
mkdir -p Adapters/scripts
cp "$CHECK_WU" "$SCRIPTS/merge-classify.sh" Adapters/scripts/
git add -A && git commit -q -m "no registry"
BASE="$(git rev-parse HEAD)"
commit_with "feat: anything" "Work Unit: WU-QA-1"
expect 1 "the framework root with no registry fails closed" -- bash Adapters/scripts/check-work-units.sh "$BASE" HEAD
expect_output "Could not locate Registry/work-units.yml"
expect 1 "IAENG_REGISTRY_WORK_UNITS naming a missing file fails closed" -- \
  env IAENG_REGISTRY_WORK_UNITS=/nonexistent/devops320.yml bash Adapters/scripts/check-work-units.sh "$BASE" HEAD

# The framework's own behaviour is unchanged: run from the framework root it
# reads its own registry.
FW_ROOT_320="$(cd "$SCRIPTS/../.." && pwd)"
TOTAL=$((TOTAL + 1))
FW_OUT_320="$(cd "$FW_ROOT_320" && bash "$CHECK_WU" HEAD HEAD 2>&1)"
if grep -qxF "Registry: Registry/work-units.yml" <<< "$FW_OUT_320"; then
  [ -n "$VERBOSE" ] && printf '   ok   the framework run from its own root reads its own registry\n'
else
  printf '   FAIL the framework run from its own root did not read Registry/work-units.yml\n'
  FAILED=$((FAILED + 1))
fi

section "setup-project-bootstrap.sh / install.sh — registry, LF rules, summary (WU-IAENG-320)"

new_repo boot-320
if ln -s "$FRAMEWORK_ROOT" ia-engineering 2>/dev/null; then
  BOOT_OUT="$(bash ./ia-engineering/Adapters/scripts/setup-project-bootstrap.sh generic 2>&1)"

  TOTAL=$((TOTAL + 1))
  if [ -f Registry/work-units.yml ] && grep -qxF 'work_units:' Registry/work-units.yml \
     && ! grep -qE '^  - id: ' Registry/work-units.yml; then
    [ -n "$VERBOSE" ] && printf '   ok   the bootstrap wrote an empty starter Registry/work-units.yml\n'
  else
    printf '   FAIL the bootstrap did not write an empty starter Registry/work-units.yml\n'
    FAILED=$((FAILED + 1))
  fi

  for rule in '/.claude/settings.json' '/.claude/skills/**' '/.ia-engineering/stack' '/.ia-engineering/risk-map.yml' \
              '/Registry/work-units.yml' '/Dockerfile' '/.gitmodules'; do
    TOTAL=$((TOTAL + 1))
    if grep -qxF "$rule text eol=lf" .gitattributes 2>/dev/null; then
      [ -n "$VERBOSE" ] && printf '   ok   .gitattributes carries an LF rule for %s\n' "$rule"
    else
      printf '   FAIL .gitattributes has no LF rule for %s\n' "$rule"
      FAILED=$((FAILED + 1))
    fi
  done

  TOTAL=$((TOTAL + 1))
  if grep -qE '^\* |text=auto' .gitattributes 2>/dev/null; then
    printf '   FAIL .gitattributes carries a project-wide rule; the rules must be exact paths\n'
    FAILED=$((FAILED + 1))
  else
    [ -n "$VERBOSE" ] && printf '   ok   .gitattributes has no project-wide eol rule\n'
  fi

  TOTAL=$((TOTAL + 1))
  if printf '%s' "$BOOT_OUT" | grep -qF "setup-project-bootstrap.sh <stack>"; then
    printf '   FAIL install.sh told the reader to run the bootstrap script while it was running\n'
    FAILED=$((FAILED + 1))
  else
    [ -n "$VERBOSE" ] && printf '   ok   the summary does not point back at the running bootstrap\n'
  fi

  # Run on its own, install.sh still names the bootstrap as the next step.
  new_repo inst-320
  ln -s "$FRAMEWORK_ROOT" ia-engineering 2>/dev/null
  expect 0 "install.sh run on its own succeeds" -- bash ./ia-engineering/Adapters/scripts/install.sh
  expect_output "setup-project-bootstrap.sh <stack>"
else
  skip 12 "bootstrap registry/LF/summary: ln -s failed on this platform (no admin rights / Developer Mode off) -- not a fix defect."
fi

section "install-hooks.sh — framework-inside-project by identity, not spelling (WU-IAENG-320, DEF-14)"

new_repo hooks-320
if ln -s "$FRAMEWORK_ROOT" ia-engineering 2>/dev/null; then
  HOOKS_320="$PWD/ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh"
  expect 0 "install-hooks.sh finds the framework inside the project" -- bash "$HOOKS_320" --print
  expect_output 'ia-engineering/Adapters'

  # The project reached through a symlink: its logical path is spelled
  # differently from the one the framework was located by.
  PROJ_REAL="$PWD"
  PROJ_LINK="$WORK/hooks-320-link"
  rm -rf "$PROJ_LINK"
  if ln -s "$PROJ_REAL" "$PROJ_LINK" 2>/dev/null && [ -L "$PROJ_LINK" ]; then
    cd "$PROJ_LINK" || exit 1
    expect 0 "install-hooks.sh accepts the project reached through a symlinked path" -- bash "$HOOKS_320" --print
    cd "$PROJ_REAL" || exit 1
  fi

  # A differently-cased spelling of the same directory (Windows, macOS): only
  # meaningful where the filesystem folds case, and a no-op where it does not.
  ALT_CASE="$(dirname "$PROJ_REAL")/$(basename "$PROJ_REAL" | tr '[:lower:]' '[:upper:]')"
  if [ "$ALT_CASE" != "$PROJ_REAL" ] && [ -d "$ALT_CASE" ] && [ "$ALT_CASE" -ef "$PROJ_REAL" ]; then
    cd "$ALT_CASE" || exit 1
    expect 0 "install-hooks.sh accepts a differently-cased spelling of the project path" -- bash "$HOOKS_320" --print
    cd "$PROJ_REAL" || exit 1
  fi

  # Not inside the project is still refused.
  new_repo hooks-320-outside
  expect 1 "install-hooks.sh still refuses a framework that is not inside the project" -- bash "$HOOKS_320" --print
  expect_output "is not inside the project"
else
  skip 2 "install-hooks.sh inside-project detection: ln -s failed on this platform (no admin rights / Developer Mode off) -- not a fix defect."
fi

# ------------------- validate-framework.sh short-circuit safety (WU-IAENG-319) --
#
# Section 9 of the validator answered "does this path exist" with
# `printf '%s\n' "$TRACKED_PATHS" | grep -qxF -- "$p"` under pipefail. grep -q
# leaves at its first match; the bash-builtin printf writes through a ~4 KB
# buffer, so a list past that takes SIGPIPE on its second write and the pipeline
# reports failure for a path that IS tracked. It flaked twice on CI
# (PR #174, PR #182: "documents reference paths that do not exist"). A list this
# size makes it deterministic, which a 6.7 KB list on a fast runner is not.

section "validate-framework.sh — resolves() does not read SIGPIPE as a miss (WU-IAENG-319)"

VF="$SCRIPTS/validate-framework.sh"
RES_HARNESS="$WORK/resolves-harness.sh"
{
  echo 'set -uo pipefail'
  sed -n '/^has_line() {/,/^}/p' "$VF"
  sed -n '/^resolves() {/,/^}/p' "$VF"
  cat <<'HARNESS'
{
  echo "Adapters/git-hooks/pre-push"
  echo "dirfirst/leaf.md"
  i=0
  while [ "$i" -lt 6000 ]; do echo "Core/filler-$i.md"; i=$((i + 1)); done
} > "$WORK_LIST"
TRACKED_PATHS="$(cat "$WORK_LIST")"
n=0
while [ "$n" -lt 50 ]; do
  resolves "Adapters/git-hooks/pre-push" || { echo "file ref missed on iteration $n"; exit 1; }
  resolves "dirfirst/" || { echo "directory ref missed on iteration $n"; exit 1; }
  n=$((n + 1))
done
resolves "Adapters/git-hooks/absent" && { echo "an absent path resolved"; exit 1; }
exit 0
HARNESS
} > "$RES_HARNESS"
expect 0 "resolves() finds a tracked file and directory in a 100 KB list, 50 times" -- env WORK_LIST="$WORK/resolves-list.txt" bash "$RES_HARNESS"

# No `printf ... | grep -q` / `echo ... | grep -q` may come back into the
# validator: every membership test over a captured variable uses has_line or a
# here-string. Comment lines are exempt - they explain the bug.
SIGPIPE_HITS="$(grep -nE "(printf|echo) .*\| *grep -[a-zA-Z]*q" "$VF" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
if [ -z "$SIGPIPE_HITS" ]; then
  TOTAL=$((TOTAL + 1))
  [ -n "$VERBOSE" ] && printf '   ok   validate-framework.sh has no printf/echo piped into grep -q\n'
else
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
  printf '   FAIL validate-framework.sh pipes a variable into grep -q (SIGPIPE under pipefail):\n%s\n' "$SIGPIPE_HITS"
fi

# ------ validate-framework.sh chain diagrams vs the Registry (WU-IAENG-335) --
#
# Core/AGENT_CHAINS.md draws each chain and Registry/chains.yml records it as
# data. Nothing compared their steps. Three diagrams lost four steps that the
# Registry still held: the Review Chain its Security and Compliance Engineers,
# the Architecture Chain its Security Engineer, the Feature Chain its ADR gate.
# Every check passed until a manual check-up found them (WU-IAENG-334, PR #201).
# Section 22 of the validator now compares the two step for step.
#
# These cases run the REAL chain_diagram_drift, extracted from the validator in
# the same way as resolves() above. They run it on the real files, as LF and as
# CRLF; on the #201 drift put back into the real document; and on a fixture
# pair that carries every construct of the grammar, mutated one drift at a
# time. The fixture pair is written here rather than derived from the real
# files, so rewording a diagram breaks only the cases that read the real files.
#
# CRLF: Git for Windows' awk drops a carriage return on read, so on a Windows
# run the CRLF cases pass with or without the strip. They prove the strip on
# the Linux runner, where awk keeps the CR.

section "validate-framework.sh — chain diagrams match Registry/chains.yml step for step (WU-IAENG-335)"

CHAIN_HARNESS="$WORK/chain-diagram-harness.sh"
{
  echo 'set -uo pipefail'
  sed -n '/^chain_diagram_drift() {/,/^}/p' "$VF"
  cat <<'HARNESS'
chain_diagram_drift "$1" "$2"
HARNESS
} > "$CHAIN_HARNESS"
CHAIN_ROOT="$(cd "$SCRIPTS/../.." && pwd)"
CHAIN_FIX="$WORK/chain-diagrams"
CHAIN_TAB=$'\t'
mkdir -p "$CHAIN_FIX"

expect 0 "chain diagrams: chain_diagram_drift is extracted from the validator" -- \
  grep -q '^chain_diagram_drift() {' "$CHAIN_HARNESS"

# chain_drift_case <what> <document> <registry> <expected output...>
# The pair must FAIL, and its output must contain every expected string.
chain_drift_case() {
  local what="$1" doc="$2" reg="$3" want
  shift 3
  expect 1 "chain diagrams: $what fails" -- bash "$CHAIN_HARNESS" "$doc" "$reg"
  for want in "$@"; do
    expect_output "$want"
  done
}

# --- The real files.
expect 0 "chain diagrams: the real Core/AGENT_CHAINS.md and Registry/chains.yml agree step for step" -- \
  bash "$CHAIN_HARNESS" "$CHAIN_ROOT/Core/AGENT_CHAINS.md" "$CHAIN_ROOT/Registry/chains.yml"
for chain_name in Feature Review Architecture; do
  expect_output "ok${CHAIN_TAB}$chain_name Chain: diagram and Registry agree step for step"
done

tr -d '\r' < "$CHAIN_ROOT/Core/AGENT_CHAINS.md" > "$CHAIN_FIX/real.md"
tr -d '\r' < "$CHAIN_ROOT/Registry/chains.yml" > "$CHAIN_FIX/real.yml"
awk '{ printf "%s\r\n", $0 }' "$CHAIN_FIX/real.md" > "$CHAIN_FIX/real-crlf.md"
awk '{ printf "%s\r\n", $0 }' "$CHAIN_FIX/real.yml" > "$CHAIN_FIX/real-crlf.yml"
CHAIN_CR="$(tr -cd '\r' < "$CHAIN_FIX/real-crlf.md" | wc -c | tr -d ' ')"
CHAIN_LF="$(tr -cd '\n' < "$CHAIN_FIX/real-crlf.md" | wc -c | tr -d ' ')"
expect 0 "chain diagrams: the CRLF copy ends every line in CRLF ($CHAIN_CR CR, $CHAIN_LF LF)" -- \
  test "$CHAIN_LF" -gt 0 -a "$CHAIN_CR" = "$CHAIN_LF"
expect 0 "chain diagrams: the real files agree checked out CRLF" -- \
  bash "$CHAIN_HARNESS" "$CHAIN_FIX/real-crlf.md" "$CHAIN_FIX/real-crlf.yml"
expect 0 "chain diagrams: the real files agree checked out LF" -- \
  bash "$CHAIN_HARNESS" "$CHAIN_FIX/real.md" "$CHAIN_FIX/real.yml"

# The #201 drift, put back: the Review Chain diagram without its Security
# Engineer and Compliance Engineer steps, against the Registry that kept them.
awk '/^# / { review = ($0 == "# Review Chain") }
     review && /^(Security|Compliance) Engineer  \(/ { next }
     { print }' "$CHAIN_FIX/real.md" > "$CHAIN_FIX/real-201.md"
expect 1 "chain diagrams: the #201 fixture really removed lines from the real document" -- \
  cmp -s "$CHAIN_FIX/real.md" "$CHAIN_FIX/real-201.md"
chain_drift_case "the #201 drift (Review Chain diagram without its Security and Compliance Engineers)" \
  "$CHAIN_FIX/real-201.md" "$CHAIN_FIX/real.yml" \
  "Review Chain, step 2: $CHAIN_FIX/real-201.md:" \
  "records \"employee: Security Engineer (conditional)\""

# --- A fixture pair carrying every construct the grammar reads: outputs with
# arrows inside, a conditional gate, the multi-pole clause alone and beside a
# condition, Engineer(s) with its parallel marker, the review loop, a branch
# box, "(P1/P2 ...)" as a condition, "when: Always", a folded "when: >-", and
# block-scalar text that looks like keys and steps, one at the very indentation
# of a step.
cat > "$CHAIN_FIX/base.md" <<'EOF'
# Agent Chains

Every construct the diagrams of Core/AGENT_CHAINS.md use, in two chains.

# Chain Selection

| Request type | Chain |
|---|---|
| A test request | Alpha Chain |

---

# Alpha Chain

```
Business Analyst
      ↓
  [Specification — acceptance criteria]
      ↓
Main Agent → Director  (if an ADR is required)
      ↓
  [ADR decision → implementation blocked until Accepted]
      ↓
Main Agent  (Engineering Manager if multi-pole work)
      ↓
Engineer(s)        ← parallel if Work Units are independent
      ↓
Code Reviewer
      ↓
  ┌── Approved ──────────────────────────────┐
  │                                          │
  └── Changes requested → Engineer → resubmit ──┘
      ↓
Main Agent  (if Accepted; Engineering Manager if multi-pole work)
      ↓
Main Agent → Director
      ↓
  [Approval → Release Chain]
```

# Beta Chain

```
SRE Engineer
      ↓
Engineering Manager
      ↓
Main Agent → Director  (P1/P2 mandatory notification)
      ↓
  ┌── Security incident? → Security Engineer ──┐
  └────────────────────────────────────────────┘
      ↓
QA Engineer  (if the change is high-risk)
      ↓
Main Agent → Director
```

# Chain Conventions

- Prose under a heading that is not a chain.
EOF
cat > "$CHAIN_FIX/base.yml" <<'EOF'
chains:

  - name: Alpha Chain
    document: Core/AGENT_CHAINS.md
    steps:
      - employee: Business Analyst
        produces: Specification
      - gate: Director
        when: An ADR is required
        blocks: Implementation
      - employee: Main Agent
        note: >-
          Folded text sits deeper than a key and is never read as one:
          when: this line is prose
          - employee: Not A Step
      - employee: Engineer
        parallel: true
      - employee: Code Reviewer
        loops_to: Engineer
      - employee: Main Agent
        when: The ADR is Accepted
      - gate: Director
        when: Always

  - name: Beta Chain
    document: Core/AGENT_CHAINS.md
    trigger: >-
      - employee: Folded trigger text at the step indentation, not a step
    steps:
      - employee: SRE Engineer
      - employee: Engineering Manager
      - gate: Director
        when: Severity is P1 or P2
      - employee: Security Engineer
        when: The incident has a security dimension
      - employee: QA Engineer
        when: >-
          The change is high-risk
      - gate: Director
        when: Always
EOF
expect 0 "chain diagrams: the fixture pair carrying every construct agrees" -- \
  bash "$CHAIN_HARNESS" "$CHAIN_FIX/base.md" "$CHAIN_FIX/base.yml"
expect_output "total${CHAIN_TAB}2${CHAIN_TAB}13"

# --- One drift at a time: a diagram step removed, a Registry step added, two
# steps swapped, a gate recorded as an employee; then one case for each of the
# three attributes compared besides kind and name.
awk '$0 != "QA Engineer  (if the change is high-risk)"' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/step-removed.md"
chain_drift_case "a diagram step removed" "$CHAIN_FIX/step-removed.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain, step 5: $CHAIN_FIX/step-removed.md:" \
  "draws \"gate: Director\", $CHAIN_FIX/base.yml:" \
  "records \"employee: QA Engineer (conditional)\"" \
  "Diagram, 5 steps:" "Registry, 6 steps:"

awk '$0 == "  - name: Beta Chain" { print "      - employee: Release Manager"; print "" } { print }' \
  "$CHAIN_FIX/base.yml" > "$CHAIN_FIX/step-added.yml"
chain_drift_case "a Registry step added" "$CHAIN_FIX/base.md" "$CHAIN_FIX/step-added.yml" \
  "Alpha Chain, step 8: $CHAIN_FIX/base.md draws nothing (the diagram ends at step 7), $CHAIN_FIX/step-added.yml:" \
  "records \"employee: Release Manager\""

awk '$0 == "SRE Engineer" { print "Engineering Manager"; next }
     $0 == "Engineering Manager" { print "SRE Engineer"; next }
     { print }' "$CHAIN_FIX/base.md" > "$CHAIN_FIX/steps-swapped.md"
chain_drift_case "two diagram steps swapped" "$CHAIN_FIX/steps-swapped.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain, step 1: $CHAIN_FIX/steps-swapped.md:" \
  "draws \"employee: Engineering Manager\", $CHAIN_FIX/base.yml:" \
  "records \"employee: SRE Engineer\""

# Section 13 accepts Director as an employee: (a framework role), so only this
# comparison sees a gate recorded as an employee. The one case that pins the
# whole message: chain, position, file:line and the step on each side.
awk '!done && $0 == "      - gate: Director" { print "      - employee: Director"; done = 1; next } { print }' \
  "$CHAIN_FIX/base.yml" > "$CHAIN_FIX/gate-as-employee.yml"
CHAIN_GATE_DOC="$(grep -n '^Main Agent → Director  (if an ADR is required)$' "$CHAIN_FIX/base.md" | cut -d: -f1)"
CHAIN_GATE_REG="$(grep -n '^      - employee: Director$' "$CHAIN_FIX/gate-as-employee.yml" | cut -d: -f1)"
chain_drift_case "a gate recorded as an employee" "$CHAIN_FIX/base.md" "$CHAIN_FIX/gate-as-employee.yml" \
  "Alpha Chain, step 2: $CHAIN_FIX/base.md:$CHAIN_GATE_DOC draws \"gate: Director (conditional)\", $CHAIN_FIX/gate-as-employee.yml:$CHAIN_GATE_REG records \"employee: Director (conditional)\""

awk '$0 == "QA Engineer  (if the change is high-risk)" { print "QA Engineer"; next } { print }' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/condition-dropped.md"
chain_drift_case "a condition dropped from the diagram" "$CHAIN_FIX/condition-dropped.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain, step 5: $CHAIN_FIX/condition-dropped.md:" \
  "draws \"employee: QA Engineer\", $CHAIN_FIX/base.yml:" \
  "records \"employee: QA Engineer (conditional)\""

awk '$0 != "        parallel: true"' "$CHAIN_FIX/base.yml" > "$CHAIN_FIX/parallel-dropped.yml"
chain_drift_case "the parallel marker dropped from the Registry" "$CHAIN_FIX/base.md" "$CHAIN_FIX/parallel-dropped.yml" \
  "Alpha Chain, step 4:" \
  "draws \"employee: Engineer (parallel)\"" \
  "records \"employee: Engineer\""

awk '!/Changes requested/' "$CHAIN_FIX/base.md" > "$CHAIN_FIX/loop-dropped.md"
chain_drift_case "the review loop dropped from the diagram" "$CHAIN_FIX/loop-dropped.md" "$CHAIN_FIX/base.yml" \
  "Alpha Chain, step 5:" \
  "draws \"employee: Code Reviewer\"" \
  "records \"employee: Code Reviewer (loops to Engineer)\""

# --- What the first version let pass with exit 0 (review of PR #229). Each
# case is one of the reviewer's falsifiers, rebuilt on the fixture pair.
#
# F1, F2, F3: a box line with no "→" was skipped whatever it said. Only box
# rules and the label "Approved" are now accepted; anything else is refused.
# chain_insert_box <target> <box line> — base.md with that box line, a closing
# rule and a connector inserted before the Beta Chain's QA Engineer step.
chain_insert_box() {
  printf '%s\n' "$2" "  └─────────────────────────┘" "      ↓" > "$CHAIN_FIX/insert.txt"
  awk 'NR == FNR { add = add $0 "\n"; next }
       $0 == "QA Engineer  (if the change is high-risk)" { printf "%s", add }
       { print }' "$CHAIN_FIX/insert.txt" "$CHAIN_FIX/base.md" > "$1"
}
chain_insert_box "$CHAIN_FIX/box-step.md" "  ┌── Compliance Engineer ──┐"
chain_drift_case "a step drawn as a box, with no arrow (F1)" "$CHAIN_FIX/box-step.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain: unrecognised box line \"┌── Compliance Engineer ──┐\""
chain_insert_box "$CHAIN_FIX/box-step-condition.md" "  ┌── Compliance Engineer  (if personal data is exposed) ──┐"
chain_drift_case "a step drawn as a box with its condition, with no arrow (F1)" "$CHAIN_FIX/box-step-condition.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain: unrecognised box line \"┌── Compliance Engineer  (if personal data is exposed) ──┐\""
awk '/^  │ +│$/ { print "  │   Compliance Engineer   │"; next } { print }' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/box-interior.md"
chain_drift_case "a step written inside the review box (F2)" "$CHAIN_FIX/box-interior.md" "$CHAIN_FIX/base.yml" \
  "Alpha Chain: unrecognised box line \"│   Compliance Engineer   │\""
chain_insert_box "$CHAIN_FIX/box-ascii-arrow.md" "  ┌── Data breach? -> Compliance Engineer ──┐"
chain_drift_case "a branch box typed with -> (F3)" "$CHAIN_FIX/box-ascii-arrow.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain: unrecognised box line \"┌── Data breach? -> Compliance Engineer ──┐\""
chain_insert_box "$CHAIN_FIX/box-long-arrow.md" "  ┌── Data breach? ⟶ Compliance Engineer ──┐"
chain_drift_case "a branch box typed with ⟶ (F3)" "$CHAIN_FIX/box-long-arrow.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain: unrecognised box line \"┌── Data breach? ⟶ Compliance Engineer ──┐\""

# F4, F4d: the multi-pole exception matched any clause ending in "if multi-pole
# work". It is now that one clause, by name; anything else is a condition.
awk '$0 == "Engineering Manager" { print "Engineering Manager  (Only if multi-pole work)"; next } { print }' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/only-if-multi-pole.md"
chain_drift_case "(Only if multi-pole work) read as no condition (F4)" "$CHAIN_FIX/only-if-multi-pole.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain, step 2: $CHAIN_FIX/only-if-multi-pole.md:" \
  "draws \"employee: Engineering Manager (conditional)\"" \
  "records \"employee: Engineering Manager\""
awk '$0 == "Engineering Manager" { print "Engineering Manager  (Skipped if multi-pole work)"; next } { print }' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/skipped-if-multi-pole.md"
chain_drift_case "(Skipped if multi-pole work) read as no condition (F4)" "$CHAIN_FIX/skipped-if-multi-pole.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain, step 2:" \
  "draws \"employee: Engineering Manager (conditional)\""
awk '$0 != "        when: The ADR is Accepted"' "$CHAIN_FIX/base.yml" > "$CHAIN_FIX/accepted-dropped.yml"
awk '$0 == "Main Agent  (if Accepted; Engineering Manager if multi-pole work)" {
       print "Main Agent  (If Accepted And Engineering Manager if multi-pole work)"; next }
     { print }' "$CHAIN_FIX/base.md" > "$CHAIN_FIX/fused-clause.md"
chain_drift_case "a condition fused with the multi-pole clause, its when: gone (F4d)" "$CHAIN_FIX/fused-clause.md" "$CHAIN_FIX/accepted-dropped.yml" \
  "Alpha Chain, step 6: $CHAIN_FIX/fused-clause.md:" \
  "draws \"employee: Main Agent (conditional)\"" \
  "records \"employee: Main Agent\""
chain_drift_case "the when: beside the multi-pole clause dropped from the Registry" "$CHAIN_FIX/base.md" "$CHAIN_FIX/accepted-dropped.yml" \
  "Alpha Chain, step 6:" \
  "draws \"employee: Main Agent (conditional)\""

# Finding 3: a Registry step at the wrong indentation was ignored, not refused.
awk '{ print } $0 == "        produces: Specification" { print "    - employee: Technical Writer" }' \
  "$CHAIN_FIX/base.yml" > "$CHAIN_FIX/step-at-four.yml"
chain_drift_case "a Registry step indented four spaces" "$CHAIN_FIX/base.md" "$CHAIN_FIX/step-at-four.yml" \
  "a step at the wrong indentation (the parsing contract puts it at six spaces) \"- employee: Technical Writer\""
awk '{ print } $0 == "        produces: Specification" { print "        - employee: Technical Writer" }' \
  "$CHAIN_FIX/base.yml" > "$CHAIN_FIX/step-at-eight.yml"
chain_drift_case "a Registry step indented eight spaces" "$CHAIN_FIX/base.md" "$CHAIN_FIX/step-at-eight.yml" \
  "a step at the wrong indentation (the parsing contract puts it at six spaces) \"- employee: Technical Writer\""

# The same class as F1: an output line that opens "[" and never closes it.
awk '$0 == "  [Approval → Release Chain]" { print "  [Approval → Release Chain"; next } { print }' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/unclosed-output.md"
chain_drift_case "an output line that never closes its bracket" "$CHAIN_FIX/unclosed-output.md" "$CHAIN_FIX/base.yml" \
  "Alpha Chain: unrecognised output line \"[Approval → Release Chain\""

# --- Rule 1: what cannot be compared fails. It is never skipped.
awk '/^# / { beta = ($0 == "# Beta Chain") } !(beta && /^```/)' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/no-diagram.md"
chain_drift_case "a chain whose diagram is missing" "$CHAIN_FIX/no-diagram.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain: $CHAIN_FIX/no-diagram.md draws no diagram for it"

printf '\n  - name: Gamma Chain\n    steps:\n      - employee: Technical Lead\n' \
  | cat "$CHAIN_FIX/base.yml" - > "$CHAIN_FIX/extra-chain.yml"
chain_drift_case "a Registry chain the document does not draw" "$CHAIN_FIX/base.md" "$CHAIN_FIX/extra-chain.yml" \
  "Gamma Chain: $CHAIN_FIX/extra-chain.yml records it, but $CHAIN_FIX/base.md has no \"# Gamma Chain\" section"

{
  cat "$CHAIN_FIX/base.md"
  cat <<'EOF'

# Gamma Chain

```
Technical Lead
```
EOF
} > "$CHAIN_FIX/document-only.md"
chain_drift_case "a chain the document draws and the Registry lacks" "$CHAIN_FIX/document-only.md" "$CHAIN_FIX/base.yml" \
  "Gamma Chain: $CHAIN_FIX/document-only.md draws it, but $CHAIN_FIX/base.yml has no entry for it"

printf '\n  - name: Beta Chain\n    steps:\n      - employee: SRE Engineer\n' \
  | cat "$CHAIN_FIX/base.yml" - > "$CHAIN_FIX/recorded-twice.yml"
chain_drift_case "a chain the Registry records twice" "$CHAIN_FIX/base.md" "$CHAIN_FIX/recorded-twice.yml" \
  "chain \"Beta Chain\" is recorded twice"

{
  cat "$CHAIN_FIX/base.md"
  cat <<'EOF'

# Beta Chain

```
SRE Engineer
```
EOF
} > "$CHAIN_FIX/two-sections.md"
chain_drift_case "a chain the document draws in two sections" "$CHAIN_FIX/two-sections.md" "$CHAIN_FIX/base.yml" \
  "chain \"Beta Chain\" has two sections"

awk '$0 == "SRE Engineer" { print "SRE Engineer → QA Engineer"; next } { print }' \
  "$CHAIN_FIX/base.md" > "$CHAIN_FIX/unreadable.md"
chain_drift_case "a diagram line outside the grammar" "$CHAIN_FIX/unreadable.md" "$CHAIN_FIX/base.yml" \
  "Beta Chain: unrecognised step line \"SRE Engineer → QA Engineer\""

: > "$CHAIN_FIX/empty.md"
: > "$CHAIN_FIX/empty.yml"
chain_drift_case "two empty files" "$CHAIN_FIX/empty.md" "$CHAIN_FIX/empty.yml" \
  "no chain diagram was compared" "total${CHAIN_TAB}0${CHAIN_TAB}0"
chain_drift_case "a missing file" "$CHAIN_FIX/absent.md" "$CHAIN_FIX/base.yml" \
  "cannot compare chain diagrams: $CHAIN_FIX/absent.md or $CHAIN_FIX/base.yml is missing"

# ------------------------------------------------- git-hooks/pre-push -------
#
# Pen-test finding PT2-08 (1 Oct 2026): pre-push refused every push to main
# and develop but knew nothing of release/*, so a client-side deletion of a
# release branch — which CLAUDE.md and Workflows/RELEASE.md Step 10 say never
# happens — or a force-push to one went through. The hook also had no case
# anywhere. The policy below is Workflows/RELEASE.md's: Step 3 creates and
# pushes the release branch (allowed); Step 4 lands every fix through a Pull
# Request targeting it (so any direct update, fast-forward or force, is
# refused); Step 10 never deletes it (refused). DEF-2 (QA adoption test,
# 2 Oct 2026) extended the creation rule to main and develop: a new project's
# documented first push of them (Workflows/PROJECT_BOOTSTRAP.md) was refused,
# and the only way through was a hook bypass. Every update and deletion of
# them stays refused.
#
# Most cases feed the REAL hook git's REAL stdin protocol —
#   <local ref> <local sha> <remote ref> <remote sha>
# one line per ref, all-zero sha for a deletion (local) or a creation
# (remote) — with object names taken from a real throwaway repository. The
# last blocks install the hook and push for real, into throwaway bare
# repositories under $WORK only.

section "git-hooks/pre-push — protected and release branches (WU-IAENG-315)"

PREPUSH="$SCRIPTS/../git-hooks/pre-push"

new_repo pre-push
PP_OLD="$(git rev-parse HEAD)"
echo two > two.txt && git add two.txt && git commit -q -m "two"
PP_NEW="$(git rev-parse HEAD)"
# PP_SIDE is not a descendant of PP_NEW: replacing PP_NEW with it on the
# remote is a force-push.
git checkout -q -b side "$PP_OLD"
echo side > side.txt && git add side.txt && git commit -q -m "side"
PP_SIDE="$(git rev-parse HEAD)"
git checkout -q main
PP_ZERO="0000000000000000000000000000000000000000"
PP_ZERO256="0000000000000000000000000000000000000000000000000000000000000000"

# "${PP[@]}" <stdin line...> — runs the hook with one stdin line per argument,
# and the two positional arguments git passes (remote name, remote URL). A
# feeder script rather than a shell function: a function reached only through
# `expect "$@"` is reported unreachable by shellcheck (SC2317).
cat > "$WORK/pre-push-feed.sh" <<'FEED'
hook="$1"; shift
printf '%s\n' "$@" | bash "$hook" origin https://example.invalid/repo.git
FEED
PP=(bash "$WORK/pre-push-feed.sh" "$PREPUSH")

for pp_branch in main develop; do
  expect 1 "push to $pp_branch (fast-forward) is refused" -- \
    "${PP[@]}" "refs/heads/work $PP_NEW refs/heads/$pp_branch $PP_OLD"
  expect_output "direct push to '$pp_branch' is not allowed"
  expect 1 "force-push to $pp_branch is refused" -- \
    "${PP[@]}" "refs/heads/side $PP_SIDE refs/heads/$pp_branch $PP_NEW"
  expect 1 "deletion of $pp_branch is refused" -- \
    "${PP[@]}" "(delete) $PP_ZERO refs/heads/$pp_branch $PP_NEW"
  # DEF-2: a new project's first push of main and develop
  # (Workflows/PROJECT_BOOTSTRAP.md) creates them, and that must not need a
  # hook bypass. Creation overwrites nothing; branch protection takes over
  # once the branch exists.
  expect 0 "creation of an absent $pp_branch is allowed (bootstrap)" -- \
    "${PP[@]}" "refs/heads/$pp_branch $PP_NEW refs/heads/$pp_branch $PP_ZERO"
done

expect 1 "a multi-ref push with develop after an allowed feature ref is refused" -- \
  "${PP[@]}" "refs/heads/feature/x $PP_NEW refs/heads/feature/x $PP_OLD" \
     "refs/heads/develop $PP_NEW refs/heads/develop $PP_OLD"
expect_output "direct push to 'develop' is not allowed"
expect 1 "a multi-ref push (feature, tag, then main) touching main is refused" -- \
  "${PP[@]}" "refs/heads/feature/x $PP_NEW refs/heads/feature/x $PP_ZERO" \
     "refs/tags/v1.0.0 $PP_NEW refs/tags/v1.0.0 $PP_ZERO" \
     "refs/heads/main $PP_NEW refs/heads/main $PP_OLD"

expect 0 "creating a feature branch is allowed" -- \
  "${PP[@]}" "refs/heads/feature/x $PP_NEW refs/heads/feature/x $PP_ZERO"
expect 0 "updating a feature branch is allowed" -- \
  "${PP[@]}" "refs/heads/feature/x $PP_NEW refs/heads/feature/x $PP_OLD"
expect 0 "deleting a feature branch is allowed" -- \
  "${PP[@]}" "(delete) $PP_ZERO refs/heads/feature/x $PP_NEW"

expect 0 "creating release/v9.9.9 is allowed (RELEASE.md Step 3)" -- \
  "${PP[@]}" "refs/heads/release/v9.9.9 $PP_NEW refs/heads/release/v9.9.9 $PP_ZERO"
expect 1 "a fast-forward to an existing release branch is refused (RELEASE.md Step 4: fixes land by PR)" -- \
  "${PP[@]}" "refs/heads/release/v9.9.9 $PP_NEW refs/heads/release/v9.9.9 $PP_OLD"
expect_output "direct push to existing release branch 'release/v9.9.9' is not allowed"
expect 1 "a force-push to a release branch is refused" -- \
  "${PP[@]}" "refs/heads/side $PP_SIDE refs/heads/release/v9.9.9 $PP_NEW"
expect_output "direct push to existing release branch 'release/v9.9.9' is not allowed"
expect 1 "deleting a release branch is refused (RELEASE.md Step 10)" -- \
  "${PP[@]}" "(delete) $PP_ZERO refs/heads/release/v9.9.9 $PP_NEW"
expect_output "deleting release branch 'release/v9.9.9' is not allowed"
expect 1 "deleting a release branch is refused in a SHA-256 repository (64-zero sha)" -- \
  "${PP[@]}" "(delete) $PP_ZERO256 refs/heads/release/v9.9.9 $PP_NEW"
expect 1 "a release-branch deletion after an allowed feature ref is refused" -- \
  "${PP[@]}" "refs/heads/feature/x $PP_NEW refs/heads/feature/x $PP_OLD" \
     "(delete) $PP_ZERO refs/heads/release/v9.9.9 $PP_NEW"

expect 0 "a branch merely starting with 'release' (release-notes) is not a release branch" -- \
  "${PP[@]}" "refs/heads/release-notes $PP_NEW refs/heads/release-notes $PP_OLD"
expect 0 "a branch containing release/ deeper in its name is not a release branch" -- \
  "${PP[@]}" "refs/heads/feature/release/x $PP_NEW refs/heads/feature/release/x $PP_OLD"

expect 0 "pushing a tag is allowed" -- \
  "${PP[@]}" "refs/tags/v1.0.0 $PP_NEW refs/tags/v1.0.0 $PP_ZERO"
expect 0 "a tag under refs/tags/release/ is not a release branch" -- \
  "${PP[@]}" "refs/tags/release/v1 $PP_NEW refs/tags/release/v1 $PP_ZERO"
expect 0 "an empty push (nothing on stdin) is allowed" -- \
  bash "$PREPUSH" origin https://example.invalid/repo.git < /dev/null

# --- The documented limit, pinned with a REAL push (SEC-IAENG-179-01). ---
# `git push --mirror` deletes a remote branch that is absent locally without
# reporting that deletion to pre-push: the hook runs, receives no line for
# it, and the branch is gone (observed on git 2.54). The hook header and
# Adapters/README.md say so; the server deletion rule and GIT_STANDARD's ban
# on --mirror cover the case. If git ever starts reporting these deletions,
# the mirror case below fails and the documentation can be tightened.
#
# The hook is installed as a wrapper that logs the stdin it receives, and an
# explicit deletion first proves the installed hook really runs here.
PPM_REMOTE="$WORK/pre-push-mirror-remote.git"
PPM_LOG="$WORK/pre-push-mirror-calls.log"
rm -rf "$PPM_REMOTE" "$PPM_LOG"
git init -q --bare "$PPM_REMOTE"
new_repo pre-push-mirror
git branch -q -m main feature/x
git branch -q release/v1
git push -q "$PPM_REMOTE" feature/x release/v1
cat > .git/hooks/pre-push <<HOOK
#!/usr/bin/env bash
input="\$(cat)"
printf '%s\n' "\$input" >> "$PPM_LOG"
echo "--- call end" >> "$PPM_LOG"
printf '%s\n' "\$input" | bash "$PREPUSH" "\$@"
HOOK
chmod +x .git/hooks/pre-push

expect 1 "control: the installed hook refuses an explicit release-branch deletion" -- \
  git push -q "$PPM_REMOTE" :refs/heads/release/v1
expect_output "deleting release branch 'release/v1' is not allowed"
git branch -q -D release/v1
expect 0 "limit: a mirror push deletes release/v1 without the hook refusing it" -- \
  git push -q --mirror "$PPM_REMOTE"
expect 1 "limit: release/v1 is gone from the remote after the mirror push" -- \
  git --git-dir="$PPM_REMOTE" rev-parse -q --verify refs/heads/release/v1
PPM_CALLS="$(grep -c -- '^--- call end' "$PPM_LOG")"
PPM_NAMED="$(grep -c 'refs/heads/release/v1' "$PPM_LOG")"
expect 0 "limit: the hook ran for both pushes (2 calls, got $PPM_CALLS)" -- \
  test "$PPM_CALLS" = 2
expect 0 "limit: only the explicit deletion named release/v1 (1 line, got $PPM_NAMED)" -- \
  test "$PPM_NAMED" = 1

# --- DEF-2, with a REAL push: the bootstrap's first push of main and develop
# into an empty remote, through the installed hook, then the refusals that
# must still hold once the branches exist.
PPB_REMOTE="$WORK/pre-push-bootstrap-remote.git"
rm -rf "$PPB_REMOTE"
git init -q --bare "$PPB_REMOTE"
new_repo pre-push-bootstrap
cat > .git/hooks/pre-push <<HOOK
#!/usr/bin/env bash
exec bash "$PREPUSH" "\$@"
HOOK
chmod +x .git/hooks/pre-push

expect 0 "bootstrap: creating main on an empty remote is allowed" -- \
  git push -q -u "$PPB_REMOTE" main
git branch develop
expect 0 "bootstrap: creating develop is allowed" -- \
  git push -q -u "$PPB_REMOTE" develop
expect 0 "bootstrap: both branches now exist on the remote" -- \
  git --git-dir="$PPB_REMOTE" rev-parse -q --verify refs/heads/develop
echo more > more.txt && git add more.txt && git commit -q -m "more"
expect 1 "bootstrap: a later update of main is refused" -- \
  git push -q "$PPB_REMOTE" main
expect_output "direct push to 'main' is not allowed"
expect 1 "bootstrap: a later update of develop is refused" -- \
  git push -q "$PPB_REMOTE" main:develop
expect 1 "bootstrap: deleting develop is refused" -- \
  git push -q "$PPB_REMOTE" :refs/heads/develop
expect 0 "bootstrap: develop survived the refused deletion" -- \
  git --git-dir="$PPB_REMOTE" rev-parse -q --verify refs/heads/develop

# --- SEC-IAENG-179-02 (issue #181): a case variant of a protected name. ---
# On a case-insensitive filesystem with packed refs, the remote holds no
# loose refs/heads/main, so `git push origin x:refs/heads/Main` is reported to
# the hook as a creation, and the loose file the remote writes is the one it
# then resolves as `main`. The hook allowed it as a creation; it now refuses
# every case variant of main, develop and release/ outright. Exact names keep
# the behaviour pinned above.
section "git-hooks/pre-push — case variants of protected names (WU-IAENG-328, SEC-IAENG-179-02)"

cd "$WORK/pre-push" || exit 1
for pp_variant in Main MAIN DEVELOP Develop Release/v1 RELEASE/v9.9.9; do
  expect 1 "creating refs/heads/$pp_variant is refused (case variant)" -- \
    "${PP[@]}" "refs/heads/x $PP_NEW refs/heads/$pp_variant $PP_ZERO"
  expect_output "differs from the protected branch name"
done
expect 1 "updating refs/heads/Main is refused (case variant)" -- \
  "${PP[@]}" "refs/heads/x $PP_NEW refs/heads/Main $PP_OLD"
expect 1 "deleting refs/heads/DEVELOP is refused (case variant)" -- \
  "${PP[@]}" "(delete) $PP_ZERO refs/heads/DEVELOP $PP_NEW"
expect 1 "a case variant after an allowed feature ref is refused" -- \
  "${PP[@]}" "refs/heads/feature/x $PP_NEW refs/heads/feature/x $PP_OLD" \
     "refs/heads/x $PP_NEW refs/heads/Main $PP_ZERO"
expect 0 "exact main is still created (bootstrap)" -- \
  "${PP[@]}" "refs/heads/main $PP_NEW refs/heads/main $PP_ZERO"
expect 0 "exact release/v1 is still created (RELEASE.md Step 3)" -- \
  "${PP[@]}" "refs/heads/release/v1 $PP_NEW refs/heads/release/v1 $PP_ZERO"
expect 0 "a name merely containing a protected word (feature/Main-menu) is allowed" -- \
  "${PP[@]}" "refs/heads/feature/Main-menu $PP_NEW refs/heads/feature/Main-menu $PP_ZERO"
expect 0 "a tag refs/tags/Main is not a branch and is allowed" -- \
  "${PP[@]}" "refs/tags/Main $PP_NEW refs/tags/Main $PP_ZERO"

# SEC-IAENG-199-01: the ref directories are on the same case-insensitive
# filesystem, so a variant in the refs/heads/ part lands on the protected
# branch just the same. The whole remote ref is folded, not the branch alone.
for pp_variant in refs/Heads/main refs/HEADS/develop refs/Heads/release/v1 REFS/heads/main; do
  expect 1 "creating $pp_variant is refused (case variant of the ref path)" -- \
    "${PP[@]}" "refs/heads/x $PP_NEW $pp_variant $PP_ZERO"
  expect_output "'$pp_variant' differs from the protected branch name"
done
# Review of PR #199, M1: refs/heads/release/V1 carries the EXACT release/
# prefix, so it classified as a release branch and took the creation
# exception; on a packed case-insensitive remote it moved the existing
# release/v1. A ref under a protected name must be all-lowercase.
# Issue #211 (WU-IAENG-339): the refusal names the lowercased branch the
# user probably meant, not only the release/* pattern.
for pp_pair in "refs/heads/release/V1 release/v1" \
               "refs/heads/release/v1.0.0-RC1 release/v1.0.0-rc1" \
               "refs/heads/release/v9.9.9-RC1 release/v9.9.9-rc1"; do
  pp_variant="${pp_pair% *}"
  pp_meant="${pp_pair#* }"
  expect 1 "creating $pp_variant is refused (upper case after the exact release/ prefix)" -- \
    "${PP[@]}" "refs/heads/x $PP_NEW $pp_variant $PP_ZERO"
  expect_output "'$pp_variant' differs from the protected branch name '$pp_meant' ('release/*') only by case. Did you mean '$pp_meant'?"
done
# Every other spelling of a release variant names its lowercased branch too:
# a variant in the ref path, and in the release/ prefix itself.
for pp_pair in "refs/Heads/release/v1 release/v1" \
               "refs/heads/Release/v1 release/v1" \
               "refs/heads/RELEASE/v9.9.9 release/v9.9.9"; do
  pp_variant="${pp_pair% *}"
  pp_meant="${pp_pair#* }"
  expect 1 "creating $pp_variant is refused and names '$pp_meant'" -- \
    "${PP[@]}" "refs/heads/x $PP_NEW $pp_variant $PP_ZERO"
  expect_output "Did you mean '$pp_meant'?"
done
# main and develop keep naming the protected branch itself.
expect 1 "creating refs/heads/DEVELOP is refused and names 'develop'" -- \
  "${PP[@]}" "refs/heads/x $PP_NEW refs/heads/DEVELOP $PP_ZERO"
expect_output "'refs/heads/DEVELOP' differs from the protected branch name 'develop' only by case."
expect 1 "updating refs/heads/release/V1 is refused" -- \
  "${PP[@]}" "refs/heads/x $PP_NEW refs/heads/release/V1 $PP_OLD"
expect 0 "an all-lowercase release/v9.9.9-rc1 is still created" -- \
  "${PP[@]}" "refs/heads/release/v9.9.9-rc1 $PP_NEW refs/heads/release/v9.9.9-rc1 $PP_ZERO"
expect 0 "an upper-case feature branch (feature/ABC-1) is unaffected" -- \
  "${PP[@]}" "refs/heads/feature/ABC-1 $PP_NEW refs/heads/feature/ABC-1 $PP_ZERO"
expect 0 "a tag spelled refs/Tags/main is not a branch ref and is allowed" -- \
  "${PP[@]}" "refs/tags/main $PP_NEW refs/Tags/main $PP_ZERO"

# SEC-IAENG-199-02: the fold must not follow the locale. Under a Turkish
# locale `tr '[:upper:]' '[:lower:]'` may fold I to dotless i, and MAIN then
# no longer reads as main. Where tr_TR.UTF-8 is not generated the C locale is
# used and the case still has to pass.
for pp_variant in MAIN DEVELOP RELEASE/v1; do
  expect 1 "under LC_ALL=tr_TR.UTF-8, refs/heads/$pp_variant is still refused" -- \
    env LC_ALL=tr_TR.UTF-8 "${PP[@]}" "refs/heads/x $PP_NEW refs/heads/$pp_variant $PP_ZERO"
  expect_output "differs from the protected branch name"
done

# The same case with a REAL push into a bare remote whose refs are packed.
# Control first: with no hook installed git itself accepts the push as a
# new branch, so the hook is the only client-side line. Then, through the
# installed hook, the push is refused and the remote's main is untouched.
PPC_CONTROL="$WORK/pre-push-case-control.git"
PPC_REMOTE="$WORK/pre-push-case-remote.git"
rm -rf "$PPC_CONTROL" "$PPC_REMOTE"
git init -q --bare "$PPC_CONTROL"
git init -q --bare "$PPC_REMOTE"
new_repo pre-push-case
git branch develop
git branch release/v1
git push -q "$PPC_CONTROL" main develop release/v1
git push -q "$PPC_REMOTE" main develop release/v1
git --git-dir="$PPC_CONTROL" pack-refs --all
git --git-dir="$PPC_REMOTE" pack-refs --all
PPC_MAIN="$(git rev-parse HEAD)"
echo case > case.txt && git add case.txt && git commit -q -m "case"
expect 0 "control: without the hook, git accepts HEAD:refs/heads/Main into a packed remote" -- \
  git push -q "$PPC_CONTROL" HEAD:refs/heads/Main
cat > .git/hooks/pre-push <<HOOK
#!/usr/bin/env bash
exec bash "$PREPUSH" "\$@"
HOOK
chmod +x .git/hooks/pre-push
expect 1 "real push: HEAD:refs/heads/Main into a packed remote is refused" -- \
  git push -q "$PPC_REMOTE" HEAD:refs/heads/Main
expect_output "'refs/heads/Main' differs from the protected branch name 'main' only by case"
# SEC-IAENG-199-01, real pushes: a variant in the ref path itself.
for ppc_ref in refs/Heads/main refs/HEADS/develop refs/Heads/release/v1 refs/heads/release/V1; do
  expect 1 "real push: HEAD:$ppc_ref into a packed remote is refused" -- \
    git push -q "$PPC_REMOTE" "HEAD:$ppc_ref"
  expect_output "'$ppc_ref' differs from the protected branch name"
done
expect_output "Did you mean 'release/v1'?"
for ppc_branch in main develop release/v1; do
  expect 0 "real push: the remote's $ppc_branch still points at its original commit" -- \
    test "$(git --git-dir="$PPC_REMOTE" rev-parse "refs/heads/$ppc_branch")" = "$PPC_MAIN"
done

# ------------------------------------------------- usage-dashboard.sh -------
# WU-IAENG-326. A fixture repository with trailers and a synthetic transcript
# directory: the page must carry the aggregates, and must NOT carry any of the
# content the sources hold — every free-text field in the fixtures contains an
# OBS326-SENTINEL marker, and no marker may reach the page.

DASH="$SCRIPTS/usage-dashboard.sh"
COLLECT="$SCRIPTS/../ai-runtimes/claude-code/usage-collect.sh"

section "usage-dashboard.sh"

new_repo usage-basic
write_employee_roster "DevOps Engineer" "Observability Engineer" "Backend Engineer" "Scrum Master"
cat > Registry/chains.yml <<'CHAINS'
chains:

  - name: Test Chain
    workflow: Workflows/TEST.md
    steps:
      - employee: DevOps Engineer
        produces: something
      - gate: Director
        when: Always
        blocks: Delivery
      - employee: Scrum Master
        when: Something rare happens
        produces: something else
      - employee: Engineer
        produces: the implementation
CHAINS
cat > Registry/work-units.yml <<'WUS'
work_units:
  - id: WU-TEST-001
    employee: DevOps Engineer
    title: OBS326-SENTINEL-WU-TITLE
    milestone: Testing
  - id: WU-TEST-002
    employee: Observability Engineer
    title: another
    milestone: Testing
WUS
git add -A && git commit -q -m "registries"
commit_with "feat: before the tag" "OBS326-SENTINEL-COMMIT-BODY" "" "Work Unit: WU-TEST-001" "" \
  "Employee: DevOps Engineer" "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git tag v1
commit_with "feat: after the tag" "Work Unit: WU-TEST-001" "" \
  "Employee: DevOps Engineer" "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
commit_with "feat: observability" "Work Unit: WU-TEST-002" "" \
  "Employee: Observability Engineer" "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
# Trailer-looking lines in the BODY are not attribution (F3): only the final
# trailer block counts, and the model is the runtime co-author's, not the
# first co-author's.
commit_with "feat: real trailers only" "Employee: Scrum Master" \
  "Co-Authored-By: OBS326 Human <human@example.invalid>" "" "Work Unit: WU-TEST-002" "" \
  "Employee: Observability Engineer" "Co-Authored-By: OBS326 Human <human@example.invalid>" \
  "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
USAGE_REPO="$PWD"

# The transcript: msg_A is written twice (one line per content block, as the
# runtime does) and must count once; the last two lines are a truncated write
# and a non-object, which must be skipped without losing the file.
UT="$WORK/usage-transcripts"
rm -rf "$UT"
mkdir -p "$UT/s1/subagents"
cat > "$UT/s1.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-10-01T09:59:00Z","message":{"role":"user","content":"OBS326-SENTINEL-PROMPT"}}
{"type":"assistant","timestamp":"2026-10-01T10:00:00Z","message":{"id":"msg_A","model":"claude-test-1","content":[{"type":"text","text":"OBS326-SENTINEL-REPLY"}],"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":10,"cache_read_input_tokens":1000}}}
{"type":"assistant","timestamp":"2026-10-01T10:00:01Z","message":{"id":"msg_A","model":"claude-test-1","content":[{"type":"tool_use","id":"toolu_1","name":"Agent","input":{"subagent_type":"observability-engineer","model":"opus","description":"OBS326-SENTINEL-DESC","prompt":"OBS326-SENTINEL-DISPATCH-PROMPT"}}],"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":10,"cache_read_input_tokens":1000}}}
{"type":"user","timestamp":"2026-10-01T10:00:02Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"OBS326-SENTINEL-TOOL-RESULT"}]}}
{"type":"assistant","timestamp":"2026-10-02T08:00:00Z","message":{"id":"msg_B","model":"claude-test-2","content":[{"type":"tool_use","id":"toolu_2","name":"Agent","input":{"subagent_type":"devops-engineer","prompt":"OBS326-SENTINEL-SECOND-PROMPT"}}],"usage":{"input_tokens":1,"output_tokens":2,"cache_creation_input_tokens":3,"cache_read_input_tokens":4}}}
{"type":"assistant","message":{"id":"msg_TRUNC
42
JSONL
cat > "$UT/s1/subagents/agent-x.jsonl" <<'JSONL'
{"type":"assistant","isSidechain":true,"timestamp":"2026-10-02T08:00:05Z","message":{"id":"msg_C","model":"claude-test-1","content":[{"type":"text","text":"OBS326-SENTINEL-SUBAGENT-REPLY"},{"type":"tool_use","id":"toolu_3","name":"Agent","input":{"subagent_type":"general-purpose","prompt":"OBS326-SENTINEL-NESTED"}}],"usage":{"input_tokens":5,"output_tokens":5,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
JSONL
printf '%s\n' '{"agentType":"observability-engineer","description":"OBS326-SENTINEL-META"}' > "$UT/s1/subagents/agent-x.meta.json"

UPAGE="$WORK/usage-out/dashboard.html"
expect 0 "dashboard: builds the page from git and a transcript directory" -- \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE" --transcripts-dir "$UT"
expect_output "source found: Claude Code transcripts"
expect_output "Employees: 4 on roster, 2 never used"
expect 0 "dashboard: the page exists" -- test -s "$UPAGE"
# Aggregates, read from the page's embedded data block (field order is fixed
# by the script's jq, so a literal match is exact).
expect 0 "dashboard: Observability Engineer has 1 dispatch, 2 commits in range, 2 all time, 1 Work Unit" -- \
  grep -qF '"name":"Observability Engineer","roster":"framework","dispatches":1,"commits_range":2,"commits_all":2,"work_units":1' "$UPAGE"
expect 0 "dashboard: the model is the runtime co-author's, not the first co-author's" -- \
  grep -qF '{"model":"Claude Opus 5.5","commits_all":2,"commits_range":2}' "$UPAGE"
expect 1 "dashboard: a non-runtime co-author's name is not shown as a model" -- grep -qF 'OBS326 Human' "$UPAGE"
expect 0 "dashboard: DevOps Engineer has 1 commit since v1 and 2 all time" -- \
  grep -qF '"name":"DevOps Engineer","roster":"framework","dispatches":1,"commits_range":1,"commits_all":2,"work_units":1' "$UPAGE"
expect 0 "dashboard: an Employee with no activity is marked never used" -- \
  grep -qF '"name":"Scrum Master","roster":"framework","dispatches":0,"commits_range":0,"commits_all":0,"work_units":0,"activity":0,"status":"never"' "$UPAGE"
expect 0 "dashboard: never-used is labelled in text, not by colour alone" -- grep -qF 'NEVER USED' "$UPAGE"
expect 0 "dashboard: a message written on two lines is counted once (input 106, not 206)" -- \
  grep -qF '"tokens":{"calls":3,"input":106,"output":57,"cw":13,"cr":1004,"total":1180' "$UPAGE"
expect 0 "dashboard: a non-Employee agent type is listed apart" -- \
  grep -qF '"other_agents":[{"type":"general-purpose","dispatches":1}]' "$UPAGE"
expect 0 "dashboard: chain coverage counts the unexercised steps" -- \
  grep -qF 'Test Chain - 1 of 3 Employee steps exercised' "$UPAGE"
expect 0 "dashboard: commits per model come from Co-Authored-By" -- \
  grep -qF '{"model":"Claude Sonnet 5.5","commits_all":2,"commits_range":1}' "$UPAGE"
expect 0 "dashboard: subagent tokens are attributed to the agent type from .meta.json" -- \
  grep -qF '"agent":"observability-engineer"' "$UPAGE"
expect 0 "dashboard: the range is the latest tag" -- grep -qF 'since v1' "$UPAGE"
expect 0 "dashboard: no cost without prices, and the page says so" -- grep -qF 'No cost is shown' "$UPAGE"
# Privacy: nothing written as content in any source reaches the page.
expect 1 "dashboard privacy: no prompt, reply, tool, commit-body or registry text in the page" -- \
  grep -qF 'OBS326-SENTINEL' "$UPAGE"
expect 1 "dashboard privacy: no co-author e-mail address in the page" -- grep -qF 'noreply@' "$UPAGE"
expect 1 "dashboard: self-contained, no URL to fetch anything from" -- grep -qE 'https?://' "$UPAGE"

printf 'claude-test-1\t1000000\t2000000\t3000000\t4000000\n' > "$WORK/usage-prices.tsv"
expect 0 "dashboard: --prices computes a cost per model" -- \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE" --transcripts-dir "$UT" --prices "$WORK/usage-prices.tsv"
expect 0 "dashboard: the cost is input+output+cache write+cache read at the stated prices" -- \
  grep -qF ">\$4245<" "$UPAGE"

# F1/F2/F6 (PR #196 review): a model writes subagent_type, model and
# agentType itself, so prose or a credential can arrive in any of them. Each
# leak below is shaped like ordinary text: with a space, longer than 64
# characters, credential-shaped, or a timestamp that is not a date. None may
# reach the page. The same fixture checks named-teammate attribution: a
# subagent's agentType is the dispatch NAME, resolved through the dispatch to
# its type, or through toolUseId when the meta carries one.
UT2="$WORK/usage-transcripts-leak"
rm -rf "$UT2"
mkdir -p "$UT2/s2/subagents"
cat > "$UT2/s2.jsonl" <<'JSONL'
{"type":"assistant","timestamp":"TSLEAKXYZW-not-a-date","message":{"id":"msg_L1","model":"OBS326-LEAK model with spaces","content":[{"type":"tool_use","id":"toolu_L1","name":"Agent","input":{"subagent_type":"OBS326-LEAK the database password is hunter2","model":"OBS326-LEAK opus please"}}],"usage":{"input_tokens":"OBS326-LEAK-COUNT","output_tokens":1,"cache_creation_input_tokens":null,"cache_read_input_tokens":0}}}
{"type":"assistant","timestamp":"2026-10-03T08:00:00Z","message":{"id":"msg_L2","model":"OBS326LEAKLONGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","content":[{"type":"tool_use","id":"toolu_L2","name":"Agent","input":{"subagent_type":"OBS326LEAKLONGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","model":"OBS326LEAKLONGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}}],"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
{"type":"assistant","timestamp":"2026-10-03T08:01:00Z","message":{"id":"msg_L3","model":"claude-test-1","content":[{"type":"tool_use","id":"toolu_L3","name":"Agent","input":{"subagent_type":"AKIAOBS326LEAKZZ","model":"sonnet"}},{"type":"tool_use","id":"toolu_T1","name":"Agent","input":{"subagent_type":"devops-engineer","name":"lexer-attack"}},{"type":"tool_use","id":"toolu_T2","name":"Agent","input":{"subagent_type":"security-engineer","name":"OBS326-LEAK name with space"}}],"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
JSONL
printf '%s\n' '{"type":"assistant","timestamp":"2026-10-03T08:02:00Z","message":{"id":"msg_T1","model":"claude-test-1","content":[],"usage":{"input_tokens":3,"output_tokens":3,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' > "$UT2/s2/subagents/agent-t.jsonl"
printf '%s\n' '{"agentType":"lexer-attack"}' > "$UT2/s2/subagents/agent-t.meta.json"
printf '%s\n' '{"type":"assistant","timestamp":"2026-10-03T08:03:00Z","message":{"id":"msg_T2","model":"claude-test-1","content":[],"usage":{"input_tokens":4,"output_tokens":4,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' > "$UT2/s2/subagents/agent-u.jsonl"
printf '%s\n' '{"agentType":"OBS326-LEAK meta with space","toolUseId":"toolu_T2"}' > "$UT2/s2/subagents/agent-u.meta.json"
printf '%s\n' '{"type":"assistant","timestamp":"2026-10-03T08:04:00Z","message":{"id":"msg_T3","model":"claude-test-1","content":[],"usage":{"input_tokens":5,"output_tokens":5,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' > "$UT2/s2/subagents/agent-v.jsonl"
printf '%s\n' '{"agentType":"OBS326LEAKLONGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}' > "$UT2/s2/subagents/agent-v.meta.json"

expect 0 "collector: malformed values are aggregated without a jq error" -- \
  bash "$COLLECT" --transcripts-dir "$UT2"
expect 1 "collector: nothing went to jq's error output" -- grep -qF 'jq:' <<< "$LAST_OUTPUT"
UPAGE2="$WORK/usage-out/leak.html"
expect 0 "dashboard: builds from the malformed transcript" -- \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE2" --transcripts-dir "$UT2"
expect 1 "dashboard privacy: no value with a space reaches the page (subagent_type, model, name, agentType)" -- \
  grep -qF 'OBS326-LEAK' "$UPAGE2"
expect 1 "dashboard privacy: no value longer than 64 characters reaches the page" -- \
  grep -qF 'OBS326LEAKLONG' "$UPAGE2"
expect 1 "dashboard privacy: a credential-shaped agent type is redacted" -- grep -qF 'AKIAOBS326' "$UPAGE2"
expect 0 "dashboard privacy: the redacted bucket is shown instead" -- grep -qF '(redacted)' "$UPAGE2"
expect 0 "dashboard privacy: the unrecognised bucket is shown instead" -- grep -qF '(unrecognised)' "$UPAGE2"
expect 1 "dashboard privacy: a timestamp that is not a date does not reach the page" -- grep -qF 'TSLEAKXYZW' "$UPAGE2"
expect 0 "dashboard: a timestamp that is not a date counts under 'unknown'" -- grep -qF '"day":"unknown"' "$UPAGE2"
expect 0 "dashboard: a teammate's tokens go to its dispatch's type, not its name" -- \
  grep -qF '"agent":"devops-engineer"' "$UPAGE2"
expect 1 "dashboard: the teammate name itself is not used as the agent" -- grep -qF '"agent":"lexer-attack"' "$UPAGE2"
expect 0 "dashboard: a subagent is attributed through its toolUseId" -- \
  grep -qF '"agent":"security-engineer"' "$UPAGE2"

# The default lookup: <config>/projects/<slug>, the slug being the project's
# native absolute path with every non-alphanumeric character turned to '-'.
USAGE_NATIVE="$(cd "$USAGE_REPO" && pwd -P)"
if command -v cygpath >/dev/null 2>&1; then USAGE_NATIVE="$(cygpath -w "$USAGE_NATIVE")"; fi
USAGE_SLUG="$(printf '%s' "$USAGE_NATIVE" | sed 's/[^A-Za-z0-9]/-/g')"
rm -rf "$WORK/usage-slug-config"
mkdir -p "$WORK/usage-slug-config/projects/$USAGE_SLUG"
cp -R "$UT/." "$WORK/usage-slug-config/projects/$USAGE_SLUG/"
expect 0 "dashboard: finds the transcripts by the project's slug without --transcripts-dir" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-slug-config" bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE"
expect_output "source found: Claude Code transcripts"
expect 0 "dashboard: the slug-found transcripts carry the same dispatch" -- \
  grep -qF '"name":"Observability Engineer","roster":"framework","dispatches":1' "$UPAGE"

# R1 (PR #196 security re-review): one dispatch per credential family, each
# as a subagent_type. All nine must count under (redacted) — including the
# ones whose `_` the shape alone would only have called unrecognised — and
# none may reach the page. The values are deliberately short of the real
# formats' lengths, so no secret scanner mistakes the fixture for a key.
UT3="$WORK/usage-transcripts-secret"
rm -rf "$UT3"
mkdir -p "$UT3"
{
  i=0
  for v in AIzaOBS326aaaaaaaaaaaaaaaa eyJOBS326abc.def hf_OBS326aaaaaaaaaaaaaaaa glpat-OBS326aaaa \
           npm_OBS326aaaaaaaaaaaaaaaa xapp-OBS326-1-aaaa ASIAOBS326ZZZZZZ rk_live_OBS326aaaa \
           OBS326aaaaaaaaaaaaaaaaaaaaaaaaaa; do
    i=$((i + 1))
    printf '{"type":"assistant","timestamp":"2026-10-04T08:00:00Z","message":{"id":"msg_S%s","model":"claude-test-1","content":[{"type":"tool_use","id":"toolu_S%s","name":"Agent","input":{"subagent_type":"%s"}}],"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' "$i" "$i" "$v"
  done
} > "$UT3/s3.jsonl"
UPAGE3="$WORK/usage-out/secret.html"
expect 0 "dashboard: builds from credential-shaped agent types" -- \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE3" --transcripts-dir "$UT3"
expect 0 "dashboard privacy: all nine credential families count as (redacted)" -- \
  grep -qF '{"type":"(redacted)","model":"inherit","n":9}' "$UPAGE3"
expect 1 "dashboard privacy: no credential-shaped value reaches the page" -- grep -qF 'OBS326' "$UPAGE3"

# The collector and the dashboard carry the same expression, by design in two
# places (the git half must not depend on the runtime half being present).
expect 0 "dashboard and collector redact with the same SECRET_RE" -- \
  test "$(grep '^SECRET_RE=' "$DASH")" = "$(grep '^SECRET_RE=' "$COLLECT")"

# R2 and HTML injection: git trailer values pass the same credential check,
# and a trailer that is markup is a value of the wrong shape, never markup.
new_repo usage-git
write_employee_roster "DevOps Engineer"
git add -A && git commit -q -m "roster"
commit_with "feat: a secret as a name" "Employee: AIzaOBS326aaaaaaaaaaaaaaaa"
commit_with "feat: markup as a name" "Employee: </script><img src=x onerror=alert(1)>"
UPAGE4="$WORK/usage-out/git.html"
mkdir -p "$WORK/usage-empty-config"
expect 0 "dashboard: builds from hostile trailer values" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$PWD" --out "$UPAGE4"
expect 0 "dashboard privacy: a credential-shaped Employee trailer counts as (redacted)" -- \
  grep -qF '{"name":"(redacted)","commits":1}' "$UPAGE4"
expect 1 "dashboard privacy: the credential-shaped trailer value is absent" -- grep -qF 'OBS326' "$UPAGE4"
expect 0 "dashboard: a markup trailer counts as (unrecognised)" -- \
  grep -qF '{"name":"(unrecognised)","commits":1}' "$UPAGE4"
expect 1 "dashboard: the markup trailer does not reach the page as markup" -- grep -qF '<img src=x' "$UPAGE4"
expect 1 "dashboard: nor as an event handler" -- grep -qF 'onerror=alert' "$UPAGE4"

# R3: on Windows, --open goes through explorer.exe, which reads a comma as a
# switch separator; a path with one is refused. uname, cygpath and
# explorer.exe are stubbed so the Windows branch runs on any host.
WSTUB="$WORK/usage-winstub"
rm -rf "$WSTUB"
mkdir -p "$WSTUB"
cat > "$WSTUB/uname" <<'STUB'
#!/usr/bin/env bash
echo MINGW64_NT-10.0
STUB
cat > "$WSTUB/cygpath" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${@: -1}"
STUB
cat > "$WSTUB/explorer.exe" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$1" > "$WSTUB/explorer-called.txt"
exit 1
STUB
chmod +x "$WSTUB/uname" "$WSTUB/cygpath" "$WSTUB/explorer.exe"
expect 1 "dashboard: --open on Windows refuses a path with a comma" -- \
  env PATH="$WSTUB:$PATH" CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$WORK/usage-out/a,b.html" --open
expect_output "contains a comma"
expect 1 "dashboard: explorer.exe was not called for the comma path" -- test -f "$WSTUB/explorer-called.txt"
expect 0 "dashboard: --open on Windows hands a comma-free path to explorer.exe (its exit 1 ignored)" -- \
  env PATH="$WSTUB:$PATH" CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE" --open
expect 0 "dashboard: explorer.exe received the page path" -- grep -qF 'dashboard.html' "$WSTUB/explorer-called.txt"

# WU-IAENG-330 — the runtime's own override of the slug is honoured.
TAB=$'\t'
cat > "$WORK/usage-opener330.sh" <<OPENER
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "$WORK/usage-opened330.txt"
OPENER
chmod +x "$WORK/usage-opener330.sh"
rm -rf "$WORK/usage-named-config"
mkdir -p "$WORK/usage-named-config/projects/obs330-named"
cp -R "$UT/." "$WORK/usage-named-config/projects/obs330-named/"
expect 0 "collector: CLAUDE_CODE_PROJECT_DIR_NAME names the transcript directory" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-named-config" CLAUDE_CODE_PROJECT_DIR_NAME=obs330-named \
  bash "$COLLECT" --project-dir "$USAGE_REPO"
expect_output "dispatch${TAB}observability-engineer${TAB}opus${TAB}1"

# WU-IAENG-330 — incremental reading. A cached run re-reads only what grew,
# from the last complete line; the result must equal a from-scratch read at
# every step. A line still being written (no newline) is not counted until it
# is complete, and is then counted once.
UTI="$WORK/usage-transcripts-incr"
UCACHE="$WORK/usage-collect-cache"
rm -rf "$UTI" "$UCACHE"
mkdir -p "$UTI"
cp "$UT/s1.jsonl" "$UTI/s1.jsonl"
usage_line() {
  printf '{"type":"assistant","timestamp":"2026-10-06T09:00:00Z","message":{"id":"%s","model":"claude-test-1","content":[],"usage":{"input_tokens":%s,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' "$1" "$2"
}
# usage_source <cache-args...> — the collector's `source` line.
usage_source() { bash "$COLLECT" --transcripts-dir "$UTI" "$@" 2>/dev/null | head -n 1; }
expect 0 "collector cache: a first cached run equals an uncached one" -- \
  test "$(usage_source --cache-dir "$UCACHE")" = "$(usage_source)"
{ usage_line msg_G1 7; printf '\n'; } >> "$UTI/s1.jsonl"
expect 0 "collector cache: a grown file adds its new message (2 calls -> 3)" -- \
  test "$(usage_source --cache-dir "$UCACHE")" = "source${TAB}1${TAB}1${TAB}3${TAB}2"
usage_line msg_P1 9 | head -c 60 >> "$UTI/s1.jsonl"
expect 0 "collector cache: a line still being written is not counted yet" -- \
  test "$(usage_source --cache-dir "$UCACHE")" = "source${TAB}1${TAB}1${TAB}3${TAB}2"
{ usage_line msg_P1 9 | tail -c +61; printf '\n'; } >> "$UTI/s1.jsonl"
expect 0 "collector cache: once complete, it is counted once (3 -> 4)" -- \
  test "$(usage_source --cache-dir "$UCACHE")" = "source${TAB}1${TAB}1${TAB}4${TAB}2"
expect 0 "collector cache: the incremental result equals a from-scratch read" -- \
  test "$(bash "$COLLECT" --transcripts-dir "$UTI" --cache-dir "$UCACHE" 2>/dev/null | sort)" \
     = "$(bash "$COLLECT" --transcripts-dir "$UTI" 2>/dev/null | sort)"
mkdir -p "$UTI/s9"
{ usage_line msg_N1 1; printf '\n'; } > "$UTI/s9.jsonl"
expect 0 "collector cache: a new file is read (4 -> 5 calls, 2 files)" -- \
  test "$(usage_source --cache-dir "$UCACHE")" = "source${TAB}1${TAB}2${TAB}5${TAB}2"
rm -f "$UTI/s9.jsonl"
expect 0 "collector cache: a deleted file's records are dropped (5 -> 4)" -- \
  test "$(usage_source --cache-dir "$UCACHE")" = "source${TAB}1${TAB}1${TAB}4${TAB}2"
{ usage_line msg_S1 1; printf '\n'; } > "$UTI/s1.jsonl"
expect 0 "collector cache: a file that shrank is read again from the start (1 call)" -- \
  test "$(usage_source --cache-dir "$UCACHE")" = "source${TAB}1${TAB}1${TAB}1${TAB}0"

# WU-IAENG-330 — live mode. Bounded by IAENG_USAGE_WATCH_MAX_CYCLES, with a
# 1 s sleep standing in for the interval.
expect 2 "dashboard --watch: an interval under 10 s is refused" -- \
  bash "$DASH" --project-dir "$USAGE_REPO" --watch 5
expect_output "the interval is 10 to 86400 seconds"
UWPAGE="$WORK/usage-out/watch.html"
rm -f "$WORK/usage-opened330.txt"
expect 0 "dashboard --watch: two cycles, then a clean stop" -- \
  env IAENG_USAGE_WATCH_MAX_CYCLES=2 IAENG_USAGE_WATCH_SLEEP=1 IAENG_USAGE_OPENER="$WORK/usage-opener330.sh" \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UWPAGE" --transcripts-dir "$UT" --open --watch
expect_output "rebuilt in"
expect_output "no change in HEAD or the transcripts; page kept"
expect 0 "dashboard --watch: the page reloads itself every 10 s (the default)" -- \
  grep -qF '<meta http-equiv="refresh" content="10">' "$UWPAGE"
expect 0 "dashboard --watch: the header says when it was last updated" -- grep -qF 'last updated' "$UWPAGE"
expect 0 "dashboard --watch: --open opened the page once" -- \
  test "$(grep -c . "$WORK/usage-opened330.txt")" = 1
expect 0 "dashboard --watch: the live page carries the same aggregates" -- \
  grep -qF '"name":"Observability Engineer","roster":"framework","dispatches":1' "$UWPAGE"
expect 1 "dashboard: a page built without --watch has no reload directive" -- \
  grep -qF 'http-equiv="refresh"' "$UPAGE"
expect 0 "dashboard --watch 30 --open: an explicit interval before another flag" -- \
  env IAENG_USAGE_WATCH_MAX_CYCLES=1 IAENG_USAGE_OPENER="$WORK/usage-opener330.sh" \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UWPAGE" --transcripts-dir "$UT" --watch 30 --open
expect 0 "dashboard --watch 30: the page reloads every 30 s" -- \
  grep -qF '<meta http-equiv="refresh" content="30">' "$UWPAGE"

# WU-IAENG-330 — per project. A throwaway adopter with the framework as a
# submodule at ia-engineering/: the page reads the PROJECT's history, the
# framework roster plus the project roster, only the transcripts of the
# project's own slug, and is written under the project. The framework's own
# commits and the transcripts of the framework's path are not counted.
FWREPO="$WORK/usage-framework"
rm -rf "$FWREPO"
mkdir -p "$FWREPO/Adapters/scripts" "$FWREPO/Adapters/ai-runtimes/claude-code" "$FWREPO/Registry"
cp "$DASH" "$FWREPO/Adapters/scripts/"
cp "$COLLECT" "$FWREPO/Adapters/ai-runtimes/claude-code/"
(
  cd "$FWREPO" || exit 1
  git init -q -b main .
  git config user.email test@example.invalid
  git config user.name "Test Runner"
  git config commit.gpgsign false
  git config core.autocrlf false
  ROSTER_TARGET=Registry/employees.yml write_employee_roster "DevOps Engineer" "Observability Engineer"
  git add -A
  git commit -q -m "framework work

Employee: DevOps Engineer"
)
new_repo usage-adopter
ADOPTER="$PWD"
git -c protocol.file.allow=always submodule add -q "$FWREPO" ia-engineering >/dev/null 2>&1
git commit -q -m "adopt the framework"
ROSTER_TARGET=.ia-engineering/Registry/employees.yml write_employee_roster "Domain Expert"
ACFG="$WORK/usage-adopter-config"
rm -rf "$ACFG"
mkdir -p "$ACFG"
expect 0 "adopter: the dashboard runs from the project root through the submodule path" -- \
  env CLAUDE_CONFIG_DIR="$ACFG" bash ia-engineering/Adapters/scripts/usage-dashboard.sh
expect 0 "adopter: the page is written under the project" -- test -s "$ADOPTER/.ia-engineering/usage/dashboard.html"
expect 1 "adopter: nothing is written under the framework" -- test -e "$ADOPTER/ia-engineering/.ia-engineering/usage/dashboard.html"
APAGE="$ADOPTER/.ia-engineering/usage/dashboard.html"
expect 0 "adopter: the project roster is unioned in" -- grep -qF '"name":"Domain Expert","roster":"project"' "$APAGE"
expect 0 "adopter: a new project starts at zero - every Employee never used" -- \
  grep -qF '"totals":{"roster":3,"never":3,"rare":0,"dispatches":0' "$APAGE"
expect 0 "adopter: the framework's own commits are not the project's" -- \
  grep -qF '"name":"DevOps Engineer","roster":"framework","dispatches":0,"commits_range":0,"commits_all":0' "$APAGE"
# Transcripts: one under the project's slug, one under the framework
# submodule's path — only the first is the project's.
ANATIVE="$(cd "$ADOPTER" && pwd -P)"
FNATIVE="$(cd "$ADOPTER/ia-engineering" && pwd -P)"
if command -v cygpath >/dev/null 2>&1; then ANATIVE="$(cygpath -w "$ANATIVE")"; FNATIVE="$(cygpath -w "$FNATIVE")"; fi
ASLUG="$(printf '%s' "$ANATIVE" | sed 's/[^A-Za-z0-9]/-/g')"
FSLUG="$(printf '%s' "$FNATIVE" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$ACFG/projects/$ASLUG" "$ACFG/projects/$FSLUG"
printf '%s\n' '{"type":"assistant","timestamp":"2026-10-06T10:00:00Z","message":{"id":"msg_AD1","model":"claude-test-1","content":[{"type":"tool_use","id":"toolu_AD1","name":"Agent","input":{"subagent_type":"observability-engineer"}}],"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' > "$ACFG/projects/$ASLUG/s.jsonl"
printf '%s\n' '{"type":"assistant","timestamp":"2026-10-06T10:00:00Z","message":{"id":"msg_FW1","model":"claude-test-1","content":[{"type":"tool_use","id":"toolu_FW1","name":"Agent","input":{"subagent_type":"devops-engineer"}}],"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' > "$ACFG/projects/$FSLUG/s.jsonl"
commit_with "feat: first real work" "Work Unit: WU-AD-001" "" "Employee: Observability Engineer"
expect 0 "adopter: run from INSIDE the submodule, the project is still the one measured" -- \
  env CLAUDE_CONFIG_DIR="$ACFG" bash -c 'cd ia-engineering && bash Adapters/scripts/usage-dashboard.sh'
expect_output "the project that includes this framework"
expect 0 "adopter: the project's own dispatch and commit are counted" -- \
  grep -qF '"name":"Observability Engineer","roster":"framework","dispatches":1,"commits_range":1,"commits_all":1' "$APAGE"
expect 0 "adopter: the framework path's transcripts are not the project's" -- \
  grep -qF '"name":"DevOps Engineer","roster":"framework","dispatches":0' "$APAGE"
cd "$WORK" || exit 1

# ---- PR #204 review regressions (Security Engineer F1-F9, Code Reviewer M1/m1/m2)

# F1 — a .meta.json's free-text description never reaches the cache.
UTM="$WORK/usage-transcripts-meta"
UCM="$WORK/usage-cache-meta"
rm -rf "$UTM" "$UCM"
mkdir -p "$UTM/s/subagents"
cp "$UT/s1.jsonl" "$UTM/s.jsonl"
printf '%s\n' '{"type":"assistant","timestamp":"2026-10-06T08:00:00Z","message":{"id":"msg_M1","model":"claude-test-1","content":[],"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' > "$UTM/s/subagents/agent-m.jsonl"
printf '%s\n' '{"agentType":"devops-engineer","description":"OBS330-DESC-SENTINEL rotate the prod key","toolUseId":"toolu_M1"}' > "$UTM/s/subagents/agent-m.meta.json"
expect 0 "F1: a cached run over a subagent with a described dispatch" -- \
  bash "$COLLECT" --transcripts-dir "$UTM" --cache-dir "$UCM"
expect 1 "F1: no .meta.json description text anywhere in the cache" -- grep -rqF 'OBS330-DESC-SENTINEL' "$UCM"
expect 1 "F1: no per-run work files are left in the cache" -- test -e "$UCM/v1/work"
expect 0 "F1: the subagent is still labelled from agentType" -- \
  bash "$COLLECT" --transcripts-dir "$UTM"
expect_output "${TAB}devops-engineer${TAB}"

# F2 + M1 — a slug longer than the runtime keeps. IAENG_USAGE_SLUG_MAX
# stands in for 200, so two sibling paths share the kept prefix.
new_repo usage-long-alpha
LALPHA="$PWD"
mkdir -p "$WORK/usage-long-beta"
lnative() { local p; p="$(cd "$1" && pwd -P)"; if command -v cygpath >/dev/null 2>&1; then p="$(cygpath -w "$p")"; fi; printf '%s' "$p"; }
LA="$(lnative "$LALPHA")"
LB="$(lnative "$WORK/usage-long-beta")"
LCOMMON="$(lnative "$WORK")"
LPREFIX="${LCOMMON//[^A-Za-z0-9]/-}-usage-long-"
LMAX="${#LPREFIX}"
case "$LA" in *\\*) LSEP="\\" ;; *) LSEP="/" ;; esac
jsonpath() { local p="$1"; printf '%s' "${p//\\/\\\\}"; }
long_dir() {  # long_dir <suffix> <cwd-or-empty> <msg-id> <input>
  local d="$WORK/usage-long-config/projects/${LPREFIX}-$1"
  mkdir -p "$d"
  if [ -n "$2" ]; then
    printf '{"type":"user","cwd":"%s","sessionId":"s-%s"}\n' "$(jsonpath "$2")" "$1" > "$d/s.jsonl"
  else
    printf '{"type":"user","sessionId":"s-%s"}\n' "$1" > "$d/s.jsonl"
  fi
  printf '{"type":"assistant","timestamp":"2026-10-06T08:00:00Z","message":{"id":"%s","model":"claude-test-1","content":[],"usage":{"input_tokens":%s,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' "$3" "$4" >> "$d/s.jsonl"
}
rm -rf "$WORK/usage-long-config"
long_dir hashA "$LA" msg_LA 11
long_dir hashB "$LB" msg_LB 22
long_dir hashW "$LA${LSEP}.claude${LSEP}worktrees${LSEP}w1" msg_LW 33
expect 0 "F2: a sibling sharing the kept prefix is skipped, the project and its worktree kept" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-long-config" IAENG_USAGE_SLUG_MAX="$LMAX" \
  bash "$COLLECT" --project-dir "$LALPHA"
expect_output "source${TAB}2${TAB}2${TAB}2${TAB}0"
expect_output "recorded in another project"
long_dir hashU "" msg_LU 44
expect 4 "M1: a candidate whose owner cannot be read makes the source ambiguous (exit 4)" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-long-config" IAENG_USAGE_SLUG_MAX="$LMAX" \
  bash "$COLLECT" --project-dir "$LALPHA"
expect_output "AMBIGUOUS"
LPAGE="$WORK/usage-out/long.html"
expect 0 "M1: the dashboard still builds, and says the transcripts are ambiguous" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-long-config" IAENG_USAGE_SLUG_MAX="$LMAX" \
  bash "$DASH" --project-dir "$LALPHA" --out "$LPAGE"
expect 0 "M1: the page names the source ambiguous" -- grep -qF '"status":"ambiguous"' "$LPAGE"
expect 0 "M1: no transcript usage is counted for an ambiguous source" -- grep -qF '"have_transcripts":false' "$LPAGE"
rm -rf "$WORK/usage-long-config/projects/${LPREFIX}-hashU"
long_dir hashA2 "$LA" msg_LA2 55
expect 4 "M1: two directories both recorded in the project root are ambiguous too" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-long-config" IAENG_USAGE_SLUG_MAX="$LMAX" \
  bash "$COLLECT" --project-dir "$LALPHA"
cd "$WORK" || exit 1

# F3 — a poisoned index or record is not trusted: no command runs, no file
# outside rec/ is touched, a cached value is shaped again.
UTP="$WORK/usage-transcripts-poison"
UCP="$WORK/usage-cache-poison"
rm -rf "$UTP" "$UCP" "$WORK/PWNED_ARITH"
mkdir -p "$UTP"
cp "$UT/s1.jsonl" "$UTP/s1.jsonl"
expect 0 "F3: a first cached run" -- bash "$COLLECT" --transcripts-dir "$UTP" --cache-dir "$UCP"
printf 'victim\n' > "$UCP/victim.tsv"
{
  printf '%s\t1\t0\t1\tx\t%s\n' '../../victim' "$UTP/s1.jsonl"
  printf '7\t1\t%s\t1\tx\t%s\n' "PATH[\$(touch $WORK/PWNED_ARITH)0]" "$UTP/s1.jsonl"
} > "$UCP/v1/index.tsv"
printf '%s\n' '{"type":"assistant","timestamp":"2026-10-06T09:00:00Z","message":{"id":"msg_P2","model":"claude-test-1","content":[],"usage":{"input_tokens":5,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' >> "$UTP/s1.jsonl"
expect 0 "F3: a run over a poisoned index succeeds" -- bash "$COLLECT" --transcripts-dir "$UTP" --cache-dir "$UCP"
expect 1 "F3: an offset written as an arithmetic expression ran no command" -- test -e "$WORK/PWNED_ARITH"
expect 0 "F3: an idx written as a path did not touch a file outside rec/" -- grep -qxF victim "$UCP/victim.tsv"
expect 0 "F3: the poisoned index lines were ignored and the file read whole (3 calls)" -- \
  test "$(bash "$COLLECT" --transcripts-dir "$UTP" --cache-dir "$UCP" 2>/dev/null | head -n 1)" = "source${TAB}1${TAB}1${TAB}3${TAB}2"
for r in "$UCP"/v1/rec/*.tsv; do
  printf 'C\tmsg_POISON\t2026-10-06\tthe password is hunter2\tmain session\t\t1\t1\t0\t0\n' >> "$r"
done
expect 0 "F3: a run over a poisoned record" -- bash "$COLLECT" --transcripts-dir "$UTP" --cache-dir "$UCP"
expect_output "(unrecognised)"
expect 1 "F3: a cached value is shaped again, not passed through" -- grep -qF 'hunter2' <<< "$LAST_OUTPUT"

# m1 — a same-size rewrite and a replaced (rotated) file are read again.
UTR="$WORK/usage-transcripts-rotate"
UCR="$WORK/usage-cache-rotate"
rm -rf "$UTR" "$UCR"
mkdir -p "$UTR"
rot_line() { printf '{"type":"assistant","sessionId":"%s","timestamp":"2026-10-06T09:00:00Z","message":{"id":"%s","model":"claude-test-1","content":[],"usage":{"input_tokens":%s,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' "$1" "$2" "$3"; }
rot_line sessA msg_R1 7 > "$UTR/s.jsonl"
expect 0 "m1: a first cached run" -- bash "$COLLECT" --transcripts-dir "$UTR" --cache-dir "$UCR"
rot_line sessA msg_R1 9 > "$UTR/s.jsonl"
touch -d '2030-01-01 00:00:00' "$UTR/s.jsonl"
expect 0 "m1: a same-size rewrite with a new mtime is read again (input 9, not 7)" -- \
  test "$(bash "$COLLECT" --transcripts-dir "$UTR" --cache-dir "$UCR" 2>/dev/null | sort)" = "$(bash "$COLLECT" --transcripts-dir "$UTR" 2>/dev/null | sort)"
{ rot_line sessB msg_R2 1000; rot_line sessB msg_R3 7; } > "$UTR/s.jsonl"
expect 0 "m1: a replaced file that grew is read from the start, not from the old offset" -- \
  test "$(bash "$COLLECT" --transcripts-dir "$UTR" --cache-dir "$UCR" 2>/dev/null | sort)" = "$(bash "$COLLECT" --transcripts-dir "$UTR" 2>/dev/null | sort)"

# F8 — a file name with a newline is skipped with a warning; the rest counts.
UT8="$WORK/usage-transcripts-newline"
rm -rf "$UT8"
mkdir -p "$UT8"
cp "$UT/s1.jsonl" "$UT8/s1.jsonl"
cp "$UT/s1.jsonl" "$UT8/n${NL:=$'\n'}l.jsonl"
expect 0 "F8: a transcript named with a newline does not stop the others" -- \
  bash "$COLLECT" --transcripts-dir "$UT8"
expect_output "WARNING: skipped 1 transcript file(s)"
expect_output "source${TAB}1${TAB}1${TAB}2${TAB}2"

# F9 — a raw transcript line cannot pose as a file marker.
UT9="$WORK/usage-transcripts-marker"
rm -rf "$UT9"
mkdir -p "$UT9"
cp "$UT/s1.jsonl" "$UT9/s1.jsonl"
printf '\036S 999 {"agentType":"x"} {"type":"assistant","message":{"id":"msg_F9","model":"claude-test-1","usage":{"input_tokens":1}}}\n' >> "$UT9/s1.jsonl"
expect 0 "F9: a forged marker line is dropped, not obeyed" -- bash "$COLLECT" --transcripts-dir "$UT9"
expect_output "source${TAB}1${TAB}1${TAB}2${TAB}2"

# F7 — the slug override is honoured only as the runtime honours it.
mkdir -p "$WORK/usage-home7/.claude/projects/obs330-named"
cp -R "$UT/." "$WORK/usage-home7/.claude/projects/obs330-named/"
expect 3 "F7: without CLAUDE_CONFIG_DIR the override is ignored, as the runtime ignores it" -- \
  env -u CLAUDE_CONFIG_DIR HOME="$WORK/usage-home7" CLAUDE_CODE_PROJECT_DIR_NAME=obs330-named \
  bash "$COLLECT" --project-dir "$USAGE_REPO"
expect 3 "F7: an override that is not a plain name is ignored" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-named-config" CLAUDE_CODE_PROJECT_DIR_NAME='../usage-named-config/projects/obs330-named' \
  bash "$COLLECT" --project-dir "$USAGE_REPO"

# F4 / m2 — the interval is a plain decimal within bounds, or refused.
mkdir -p "$WORK/usage-empty-config"
for bad in 018 010 18446744073709551615 86401 9; do
  expect 2 "F4: --watch $bad is refused, never a silent one-shot build" -- \
    env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO" --watch "$bad"
done
WTMP="$WORK/usage-watch-tmp"
rm -rf "$WTMP"
mkdir -p "$WTMP"
# F5 — the sleep knob is a number or nothing; this one would run a command.
expect 0 "F5: a watch run with an arithmetic-expression sleep knob" -- \
  env TMPDIR="$WTMP" CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" IAENG_USAGE_WATCH_MAX_CYCLES=2 \
  IAENG_USAGE_WATCH_SLEEP="SECONDS[\$(touch $WORK/PWNED_SLEEP)0]*0+1" \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$WORK/usage-out/f5.html" --watch
expect 1 "F5: the sleep knob ran no command" -- test -e "$WORK/PWNED_SLEEP"
expect 0 "F4: the watch's temporary directory is removed when it stops" -- \
  test -z "$(find "$WTMP" -mindepth 1 -maxdepth 1 -name 'obs330-watch.*' 2>/dev/null)"

# The Windows launcher passes the script as a native path (C:\...\x.sh); a
# --watch build re-runs the script by that path, so it must resolve. Found
# by running usage-dashboard.cmd --watch for real (WU-IAENG-330).
UDASH_NATIVE="$DASH"
if command -v cygpath >/dev/null 2>&1; then UDASH_NATIVE="$(cygpath -w "$DASH")"; fi
expect 0 "watch: started by the script's native path, the rebuild finds the script" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" IAENG_USAGE_WATCH_MAX_CYCLES=1 \
  bash "$UDASH_NATIVE" --project-dir "$USAGE_REPO" --out "$WORK/usage-out/native.html" --watch
expect_output "rebuilt in"

# F6 — a file already at the temporary page's name is never written through.
F6DIR="$WORK/usage-out-f6"
rm -rf "$F6DIR"
mkdir -p "$F6DIR"
# The planter takes the dashboard's PID by exec'ing it, so it knows the
# temporary name the dashboard will try first.
cat > "$WORK/usage-f6-planter.sh" <<'PLANT'
#!/usr/bin/env bash
printf decoy > "$1/.page.html.$$.tmp"
exec bash "$2" --project-dir "$3" --out "$1/page.html"
PLANT
expect 0 "F6: the page is written although its first temporary name is taken" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$WORK/usage-f6-planter.sh" "$F6DIR" "$DASH" "$USAGE_REPO"
expect 0 "F6: the planted file is untouched" -- test "$(cat "$F6DIR"/.page.html.*.tmp 2>/dev/null)" = decoy
expect 0 "F6: the page itself was written" -- grep -qF 'usage-data' "$F6DIR/page.html"
expect 0 "F6: no private page directory is left behind" -- \
  test -z "$(find "$F6DIR" -mindepth 1 -maxdepth 1 -name '.usage-dashboard.*' 2>/dev/null)"

# Security re-check R1 — noclobber refuses regular files only: a FIFO at a
# predictable name would have received the page or blocked the build. The
# page is now rendered inside a private mktemp directory, so nothing planted
# in the output folder is opened. Bounded by timeout: a hang is a failure.
F7DIR="$WORK/usage-out-fifo"
rm -rf "$F7DIR"
mkdir -p "$F7DIR"
cat > "$WORK/usage-fifo-planter.sh" <<'PLANT'
#!/usr/bin/env bash
mkfifo "$1/.page.html.$$.tmp"
exec bash "$2" --project-dir "$3" --out "$1/page.html"
PLANT
expect 0 "R1-sec: a FIFO planted at a predictable name neither receives the page nor blocks the build" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" timeout 300 bash "$WORK/usage-fifo-planter.sh" "$F7DIR" "$DASH" "$USAGE_REPO"
expect 0 "R1-sec: the page was written" -- grep -qF 'usage-data' "$F7DIR/page.html"

# Code re-check R1 — a native Windows --out path (C:\...\x.html) is used as
# given; on POSIX hosts the same test passes the POSIX path.
UNATIVE_OUT="$WORK/usage-out/native-out/dash.html"
UNATIVE_ARG="$UNATIVE_OUT"
if command -v cygpath >/dev/null 2>&1; then UNATIVE_ARG="$(cygpath -w "$UNATIVE_OUT")"; fi
expect 0 "R1: --out given as a native path builds the page there" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO" --out "$UNATIVE_ARG"
expect 0 "R1: the page is at that path" -- grep -qF 'usage-data' "$UNATIVE_OUT"
rm -f "$UNATIVE_OUT"
expect 0 "R1: the same under --watch" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" IAENG_USAGE_WATCH_MAX_CYCLES=1 \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UNATIVE_ARG" --watch
expect 0 "R1: the watch page is at that path, with its reload directive" -- \
  grep -qF 'http-equiv="refresh"' "$UNATIVE_OUT"
expect 0 "R1: the watch removed its private page directory" -- \
  test -z "$(find "$WORK/usage-out/native-out" -mindepth 1 -maxdepth 1 -name '.usage-dashboard.*' 2>/dev/null)"

# Code re-check suggestion — a leading zero is named as the reason.
expect 2 "--watch 010 says why it is refused" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO" --watch 010
expect_output "without a leading zero"

# Security re-check R2 — a cached record line that starts with digits is not
# a store instruction: only new records from stdin are filed under rec/.
mkdir -p "$UCP/v1/rec/1"
for r in "$UCP"/v1/rec/*.tsv; do
  printf '1/../../ESCAPED\tC\tmsg_ESC\t2026-10-06\tclaude-test-1\tmain session\t\t1\t1\t0\t0\n' >> "$r"
done
expect 0 "R2-sec: a run over a cache holding a digit-prefixed record line" -- \
  bash "$COLLECT" --transcripts-dir "$UTP" --cache-dir "$UCP"
expect 1 "R2-sec: no file was written outside rec/" -- test -e "$UCP/v1/ESCAPED.tsv"

# Security re-check: under mawk 1.3.4 an open-ended {24,} matched every
# name, so every name came out (redacted). Both scripts run here with `awk`
# being mawk where it is installed (Debian/Ubuntu, CI), the default awk
# otherwise; ordinary names must survive, a credential must not.
UAWK="$WORK/usage-awk-bin"
mkdir -p "$UAWK"
if command -v mawk >/dev/null 2>&1; then
  cat > "$UAWK/awk" <<'SHIM'
#!/usr/bin/env bash
exec mawk "$@"
SHIM
  chmod +x "$UAWK/awk"
fi
expect 0 "mawk: the dashboard builds with the platform's awk" -- \
  env PATH="$UAWK:$PATH" bash "$DASH" --project-dir "$USAGE_REPO" --out "$WORK/usage-out/mawk.html" --transcripts-dir "$UT"
expect 0 "mawk: ordinary Employee names and dispatches survive" -- \
  grep -qF '"name":"Observability Engineer","roster":"framework","dispatches":1' "$WORK/usage-out/mawk.html"
expect 1 "mawk: no ordinary model is taken for a credential" -- grep -qF '"model":"(redacted)"' "$WORK/usage-out/mawk.html"
expect 0 "mawk: a credential-shaped trailer is still redacted" -- \
  env PATH="$UAWK:$PATH" CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$WORK/usage-git" --out "$WORK/usage-out/mawk-git.html"
expect 0 "mawk: the credential counts as (redacted)" -- grep -qF '{"name":"(redacted)","commits":1}' "$WORK/usage-out/mawk-git.html"

# Security re-check R3: an output folder other users can write to, without
# the sticky bit, is refused; with it, accepted. Windows has no mode bits:
# there the build proceeds.
U3="$WORK/usage-out-shared"
rm -rf "$U3"
mkdir -p "$U3"
chmod 0777 "$U3"
U3WANT=1
case "${OSTYPE:-}" in msys*|cygwin*|win*) U3WANT=0 ;; esac
expect "$U3WANT" "R3: a world-writable output folder without the sticky bit is refused (not on Windows)" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO" --out "$U3/page.html"
chmod 1777 "$U3"
expect 0 "R3: with the sticky bit it is accepted" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO" --out "$U3/page.html"
# A private folder reached through a symlink is judged by the folder, not by
# the link, whose own mode reads 0777 on Linux (code review suggestion).
rm -rf "$WORK/usage-out-private" "$WORK/usage-out-link"
mkdir -p "$WORK/usage-out-private"
chmod 0700 "$WORK/usage-out-private"
ln -s "$WORK/usage-out-private" "$WORK/usage-out-link"
expect 0 "R3: a private folder reached through a symlink is accepted" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO" --out "$WORK/usage-out-link/page.html"

mkdir -p "$WORK/usage-empty-config"
expect 0 "dashboard: builds without any transcript" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO"
expect_output "source missing: Claude Code transcripts"
expect 0 "dashboard: the default output is .ia-engineering/usage/dashboard.html" -- \
  test -s "$USAGE_REPO/.ia-engineering/usage/dashboard.html"

cat > "$WORK/usage-opener.sh" <<OPENER
#!/usr/bin/env bash
printf '%s\n' "\$1" > "$WORK/usage-opened.txt"
OPENER
chmod +x "$WORK/usage-opener.sh"
rm -f "$WORK/usage-opened.txt"
expect 0 "dashboard: --open hands the page to the opener" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" IAENG_USAGE_OPENER="$WORK/usage-opener.sh" \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE" --open
expect 0 "dashboard: the opener received the page path" -- grep -qF 'dashboard.html' "$WORK/usage-opened.txt"

mkdir -p "$WORK/usage-not-a-repo"
expect 1 "dashboard: outside a git work tree it fails" -- \
  env GIT_CEILING_DIRECTORIES="$WORK" bash "$DASH" --project-dir "$WORK/usage-not-a-repo"
expect_output "is not inside a git work tree"
expect 1 "dashboard: a --since that is not a commit fails" -- \
  bash "$DASH" --project-dir "$USAGE_REPO" --out "$UPAGE" --since no-such-ref
expect 2 "dashboard: an unknown argument is a usage error" -- bash "$DASH" --bogus

mkdir -p "$WORK/usage-empty-transcripts"
expect 3 "collector: an empty transcript directory is 'none found' (3), not an error" -- \
  bash "$COLLECT" --transcripts-dir "$WORK/usage-empty-transcripts"
expect 1 "collector: an explicit transcript directory that does not exist is an error" -- \
  bash "$COLLECT" --transcripts-dir "$WORK/usage-no-such-dir"

# ---- WU-IAENG-341: kept fresh — persistent cache, fast open, refreshes ------
# A project that ignores .ia-engineering/usage/ (install.sh makes every adopter
# do so), a transcript copy of its own, an opener that records each page it is
# handed, and a TMPDIR of its own so leftovers can be counted. FRUN measures
# that project with the same arguments everywhere unless a case adds one.
new_repo usage-fresh
FRESH="$PWD"
write_employee_roster "DevOps Engineer" "Observability Engineer" "Scrum Master"
printf '.ia-engineering/usage/\n' > .gitignore
git add -A && git commit -q -m "roster and the ignore rule"
commit_with "feat: first" "OBS341-SENTINEL-BODY" "" "Work Unit: WU-TEST-001" "" "Employee: DevOps Engineer"
FT="$WORK/usage-fresh-transcripts"
FTMP="$WORK/usage-fresh-tmp"
rm -rf "$FT" "$FTMP"
mkdir -p "$FT" "$FTMP"
cp "$UT/s1.jsonl" "$FT/s1.jsonl"
FU="$FRESH/.ia-engineering/usage"
FC="$FU/cache"
FPAGE="$FU/dashboard.html"
FOPEN="$WORK/usage-fresh-opened.txt"
cat > "$WORK/usage-fresh-opener.sh" <<OPENER
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "$FOPEN"
OPENER
chmod +x "$WORK/usage-fresh-opener.sh"
FRUN=(env TMPDIR="$FTMP" IAENG_USAGE_OPENER="$WORK/usage-fresh-opener.sh"
  bash "$DASH" --project-dir "$FRESH" --transcripts-dir "$FT")

# The persistent cache: kept between runs, shaped values only.
expect 0 "cache: a first build" -- "${FRUN[@]}"
expect 1 "cache: an ignored cache is used, with no note about falling back" -- \
  grep -qF 'not using the persistent cache' <<< "$LAST_OUTPUT"
expect 0 "cache: the git half is kept in .ia-engineering/usage/cache" -- test -s "$FC/git/key"
expect 0 "cache: so are the transcript records" -- test -f "$FC/transcripts/v1/index.tsv"
expect 1 "cache: no work file is kept there (raw git output stays in a temporary directory)" -- test -e "$FC/build"
expect 1 "cache: no commit-message or transcript text is kept, only shaped values" -- \
  grep -rqE 'OBS341-SENTINEL|OBS326-SENTINEL' "$FC"
expect 0 "cache: the run's temporary directories are gone" -- test -z "$(find "$FTMP" -mindepth 1 -maxdepth 1)"
# Windows (noacl) keeps no mode bits, as for R3 above.
FPERM_WANT=0
case "${OSTYPE:-}" in msys*|cygwin*|win*) FPERM_WANT=1 ;; esac
expect "$FPERM_WANT" "cache: created 0700 (Windows has no mode bits to set)" -- \
  test -n "$(find "$FC/." -maxdepth 0 -perm 0700 2>/dev/null)"
# A row added to the cached git half, and a record added to a cached
# transcript file, are counted by the next run: it read the cache, not git
# and the transcripts again. Both are shaped values, as the cache holds.
printf 'feedfacefeedfacefeedfacefeedfacefeedface\t1\tScrum Master\t(no trailer)\tClaude Opus 5.5\t1\t1\n' >> "$FC/git/commits.tsv"
for r in "$FC"/transcripts/v1/rec/*.tsv; do
  printf 'C\tmsg_PERSIST341\t2026-10-07\tclaude-persist-341\tmain session\t\t1\t1\t0\t0\n' >> "$r"
done
expect 0 "cache: a second run" -- "${FRUN[@]}"
expect 0 "cache: it took the git half from the cache" -- \
  grep -qF '"name":"Scrum Master","roster":"framework","dispatches":0,"commits_range":1,"commits_all":1' "$FPAGE"
expect 0 "cache: and the transcript records" -- grep -qF '"model":"claude-persist-341"' "$FPAGE"
expect 0 "cache: a --watch started later uses the same cache" -- \
  env IAENG_USAGE_WATCH_MAX_CYCLES=1 "${FRUN[@]}" --watch
expect 0 "cache: the watch counted the cached record" -- grep -qF '"model":"claude-persist-341"' "$FPAGE"
expect 0 "cache: the cache outlives the watch" -- test -f "$FC/transcripts/v1/index.tsv"
expect 0 "cache: the watch left no temporary directory" -- test -z "$(find "$FTMP" -mindepth 1 -maxdepth 1)"
# An uncommitted registry edit is newer than the cached git half: read again.
printf '  - name: Domain Lead\n    category: Management\n' >> "$FRESH/Registry/employees.yml"
expect 0 "cache: a run after an uncommitted registry edit" -- "${FRUN[@]}"
expect 0 "cache: the edit is on the page" -- grep -qF '"name":"Domain Lead"' "$FPAGE"
expect 1 "cache: the git half was recomputed, not taken from the cache" -- \
  grep -qF '"name":"Scrum Master","roster":"framework","dispatches":0,"commits_range":1' "$FPAGE"

# Refused: a link (a junction on Windows, which [ -L ] reports as one), a
# directory another user owns, a cache git does not ignore. Each run falls
# back to a cache of its own and still writes the page.
FL="$WORK/usage-fresh-elsewhere"
rm -rf "$FC" "$FL"
mkdir -p "$FL"
case "${OSTYPE:-}" in
  msys*|cygwin*|win*) cmd //c mklink //J "$(cygpath -w "$FC")" "$(cygpath -w "$FL")" > /dev/null ;;
  *) ln -s "$FL" "$FC" ;;
esac
expect 0 "refusal: the cache is a link here" -- test -L "$FC"
expect 0 "refusal: a linked cache is not used; the page is still built" -- "${FRUN[@]}"
expect_output "is a symbolic link or a junction"
expect 0 "refusal: nothing was written through the link" -- test -z "$(find "$FL" -mindepth 1 2>/dev/null)"
case "${OSTYPE:-}" in msys*|cygwin*|win*) cmd //c rmdir "$(cygpath -w "$FC")" ;; *) rm -f "$FC" ;; esac
# Ownership: / is root's on Linux and macOS. Where / is the runner's own —
# as root, or under Git for Windows, whose noacl mount reads every path as
# the user's — no directory is another user's, and a private one is used.
if [ -O / ]; then
  UFOR="$WORK/usage-cache-own"
  mkdir -p "$UFOR"
  expect 0 "ownership: a cache directory of the user's own is used" -- \
    env IAENG_USAGE_CACHE="$UFOR" "${FRUN[@]}" --out "$WORK/usage-out/foreign.html"
  expect 0 "ownership: (no other owner exists here) its git half was written" -- test -s "$UFOR/git/key"
else
  expect 0 "ownership: a cache directory another user owns (/) is not used; the page is still built" -- \
    env IAENG_USAGE_CACHE=/ "${FRUN[@]}" --out "$WORK/usage-out/foreign.html"
  expect_output "is not owned by you"
fi
expect 0 "refusal: a project whose .gitignore does not cover the cache still gets its page" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$USAGE_REPO" --out "$WORK/usage-out/unignored.html"
expect_output "git does not ignore"
expect 1 "refusal: and no cache was created in it" -- test -e "$USAGE_REPO/.ia-engineering/usage/cache"

# Fast open: --open rebuilds only when something the page is built from changed.
rm -f "$FOPEN" "$FU/.dashboard.html.fingerprint"
expect 0 "fast open: --open with no fingerprint yet builds, then opens" -- "${FRUN[@]}" --open
expect_output "Usage dashboard written"
expect 0 "fast open: the fingerprint is beside the page" -- test -s "$FU/.dashboard.html.fingerprint"
: > "$WORK/usage-fresh-mark"
expect 0 "fast open: --open again with nothing changed" -- "${FRUN[@]}" --open
expect_output "is up to date"
expect 1 "fast open: no build ran" -- grep -qF 'Usage dashboard written' <<< "$LAST_OUTPUT"
expect 1 "fast open: the page was not rewritten" -- test "$FPAGE" -nt "$WORK/usage-fresh-mark"
expect 0 "fast open: the page was opened both times" -- test "$(grep -c . "$FOPEN")" = 2
commit_with "feat: second" "Work Unit: WU-TEST-002" "" "Employee: Observability Engineer"
expect 0 "fast open: after a new commit, --open rebuilds" -- "${FRUN[@]}" --open
expect_output "Usage dashboard written"
expect 0 "fast open: the new commit is on the page" -- \
  grep -qF '"name":"Observability Engineer","roster":"framework","dispatches":1,"commits_range":1,"commits_all":1' "$FPAGE"
{ usage_line msg_F341A 3; printf '\n'; } >> "$FT/s1.jsonl"
expect 0 "fast open: after a transcript grew, --open rebuilds" -- "${FRUN[@]}" --open
expect_output "Usage dashboard written"
git tag v9
expect 0 "fast open: after a new release tag on the same commit, --open rebuilds" -- "${FRUN[@]}" --open
expect_output "Usage dashboard written"
expect 0 "fast open: the range is the new tag" -- grep -qF 'since v9' "$FPAGE"
expect 0 "fast open: another --since is another page: rebuilt" -- "${FRUN[@]}" --open --since HEAD~1
expect_output "Usage dashboard written"

# --refresh: debounced, single instance, nothing done when unchanged.
rm -f "$FC/refresh.stamp"
expect 0 "refresh: --refresh rebuilds a stale page" -- "${FRUN[@]}" --refresh --min-interval 10
expect_output "Usage dashboard written"
expect 0 "refresh: its page reloads itself every interval" -- \
  grep -qF '<meta http-equiv="refresh" content="10">' "$FPAGE"
expect 0 "refresh: and says it is kept fresh in the background" -- grep -qF 'Kept fresh:' "$FPAGE"
expect 0 "refresh: another within the interval is skipped" -- "${FRUN[@]}" --refresh --min-interval 600
expect_output "skipped: the last refresh started"
rm -f "$FC/refresh.stamp"
expect 0 "refresh: with nothing changed it is skipped without a build" -- "${FRUN[@]}" --refresh --min-interval 10
expect_output "no change in HEAD"
expect 1 "refresh: no build ran" -- grep -qF 'Usage dashboard written' <<< "$LAST_OUTPUT"
for bad in 9 010 86401; do
  expect 2 "refresh: --min-interval $bad is refused" -- "${FRUN[@]}" --refresh --min-interval "$bad"
done
expect 2 "--no-wait without --open is a usage error" -- "${FRUN[@]}" --no-wait
expect 2 "--refresh with --watch is a usage error" -- "${FRUN[@]}" --refresh --watch

# The lock: a live owner is waited for or skipped; a stale one is taken over.
sleep 60 &
FLIVE=$!
FDEAD="$(bash -c 'echo $$')"
rm -f "$FC/refresh.stamp"
mkdir -p "$FC/lock"
printf '%s %s\n' "$FLIVE" "$(date +%s)" > "$FC/lock/owner"
{ usage_line msg_F341B 4; printf '\n'; } >> "$FT/s1.jsonl"
expect 0 "lock: a refresh while another runs is skipped" -- "${FRUN[@]}" --refresh
expect_output "another one is running (pid $FLIVE)"
expect 0 "lock: the running one's lock is left alone" -- grep -qF "$FLIVE" "$FC/lock/owner"
expect 0 "lock: the hook starts none either" -- "${FRUN[@]}" --refresh-in-background
expect_output "one is already running (pid $FLIVE)"
printf '%s %s\n' "$FDEAD" "$(date +%s)" > "$FC/lock/owner"
expect 0 "lock: a lock whose process is gone is taken over" -- "${FRUN[@]}" --refresh
expect_output "took over a stale lock"
expect_output "Usage dashboard written"
expect 1 "lock: and released when the refresh ends" -- test -e "$FC/lock"
rm -f "$FC/refresh.stamp"
mkdir -p "$FC/lock"
printf '%s %s\n' "$FLIVE" "$(( $(date +%s) - 700 ))" > "$FC/lock/owner"
{ usage_line msg_F341C 5; printf '\n'; } >> "$FT/s1.jsonl"
expect 0 "lock: a lock older than 10 minutes is taken over, though its process lives" -- "${FRUN[@]}" --refresh
expect_output "took over a stale lock"
kill "$FLIVE" 2>/dev/null
wait "$FLIVE" 2>/dev/null
sleep 4 &
FSHORT=$!
mkdir -p "$FC/lock"
printf '%s %s\n' "$FSHORT" "$(date +%s)" > "$FC/lock/owner"
{ usage_line msg_F341D 6; printf '\n'; } >> "$FT/s1.jsonl"
expect 0 "lock: --open waits for the run holding the lock, then builds" -- "${FRUN[@]}" --open
expect_output "waiting for the refresh that is running (pid $FSHORT)"
expect_output "Usage dashboard written"
wait "$FSHORT" 2>/dev/null

# In the background: the caller reads stdout through a pipe, as a hook runner
# does, and $(...) returns only once every writer of that pipe has closed it.
# The refresh waits 8 s once it holds the lock, so a refresh that kept the
# pipe would have made the caller wait at least that long.
rm -f "$FC/refresh.stamp" "$FU/refresh.log" "$FU/refresh.log.1"
{ usage_line msg_F341E 7; printf '\n'; } >> "$FT/s1.jsonl"
BG_T0=$SECONDS
BG_OUT="$(env IAENG_USAGE_WORKER_DELAY=8 "${FRUN[@]}" --refresh-in-background --min-interval 10 2> "$WORK/usage-bg-err.txt")"
BG_RC=$?
BG_SECS=$((SECONDS - BG_T0))
expect 0 "background: exits 0" -- test "$BG_RC" = 0
expect 0 "background: returned before its refresh could end (${BG_SECS} s; the refresh waits 8 s)" -- test "$BG_SECS" -lt 8
expect 0 "background: one line on stdout" -- test "$(printf '%s\n' "$BG_OUT" | grep -c .)" = 1
expect 0 "background: saying the refresh started" -- grep -qF 'in the background' <<< "$BG_OUT"
expect 0 "background: nothing on stderr" -- test ! -s "$WORK/usage-bg-err.txt"
i=0
while [ "$i" -lt 300 ] && { ! grep -qsF 'page rebuilt' "$FU/refresh.log" || [ -e "$FC/lock" ]; }; do
  sleep 1
  i=$((i + 1))
done
expect 0 "background: the detached refresh rebuilt the page" -- grep -qF 'page rebuilt' "$FU/refresh.log"
expect 0 "background: its output went to the log" -- grep -qF 'Usage dashboard written' "$FU/refresh.log"
BG_PID="$(sed -n 's/.*refresh started (pid \([0-9]*\)).*/\1/p' "$FU/refresh.log" | tail -n 1)"
expect 0 "background: the log names the refresh's process" -- test -n "$BG_PID"
expect 1 "background: that process is gone once it ended (no orphan)" -- kill -0 "${BG_PID:-0}"
expect 1 "background: its lock is released" -- test -e "$FC/lock"
expect 0 "background: no temporary directory is left" -- test -z "$(find "$FTMP" -mindepth 1 -maxdepth 1)"
expect 0 "background: a call within the interval is skipped by the hook itself" -- \
  "${FRUN[@]}" --refresh-in-background --min-interval 600
expect_output "skipped: the last one started"
expect 0 "background: a bad argument still exits 0, in one line (a hook never fails)" -- \
  "${FRUN[@]}" --refresh-in-background --min-interval 5
expect_output "refresh not started"
expect 0 "background: that is one line" -- test "$(printf '%s\n' "$LAST_OUTPUT" | grep -c .)" = 1

# The log is bounded: past 64 KiB it moves to refresh.log.1.
rm -f "$FC/refresh.stamp"
head -c 70000 /dev/zero | tr '\0' 'x' > "$FU/refresh.log"
expect 0 "log: a refresh run as the background one" -- env IAENG_USAGE_WORKER=bg "${FRUN[@]}" --refresh
expect 0 "log: it wrote to its log, not to its caller" -- test -z "$LAST_OUTPUT"
expect 0 "log: past 64 KiB the log moved to refresh.log.1" -- test "$(wc -c < "$FU/refresh.log.1")" -ge 70000
expect 0 "log: the new log starts small" -- test "$(wc -c < "$FU/refresh.log")" -lt 8192

# --open --no-wait: the page at once, and a refresh behind it even within the
# interval — it was asked for.
date +%s > "$FC/refresh.stamp"
{ usage_line msg_F341F 8; printf '\n'; } >> "$FT/s1.jsonl"
rm -f "$FOPEN" "$FU/refresh.log"
expect 0 "--open --no-wait: opens the existing page at once" -- \
  env IAENG_USAGE_WORKER_DELAY=3 "${FRUN[@]}" --open --no-wait
expect_output "opened as it is; refreshing it in the background"
expect 0 "--open --no-wait: the page went to the opener" -- test "$(grep -c . "$FOPEN")" = 1
i=0
while [ "$i" -lt 300 ] && { ! grep -qsF 'page rebuilt' "$FU/refresh.log" || [ -e "$FC/lock" ]; }; do
  sleep 1
  i=$((i + 1))
done
expect 0 "--open --no-wait: its refresh ran though one had just started" -- grep -qF 'page rebuilt' "$FU/refresh.log"
rm -f "$FPAGE"
expect 0 "--open --no-wait: with no page yet, builds one first" -- "${FRUN[@]}" --open --no-wait
expect_output "Usage dashboard written"
expect 0 "--open --no-wait: that page keeps itself fresh" -- grep -qF 'Kept fresh:' "$FPAGE"

# Code review of #230, M1: a page from a plain build (every page the Windows
# launcher writes) does not reload itself, so --no-wait and a refresh rebuild
# it instead of keeping it; a tab opened on it would never show a refresh.
expect 0 "M1: a plain build" -- "${FRUN[@]}"
expect 1 "M1: its page does not reload itself" -- grep -qF 'http-equiv="refresh"' "$FPAGE"
expect 0 "M1: --open --no-wait on that page" -- "${FRUN[@]}" --open --no-wait
expect_output "Usage dashboard written"
expect 0 "M1: builds first a page that reloads itself" -- grep -qF '<meta http-equiv="refresh" content="60">' "$FPAGE"
rm -f "$FC/refresh.stamp"
expect 0 "M1: a refresh keeps that page while nothing changes" -- "${FRUN[@]}" --refresh
expect_output "page kept"
expect 0 "M1: after another plain build" -- "${FRUN[@]}"
rm -f "$FC/refresh.stamp"
expect 0 "M1: a refresh rebuilds the page that does not reload" -- "${FRUN[@]}" --refresh
expect_output "Usage dashboard written"
expect 0 "M1: and its page reloads itself" -- grep -qF 'Kept fresh:' "$FPAGE"

# PR #230 security review S3: a lock started in the future is stale, though
# its process lives (it would never age out otherwise).
sleep 60 &
FLIVE3=$!
rm -f "$FC/refresh.stamp"
mkdir -p "$FC/lock"
printf '%s %s\n' "$FLIVE3" 99999999999 > "$FC/lock/owner"
{ usage_line msg_F341G 9; printf '\n'; } >> "$FT/s1.jsonl"
expect 0 "S3: a lock started in the future is taken over, though its process lives" -- "${FRUN[@]}" --refresh
expect_output "took over a stale lock"
kill "$FLIVE3" 2>/dev/null
wait "$FLIVE3" 2>/dev/null

# S1: a repository that commits .ia-engineering/usage as a link to a folder
# outside it (a junction on Windows, where git cannot commit one: the same
# check). Nothing is written through it, from any mode.
new_repo usage-s1
S1R="$PWD"
S1LOOT="$WORK/usage-s1-loot"
write_employee_roster "DevOps Engineer"
git add -A && git commit -q -m "roster"
rm -rf "$S1LOOT"
mkdir -p "$S1LOOT" .ia-engineering
case "${OSTYPE:-}" in
  msys*|cygwin*|win*) cmd //c mklink //J "$(cygpath -w "$S1R/.ia-engineering/usage")" "$(cygpath -w "$S1LOOT")" > /dev/null ;;
  *) ln -s ../../usage-s1-loot .ia-engineering/usage
     git add .ia-engineering/usage && git commit -q -m "the usage folder, committed as a link" ;;
esac
expect 0 "S1: the usage folder is a link" -- test -L "$S1R/.ia-engineering/usage"
expect 0 "S1: the hook starts no refresh, in one line, exit 0" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$S1R" --refresh-in-background
expect_output "reached through a symbolic link or a junction"
expect 1 "S1: a build refuses to write its default page through the link" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$S1R"
expect_output "refusing to write the page through it"
expect 1 "S1: so does a refresh run as the background one" -- \
  env IAENG_USAGE_WORKER=bg CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$S1R" --refresh
expect 0 "S1: nothing was written outside the project" -- test -z "$(find "$S1LOOT" -mindepth 1 2>/dev/null)"
case "${OSTYPE:-}" in msys*|cygwin*|win*) cmd //c rmdir "$(cygpath -w "$S1R/.ia-engineering/usage")" ;; esac

# S2: a repository that force-adds its own dashboard.html (and a fingerprint)
# under the ignore rule. --open --no-wait builds first and never opens it.
new_repo usage-s2
S2R="$PWD"
write_employee_roster "DevOps Engineer"
printf '.ia-engineering/usage/\n' > .gitignore
mkdir -p .ia-engineering/usage
printf '<html><body>OBS341-ATTACKER-PAGE<script>1</script></body></html>\n' > .ia-engineering/usage/dashboard.html
printf 'forged\n' > .ia-engineering/usage/.dashboard.html.fingerprint
git add -A
git add -f .ia-engineering/usage/dashboard.html .ia-engineering/usage/.dashboard.html.fingerprint
git commit -q -m "a page of the repository's own"
cat > "$WORK/usage-s2-opener.sh" <<OPENER
#!/usr/bin/env bash
cp "\$1" "$WORK/usage-s2-opened.html"
OPENER
chmod +x "$WORK/usage-s2-opener.sh"
rm -f "$WORK/usage-s2-opened.html"
expect 0 "S2: --open --no-wait on a page the repository committed" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" IAENG_USAGE_OPENER="$WORK/usage-s2-opener.sh" \
  bash "$DASH" --project-dir "$S2R" --open --no-wait
expect_output "Usage dashboard written"
expect 1 "S2: the committed page was never opened" -- grep -qF 'OBS341-ATTACKER-PAGE' "$WORK/usage-s2-opened.html"
expect 0 "S2: the page opened is this script's, under its CSP" -- \
  grep -qF "default-src 'none'" "$WORK/usage-s2-opened.html"

# QA of #230: in a project that does not ignore .ia-engineering/usage/, a
# refresh run as the background one writes nothing in the work tree; it
# records why in .git, and the hook then starts none within the interval.
new_repo usage-unignored-bg
QR="$PWD"
write_employee_roster "DevOps Engineer"
git add -A && git commit -q -m "roster, no ignore rule"
expect 0 "QA: a refresh run as the background one, in a project that does not ignore its usage folder" -- \
  env IAENG_USAGE_WORKER=bg CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$QR" --refresh
expect 0 "QA: it left nothing for git status to show" -- test -z "$(git -C "$QR" status --porcelain)"
expect 0 "QA: it recorded why in .git, out of the work tree" -- test -s "$QR/.git/ia-engineering-usage.refused"
expect 0 "QA: the hook starts no refresh within the interval, and says why" -- \
  env CLAUDE_CONFIG_DIR="$WORK/usage-empty-config" bash "$DASH" --project-dir "$QR" --refresh-in-background
expect_output "could not use the cache: git does not ignore"
expect 0 "QA: --refresh-in-background with --open (the Windows launcher's) says it is for a hook" -- \
  bash "$DASH" --project-dir "$QR" --refresh-in-background --open
expect_output "not through usage-dashboard.cmd"
cd "$FRESH" || exit 1

# The collector: --listing-out is what --list prints; a cache older than the
# script is read again (a copy of the script, so the real one is untouched).
expect 0 "collector: --listing-out writes the listing --list prints" -- \
  test "$(bash "$COLLECT" --transcripts-dir "$UT" --listing-out "$WORK/usage-listing.txt" > /dev/null 2>&1; cat "$WORK/usage-listing.txt")" \
     = "$(bash "$COLLECT" --transcripts-dir "$UT" --list)"
UCOPY="$WORK/usage-collect-copy.sh"
UCV="$WORK/usage-cache-version"
rm -rf "$UCV"
cp "$COLLECT" "$UCOPY"
expect 0 "collector: a cached run" -- bash "$UCOPY" --transcripts-dir "$UT" --cache-dir "$UCV"
for r in "$UCV"/v1/rec/*.tsv; do
  printf 'C\tmsg_OLDVER\t2026-10-07\tclaude-old-version\tmain session\t\t1\t1\t0\t0\n' >> "$r"
done
expect 0 "collector: the cache is reused while the script is unchanged" -- \
  bash "$UCOPY" --transcripts-dir "$UT" --cache-dir "$UCV"
expect_output "claude-old-version"
touch "$UCOPY"
expect 0 "collector: a newer version of the script reads everything again" -- \
  bash "$UCOPY" --transcripts-dir "$UT" --cache-dir "$UCV"
expect 1 "collector: and what the older version stored is not counted" -- grep -qF 'claude-old-version' <<< "$LAST_OUTPUT"
cd "$WORK" || exit 1

# ------------------------------------------------- usage-dashboard.cmd ------
# WU-IAENG-329. The Windows launcher cannot be run on the Linux CI runner, so
# its contract is pinned statically: it exists, it is CRLF where cmd.exe reads
# it (the attribute, and the bytes actually checked out), it runs the script
# with --open, and it never runs the PATH's `bash` — in PowerShell and cmd that
# is WSL's System32\bash.exe, the defect this launcher exists to avoid
# (Governance/TROUBLESHOOTING.md, entry AA).

LAUNCHER="$SCRIPTS/usage-dashboard.cmd"
section "usage-dashboard.cmd"

expect 0 "launcher: usage-dashboard.cmd exists" -- test -f "$LAUNCHER"
expect 0 "launcher: .gitattributes checks it out CRLF" -- \
  grep -qx 'Adapters/scripts/usage-dashboard.cmd: eol: crlf' \
    <<< "$(git -C "$SCRIPTS/../.." check-attr eol -- Adapters/scripts/usage-dashboard.cmd)"
# Counted in bytes with tr, not with a grep for a trailing CR: while this test
# was written, such a grep inside a function counted every line of an LF file
# as CR-terminated under Git for Windows, so the assertion passed on the very
# file it exists to reject. As many CR as LF bytes, and the file ends in CR LF,
# so its last line is terminated too. Computed inline, not in a function: a
# function reached only through `expect` is reported unreachable by shellcheck
# (SC2317), as the pre-push feeder above explains.
L_CR="$(tr -cd '\r' < "$LAUNCHER" 2>/dev/null | wc -c | tr -d ' ')"
L_LF="$(tr -cd '\n' < "$LAUNCHER" 2>/dev/null | wc -c | tr -d ' ')"
L_END="$(tail -c 2 "$LAUNCHER" 2>/dev/null | od -An -c | tr -d ' ')"
expect 0 "launcher: every line of the checked-out file ends in CRLF ($L_CR CR, $L_LF LF)" -- \
  test "$L_LF" -gt 0 -a "$L_CR" = "$L_LF" -a "$L_END" = '\r\n'
expect 0 "launcher: it runs usage-dashboard.sh --open, passing arguments through" -- \
  grep -qF 'usage-dashboard.sh" --open %*' "$LAUNCHER"
expect 0 "launcher: it runs Git for Windows' own bin\\bash.exe" -- \
  grep -qF '"%IAENG_GITROOT%\bin\bash.exe"' "$LAUNCHER"
# Outside rem comments and echoed messages, `bash` may appear only as the
# resolved bin\bash.exe.
L_CODE="$(tr -d '\r' < "$LAUNCHER" 2>/dev/null \
  | grep -viE '^[[:space:]]*(@?rem|::|echo)([[:space:]]|$)')"
expect 1 "launcher: no bare bash (PATH lookup reaches WSL in PowerShell and cmd)" -- \
  grep -iE '(^|[^\\a-z_.-])bash(\.exe)?([^a-z_.-]|$)' <<< "$L_CODE"

# The two defects of PR #200's review, pinned so they cannot return.
# M1: after a cd, %~dp0 re-resolves against the new directory when the file
# was invoked by a relative path, so it is captured before the first cd and
# never read after it.
expect 0 "launcher: the script directory is captured into IAENG_HERE" -- \
  grep -qxF 'set "IAENG_HERE=%~dp0"' <<< "$L_CODE"
L_DP0_AFTER_CD="$(awk '/^cd /{cd=1} cd && /%~dp0/' <<< "$L_CODE")"
expect 0 "launcher: %~dp0 is not read after the first cd" -- \
  test -z "$L_DP0_AFTER_CD"
# M2: a path expanded with %VAR% inside a for set or an if block is parsed
# as batch syntax, so a ")" in it (C:\Program Files (x86)\Git) is a syntax
# error. The for /f command must not open with '"" (which leaves the paths
# unquoted), and cmdcmdline must not be tokenised by a plain for.
expect 1 "launcher: no for /f command opens with '\"\" (unquoted paths)" -- \
  grep -F "in ('\"\"" <<< "$L_CODE"
expect 1 "launcher: cmdcmdline is not expanded in a for set" -- \
  grep -F '(%cmdcmdline%)' <<< "$L_CODE"

# WU-IAENG-338, issue #210: `call` doubles every caret, inside quotes too,
# and expands %NAME% a second time, so a "^" in the adopting project's path
# made rev-parse fail and the dashboard silently measured the framework. The
# superproject lookup runs without `call`: its child command starts with the
# bare word cd (cmd /c strips the quotes of a command starting with one), and
# git runs in IAENG_ROOT. Verified on Windows with "^", "(x) & y" and
# "(x86)" paths; the Linux runner can only pin the text.
expect 1 "launcher: no call anywhere (it doubles carets and re-expands %NAME%)" -- \
  grep -iE '(^|[^a-z_])call[[:space:]]' <<< "$L_CODE"
expect 0 "launcher: the superproject lookup starts with cd /d into IAENG_ROOT, then runs git" -- \
  grep -qF "in ('cd /d \"%%IAENG_ROOT%%\" ^&^& \"%%IAENG_GITROOT%%\\bin\\git.exe\" rev-parse --show-superproject-working-tree 2^>nul')" <<< "$L_CODE"

# ------------------------------------------ check-approval-carry-over.sh ----

section "check-approval-carry-over.sh — approvals across an update merge of develop (WU-IAENG-344)"

# Every history is built here. The cases this rule was decided on are real
# Pull Requests of this repository (#202, #215, #220 carry over; #202 from its
# earlier head, #203 and #201 do not), but this suite also runs from a shallow
# CI checkout and inside adopting projects, where that history is absent, so
# each is rebuilt below in the same shape, named after the PR it stands for.
# The run against the real commits is evidence in WU-IAENG-344's Pull Request.
# The attacks are the Code Reviewer's on PR #225 (comment 6035895314) and the
# Prompt Engineer's registry cases; each is a merge that must be refused.

CARRY="$SCRIPTS/check-approval-carry-over.sh"
CO_TAIL="merges equal git's own merge outside Registry/work-units.yml; registry entry identical; checker: check-approval-carry-over.sh"

# co_entry <id> <title> — one registry entry in the parsing contract's shape,
# preceded by its blank separator line.
co_entry() {
  printf '\n  - id: %s\n    employee: Technical Writer\n    title: %s\n    milestone: Precision\n    delivers: Registry/work-units.yml\n' "$1" "$2"
}
# co_registry <entry-spec...> — the whole registry; a spec is <id>:<title>.
co_registry() {
  local spec
  printf '# Work Unit Registry (test fixture)\n\nwork_units:\n'
  for spec in "$@"; do co_entry "${spec%%:*}" "${spec#*:}"; done
}
# co_start <branch> <approved> <develop-commit> <entry-spec...> — merges the
# develop commit into the approved head without committing and resolves the
# registry with exactly the entries given, in that order. Edits follow, then
# co_commit.
co_start() {
  local branch="$1" head="$2" dev="$3"
  shift 3
  git checkout -q -B "$branch" "$head"
  git merge -q --no-ff --no-commit "$dev" > /dev/null 2>&1
  co_registry "$@" > Registry/work-units.yml
  git add -A
}
co_commit() {
  git commit -q -m "Merge develop into the branch"
  CO_M="$(git rev-parse HEAD)"
}

new_repo carry-lab
git branch -m develop
mkdir -p Registry templates
cat > policy.md <<'EOF'
# Policy

## Release
- Director approval is required.

## Hotfix
- Director approval is required.

## Develop
- Code review is required.

## Main
- Release Manager only.
EOF
cat > app.py <<'EOF'
def handle(request):
    data = parse(request)
    return render(data)


def admin(request):
    data = parse(request)
    return render(data)
EOF
co_registry "WU-T-1:one" "WU-T-2:two" > Registry/work-units.yml
printf 'line one\nline two\n' > z-notes.md
printf '#!/bin/sh\necho run\n' > run.sh
git add -A && git commit -q -m "D0"
CO_D0="$(git rev-parse HEAD)"

# develop moves on: a new file and its own registry entry, appended.
printf 'unrelated develop change\n' > dev.md
co_registry "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" > Registry/work-units.yml
git add -A && git commit -q -m "D1"
CO_D1="$(git rev-parse HEAD)"

# The approved head: the Pull Request's lines in a Markdown policy, a code
# file, a note, a commit template with its trailers, and its registry entry.
git checkout -q -b pr "$CO_D0"
cat > policy.md <<'EOF'
# Policy

## Release
- Director approval is required.

## Hotfix

## Develop
- Code review is required.
- The Main Agent may merge.
- Only after review.

These rules apply to every Pull Request.

## Main
- Release Manager only.
- Releases go develop → main.
EOF
cat > app.py <<'EOF'
def handle(request):
    check_auth(request)
    data = parse(request)
    return render(data)


def admin(request):
    data = parse(request)
    return render(data)
EOF
co_registry "WU-T-1:one" "WU-T-2:two" "WU-T-3:three" > Registry/work-units.yml
printf 'line one\nline two (PR)\n' > z-notes.md
printf 'docs(x): y\n\nWork Unit: WU-X-1\n\nEmployee: Technical Writer\n' > templates/commit.txt
git add -A && git commit -q -m "A: the approved head"
CO_A="$(git rev-parse HEAD)"

# A second approved head, A plus a binary file holding NUL bytes.
git checkout -q -b pr-bin "$CO_A"
mkdir -p assets
printf 'PNG\000\000\001\002binary\n' > assets/logo.bin
git add -A && git commit -q -m "B: the approved head with a binary file"
CO_B="$(git rev-parse HEAD)"

# The honest update merges.
co_start m-ok "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_commit
CO_OK="$CO_M"
co_start m-idorder "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-3:three" "WU-T-4:four"
co_commit
CO_IDORDER="$CO_M"
co_start m-reorder-only "$CO_A" "$CO_D1" "WU-T-4:four" "WU-T-2:two" "WU-T-3:three" "WU-T-1:one"
co_commit
CO_REORDER_ONLY="$CO_M"
co_start m-bin "$CO_B" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_commit
CO_BIN_OK="$CO_M"
# Reset back to the approved head after an extra commit, then develop merged:
# the extra commit is not in the history, so nothing unreviewed is.
git checkout -q -B m-rewound "$CO_A"
printf 'extra\n' >> z-notes.md
git add -A && git commit -q -m "an extra commit, abandoned"
co_start m-rewound "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_commit
CO_REWOUND="$CO_M"

expect 0 "#202/#215 shape: a registry-only conflict resolved by keeping both entries carries over" -- \
  bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect_output "both sides kept"
expect_output "byte for byte the same on both heads: WU-T-3"
expect 0 "#220 shape: the PR's entry placed in ID order carries over" -- \
  bash "$CARRY" "$CO_A" "$CO_IDORDER" --base develop
expect 0 "a resolution that only reorders registry entries, other PRs' included, carries over" -- \
  bash "$CARRY" "$CO_A" "$CO_REORDER_ONLY" --base develop
expect 0 "a binary file with NUL bytes in the PR does not stop an honest merge carrying over" -- \
  bash "$CARRY" "$CO_B" "$CO_BIN_OK" --base develop
expect 0 "a branch reset to the approved head, then merged with develop, carries over" -- \
  bash "$CARRY" "$CO_A" "$CO_REWOUND" --base develop

# The record: stdout is exactly that one line on success, and empty otherwise.
CO_STDOUT="$(bash "$CARRY" "$CO_A" "$CO_OK" --base develop 2> /dev/null)"
expect 0 "on success stdout is exactly the record, full commit ids, nothing else" -- \
  test "$CO_STDOUT" = "Approval carry-over: $CO_A -> $CO_OK; $CO_TAIL"
# QA, PR #232: from a PowerShell 5.1 console on code page 850 a non-ASCII
# arrow in the record printed mangled, with exit 0. Every byte of the record
# must be printable 7-bit ASCII (space to tilde).
expect 1 "the record is 7-bit ASCII: no byte outside space..tilde" -- \
  env LC_ALL=C grep -q '[^ -~]' <<< "$CO_STDOUT"
expect 0 "the record is not empty (the ASCII check above read a real record)" -- \
  test -n "$CO_STDOUT"

# A merge chain: develop merged twice; the second merge honest, then not.
git checkout -q develop
printf 'second develop change\n' > dev2.md
co_registry "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-5:five" > Registry/work-units.yml
git add -A && git commit -q -m "D3"
CO_D3="$(git rev-parse HEAD)"
co_start m-chain "$CO_OK" "$CO_D3" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three" "WU-T-5:five"
co_commit
CO_CHAIN="$CO_M"
co_start m-chain-bad "$CO_OK" "$CO_D3" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_commit
CO_CHAIN_BAD="$CO_M"
expect 0 "two honest merges of develop in a row carry over" -- \
  bash "$CARRY" "$CO_A" "$CO_CHAIN" --base develop
expect 1 "a second merge that drops develop's newer entry does not" -- \
  bash "$CARRY" "$CO_A" "$CO_CHAIN_BAD" --base develop
expect_output "WU-T-5"

# The Code Reviewer's attacks: each update merge changes something by hand.
co_start m-edit "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
cat > app.py <<'EOF'
def handle(request):
    check_auth(request, skip=True)
    data = parse(request)
    return render(data)


def admin(request):
    data = parse(request)
    return render(data)
EOF
git add -A && co_commit
CO_EDIT="$CO_M"
expect 1 "a merge that edits a PR line is refused" -- bash "$CARRY" "$CO_A" "$CO_EDIT" --base develop
expect_output "differs from git's own merge of its parents outside Registry/work-units.yml, in app.py"
CO_STDOUT="$(bash "$CARRY" "$CO_A" "$CO_EDIT" --base develop 2> /dev/null)"
expect 0 "on a refusal stdout is empty: there is no record to paste" -- test -z "$CO_STDOUT"

co_start m-relocate "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
cat > app.py <<'EOF'
def handle(request):
    data = parse(request)
    return render(data)


def admin(request):
    check_auth(request)
    data = parse(request)
    return render(data)
EOF
git add -A && co_commit
expect 1 "a merge that relocates a PR line to another function is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "in app.py"

co_start m-swap "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
cat > policy.md <<'EOF'
# Policy

## Release

## Hotfix
- Director approval is required.

## Develop
- Code review is required.
- The Main Agent may merge.
- Only after review.

These rules apply to every Pull Request.

## Main
- Release Manager only.
- Releases go develop → main.
EOF
git add -A && co_commit
expect 1 "a merge that removes the OTHER identical bullet instead is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "in policy.md"

co_start m-rename "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
git mv -f z-notes.md notes-z.md
co_commit
expect 1 "a merge that renames a PR file is refused" -- bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "notes-z.md"

co_start m-mode "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
chmod +x run.sh
git update-index --chmod=+x run.sh
co_commit
expect 1 "a merge that sets +x on a file is refused" -- bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "in run.sh"

co_start m-reorder "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
cat > policy.md <<'EOF'
# Policy

## Release
- Director approval is required.

## Hotfix

## Develop
- Code review is required.
- Only after review.
- The Main Agent may merge.

These rules apply to every Pull Request.

## Main
- Release Manager only.
- Releases go develop → main.
EOF
git add -A && co_commit
expect 1 "a merge that reorders two PR lines is refused" -- bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "in policy.md"

co_start m-crlf "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
printf '# Policy\n\n## Release\n- Director approval is required.\n\n## Hotfix\n\n## Develop\n- Code review is required.\n- The Main Agent may merge.\n- Only after review.\r\n\nThese rules apply to every Pull Request.\n\n## Main\n- Release Manager only.\n- Releases go develop \342\206\222 main.\n' > policy.md
git add -A && co_commit
expect 1 "a merge that turns a PR line's LF into CRLF is refused" -- bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "in policy.md"

co_start m-lazy "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
printf '# Policy\n\n## Release\n- Director approval is required.\n\n## Hotfix\n\n## Develop\n- Code review is required.\n- The Main Agent may merge.\n- Only after review.\nThese rules apply to every Pull Request.\n\n## Main\n- Release Manager only.\n- Releases go develop \342\206\222 main.\n' > policy.md
git add -A && co_commit
expect 1 "a merge that drops a Markdown blank line (the paragraph joins the bullet) is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "in policy.md"

co_start m-trailer "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
printf 'docs(x): y\n\nWork Unit: WU-X-1\nEmployee: Technical Writer\n' > templates/commit.txt
git add -A && co_commit
expect 1 "a merge that drops the blank line between two trailers is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "templates/commit.txt"

co_start m-arrow "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
printf '# Policy\n\n## Release\n- Director approval is required.\n\n## Hotfix\n\n## Develop\n- Code review is required.\n- The Main Agent may merge.\n- Only after review.\n\nThese rules apply to every Pull Request.\n\n## Main\n- Release Manager only.\n- Releases go develop \342\206\220 main.\n' > policy.md
git add -A && co_commit
expect 1 "a merge that flips a non-ASCII arrow is refused" -- bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "in policy.md"

git checkout -q -B m-ours "$CO_A"
git merge -q -s ours --no-edit "$CO_D1"
expect 1 "a merge -s ours, which discards develop's changes, is refused" -- \
  bash "$CARRY" "$CO_A" "$(git rev-parse HEAD)" --base develop
expect_output "dev.md"

co_start m-bin-edit "$CO_B" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
printf 'line one\nline two (PR, changed after approval)\n' > z-notes.md
git add -A && co_commit
expect 1 "a binary file in the PR does not hide a later PR line edited by the merge" -- \
  bash "$CARRY" "$CO_B" "$CO_M" --base develop
expect_output "in z-notes.md"

# Crafted merges: the history itself is wrong.
git checkout -q -B side "$CO_D0"
printf 'not from develop\n' > side.txt
git add -A && git commit -q -m "a side commit, not on develop"
CO_SIDE="$(git rev-parse HEAD)"
CO_OK_TREE="$(git rev-parse "$CO_OK^{tree}")"
CO_NOANC="$(git commit-tree "$CO_OK_TREE" -p "$CO_D0" -p "$CO_D1" -m "Merge develop (approved head dropped)")"
CO_OCTO="$(git commit-tree "$CO_OK_TREE" -p "$CO_A" -p "$CO_D1" -p "$CO_SIDE" -m "Merge develop (octopus)")"
CO_XSIDE="$(git commit-tree "$CO_OK_TREE" -p "$CO_A" -p "$CO_SIDE" -m "Merge a commit that is not on develop")"
expect 1 "a merge that drops the approved head from the history is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_NOANC" --base develop
expect_output "is not an ancestor of the new head"
expect 1 "an octopus merge is refused" -- bash "$CARRY" "$CO_A" "$CO_OCTO" --base develop
expect_output "is a merge of 3 parents"
expect 1 "a merge whose second parent is not on develop is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_XSIDE" --base develop
expect_output "is not on develop"

# #202 from its earlier head: a commit was pushed after the approval, then
# develop merged. The commit voids the approval; the merge cannot restore it.
git checkout -q -B after-approval "$CO_A"
printf 'line one\nline two (PR, revised)\n' > z-notes.md
git add -A && git commit -q -m "a change after the approval"
co_start after-approval "$(git rev-parse HEAD)" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_commit
expect 1 "#202 from its earlier head: a commit after the approval, then a merge, is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "is not a merge"

# #203 and #201: develop changed a line next to the PR's, so git's own merge
# conflicts outside the registry; the resolution keeps both, by hand.
git checkout -q -B develop-next "$CO_D1"
printf '# Policy\n\n## Release\n- Director approval is required.\n\n## Hotfix\n- Director approval is required.\n\n## Develop\n- Code review by the Code Reviewer is required.\n\n## Main\n- Release Manager only.\n' > policy.md
git add -A && git commit -q -m "D2: develop rewrites the Develop bullet"
CO_D2="$(git rev-parse HEAD)"
co_start m-conflict "$CO_A" "$CO_D2" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
printf '# Policy\n\n## Release\n- Director approval is required.\n\n## Hotfix\n\n## Develop\n- Code review by the Code Reviewer is required.\n- The Main Agent may merge.\n- Only after review.\n\nThese rules apply to every Pull Request.\n\n## Main\n- Release Manager only.\n- Releases go develop \342\206\222 main.\n' > policy.md
git add -A && co_commit
expect 1 "#203/#201 shape: a conflict outside the registry, resolved by hand, is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base "$CO_D2"
expect_output "conflicts outside Registry/work-units.yml, in policy.md"

# The machine's own state must not redefine git's own merge (Security Engineer
# on PR #232). The same conflict, resolved the way `merge=union` would: with
# that driver in core.attributesFile, git's merge resolves it on its own, so
# the hand resolution used to pass as "git's own merge".
printf '* merge=union\n' > .git/carry-union-attributes
CO_UNION_TREE="$(git -c core.attributesFile=.git/carry-union-attributes --attr-source=4b825dc642cb6eb9a060e54bf8d69288fbee4904 merge-tree --write-tree --no-messages "$CO_A" "$CO_D2" | head -1)"
co_start m-union "$CO_A" "$CO_D2" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
git cat-file blob "$CO_UNION_TREE:policy.md" > policy.md
git add -A && co_commit
CO_UNION="$CO_M"
git config core.attributesFile .git/carry-union-attributes
expect 1 "core.attributesFile with merge=union does not turn a hand resolution into git's own merge" -- \
  bash "$CARRY" "$CO_A" "$CO_UNION" --base "$CO_D2"
expect_output "conflicts outside Registry/work-units.yml, in policy.md"
git config --unset core.attributesFile
mkdir -p .git/info
printf '* merge=union\n' > .git/info/attributes
expect 2 "a non-empty .git/info/attributes, which no option switches off, fails closed" -- \
  bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect_output "info/attributes"
# Emptied, not deleted: the refusal is for a NON-empty file, and nothing in
# this suite deletes inside .git/.
: > .git/info/attributes
expect 0 "an empty .git/info/attributes is not refused" -- \
  bash "$CARRY" "$CO_A" "$CO_OK" --base develop
# A local replace ref that shows the honest merge in place of the hand-edited one.
git replace "$CO_EDIT" "$CO_OK"
expect 1 "a refs/replace entry swapping in an honest merge for a hand-edited one is ignored" -- \
  bash "$CARRY" "$CO_A" "$CO_EDIT" --base develop
expect_output "in app.py"
git replace -d "$CO_EDIT" > /dev/null
# Variables that move git's repository, objects, config or attribute source.
expect 2 "GIT_CONFIG_GLOBAL in the environment fails closed" -- \
  env GIT_CONFIG_GLOBAL=/dev/null bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect_output "GIT_CONFIG_GLOBAL is set"
expect 2 "GIT_REPLACE_REF_BASE in the environment fails closed" -- \
  env GIT_REPLACE_REF_BASE=refs/replace/ bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect_output "GIT_REPLACE_REF_BASE is set"
expect 2 "GIT_DIR in the environment fails closed" -- \
  env GIT_DIR=.git bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect_output "GIT_DIR is set"

# The registry: exactly git's own merge's entries, byte for byte, any order.
co_start m-drop-dev "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-3:three"
co_commit
expect 1 "a resolution that drops develop's newly arrived entry is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "does not hold exactly the entries git's own merge of its parents holds"
expect_output "WU-T-4"
co_start m-edit-other "$CO_A" "$CO_D1" "WU-T-1:one, retitled" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_commit
expect 1 "a resolution that edits another Work Unit's title is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "WU-T-1"
co_start m-edit-own "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three, retitled"
co_commit
expect 1 "a conflict resolution that edits the PR's own registry entry is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "WU-T-3"
co_start m-reg-crlf "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_registry "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"$'\r' > Registry/work-units.yml
git add -A && co_commit
expect 1 "a CR added to the PR's own entry is seen (bash keeps the CR awk and grep drop)" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "WU-T-3"
co_start m-reg-nul "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:three"
co_registry "WU-T-1:one" "WU-T-2:two" "WU-T-4:four" "WU-T-3:thr" > Registry/work-units.yml
printf '\000ee\n' >> Registry/work-units.yml
git add -A && co_commit
expect 1 "a NUL byte in the registry is refused, not read past" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "a NUL or another control byte"
co_start m-markers "$CO_A" "$CO_D1" "WU-T-1:one" "WU-T-2:two"
git cat-file blob "$(git --attr-source=4b825dc642cb6eb9a060e54bf8d69288fbee4904 merge-tree --write-tree --no-messages "$CO_A" "$CO_D1" | head -1):Registry/work-units.yml" > Registry/work-units.yml
git add -A && co_commit
expect 1 "a resolution that commits git's conflict markers in the registry is refused" -- \
  bash "$CARRY" "$CO_A" "$CO_M" --base develop
expect_output "does not hold exactly the entries"

# Configuration that changes what git diff or git merge print must not change
# the verdict: a hostile config in the repository's own .git/config (through
# include.path: GIT_CONFIG* in the environment is refused, see above), run
# from a subdirectory. The subdirectory is load-bearing on its own:
# `git merge-tree --name-only` prints conflicted paths relative to the current
# directory, which once made the registry's conflict read
# ../Registry/work-units.yml and refused the honest merge.
cat > .git/carry-hostile.gitconfig <<'EOF'
[diff]
	relative = true
	noprefix = true
	mnemonicPrefix = true
	algorithm = patience
	indentHeuristic = false
	interHunkContext = 10
	orderFile = .git/carry-order.txt
	renames = copies
	ignoreSubmodules = all
[core]
	quotePath = false
	autocrlf = true
[merge]
	conflictStyle = zdiff3
	renames = false
	directoryRenames = true
	renormalize = true
EOF
# diff.orderFile is relative to the top of the work tree; .git/ keeps it
# out of every later `git add -A`.
printf 'z-notes.md\napp.py\n' > .git/carry-order.txt
git config include.path carry-hostile.gitconfig
cd templates || exit 1
expect 0 "hostile diff/merge config, from a subdirectory: the honest merge still carries over" -- \
  bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect 0 "hostile config: the ID-ordered resolution still carries over" -- \
  bash "$CARRY" "$CO_A" "$CO_IDORDER" --base develop
expect 1 "hostile config: an edit outside the subdirectory is still refused" -- \
  bash "$CARRY" "$CO_A" "$CO_EDIT" --base develop
expect_output "in app.py"
cd .. || exit 1
git config --unset include.path

# A submodule pointer that .gitmodules (ignore = all) and the config both hide
# from git diff.
new_repo carry-sub
git branch -m develop
mkdir -p Registry
printf '[submodule "vendor/fw"]\n\tpath = vendor/fw\n\turl = https://example.invalid/fw.git\n\tignore = all\n' > .gitmodules
co_registry "WU-T-1:one" > Registry/work-units.yml
git add -A && git commit -q -m "D0"
CS_PIN0="$(git rev-parse HEAD)"
git update-index --add --cacheinfo "160000,$CS_PIN0,vendor/fw"
mkdir -p vendor/fw
git commit -q -m "D0: the submodule"
CS_D0="$(git rev-parse HEAD)"
printf 'develop\n' > dev.md
co_registry "WU-T-1:one" "WU-T-4:four" > Registry/work-units.yml
git add -A && git commit -q -m "D1"
CS_D1="$(git rev-parse HEAD)"
git checkout -q -b pr "$CS_D0"
co_registry "WU-T-1:one" "WU-T-3:three" > Registry/work-units.yml
git add -A && git commit -q -m "A"
CS_A="$(git rev-parse HEAD)"
git config diff.ignoreSubmodules all
git config submodule.vendor/fw.ignore all
co_start m-sub "$CS_A" "$CS_D1" "WU-T-1:one" "WU-T-4:four" "WU-T-3:three"
co_commit
expect 0 "submodule lab: the honest merge carries over" -- bash "$CARRY" "$CS_A" "$CO_M" --base develop
co_start m-sub-moved "$CS_A" "$CS_D1" "WU-T-1:one" "WU-T-4:four" "WU-T-3:three"
git update-index --cacheinfo "160000,$CS_D1,vendor/fw"
co_commit
expect 1 "a merge that moves a submodule pointer hidden by ignore = all is refused" -- \
  bash "$CARRY" "$CS_A" "$CO_M" --base develop
expect_output "in vendor/fw"

# Usage and environment: exit 2, never 0, and no record.
cd "$WORK/carry-lab" || exit 1
expect 2 "no argument is a usage error" -- bash "$CARRY"
expect 2 "one revision is a usage error" -- bash "$CARRY" "$CO_A"
expect 2 "an unknown option is a usage error" -- bash "$CARRY" "$CO_A" "$CO_OK" --bogus
expect 2 "a revision that does not resolve fails closed" -- bash "$CARRY" "$CO_A" no-such-revision --base develop
expect_output "is not a commit in this repository"
expect 2 "the approved head being the new head is nothing to carry over" -- \
  bash "$CARRY" "$CO_OK" "$CO_OK" --base develop
expect 2 "without --base, a missing origin/develop fails closed" -- bash "$CARRY" "$CO_A" "$CO_OK"
expect_output "origin/develop"
git update-ref refs/remotes/origin/develop develop
expect 0 "without --base, origin/develop is the base" -- bash "$CARRY" "$CO_A" "$CO_OK"
mkdir -p "$WORK/carry-norepo"
cd "$WORK/carry-norepo" || exit 1
expect 2 "outside a git repository it fails closed" -- env GIT_CEILING_DIRECTORIES="$WORK" bash "$CARRY" "$CO_A" "$CO_OK"
# A shallow repository, made by the file a shallow clone writes: ancestry and
# merge bases are not decidable on truncated history.
new_repo carry-shallow
echo two > two.txt && git add -A && git commit -q -m "two"
git rev-parse HEAD~1 > .git/shallow
expect 2 "a shallow clone fails closed" -- bash "$CARRY" HEAD~1 HEAD --base HEAD
expect_output "shallow"
cd "$WORK/carry-lab" || exit 1
# Shims of its own: this section must not depend on another section's state.
CO_REAL_GIT="$(command -v git)"
mkdir -p "$WORK/carry-shim-old" "$WORK/carry-shim-mt"
cat > "$WORK/carry-shim-old/git" <<SHIM
#!/usr/bin/env bash
if [ "\$1" = "version" ]; then echo "git version 2.39.5"; exit 0; fi
exec "$CO_REAL_GIT" "\$@"
SHIM
cat > "$WORK/carry-shim-mt/git" <<SHIM
#!/usr/bin/env bash
for a in "\$@"; do [ "\$a" = "merge-tree" ] && exit 128; done
exec "$CO_REAL_GIT" "\$@"
SHIM
chmod +x "$WORK/carry-shim-old/git" "$WORK/carry-shim-mt/git"
expect 2 "git older than 2.40 fails closed" -- env PATH="$WORK/carry-shim-old:$PATH" bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect_output "2.40"
expect 2 "a git merge-tree that errors fails closed" -- env PATH="$WORK/carry-shim-mt:$PATH" bash "$CARRY" "$CO_A" "$CO_OK" --base develop
expect_output "merge-tree exited"
mkdir -p "$WORK/carry-alone"
cp "$CARRY" "$WORK/carry-alone/"
expect 2 "without merge-classify.sh beside it, it fails closed" -- \
  bash "$WORK/carry-alone/check-approval-carry-over.sh" "$CO_A" "$CO_OK" --base develop
expect_output "merge-classify.sh not found"

# --------------------------------------------------------------- verdict ----

cd "$HERE" || exit 1
printf '\n'
if [ "$FAILED" -eq 0 ]; then
  if [ "$SKIPPED" -gt 0 ]; then
    printf 'Result: %s checks passed, %s skipped (%s).\n' "$TOTAL" "$SKIPPED" "$SKIP_REASONS"
  else
    printf 'Result: %s checks passed.\n' "$TOTAL"
  fi
  exit 0
fi
if [ "$SKIPPED" -gt 0 ]; then
  printf 'Result: %s of %s checks FAILED (%s skipped: %s).\n' "$FAILED" "$TOTAL" "$SKIPPED" "$SKIP_REASONS"
else
  printf 'Result: %s of %s checks FAILED.\n' "$FAILED" "$TOTAL"
fi
exit 1
