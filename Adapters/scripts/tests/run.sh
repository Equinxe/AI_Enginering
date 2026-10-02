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
  if printf '%s' "$LAST_OUTPUT" | grep -qF -- "$1"; then
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
expect_output "no RISK: record"

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

expect 2 "an unknown option is a usage error" -- bash "$CHECK_MAP" --nope .

# ------------------------------------------- setup-project-bootstrap.sh -----

section "setup-project-bootstrap.sh — the stack it records"

# --dry-run so nothing is installed: this asserts the declaration, not the
# whole bootstrap, and a dry run is the only shape that can be asserted here
# without a git remote and a full project.
D="$(project bs-dry)"
TOTAL=$((TOTAL + 1))
OUT="$(cd "$D" && bash "$SCRIPTS/setup-project-bootstrap.sh" go --dry-run 2>&1)"
if printf '%s' "$OUT" | grep -qF -- "[dry-run] write .ia-engineering/stack containing 'go'"; then
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
if printf '%s' "$OUT" | grep -qF -- "[dry-run] write .ia-engineering/risk-map.yml"; then
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
if printf '%s' "$LAST_OUTPUT" | grep -qE "matches no tracked file|match no zone"; then
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
if printf '%s\n' "$EXPLAIN_OUT" | grep -qE '^Dockerfile sensitive$'; then
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
  if printf '%s' "$OUT" | grep -qF -- "./ia-engineering/Adapters/scripts/setup-branch-protection.sh"; then
    [ -n "$VERBOSE" ] && printf '   ok   the branch-protection hint stays under the link name\n'
  else
    printf '   FAIL the branch-protection hint did not stay under the link name\n'
    printf '%s\n' "$OUT" | grep -i "branch protection" | sed 's/^/        | /'
    FAILED=$((FAILED + 1))
  fi

  TOTAL=$((TOTAL + 1))
  if printf '%s' "$OUT" | grep -qE -- '\.\./[^ ]*Adapters/scripts/setup-branch-protection\.sh'; then
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
if printf '%s' "$OUT" | grep -qF -- "Frontier via Tier Override, Director approval each time -> fable"; then
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
if printf '%s' "$OUT" | grep -qF -- "Frontier via Tier Override, Director approval each time -> my-frontier-model"; then
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
if frontmatter "$D/.claude/agents/software-architect.md" | grep -qx "effort: high"; then
  [ -n "$VERBOSE" ] && printf '   ok   Strategic Judgment (Software Architect) emits effort: high\n'
else
  printf '   FAIL Software Architect frontmatter has no effort: high\n'
  FAILED=$((FAILED + 1))
fi

TOTAL=$((TOTAL + 1))
if frontmatter "$D/.claude/agents/devops-engineer.md" | grep -q "^effort:"; then
  printf '   FAIL Standard Execution (DevOps Engineer) must inherit — no effort: field\n'
  FAILED=$((FAILED + 1))
else
  [ -n "$VERBOSE" ] && printf '   ok   Standard Execution (DevOps Engineer) has no effort: field (inherits)\n'
fi

# --effort-map overrides the default, mirroring --map.
D="$(project ga-effort-map)"
bash "$GEN" --project "$D" --effort-map "standard=medium,strategic=xhigh" >/dev/null 2>&1
TOTAL=$((TOTAL + 1))
if frontmatter "$D/.claude/agents/devops-engineer.md" | grep -qx "effort: medium"; then
  [ -n "$VERBOSE" ] && printf '   ok   --effort-map standard=medium is honoured\n'
else
  printf '   FAIL --effort-map standard=medium was not applied to a Standard Execution Employee\n'
  FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
if frontmatter "$D/.claude/agents/software-architect.md" | grep -qx "effort: xhigh"; then
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
if frontmatter "$D/.claude/agents/software-architect.md" | grep -q "^effort:"; then
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
if [ "\$1" = "version" ]; then echo "git version 2.30.0"; exit 0; fi
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$WORK/shim-old/git"
expect 1 "git older than 2.38 fails closed" -- env PATH="$WORK/shim-old:$PATH" bash "$CHECK_EMP" "$BASE" HEAD
expect_output "cannot classify"

# Fail closed: a git whose merge-tree errors must not turn into a pass.
mk_emp_merge_repo mrg-shim
git merge -q --no-ff side -m "Merge branch 'side'"
REAL_GIT="$(command -v git)"
mkdir -p "$WORK/shim"
cat > "$WORK/shim/git" <<SHIM
#!/usr/bin/env bash
if [ "\$1" = "merge-tree" ]; then exit 128; fi
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$WORK/shim/git"
expect 1 "a merge the classifier cannot run on fails closed" -- env PATH="$WORK/shim:$PATH" bash "$CHECK_EMP" "$BASE" HEAD
expect_output "could not be classified"

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
  if printf '%s' "$LAST_OUTPUT" | grep -qF -- "$1"; then
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
      *) if ! printf '%s\n' "$line" | grep -Eq '^[[:space:]]*shellcheck --version[[:space:]]*$'; then
           echo "shellcheck call without --norc: $line"; bad=1
         fi ;;
    esac
  done <<< "$sc_calls"
  if ! printf '%s\n' "$sc_calls" | grep -q -- '--norc -x'; then
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

  if ! prv_code "$file" | grep -Eq '^[[:space:]]*JS_YAML_VERSION="[0-9]+\.[0-9]+\.[0-9]+"'; then
    echo "JS_YAML_VERSION is not an exact x.y.z"; bad=1
  fi
  if ! prv_code "$file" | grep -qF -- "$PRV_MKTEMP_LITERAL"; then
    echo "grader directory is not created with mktemp -d"; bad=1
  fi
  if ! prv_code "$file" | grep -qF -- "$PRV_TRAP_LITERAL"; then
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
