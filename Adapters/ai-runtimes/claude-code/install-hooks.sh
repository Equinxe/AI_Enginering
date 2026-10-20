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
# "already there" only when the same event has a group with the same matcher
# holding an entry equal to the template's in every field — its command (the
# project directory's spelling aside), its type, its timeout, any other — so a
# re-run adds nothing; an entry that only names a framework hook script —
# another matcher, an "|| true", an echo, the exact command with another
# timeout — does not count, the framework's entry is added beside it, and the
# other one is reported for the project to check. The report lists what was
# added and what was found present, nothing more, plus a warning when the
# project's settings switch every hook off ("disableAllHooks": true), which
# this script reports and never changes. The file is rewritten by jq, so its
# formatting is normalised (two-space indent); its content is kept. Without jq, when the
# file is not a JSON object, or when it is a symbolic link, nothing is written
# and the merge is left to you (--print). A project that does not want one of the
# framework's hooks does not delete its entry — a re-run adds it back — but
# uses the hook's own switch where it has one (hooks/README.md).
#
# The project's .gitattributes gets the line "/.claude/settings.json text
# eol=lf" when it does not have it yet (issue #242), so a clone with
# core.autocrlf=true checks the file out as it was written; nothing else in
# .gitattributes is touched.
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

# HOOKS SWITCHED OFF ARE SAID, NOT LEFT SILENT (issue #241, L2). With
# "disableAllHooks": true in the project's settings, Claude Code runs none of
# the hooks this script installs, the guards included, while the installer
# would otherwise report success. It is the project's setting and is never
# changed here; it is named on stderr and in the report, every run, until it
# is removed. Both project files are read: settings.json, which this script
# writes, and settings.local.json, the developer's own, which switches the
# hooks off just as surely for that developer.
hooks_disabled_in() {
  local f
  for f in "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json"; do
    [ -f "$f" ] || continue
    if command -v jq >/dev/null 2>&1 && jq -e 'type == "object"' "$f" >/dev/null 2>&1; then
      jq -e '.disableAllHooks == true' "$f" >/dev/null 2>&1 || continue
    else
      # No jq, or not JSON jq can read: the key as Claude Code would see it.
      grep -Eq '"disableAllHooks"[[:space:]]*:[[:space:]]*true' "$f" || continue
    fi
    printf '%s\n' ".claude/${f##*/.claude/}"
  done
}
warn_if_hooks_disabled() {
  local found
  found="$(hooks_disabled_in)"
  [ -n "$found" ] || return 0
  {
    echo "! \"disableAllHooks\": true is set in:"
    printf '%s\n' "$found" | sed 's/^/    /'
    echo "  While it is, Claude Code runs NONE of the hooks, the framework's guards included."
    echo "  This installer does not change it: remove it there for the hooks to run."
  } >&2
  echo "  WARNING: every hook is switched off (\"disableAllHooks\": true in $(printf '%s\n' "$found" | tr '\n' ' ' | sed 's/ $//')); none of these hooks will run."
}

# THE INSTALLED FILE IS PINNED TO LF IN THE PROJECT (issue #242). Without the
# rule, a clone with core.autocrlf=true checks settings.json out CRLF, unlike
# the framework's own copy. Exact line (a CRLF .gitattributes read as LF);
# appended on its own line, so a file without a final newline is not joined to
# it. Written out here rather than sourced from a shared file: this script is
# a control path (Adapters/scripts/check-control-paths.sh), and a file it
# sources would have to be one too.
ensure_lf_rule() {
  local rule="/.claude/settings.json text eol=lf" attr="$PROJECT/.gitattributes" sep=""
  if [ -f "$attr" ] && tr -d '\r' < "$attr" | grep -qxF "$rule"; then
    return 0
  fi
  # Read before the append starts: a last line without its newline gets one.
  if [ -s "$attr" ] && [ -n "$(tail -c 1 "$attr")" ]; then sep=$'\n'; fi
  if {
    printf '%s' "$sep"
    echo "# IA Engineering — .claude/settings.json is written by install-hooks.sh;"
    echo "# LF on every checkout, as in the framework (issue #242)."
    echo "$rule"
  } >> "$attr"; then
    echo "+ .gitattributes: $rule (commit it with settings.json)"
  else
    echo "! could not append to $attr; add this line to it by hand: $rule" >&2
    return 1
  fi
}

# Every run that leaves settings.json in place ends here: the LF rule, then
# the warning. Exit 1 when the rule could not be written — settings.json is
# installed, but not as the project will clone it.
finish() {
  local rc=0
  ensure_lf_rule || rc=1
  warn_if_hooks_disabled
  return "$rc"
}

