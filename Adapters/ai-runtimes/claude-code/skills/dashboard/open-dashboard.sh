#!/usr/bin/env bash
# IA Engineering — /dashboard launcher (Claude Code skill, WU-IAENG-342)
#
# Opens the project's usage dashboard at once and leaves it refreshing
# itself: Adapters/scripts/usage-dashboard.sh --open --no-wait, whose
# contract is in that script's header, under KEPT FRESH. The page as it is
# opens immediately, a refresh starts behind it, and the page reloads itself
# to show it; only a project with no page yet waits for a first build.
#
# Runs from its installed place, <project>/.claude/skills/dashboard/, and
# finds everything from there, so the shell's current directory does not
# matter:
#   the project    $CLAUDE_PROJECT_DIR when it is a directory, else three
#                  levels above this file;
#   the script     Adapters/scripts/usage-dashboard.sh under, in this order,
#                  $IAENG_FRAMEWORK, the project's ia-engineering/ (an
#                  adopter's pinned framework), then the project itself (the
#                  framework repository, which has no ia-engineering/). The
#                  pinned submodule comes before the project root, so a
#                  root-level Adapters/scripts/ of an adopter's own never
#                  shadows the framework version it pinned (PR #239 security
#                  review). hooks/lib.sh looks at the root first; that order
#                  finds documents, this one picks a script to run.
#
# Prints ONE line for the user: where the page is and that it keeps itself
# fresh, or why it did not open (then the script's last lines, and exit 1).
# Called with Git Bash's bash on Windows, never through usage-dashboard.cmd,
# which costs seconds to start and adds a plain --open.

set -uo pipefail

case "$0" in
  */*) HERE="$(cd "${0%/*}" && pwd)" ;;
  *) HERE="$PWD" ;;
esac
ROOT="$(cd "$HERE/../../.." && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  ROOT="$(cd "$CLAUDE_PROJECT_DIR" && pwd)"
fi

SCRIPT=""
for c in "${IAENG_FRAMEWORK:-}" "$ROOT/ia-engineering" "$ROOT"; do
  if [ -n "$c" ] && [ -f "$c/Adapters/scripts/usage-dashboard.sh" ]; then
    SCRIPT="$c/Adapters/scripts/usage-dashboard.sh"
    break
  fi
done
if [ -z "$SCRIPT" ]; then
  echo "Usage dashboard not opened: Adapters/scripts/usage-dashboard.sh was found neither in $ROOT/ia-engineering nor in $ROOT (a framework pinned before the kept-fresh dashboard has none; update the ia-engineering submodule)."
  exit 1
fi

OUT="$(bash "$SCRIPT" --open --no-wait --project-dir "$ROOT" 2>&1 </dev/null)"
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "Usage dashboard not opened (usage-dashboard.sh exited $RC):"
  printf '%s\n' "$OUT" | tail -n 5 | sed 's/^/  /'
  exit 1
fi

PAGE="$ROOT/.ia-engineering/usage/dashboard.html"
command -v cygpath >/dev/null 2>&1 && PAGE="$(cygpath -w "$PAGE")"
AUTO="refreshed in the background after every turn by the Stop hook"
case "${IAENG_USAGE_AUTO_REFRESH:-}" in
  [0]|[Oo][Ff][Ff]|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]) AUTO="automatic refresh after each turn is off for this session" ;;
esac
[ -e "$ROOT/.ia-engineering/usage-auto-refresh.off" ] && AUTO="automatic refresh after each turn is off for this project"
echo "Usage dashboard opened: $PAGE - it keeps itself fresh (a refresh is running now, the page reloads itself every 60 s; $AUTO)."
exit 0
