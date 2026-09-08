#!/usr/bin/env bash
# IA Engineering — check-employee-trailers.sh
#
# Every non-merge commit in a range carries an `Employee: <Name>` trailer, and
# the name resolves against the Employee roster.
#
# This is the SERVER-SIDE BACKSTOP for Adapters/git-hooks/commit-msg. The hook
# is the first line and the better one — it refuses before the commit exists —
# but it is bypassable with --no-verify and absent entirely on a machine where
# install.sh was never run. A control that can be skipped from a developer
# machine is not a control until something re-checks it where it cannot be
# skipped (Core/MAIN_AGENT_CONDUCT.md, Dispatch Discipline).
#
# It was embedded in Adapters/github-actions/pr-validation.yml until
# WU-IAENG-225. See check-work-units.sh for why that location was the problem.
#
# TWO ROSTERS, UNIONED
#
# The framework roster holds the 42 Employees. A project may additionally
# define Domain Employees of its own (Templates/DOMAIN_EMPLOYEE.md), which are
# real Employees for that project and unknown to the framework. Validating
# against the framework roster alone would silently refuse every one of them,
# so the project roster is unioned in when present.
#
# $IAENG_PROJECT_ROSTER pointing at a file that does not exist is a FAILURE and
# not a fallback to the framework roster alone: that would turn a typo in a
# path into a rule that quietly refuses every Domain Employee, which is the
# shape of defect this project catalogues as a check that passes without
# evaluating what it claims to (Adapters/README.md, The Check Convention).
#
# USAGE
#
#   check-employee-trailers.sh <base-ref> <head-ref>
#
# Exit 0 when every commit resolves, 1 when any does not or when the roster
# cannot be found. A range with no non-merge commits is a pass and says so.

set -uo pipefail

# See the note in check-work-units.sh on why this helper is duplicated rather
# than sourced: these scripts run from a consumer project where the framework
# path varies, and a sourcing bug would only appear in somebody else's repo.
err() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error::%s\n' "$1" >&2
  else
    printf 'check-employee-trailers: ERROR: %s\n' "$1" >&2
  fi
}

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <base-ref> <head-ref>" >&2
  echo "  Validates the Employee trailer on every non-merge commit in the range." >&2
  exit 2
fi

BASE_REF="$1"
HEAD_REF="$2"

ROSTER=""
for candidate in \
  "${IAENG_REGISTRY:-}" \
  "Registry/employees.yml" \
  "ia-engineering/Registry/employees.yml"
do
  if [ -n "$candidate" ] && [ -f "$candidate" ]; then
    ROSTER="$candidate"
    break
  fi
done

if [ -z "$ROSTER" ]; then
  err "Could not locate Registry/employees.yml (looked at \$IAENG_REGISTRY, Registry/, ia-engineering/Registry/). The Employee roster is the single source of truth for this check; failing closed rather than passing without validating anything."
  exit 1
fi

echo "Roster: $ROSTER"

VALID_NAMES="$(grep -E '^  - name: ' "$ROSTER" | sed 's/^  - name: //' | tr -d '\r')"
ROSTER_COUNT="$(printf '%s\n' "$VALID_NAMES" | grep -c . || true)"
echo "Roster entries: $ROSTER_COUNT"

# A roster that parses to nothing would refuse every commit, and the message
# would describe the commits when the fault is in the parser or the file shape.
if [ "$ROSTER_COUNT" -eq 0 ]; then
  err "$ROSTER yielded no Employee names. The parsing contract is a line of the exact form '  - name: <Name>' (two spaces, dash, space). Failing rather than refusing every commit, which would describe the parser and not the commits."
  exit 1
fi

PROJECT_ROSTER=""
if [ -n "${IAENG_PROJECT_ROSTER:-}" ]; then
  if [ -f "$IAENG_PROJECT_ROSTER" ]; then
    PROJECT_ROSTER="$IAENG_PROJECT_ROSTER"
  else
    err "IAENG_PROJECT_ROSTER is set to '$IAENG_PROJECT_ROSTER' but no such file exists. Validating against the framework roster alone would silently refuse every Domain Employee; fix the path or unset the variable."
    exit 1
  fi
elif [ -f ".ia-engineering/Registry/employees.yml" ]; then
  PROJECT_ROSTER=".ia-engineering/Registry/employees.yml"
fi

if [ -n "$PROJECT_ROSTER" ]; then
  PROJECT_NAMES="$(grep -E '^  - name: ' "$PROJECT_ROSTER" | sed 's/^  - name: //' | tr -d '\r')"
  echo "Project roster: $PROJECT_ROSTER ($(printf '%s\n' "$PROJECT_NAMES" | grep -c . || true) Domain Employee(s))"
  VALID_NAMES="$(printf '%s\n%s\n' "$VALID_NAMES" "$PROJECT_NAMES")"
else
  echo "Project roster: none (.ia-engineering/Registry/employees.yml absent — no Domain Employees)"
fi

if ! COMMITS="$(git rev-list --no-merges "${BASE_REF}..${HEAD_REF}")"; then
  err "git rev-list failed over ${BASE_REF}..${HEAD_REF}. No commit was examined, so nothing was established; failing rather than reporting zero problems."
  exit 1
fi

if [ -z "$COMMITS" ]; then
  echo "No non-merge commits to validate."
  exit 0
fi

echo "Commits to validate: $(printf '%s\n' "$COMMITS" | grep -c .)"

fail=0
for sha in $COMMITS; do
  MSG="$(git log -1 --format=%B "$sha")"
  EMPLOYEE_LINES="$(printf '%s\n' "$MSG" | grep -E '^Employee: ' || true)"

  if [ -z "$EMPLOYEE_LINES" ]; then
    err "Commit $sha is missing an 'Employee: <Name>' trailer. Per Core/MAIN_AGENT_CONDUCT.md (Dispatch Discipline), every commit must identify the Employee who produced it. This commit likely skipped the local commit-msg hook (--no-verify, or the hook was never installed)."
    fail=1
    continue
  fi

  while IFS= read -r emp_line; do
    [ -n "$emp_line" ] || continue
    EMPLOYEE_NAME="$(printf '%s' "${emp_line#Employee: }" | tr -d '\r')"
    if printf '%s\n' "$VALID_NAMES" | grep -qxF "$EMPLOYEE_NAME"; then
      echo "  $sha -> $EMPLOYEE_NAME"
    else
      err "Commit $sha has 'Employee: $EMPLOYEE_NAME', which is not in $ROSTER${PROJECT_ROSTER:+ nor in the project roster $PROJECT_ROSTER}. A functional or tool label ('executor', 'coder', 'reviewer-bot') is not a valid Employee name — see Core/MAIN_AGENT_CONDUCT.md, 'Naming matters.' If this line is an EXAMPLE quoted in the message body, indent it so it does not start at column 0."
      fail=1
    fi
  done < <(printf '%s\n' "$EMPLOYEE_LINES")
done

exit "$fail"
