#!/usr/bin/env bash
# IA Engineering — Claude Code hooks: shared helpers
#
# Sourced by every hook in this directory. Claude Code delivers hook input as
# one JSON object on stdin (session_id, cwd, hook_event_name, tool_name,
# tool_input, ...). `jq` is preferred for reading it; when jq is absent the
# helpers fall back to a sed extraction that handles JSON string escapes for
# the flat fields these hooks need. A hook that cannot read its input FAILS
# CLOSED (exit 2 with the reason) rather than allowing the action — a guard
# that silently allows everything when a dependency is missing is the defect
# Adapters/README.md's Check Convention exists to name.
#
# Exit code contract (Claude Code):
#   0  allow / nothing to add
#   2  block the tool call (PreToolUse) or keep the session going (Stop), with
#      stderr shown to the model as the reason
#   other  non-blocking error, stderr shown to the user only

set -uo pipefail
export LC_ALL=C

IAENG_INPUT="$(cat)"

iaeng_have_jq() { command -v jq >/dev/null 2>&1; }

# iaeng_field <jq-path>  — prints the string at that path, or nothing.
# The fallback takes the LAST path component as a flat key, which is what the
# hooks here need (tool_name, tool_input.command, tool_input.file_path, ...).
iaeng_field() {
  local path="$1" key
  if iaeng_have_jq; then
    printf '%s' "$IAENG_INPUT" | jq -r "$path // empty" 2>/dev/null
    return
  fi
  key="${path##*.}"
  printf '%s' "$IAENG_INPUT" \
    | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p' \
    | sed 's/\\"/"/g; s/\\n/\
/g; s/\\t/\t/g; s/\\\\/\\/g'
}

# iaeng_bool <jq-path>  — prints true/false/(empty).
iaeng_bool() {
  local path="$1" key
  if iaeng_have_jq; then
    printf '%s' "$IAENG_INPUT" | jq -r "$path // empty" 2>/dev/null
    return
  fi
  key="${path##*.}"
  printf '%s' "$IAENG_INPUT" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p'
}

iaeng_block() {
  # $1 = one-line reason, $2 = standard reference
  {
    printf 'iaeng: BLOCKED — %s\n' "$1"
    printf '  %s\n' "$2"
    printf '  A control in the way is a rule in the way: escalate it with this message quoted.\n'
    printf '  If the Director has decided this action, a human runs it by hand — the hook never learns exceptions.\n'
  } >&2
  exit 2
}

# Framework root relative to the project: "." when this IS the framework
# repository, "ia-engineering" when imported as a submodule at the path
# Workflows/ONBOARDING.md assumes, or $IAENG_FRAMEWORK when set.
iaeng_framework_root() {
  local base="${CLAUDE_PROJECT_DIR:-.}" c
  for c in "${IAENG_FRAMEWORK:-}" "$base" "$base/ia-engineering"; do
    [ -n "$c" ] && [ -f "$c/Core/AGENT_CONDUCT.md" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}