if [ -f "$DEST" ] && [ "$FORCE" -eq 0 ]; then
  if [ "$(cat "$DEST")" = "$RENDERED" ]; then
    echo "= $DEST already current"
    finish; exit $?
  fi
  merge_by_hand() {
    echo "! $DEST exists and differs, and $1. Not changed." >&2
    echo "  Merge the 'hooks' block from: $0 --print" >&2
    echo "  or re-run with --force to replace the file (review its other settings first)." >&2
    warn_if_hooks_disabled
    exit 1
  }
  # A link is refused, not merged through: writing the merge would replace
  # the link with a regular file and detach it from what it points at.
  [ -L "$DEST" ] && merge_by_hand "it is a symbolic link (a merge would replace the link with a file)"
  command -v jq >/dev/null 2>&1 || merge_by_hand "jq is not installed to merge into it"
  # One JSON object, or nothing is touched. tr: jq on Windows writes CRLF.
  jq -es 'length == 1 and (.[0] | type == "object") and ((.[0].hooks // {}) | type == "object")' "$DEST" >/dev/null 2>&1 \
    || merge_by_hand "it is not one JSON object with an object 'hooks'"
  # PRESENT MEANS EXACTLY THE FRAMEWORK'S ENTRY (PR #239 security review, F1;
  # issue #241, L1). A template group is present only when a group under the
  # same event has the same matcher and holds each of the template's hook
  # entries equal in EVERY field — command, type, timeout and any other, in
  # any key order — after normalising only how the project directory is
  # spelled in the command ("${CLAUDE_PROJECT_DIR}" for "$CLAUDE_PROJECT_DIR",
  # "/./" for "/"). An entry that merely names a hook script — under a matcher
  # that never fires, with "|| true" turning its block into nothing, in an
  # echo, or the exact command with a one-second timeout, after which the
  # runtime goes on as if it had not blocked — is not the guard: the
  # framework's entry is appended beside it (a hook run twice is harmless) and
  # the other one is reported as a near miss for the project to check, naming
  # the fields that differ when its command is the template's.
  # Result: {m: merged settings, a: added, p: present, w: near misses}.
  MERGED="$(jq --argjson tpl "$RENDERED" '
    def norm: gsub("[$][{]CLAUDE_PROJECT_DIR[}]"; "$CLAUDE_PROJECT_DIR") | gsub("/[.]/"; "/");
    def nentry: if type == "object" and (.command | type) == "string" then .command |= norm else . end;
    def nentries: [.hooks[]? | nentry];
    def scripts: [.hooks[]?.command // "" | strings | scan("hooks/([A-Za-z0-9._-]+[.]sh)") | .[0]];
    def where($ev): $ev + (if (.matcher // "") != "" then " [" + .matcher + "]" else "" end);
    def differ($a; $b): [[$a, $b][] | keys[]] | unique | map(select(. as $k | $a[$k] != $b[$k]));
    . as $cur
    | ([$tpl.hooks[][] | scripts[]] | unique) as $names
    | reduce ($tpl.hooks | to_entries[]) as $e ({m: ., a: [], p: []};
        reduce $e.value[] as $g (.;
          ($g | nentries) as $want
          | ($g | where($e.key) + ": " + (scripts | join(", "))) as $label
          | if any($cur.hooks[$e.key][]?;
                   (.matcher // null) == ($g.matcher // null)
                   and (nentries as $have | all($want[]; . as $w | any($have[]; . == $w))))
            then .p += [$label]
            else .m.hooks[$e.key] = ((.m.hooks[$e.key] // []) + [$g]) | .a += [$label]
            end))
    | .w = [ $cur.hooks | to_entries[] | .key as $ev | .value[]? | . as $grp
             | .hooks[]? | . as $h | .command // "" | strings | . as $c
             | select(any($names[]; . as $n | $c | contains("hooks/" + $n)))
             | ($h | nentry) as $hn
             | [$tpl.hooks[$ev][]? | select((.matcher // null) == ($grp.matcher // null)) | nentries[]] as $tents
             | select(any($tents[]; . == $hn) | not)
             | ([$tents[] | select(.command == $hn.command)] | first) as $same
             | ($grp | where($ev)) + ": " + $c
               + (if $same == null then ""
                  else "  (the framework command; differs in: " + (differ($same; $hn) | join(", ")) + ")"
                  end) ]' "$DEST" 2>/dev/null | tr -d '\r')" \
    || merge_by_hand "the merge failed"
  ADDED="$(printf '%s\n' "$MERGED" | jq -r '.a[]' | tr -d '\r')"
  PRESENT="$(printf '%s\n' "$MERGED" | jq -r '.p[]' | tr -d '\r')"
  NEAR="$(printf '%s\n' "$MERGED" | jq -r '.w[]' | tr -d '\r')"
  if [ -n "$NEAR" ]; then
    {
      echo "! $DEST: these commands name a framework hook script but are not the framework's entry"
      echo "  (another matcher, another command, or another field such as its timeout). Check"
      echo "  each is not a weakened copy; the framework's own entry is in the file beside them"
      echo "  either way:"
      printf '%s\n' "$NEAR" | sed 's/^/    /'
    } >&2
  fi
  if [ -z "$ADDED" ]; then
    echo "= $DEST: every IA Engineering hook entry is present exactly; left as it is."
    printf '%s\n' "$PRESENT" | sed 's/^/    present: /'
    finish; exit $?
  fi
  TMP="$DEST.iaeng-merge.$$"
  if ! printf '%s\n' "$MERGED" | jq '.m' | tr -d '\r' > "$TMP" || ! jq -e 'type == "object"' "$TMP" >/dev/null 2>&1; then
    rm -f "$TMP"
    merge_by_hand "the merged file could not be written"
  fi
  mv -f "$TMP" "$DEST" || { rm -f "$TMP"; merge_by_hand "the merged file could not replace it"; }
  echo "+ $DEST: merged (framework root: $ROOT); every entry already in it is kept."
  printf '%s\n' "$ADDED" | sed 's/^/    added:   /'
  [ -z "$PRESENT" ] || printf '%s\n' "$PRESENT" | sed 's/^/    present: /'
  finish; rc=$?
  echo "  Review the diff, commit it, and restart the Claude Code session for the hooks to load."
  exit "$rc"
fi

mkdir -p "$PROJECT/.claude"
printf '%s\n' "$RENDERED" > "$DEST"
echo "+ $DEST (framework root: $ROOT)"
echo "  Hooks: $HOOK_LIST"
finish; rc=$?
echo "  Restart the Claude Code session for the hooks to load."
exit "$rc"
