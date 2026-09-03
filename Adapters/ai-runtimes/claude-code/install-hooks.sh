#!/usr/bin/env bash
# IA Engineering — install the Claude Code hooks into a project
#
# Writes .claude/settings.json from settings.example.json with __IAENG_ROOT__
# replaced by the framework's path relative to the project root. Never
# overwrites an existing settings.json: Claude Code's settings carry more than
# hooks, and a project that already has one merges by hand (the file this
# script would have written is printed with --print).
#
# Usage, from the project root:
#   ./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh [--print] [--force]
#
# The hooks are project-scoped (.claude/settings.json is committed), so every
# session on every clone runs them — unlike git hooks, Claude Code reads its
# hook configuration from the repository. That is also why this file must be
# reviewed like code: it decides what the model is allowed to do.

set -uo pipefail
export LC_ALL=C

PRINT=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --print) PRINT=1 ;;
    --force) FORCE=1 ;;
    --help|-h) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install-hooks.sh: unknown option '$arg'" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(pwd)"
EXAMPLE="$HERE/settings.example.json"
[ -f "$EXAMPLE" ] || { echo "install-hooks.sh: $EXAMPLE is missing" >&2; exit 1; }

# Framework root relative to the project: the directory three levels above
# this script (Adapters/ai-runtimes/claude-code), made relative to $PROJECT.
FW_ABS="$(cd "$HERE/../../.." && pwd)"
case "$FW_ABS" in
  "$PROJECT") ROOT="." ;;
  "$PROJECT"/*) ROOT="${FW_ABS#"$PROJECT"/}" ;;
  *) echo "install-hooks.sh: the framework ($FW_ABS) is not inside the project ($PROJECT); run from the project root" >&2; exit 1 ;;
esac

# The hook scripts must be executable for the Bash invocation to be moot and
# for a direct invocation to work; check, do not assume.
for h in "$HERE"/hooks/*.sh; do
  [ -x "$h" ] || { echo "install-hooks.sh: $h is not executable — run: chmod +x $HERE/hooks/*.sh" >&2; exit 1; }
done

RENDERED="$(sed "s#__IAENG_ROOT__#$ROOT#g" "$EXAMPLE")"

if [ "$PRINT" -eq 1 ]; then
  printf '%s\n' "$RENDERED"
  exit 0
fi

DEST="$PROJECT/.claude/settings.json"
if [ -f "$DEST" ] && [ "$FORCE" -eq 0 ]; then
  if [ "$(cat "$DEST")" = "$RENDERED" ]; then
    echo "= $DEST already current"
    exit 0
  fi
  echo "! $DEST exists and differs. Not overwritten." >&2
  echo "  Merge the 'hooks' block from: $0 --print" >&2
  echo "  or re-run with --force to replace the file (review its other settings first)." >&2
  exit 1
fi

mkdir -p "$PROJECT/.claude"
printf '%s\n' "$RENDERED" > "$DEST"
echo "+ $DEST (framework root: $ROOT)"
echo "  Hooks: SessionStart read-first, PreToolUse escape-hatch and inline-suppression blocks, PostToolUse lint, Stop gate."
echo "  Restart the Claude Code session for the hooks to load."
