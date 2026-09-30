#!/usr/bin/env bash
# IA Engineering — check-control-paths.sh
#
# Reads a list of changed file paths on standard input and reports which of
# them are CONTROL PATHS: the files that define, run, or configure the checks a
# Pull Request is judged by. Exit 1 when any is touched, 0 when none is.
#
# WHY (PT-07 of the #112 exercise)
#
# The required checks run the definitions carried by the PR under review: the
# workflow, the scripts it calls, the hooks, the roster. With 0 required
# approvals and no CODEOWNERS a PR can therefore rewrite the rule it is graded
# by. Adapters/github-actions/control-path-guard.yml runs the BASE branch's copy
# of this script (pull_request_target, never PR code) and fails when the PR
# touches any path below, unless the Director applies `control-change/approved`.
#
# THIS LIST IS THE ONLY COPY: the `case` in is_control below. The workflow calls
# this script from the base checkout, so a PR that edits the list is judged by
# the list it is editing away — and Adapters/scripts/ is itself a control path,
# so that edit is flagged too.
#
# USAGE
#
#   check-control-paths.sh [-z] < paths
#
#   -z   paths are NUL-terminated instead of newline-terminated. The workflow
#        uses it: file names are attacker-controlled and may contain newlines.
#
# HOW A NAME IS TREATED
#
#   - Never evaluated, never expanded, never passed as an argument to another
#     command: it is only compared with the literal patterns, by `case`.
#   - Matched case-insensitively. A case-insensitive checkout (Windows, macOS)
#     resolves `.GitHub/Workflows/x.yml` to the control file; fail closed.
#   - A name that is empty, absolute, or has a `.` / `..` component is not a
#     path git can produce. It is reported as a control path rather than trusted.
#   - In `case` patterns `*` also matches `/`, so `dir/*` covers every depth.
#
# `ia-engineering` (exact) is the submodule gitlink of an adopting project:
# bumping it swaps every script and hook the project runs.

set -uo pipefail

DELIM=$'\n'
case "${1:-}" in
  -z) DELIM='' ;;
  '') ;;
  *) echo "Usage: $0 [-z] < paths" >&2; exit 2 ;;
esac

shopt -s nocasematch

is_control() {
  local p="$1"
  [ -z "$p" ] && return 0
  case "/$p/" in
    //* | */./* | */../* | *//*) return 0 ;;
  esac
  case "$p" in
    .github/workflows/* | .github/actions/* | .github/CODEOWNERS | CODEOWNERS) return 0 ;;
    Adapters/github-actions/* | Adapters/git-hooks/* | Adapters/scripts/*) return 0 ;;
    Adapters/ai-runtimes/*/hooks/*) return 0 ;;
    .claude/settings.json | .claude/settings.local.json | .claude/hooks/*) return 0 ;;
    Registry/employees.yml) return 0 ;;
    .ia-engineering/*.allow | .ia-engineering/risk-map.yml) return 0 ;;
    .gitignore | .gitattributes | */.gitattributes | .gitmodules) return 0 ;;
    ia-engineering) return 0 ;;
  esac
  return 1
}

seen=0
touched=0
while IFS= read -r -d "$DELIM" path || [ -n "$path" ]; do
  seen=$((seen + 1))
  if is_control "$path"; then
    touched=$((touched + 1))
    # %q renders control characters visibly; the name is never interpreted.
    printf 'control path touched: %q\n' "$path"
  fi
done

if [ "$touched" -gt 0 ]; then
  printf 'check-control-paths: %s of %s changed paths are control paths.\n' "$touched" "$seen"
  exit 1
fi
printf 'check-control-paths: none of the %s changed paths is a control path.\n' "$seen"
exit 0
