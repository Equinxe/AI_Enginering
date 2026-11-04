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
# Prints ONE line for the user: where the page is, what happened to it, and
# what keeps it fresh; or why it did not open (then the script's last lines,
# and exit 1). The first page in a project is built in the foreground, which
# SKILL.md covers with a 600000 ms Bash timeout (cold builds measured at 9 s
# for an adopter and 57-90 s for the framework itself on a loaded machine).
# Called with Git Bash's bash on Windows, never through usage-dashboard.cmd,
# which costs seconds to start and adds a plain --open.

set -uo pipefail

case "$0" in
  */*) HERE="$(CDPATH='' cd -- "${0%/*}" && pwd)" ;;
  *) HERE="$PWD" ;;
esac
ROOT="$(cd "$HERE/../../.." && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  ROOT="$(CDPATH='' cd -- "$CLAUDE_PROJECT_DIR" && pwd)"
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

# THE LINE SAYS WHAT HAPPENED, NOT WHAT USUALLY HAPPENS (PR #239 code review).
# It is worded from what usage-dashboard.sh printed: a page opened as it was
# with a refresh started behind it, or one a refresh already running will
# update, or a first page built just now in the foreground (no refresh is
# started then: the page is new). The Stop hook is credited only when the
# project's settings register it, and an opt-out is named. A browser that
# could not be opened is said, not hidden: the script reports it as a note
# and still exits 0 (on Windows explorer.exe gives no usable status, so
# there nothing can be reported).
PAGE="$ROOT/.ia-engineering/usage/dashboard.html"
command -v cygpath >/dev/null 2>&1 && PAGE="$(cygpath -w "$PAGE")"

case "$OUT" in
  *"opened as it is; refreshing it in the background"*) NOW="a refresh is running now; " ;;
  *"a refresh is already running"*) NOW="a refresh already running will update it; " ;;
  *"Usage dashboard written"*) NOW="built just now; " ;;
  *) NOW="" ;;
esac

AUTO="not refreshed after each turn: the Stop hook is not installed (install-hooks.sh)"
for s in "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
  if [ -f "$s" ] && grep -q 'hooks/dashboard-refresh\.sh' "$s"; then
    AUTO="refreshed in the background after every turn by the Stop hook"
  fi
done
case "${IAENG_USAGE_AUTO_REFRESH:-}" in
  [0]|[Oo][Ff][Ff]|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]) AUTO="automatic refresh after each turn is off for this session" ;;
esac
[ -e "$ROOT/.ia-engineering/usage-auto-refresh.off" ] && AUTO="automatic refresh after each turn is off for this project"

TITLE="Usage dashboard opened: $PAGE"
case "$OUT" in
  *"could not open a browser"*) TITLE="Usage dashboard ready, but no browser could be opened; open it yourself: $PAGE" ;;
esac
echo "$TITLE - it keeps itself fresh (${NOW}the page reloads itself every 60 s; $AUTO)."
exit 0
