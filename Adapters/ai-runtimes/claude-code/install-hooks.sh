#!/usr/bin/env bash
# IA Engineering — install the Claude Code hooks into a project
#
# Writes .claude/settings.json from settings.example.json with __IAENG_ROOT__
# replaced by the framework's path relative to the project root. Never
# overwrites an existing settings.json: Claude Code's settings carry more than
# hooks, and a project's own entries are the project's.
#
# AN EXISTING settings.json IS MERGED INTO, NOT REPLACED (WU-IAENG-342). Each
# hook entry of the template that the file does not already have is appended
# to its event; nothing already in the file is changed, reordered or removed —
# the project's own hooks, its env, its permissions, its $comment. An entry is
# "already there" when a command under the same event already runs the same
# hook script (hooks/<name>.sh), whatever path spells it, so a re-run adds
# nothing and a hand-merged entry is not duplicated. The file is rewritten by
# jq, so its formatting is normalised (two-space indent); its content is kept.
# Without jq, or when the file is not a JSON object, nothing is written and
# the merge is left to you (--print). A project that does not want one of the
# framework's hooks does not delete its entry — a re-run adds it back — but
# uses the hook's own switch where it has one (hooks/README.md).
#
# Usage, from the project root:
#   ./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh [--print] [--force]
#
#   --print  print the file this script would write for a new project, and
#            change nothing
#   --force  replace an existing settings.json with that file instead of
#            merging (review its other settings first)
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
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
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
# THE RELATION IS ESTABLISHED BY WALKING, NOT BY COMPARING SPELLINGS.
# A string-prefix test asks whether one path is written like another, which is
# not whether one directory contains the other: on Windows the same directory
# is "C:/x" and "/c/x", and may differ in letter case, so a correct layout was
# refused (DEF-14, issue #181). Adapters/scripts/install.sh documents the
# failure at length and uses this technique: walk up from the framework and ask
# `-ef` (same device and inode) at each step, accumulating the relative path
# from the real components.
ROOT=""
_probe="$FW_ABS"
_rel=""
while :; do
  if [ "$_probe" -ef "$PROJECT" ]; then
    ROOT="${_rel:-.}"
    break
  fi
  _parent="$(dirname "$_probe")"
  [ "$_parent" = "$_probe" ] && break
  _rel="$(basename "$_probe")${_rel:+/$_rel}"
  _probe="$_parent"
done
unset _probe _rel _parent
if [ -z "$ROOT" ]; then
  echo "install-hooks.sh: the framework ($FW_ABS) is not inside the project ($PROJECT); run from the project root" >&2
  exit 1
fi

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

HOOK_LIST="SessionStart read-first, PreToolUse escape-hatch and inline-suppression blocks, PostToolUse lint, Stop gate, Stop usage-dashboard refresh (never blocks; opt-out in hooks/README.md)."

DEST="$PROJECT/.claude/settings.json"
if [ -f "$DEST" ] && [ "$FORCE" -eq 0 ]; then
  if [ "$(cat "$DEST")" = "$RENDERED" ]; then
    echo "= $DEST already current"
    exit 0
  fi
  merge_by_hand() {
    echo "! $DEST exists and differs, and $1. Not changed." >&2
    echo "  Merge the 'hooks' block from: $0 --print" >&2
    echo "  or re-run with --force to replace the file (review its other settings first)." >&2
    exit 1
  }
  command -v jq >/dev/null 2>&1 || merge_by_hand "jq is not installed to merge into it"
  # One JSON object, or nothing is touched. tr: jq on Windows writes CRLF.
  jq -es 'length == 1 and (.[0] | type == "object") and ((.[0].hooks // {}) | type == "object")' "$DEST" >/dev/null 2>&1 \
    || merge_by_hand "it is not one JSON object with an object 'hooks'"
  # {m: the merged settings, a: ["Event: script.sh", ...] added}. A template
  # group is present when every hooks/<name>.sh it runs is already run by
  # some command under the same event.
  MERGED="$(jq --argjson tpl "$RENDERED" '
    def scripts: [.hooks[]?.command // "" | strings | scan("hooks/([A-Za-z0-9._-]+[.]sh)") | .[0]];
    reduce ($tpl.hooks | to_entries[]) as $e ({m: ., a: []};
      reduce $e.value[] as $g (.;
        ($g | scripts) as $want
        | ([.m.hooks[$e.key][]? | scripts[]]) as $have
        | if ($want | length) == 0 or all($want[]; . as $w | any($have[]; . == $w)) then .
          else .m.hooks[$e.key] = ((.m.hooks[$e.key] // []) + [$g])
               | .a += [$e.key + ": " + ($want | join(", "))]
          end))' "$DEST" 2>/dev/null | tr -d '\r')" \
    || merge_by_hand "the merge failed"
  ADDED="$(printf '%s\n' "$MERGED" | jq -r '.a[]' | tr -d '\r')"
  if [ -z "$ADDED" ]; then
    echo "= $DEST already has every IA Engineering hook; left as it is."
    exit 0
  fi
  TMP="$DEST.iaeng-merge.$$"
  if ! printf '%s\n' "$MERGED" | jq '.m' | tr -d '\r' > "$TMP" || ! jq -e 'type == "object"' "$TMP" >/dev/null 2>&1; then
    rm -f "$TMP"
    merge_by_hand "the merged file could not be written"
  fi
  mv -f "$TMP" "$DEST" || { rm -f "$TMP"; merge_by_hand "the merged file could not replace it"; }
  echo "+ $DEST: merged (framework root: $ROOT); every entry already in it is kept. Added:"
  printf '%s\n' "$ADDED" | sed 's/^/    /'
  echo "  Hooks: $HOOK_LIST"
  echo "  Review the diff, commit it, and restart the Claude Code session for the hooks to load."
  exit 0
fi

mkdir -p "$PROJECT/.claude"
printf '%s\n' "$RENDERED" > "$DEST"
echo "+ $DEST (framework root: $ROOT)"
echo "  Hooks: $HOOK_LIST"
echo "  Restart the Claude Code session for the hooks to load."
