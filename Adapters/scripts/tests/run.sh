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

mk_emp_merge_repo mrg-exception
git merge -q --no-commit --no-ff side
echo extra > extra.txt && git add extra.txt
git commit -q -m "Merge branch 'side'"
mkdir -p Registry
echo "$(git rev-parse HEAD) grandfathered for the test" > Registry/merge-attribution-exceptions.txt
expect 0 "an authored merge listed in the exceptions file passes" -- bash "$CHECK_EMP" "$BASE" HEAD

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
