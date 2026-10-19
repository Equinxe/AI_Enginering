#!/usr/bin/env bash
# IA Engineering — Claude Code Stop hook: keep the usage dashboard fresh
#
# Director decision, 7 Oct 2026 (WU-IAENG-342): the usage dashboard is kept
# fresh automatically at the end of each turn, so /dashboard opens a current
# page with no rebuild to wait for. This hook starts that refresh. It calls
# Adapters/scripts/usage-dashboard.sh --refresh-in-background, whose contract
# is in that script's header, under KEPT FRESH: returns at once, one line on
# stdout, nothing on stderr, exit 0 always, the refresh detached, at most one
# start per minute, one at a time.
#
# NOT A GUARD. Every other Stop or PreToolUse hook here enforces a rule; this
# one enforces nothing and decides nothing, so it must never block, slow or
# fail a turn, and must never reach the model:
#
#   - exit 0 on every path, whatever the dashboard script does;
#   - stdout and stderr are /dev/null from the first line, so nothing it or
#     anything it starts prints can reach the transcript or be read as a
#     decision, and no child it starts holds the runtime's pipes open;
#   - stdin is not read: the payload carries nothing this hook needs, and a
#     hook that waits on stdin can wait forever;
#   - builtins only before the one call, so no process is started to find a
#     path (a process start costs tens of milliseconds on Windows, far more
#     on a loaded machine);
#   - the script is started in the background and not waited for. Its own
#     answer returns at once, but on Windows Git Bash the one call in sixty
#     seconds that starts a refresh spends 1.5 to 2.7 s starting it (measured
#     by WU-IAENG-342 from a parent waiting on the hook's pipes). Not waited
#     for, the hook costs one bash start; the script still decides, debounces
#     and detaches exactly as its contract says, with every stream on
#     /dev/null, so it holds none of the runtime's pipes.
#
# THE STOP GATE. Claude Code runs the hooks of one event in parallel, so no
# order in settings.json can sequence this after stop-gate.sh. Independence is
# what keeps the gate's decision unaffected: this hook exits 0 with no output,
# which is "nothing to add", and the gate's exit 2 stands on its own. When the
# gate blocks, the model continues and this hook runs again at the next stop;
# the dashboard script's debounce turns that second call into a no-op. The
# refresh it starts runs read-only git and writes only under the gitignored
# .ia-engineering/usage/, so the gate's `git status` sees nothing of it.
#
# SKIPPED SILENTLY when:
#   - the project opted out: the file .ia-engineering/usage-auto-refresh.off
#     exists in the project (the reliable switch), or $IAENG_USAGE_AUTO_REFRESH
#     is 0, off, false or no (any case) — in the shell, or in the "env" block
#     of .claude/settings.json or .claude/settings.local.json, which reaches
#     the hook only where the runtime passes that env to hooks;
#   - the dashboard script is absent beside this hook (a framework pinned at
#     a version without it).
# Anything else — a project that is not a git work tree, a path that does not
# exist, a cache that cannot be used — is the script's to judge, and it judges
# without failing (one line, discarded here, and exit 0). The project is
# $CLAUDE_PROJECT_DIR, which Claude Code sets for every hook; run by hand
# without it, the current directory.
#
# Not registered on SubagentStop: see hooks/README.md, Dashboard Refresh.
#
# Usage (from .claude/settings.json; no arguments, any given are ignored):
#   bash "$CLAUDE_PROJECT_DIR/<framework>/Adapters/ai-runtimes/claude-code/hooks/dashboard-refresh.sh"

exec >/dev/null 2>&1

case "${IAENG_USAGE_AUTO_REFRESH:-}" in
  [0]|[Oo][Ff][Ff]|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]) exit 0 ;;
esac

BASE="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -e "$BASE/.ia-engineering/usage-auto-refresh.off" ] && exit 0

# This file is <framework>/Adapters/ai-runtimes/claude-code/hooks/; the
# script is <framework>/Adapters/scripts/. Resolved from this file, so the
# hook and the script always come from the same framework checkout.
case "${BASH_SOURCE[0]}" in
  */*) HERE="${BASH_SOURCE[0]%/*}" ;;
  *) HERE="." ;;
esac
SCRIPT="$HERE/../../../scripts/usage-dashboard.sh"
[ -f "$SCRIPT" ] || exit 0

bash "$SCRIPT" --refresh-in-background --project-dir "$BASE" </dev/null &
exit 0
