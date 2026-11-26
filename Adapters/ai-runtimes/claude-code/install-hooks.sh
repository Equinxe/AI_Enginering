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
# other one is reported for the project to check. One exception: the
# framework's OWN earlier entry, exactly — a group whose matcher is one the
# framework used before (SUPERSEDED below) and whose entries are exactly the
# template's, nothing else in it — has its matcher updated in place, since
# appending beside it would run the hook twice (WU-IAENG-373); so does a
# group under the template's matcher whose entries are exactly the
# template's without the fields the framework added since, which get those
# fields (WU-IAENG-410: the guards' timeout and onFailure). The report
# lists what was added, updated and found present, nothing more, plus a warning when the
# project's settings switch every hook off ("disableAllHooks": true), which
# this script reports and never changes. A file with no "hooks" at all — a
# project's own settings.json often holds only its permissions, a $schema, or
# nothing — or with "hooks": null gets the framework's entries the same way
# (DEF-465-01). The file is rewritten by jq, so its formatting is normalised
# (two-space indent); its content is kept. Without jq, when the file is not
# one strict JSON object in the shape Claude Code's settings schema gives
# "hooks" (each event a list of matcher groups, each group an object whose
# "hooks" is a list), or when it is a symbolic link, nothing is written and
# the merge is left to you (--print). A comment (// or /* */) is
# not JSON: jq refuses the file, a rewrite would drop it, and the refusal
# names its line and says to remove it and re-run. A byte order mark, a value
# JSON does not have (NaN, Infinity, a number such as +1, 01 or .5) and an
# event or group out of that shape are refused the same way, each named
# (WU-IAENG-441). Every write, new file and --force included, goes to a
# temporary file beside settings.json that is then renamed over it; a
# symbolic link at that path, or anything there that is not a regular file,
# is refused on every path. A project that does not want one of the
# framework's hooks does not delete its entry — a re-run adds it back — but
# uses the hook's own switch where it has one (hooks/README.md).
#
# THE STATUS LINE IS INSTALLED BY DEFAULT AND NEVER HIDES ANOTHER (WU-IAENG-379,
# Director decision of 23 Oct 2026). The template's "statusLine" runs
# hooks/context-statusline.sh, which records the context % for the context
# alert. A statusLine in the project's settings.json wins over the user's
# own (settings precedence), so the script runs the user's ~/.claude one
# itself. When the project's settings.json already has a statusLine of its
# own, it is not replaced: its command is wrapped, the framework's command
# followed by --chain and the project's command single-quoted, every other
# field of it (padding, refreshInterval) kept; the exec form ("args") is
# folded into that command. A statusLine already running the framework's
# script, chained or not, is present and left alone; one running it from an
# earlier path (the framework moved) has that path updated in place, its
# --chain kept, as WU-IAENG-373 does for an earlier matcher; any other
# command naming the script is kept and reported. One that runs under
# "shell": "powershell", or is not a command, is kept as it is and reported:
# the context % is then not recorded. A statusLine in settings.local.json,
# which wins over the project's, is reported and never changed.
#
# The project's .gitattributes gets the line "/.claude/settings.json text
# eol=lf" when it does not have it yet (issue #242), so a clone with
# core.autocrlf=true checks the file out as it was written; nothing else in
# .gitattributes is touched.
#
# Usage, from the project root:
#   ./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh [--print] [--force]
#   ./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh --check [--quiet]
#
#   --print  print the file this script would write for a new project, and
#            change nothing
#   --force  replace an existing settings.json with that file instead of
#            merging (review its other settings first)
#   --check  report what a run would find, and write nothing (below)
#   --quiet  with --check: print nothing when there is nothing to act on
#
# --check (WU-IAENG-357): THE SAME DECISIONS, REPORTED INSTEAD OF APPLIED, in
# the record format of Adapters/scripts/install.sh --check:
#
#   <family> TAB <status> TAB <path> TAB <detail>
#
#   settings       current | absent | customized | disabled | fault
#                  (current: the template rendered for this project, line
#                  endings aside; customized: the project's own settings
#                  beside the framework's entries; disabled: that file sets
#                  "disableAllHooks": true)
#   hook           present | absent | near-miss | unchecked   (detail: the
#                  template entry, or the near-miss command; from the same jq
#                  computation a merge uses, so "present" has one definition)
#   statusline     present | absent | near-miss | shadowed   (present: the
#                  framework's, chaining the project's own or not; absent: a
#                  run installs or wraps it; near-miss: the project's own
#                  kept unwrapped; shadowed: settings.local.json sets one)
#   gitattributes  present | missing          (detail: the LF rule)
#   framework      fault                      (the framework copy is unusable)
#
# Actionable: absent, missing, disabled, fault. A near miss is information:
# the framework's entry is beside it after any run, as the write path says.
# A closing `#` line counts each family and gives the remedies. Exit codes:
# 0 nothing to act on, 3 drift, 1 a fault (something could not be evaluated:
# no jq for an existing file, a symbolic link to no file or to one that is not
# current, a path that is not a regular file, a file that is not one strict
# JSON object in that shape), 2 usage
# (--check with --print or --force; --quiet without
# --check). settings.json is parsed with jq and never evaluated; a run
# under --check writes no file and runs no git command.
#
# The hooks are project-scoped (.claude/settings.json is committed), so every
# session on every clone runs them — unlike git hooks, Claude Code reads its
# hook configuration from the repository. That is also why this file must be
# reviewed like code: it decides what the model is allowed to do.

set -uo pipefail
export LC_ALL=C

PRINT=0
FORCE=0
CHECK=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --print) PRINT=1 ;;
    --force) FORCE=1 ;;
    --check) CHECK=1 ;;
    --quiet) QUIET=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install-hooks.sh: unknown option '$arg'" >&2; exit 2 ;;
  esac
done
if [ "$CHECK" -eq 1 ] && { [ "$PRINT" -eq 1 ] || [ "$FORCE" -eq 1 ]; }; then
  echo "install-hooks.sh: --check reports and writes nothing; it cannot be combined with --print or --force." >&2
  exit 2
fi
if [ "$QUIET" -eq 1 ] && [ "$CHECK" -eq 0 ]; then
  echo "install-hooks.sh: --quiet only applies to --check." >&2
  exit 2
fi

# Under --check: no git command takes an optional lock. None runs today; the
# variable is set before any could (git's spelling of --no-optional-locks).
[ "$CHECK" -eq 1 ] && export GIT_OPTIONAL_LOCKS=0

# --check keeps the real stdout on fd 3 for the records and sends every
# human-readable line to /dev/null, as install.sh --check does.
REPORT=""
[ "$CHECK" -eq 1 ] && exec 3>&1 >/dev/null

# record <family> <status> <path> <detail> — one line: flat() flattens
# fields 2 to 4 (the detail can be a command read from the project's
# settings), so a field cannot split the record into forged ones
# (SEC-IAENG-355-02) nor carry a terminal escape. Field 1 is a literal.
# >>> record sanitiser — byte-identical in install.sh, install-hooks.sh,
# install-skills.sh and check-framework-drift.sh: none of them sources
# another, and Adapters/scripts/tests/run.sh compares the four (WU-IAENG-366).
# flat <text> — every control character (TAB, LF, CR, ESC, ...) becomes a
# space: a record is one line and carries no terminal escape.
# The C1 controls (U+0080-U+009F, CSI among them) are UTF-8 pairs \xc2\x80 to
# \xc2\x9f: a pair becomes one space. A lone byte in that range is part of
# another character and is left alone (SEC-IAENG-358-01). For these the
# result is the same under the C locale and a UTF-8 one; a UTF-8 locale also
# flattens a few other code points, U+2028 and U+2029 among them.
C1_LEAD=$'\xc2'
flat() {
  FLAT="${1//[[:cntrl:]]/ }"
  FLAT="${FLAT//"$C1_LEAD"[$'\x80'-$'\x9f']/ }"
}
# <<< record sanitiser
record() {
  local f2 f3 f4
  flat "$2"; f2="$FLAT"; flat "$3"; f3="$FLAT"; flat "$4"; f4="$FLAT"
  REPORT="$REPORT$1"$'\t'"$f2"$'\t'"$f3"$'\t'"$f4"$'\n'
}
check_fault() { record "$1" fault "$2" "$3"; echo "install-hooks.sh: $3" >&2; }

# check_report — prints the records (under --quiet the actionable ones) and
# the closing line on fd 3, then exits 1 (a fault), 3 (drift) or 0.
check_report() {
  local actionable="" faults=0 _fam _st _rest _me
  while IFS=$'\t' read -r _fam _st _rest; do
    case "$_st" in
      fault) faults=$((faults + 1)); actionable="$actionable$_fam"$'\t'"$_st"$'\t'"$_rest"$'\n' ;;
      absent|missing|disabled) actionable="$actionable$_fam"$'\t'"$_st"$'\t'"$_rest"$'\n' ;;
    esac
  done <<< "$REPORT"
  [ "$QUIET" -eq 1 ] && [ -z "$actionable" ] && exit 0
  flat "$0"; _me="$FLAT"
  {
    if [ "$QUIET" -eq 1 ]; then printf '%s' "$actionable"; else printf '%s' "$REPORT"; fi
    # The script's path reaches awk through the environment, not -v, which
    # would decode its backslashes.
    IAENG_ME="$_me" awk -F '\t' '
      NF == 0 { next }
      { n[$1]++; s[$1 FS $2]++; if ($2 ~ /^(absent|missing|disabled|fault)$/) act++; if ($2 == "fault") f++ }
      function part(fam, label, statuses,   k, i, out, sep, st) {
        out = n[fam] + 0 " " label
        k = split(statuses, st, " ")
        sep = ": "
        for (i = 1; i <= k; i++) if (s[fam FS st[i]]) { out = out sep s[fam FS st[i]] " " st[i]; sep = ", " }
        return out
      }
      END {
        line = "# install-hooks.sh --check: " (act + 0) " to act on. " part("settings", "settings item(s)", "current absent customized disabled fault")
        line = line "; " part("hook", "hook entries", "present absent near-miss unchecked fault")
        line = line "; " part("statusline", "statusLine(s)", "present absent near-miss shadowed")
        line = line "; " part("gitattributes", ".gitattributes rule(s)", "present missing")
        line = line "; " (f + 0) " fault(s)."
        if (s["settings" FS "absent"] || s["hook" FS "absent"] || s["statusline" FS "absent"] || s["gitattributes" FS "missing"])
          line = line " absent/missing: re-run " ENVIRON["IAENG_ME"] " without --force; it adds them and keeps every entry already there, except an earlier framework entry, which it updates in place (its matcher, or the fields the framework added since)."
        if (s["hook" FS "near-miss"])
          line = line " near-miss: check each is not a weakened copy; the framework entry runs beside it."
        if (s["statusline" FS "near-miss"] || s["statusline" FS "shadowed"])
          line = line " statusLine near-miss/shadowed: another status line runs and the context % is not recorded (hooks/README.md, Context Status Line)."
        if (s["settings" FS "disabled"])
          line = line " disabled: \"disableAllHooks\": true switches off every hook, the guards included; remove it there for them to run."
        if (f) line = line " fault: read the fault record(s); nothing is current until they are fixed."
        print line
      }' <<< "$REPORT"
  } >&3
  [ "$faults" -gt 0 ] && exit 1
  [ -n "$actionable" ] && exit 3
  exit 0
}

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PROJECT="$(pwd)"
EXAMPLE="$HERE/settings.example.json"
if [ ! -f "$EXAMPLE" ]; then
  [ "$CHECK" -eq 1 ] && { check_fault framework "$EXAMPLE" "$EXAMPLE is missing"; check_report; }
  echo "install-hooks.sh: $EXAMPLE is missing" >&2; exit 1
fi

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
  [ "$CHECK" -eq 1 ] && { check_fault framework "$FW_ABS" "the framework ($FW_ABS) is not inside the project ($PROJECT); run from the project root"; check_report; }
  echo "install-hooks.sh: the framework ($FW_ABS) is not inside the project ($PROJECT); run from the project root" >&2
  exit 1
fi

# The hook scripts must be executable for the Bash invocation to be moot and
# for a direct invocation to work; check, do not assume.
for h in "$HERE"/hooks/*.sh; do
  [ -x "$h" ] && continue
  if [ "$CHECK" -eq 1 ]; then
    check_fault framework "$h" "$h is not executable — run: chmod +x $HERE/hooks/*.sh"
  else
    echo "install-hooks.sh: $h is not executable — run: chmod +x $HERE/hooks/*.sh" >&2; exit 1
  fi
done

RENDERED="$(sed "s#__IAENG_ROOT__#$ROOT#g" "$EXAMPLE")"

# THE FRAMEWORK'S EARLIER MATCHERS (WU-IAENG-373), per event: "from" is a
# matcher a previous settings.example.json carried, "to" the template's
# current one for the same entries. A project group under that event whose
# matcher is exactly "from", which holds exactly the template group's entries
# (the project directory's spelling aside) and has no other key, is the
# framework's own entry from that version: merge_settings changes its matcher
# to "to" and nothing else. Without this, the current group would be appended
# beside it and both would fire on every event they share — the hooks
# reference says a handler defined in several settings FILES runs once, and
# nothing of two groups in one file. Any other group is the project's and is
# never rewritten. Add a line here whenever a template matcher changes, and
# set every existing line's "to" to the new matcher too: a line whose "to" is
# no longer a template matcher is skipped, and its adopters get the near miss.
# A line with "without" names fields the framework ADDED to the template
# group's entries (WU-IAENG-410): its earlier entries are the template's
# without them, and an exact earlier group gets them in place, its own
# command spelling kept. Same rule: exactly the earlier entries and nothing
# else, or it is the project's.
#   SessionStart: "clear" added, so /clear starts with the read-first context.
#   SessionStart: its timeout (WU-IAENG-452), the ceiling above the hook's
#     budget (hooks/README.md, Session Start Budget). An earlier entry is the
#     template's without it, under either matcher: the second line updates the
#     oldest (its matcher and the field), the third one already holding
#     "clear" (the field alone). The first line's entry, the earlier matcher
#     holding the template's entries as they are now, is kept too.
#   PreToolUse: the guards' timeout and onFailure, so a guard that times out,
#     cannot start or exits other than 0 or 2 blocks the call it guards.
SUPERSEDED='{"SessionStart":[{"from":"startup|resume|compact","to":"startup|resume|clear|compact"},
                  {"from":"startup|resume|compact","to":"startup|resume|clear|compact","without":["timeout"]},
                  {"from":"startup|resume|clear|compact","to":"startup|resume|clear|compact","without":["timeout"]}],
  "PreToolUse":[{"from":"Bash","to":"Bash","without":["timeout","onFailure"]},
                {"from":"Edit|Write|MultiEdit","to":"Edit|Write|MultiEdit","without":["timeout","onFailure"]}]}'

if [ "$PRINT" -eq 1 ]; then
  printf '%s\n' "$RENDERED"
  exit 0
fi

HOOK_LIST="SessionStart read-first, PreToolUse escape-hatch and inline-suppression blocks, PostToolUse lint, Stop gate, Stop usage-dashboard refresh (never blocks; opt-out in hooks/README.md), context alert on UserPromptSubmit and PostToolBatch (never blocks; hooks/README.md, Context Alert); statusLine recording the context % and running your own status line (hooks/README.md, Context Status Line)."

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
#
# Only a CR that ends a line is dropped before the match, never one inside a
# line (SEC-IAENG-353-01); read into the shell and matched there as a whole
# line, so no pipe can fail the match with SIGPIPE and no grep that drops a
# CR on its own (Git for Windows') decides it. One predicate, for the write
# path and for --check.
LF_RULE="/.claude/settings.json text eol=lf"
lf_rule_present() {
  local content
  [ -f "$PROJECT/.gitattributes" ] || return 1
  content="$(sed $'s/\r$//' "$PROJECT/.gitattributes")"
  [[ $'\n'"$content"$'\n' == *$'\n'"$LF_RULE"$'\n'* ]]
}
ensure_lf_rule() {
  local rule="$LF_RULE" attr="$PROJECT/.gitattributes" sep=""
  if lf_rule_present; then
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
  local rc=0 sl
  ensure_lf_rule || rc=1
  warn_if_hooks_disabled
  sl="$(statusline_shadowed)"
  if [ -n "$sl" ]; then
    flat "$sl"; sl="$FLAT"
    echo "! .claude/settings.local.json sets its own statusLine ($sl): Claude Code runs it instead of the" >&2
    echo "  project's, so the context % is not recorded for you. This installer does not change it." >&2
  fi
  return "$rc"
}

# THE DECISIONS, ONE DEFINITION EACH. The write path below and --check call
# the same three functions, so --check reports what a run would decide.
#
# settings_current: the file is the template rendered for this project. A CR
# that ends a line is not a difference (a core.autocrlf checkout of the same
# file); a CR inside a line is one (SEC-IAENG-353-01).
settings_current() { [ "$(sed $'s/\r$//' "$DEST")" = "$RENDERED" ]; }
# settings_mergeable: one JSON object whose 'hooks' is an object, absent or
# null, or nothing is touched. A project's own settings.json often has no
# 'hooks' at all: permissions only, a $schema only, or {} (DEF-465-01). The
# type is tested, not defaulted with //, which would let "hooks": false
# through to a merge that cannot index it.
#
# STRICT JSON, IN THE SHAPE CLAUDE CODE'S SETTINGS SCHEMA REQUIRES
# (WU-IAENG-441). jq 1.8.1 reads more than RFC 8259 allows: a byte order mark
# before the text, and number spellings JSON has no place for (NaN, Infinity,
# a leading + or 0, .5). Those are refused before jq is asked anything, by
# settings_bad_token below, and settings_refusal names a BOM as such. Then
# 'hooks' must hold, under each event, a list (JSON array) of matcher groups,
# or null, which a merge replaces with the list; and each group must be an
# object whose own 'hooks' is a list. That is the shape Claude Code's settings
# schema gives the key, and the presence test of merge_settings reads only
# that shape.
BOM=$'\xef\xbb\xbf'
# shape_fault, a jq definition: on the 'hooks' value, one phrase per event or
# group out of that shape, each with its remedy; nothing when it is in shape.
# The event's name is printed as JSON (tojson), so a control character in it
# is an escape, never the character. No jq variable is used: the definition
# is a shell string, and a $name in single quotes reads as a shell mistake.
SHAPE_DEFS='def shape_fault:
  if type != "object" then empty
  else to_entries[]
    | if (.value | type) == "null" then empty
      elif (.value | type) != "array" then
        "\"hooks\" > \(.key | tojson) is a JSON \(.value | type), not a list (JSON array) of matcher groups, which the Claude Code settings schema requires: make it a list and re-run"
      else
        {ev: .key, g: (.value | to_entries[])}
        | select((.g.value | type) != "object" or (.g.value.hooks | type) != "array")
        | "group \(.g.key + 1) of \"hooks\" > \(.ev | tojson) is not an object whose \"hooks\" is a list (JSON array), which the Claude Code settings schema requires: correct it and re-run"
      end
  end;'
# settings_bad_token — "<line>:<token>" for the first token outside a string
# that is not JSON: not a structural character, true, false, null or a number
# in RFC 8259's grammar. Strings are removed line by line first, as the
# comment test below does; jq refuses a raw line feed inside a string, so a
# string never spans two lines of a file jq reads. Tokens are separated by
# JSON's whitespace (RFC 8259, section 2): space, tab, line feed and carriage
# return, a CR anywhere, inside a line or as the only line ending, as much as
# at a line's end (DEF-IAENG-480-01). A byte order mark is a token that is
# not JSON: its three bytes stand outside every string. Prints nothing when
# every token is JSON.
settings_bad_token() {
  sed -E 's/"([^"\\]|\\.)*"/""/g' "$DEST" | awk '
    { line = $0; gsub(/[][{}:,]/, " ", line)
      n = split(line, tok, /[ \t\r]+/)
      for (i = 1; i <= n; i++) {
        t = tok[i]
        if (t == "" || t == "\"\"" || t == "true" || t == "false" || t == "null") continue
        if (t ~ /^-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][-+]?[0-9]+)?$/) continue
        print NR ":" substr(t, 1, 40); exit
      } }'
}
# visible <text> — sets VIS: <text> with every byte outside printable ASCII
# written as an escape, a CR as \r, a tab as \t, any other as \xHH. A refusal
# that quotes the file (a token, an event's name) then shows each character
# it names, never one that is invisible or that the terminal would act on
# (DEF-IAENG-480-01). flat, which makes such a character a space, keeps a
# record on one line; this keeps the culprit findable.
visible() {
  local h c out=""
  for h in $(printf '%s' "$1" | od -An -v -tx1); do
    case "$h" in
      0d) out+='\r' ;;
      09) out+='\t' ;;
      2[0-9a-f]|[3-6][0-9a-f]|7[0-9a-e]) printf -v c '%b' "\\x$h"; out+="$c" ;;
      *) out+="\\x$h" ;;
    esac
  done
  VIS="$out"
}
settings_mergeable() {
  [ -z "$(settings_bad_token)" ] || return 1
  jq -es "$SHAPE_DEFS"' length == 1 and (.[0] | type == "object") and (.[0].hooks | type == "object" or type == "null")
    and ([.[0].hooks | shape_fault] | length == 0)' "$DEST" >/dev/null 2>&1
}
# settings_refusal — why settings_mergeable refused the file, as one phrase
# that carries its remedy; the write path's "Not changed" line and --check's
# fault record print the same phrase. jq reads strict JSON (RFC 8259), which
# has no comments: a // or /* left once every string is removed is named with
# its line, so a URL in a string ("$schema") is never taken for one. That
# test runs only after jq has refused the file. A byte order mark is named
# first, a token that is not JSON after jq's own refusal, then the first
# event or group out of shape.
settings_refusal() {
  local line why tok shape
  if [ "$(head -c 3 "$DEST")" = "$BOM" ]; then
    printf '%s' "it begins with a byte order mark (BOM), which a JSON settings file must not begin with: save it as UTF-8 without a BOM and re-run"
    return 0
  fi
  if ! why="$(jq empty "$DEST" 2>&1)"; then
    line="$(sed -E 's/"([^"\\]|\\.)*"//g' "$DEST" | grep -n -m 1 -E '//|/[*]')"
    if [ -n "$line" ]; then
      printf '%s' "line ${line%%:*} holds a comment (// or /* */), which JSON does not allow and jq cannot read: remove it (a note can go in a \"\$comment\" key) and re-run"
    else
      flat "$(printf '%s\n' "$why" | head -n 1 | sed $'s/\r$//')"
      printf '%s' "jq cannot read it as JSON ($FLAT): correct it and re-run"
    fi
    return 0
  fi
  tok="$(settings_bad_token)"
  if [ -n "$tok" ]; then
    visible "${tok#*:}"
    printf '%s' "line ${tok%%:*} holds $VIS, which is not a JSON value: write a JSON number, true, false or null there and re-run"
    return 0
  fi
  shape="$(jq -rs "$SHAPE_DEFS"' if length == 1 and (.[0] | type == "object") then first(.[0].hooks | shape_fault) else empty end' "$DEST" 2>/dev/null | sed $'s/\r$//')"
  if [ -n "$shape" ]; then
    visible "$shape"
    printf '%s' "$VIS"
    return 0
  fi
  printf '%s' "it is not one JSON object whose 'hooks' is an object, absent or null"
}
# merge_settings: the settings on stdin, merged with the template; prints
# {m: merged settings, a: added, p: present, w: near misses}. sed: jq on
# Windows writes CRLF; its JSON escapes a CR inside a string, so the only raw
# CR is the one that ends a line, and only that one is removed (Check
# Convention, Shell Scripts, rule 3).
#
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
#
# THE FRAMEWORK'S OWN EARLIER ENTRY IS UPDATED, NOT DOUBLED (WU-IAENG-373).
# Before anything else, a group that is exactly the framework's entry under
# a SUPERSEDED "from" matcher (its entries without the line's "without"
# fields, when it has some) has its matcher set to "to" and those fields
# added from the template, unless the current
# entry is already held under "to" (then nothing is rewritten and the earlier
# group stays a near miss). The rest runs on the updated file, so the updated
# group is neither added again nor a near miss; it is reported in u, and not
# in p, which lists only what the file held before the run.
#
# THE FILE MAY HAVE NO "hooks" (DEF-465-01): settings_mergeable lets it be
# absent or null. Every read of it below indexes it by event (null[k] is null
# in jq) or defaults it to {}, so such a file gets every template entry. The
# near-miss scan once ran to_entries on null, which failed every merge into
# such a file, --check included (jq: "null (null) has no keys").
merge_settings() {
  jq --argjson tpl "$RENDERED" --argjson sup "$SUPERSEDED" --arg q "'" --arg qesc "'\"'\"'" '
    def norm: gsub("[$][{]CLAUDE_PROJECT_DIR[}]"; "$CLAUDE_PROJECT_DIR") | gsub("/[.]/"; "/");
    def nentry: if type == "object" and (.command | type) == "string" then .command |= norm else . end;
    def nentries: [.hooks[]? | nentry];
    def scripts: [.hooks[]?.command // "" | strings | scan("hooks/([A-Za-z0-9._-]+[.]sh)") | .[0]];
    def where($ev): $ev + (if (.matcher // "") != "" then " [" + .matcher + "]" else "" end);
    def differ($a; $b): [[$a, $b][] | keys[]] | unique | map(select(. as $k | $a[$k] != $b[$k]));
    def iscmd: type == "object" and .type == "command" and (.command | type) == "string";
    def shq: $q + gsub($q; $qesc) + $q;
    def holds($want): nentries as $have | all($want[]; . as $w | any($have[]; . == $w));
    def earlier($from; $want): type == "object" and (keys == ["hooks", "matcher"])
      and .matcher == $from and (.hooks | type) == "array" and nentries == $want;
    . as $orig
    | (reduce ($sup | to_entries[]) as $s ({c: $orig, u: []};
        reduce $s.value[] as $r (.;
          ([$tpl.hooks[$s.key][]? | select((.matcher // null) == $r.to)] | first) as $tg
          | if $tg == null or ((.c.hooks[$s.key] // null) | type) != "array" then .
            else ($tg | nentries) as $want
            | ($r.without // []) as $wo
            | ($want | map(delpaths([$wo[] | [.]]))) as $was
            | if (any(.c.hooks[$s.key][]; earlier($r.from; $was)) | not)
                 or any(.c.hooks[$s.key][]; type == "object" and (.matcher // null) == $r.to and holds($want))
              then .
              else .c.hooks[$s.key] |= map(if earlier($r.from; $was)
                  then .matcher = $r.to
                    | .hooks = [.hooks as $h | range(0; $h | length) as $i
                                | $h[$i] + ($tg.hooks[$i] | with_entries(select(.key as $k | any($wo[]; . == $k))))]
                  else . end)
                | .u += [{l: ($tg | where($s.key) + ": " + (scripts | join(", "))), from: $r.from, to: $r.to, without: $wo}]
              end
            end))) as $up
    | $up.c as $cur
    | ([$tpl.hooks[][] | scripts[]] | unique) as $names
    | reduce ($tpl.hooks | to_entries[]) as $e ({m: $cur, a: [], p: [], u: $up.u};
        reduce $e.value[] as $g (.;
          ($g | nentries) as $want
          | ($g | where($e.key) + ": " + (scripts | join(", "))) as $label
          | if any($cur.hooks[$e.key][]?; (.matcher // null) == ($g.matcher // null) and holds($want))
            then (if any($orig.hooks[$e.key][]?; (.matcher // null) == ($g.matcher // null) and holds($want))
                  then .p += [$label] else . end)
            else .m.hooks[$e.key] = ((.m.hooks[$e.key] // []) + [$g]) | .a += [$label]
            end))
    | .w = [ ($cur.hooks // {}) | to_entries[] | .key as $ev | .value[]? | . as $grp
             | .hooks[]? | . as $h | .command // "" | strings | . as $c
             | select(any($names[]; . as $n | $c | contains("hooks/" + $n)))
             | ($h | nentry) as $hn
             | [$tpl.hooks[$ev][]? | select((.matcher // null) == ($grp.matcher // null)) | nentries[]] as $tents
             | select(any($tents[]; . == $hn) | not)
             | ([$tents[] | select(.command == $hn.command)] | first) as $same
             | ($grp | where($ev)) + ": " + $c
               + (if $same == null then ""
                  else "  (the framework command; differs in: " + (differ($same; $hn) | join(", ")) + ")"
                  end) ]
    | ($tpl.statusLine // null) as $tsl
    | ($cur.statusLine // null) as $csl
    | ($tsl.command // "" | norm) as $ours
    | if $tsl == null then .sl = null
      elif $csl == null then
        .m.statusLine = $tsl | .sl = {st: "absent", d: "context-statusline.sh"}
      elif ($csl | iscmd) and ($csl.command | norm) == $ours then
        .sl = {st: "present", d: "context-statusline.sh"}
      elif ($csl | iscmd) and ($csl.command | norm | startswith($ours + " --chain ")) then
        .sl = {st: "present", d: ("context-statusline.sh, chaining the project statusLine "
                                  + ($csl.command | norm | ltrimstr($ours + " --chain ")))}
      elif ($csl | iscmd)
           and ($csl.command | test("^bash \"[^\"]*/hooks/context-statusline[.]sh\"( --chain .*)?$"; "s")) then
        ($csl.command | capture("^bash \"[^\"]*/hooks/context-statusline[.]sh\"(?<rest>( --chain .*)?)$"; "s").rest) as $rest
        | .m.statusLine = ($csl + {command: ($tsl.command + $rest)})
        | .sl = {st: "absent", d: ("context-statusline.sh, updated in place from an earlier path: " + $csl.command)}
      elif ($csl | iscmd) and ($csl.command | contains("context-statusline.sh")) then
        .sl = {st: "near-miss", d: ("the project statusLine names context-statusline.sh in a form of its own and is kept as it is: "
               + $csl.command)}
      elif ($csl | iscmd) and (($csl.shell // "bash") == "bash")
           and ($csl.args == null or ($csl.args | type) == "array") then
        (if ($csl.args | type) == "array" then [$csl.command] + ($csl.args | map(tostring)) | @sh
         else $csl.command end) as $own
        | .m.statusLine = (($csl | del(.args)) + {command: ($tsl.command + " --chain " + ($own | shq))})
        | .sl = {st: "absent", d: ("context-statusline.sh, chaining the project statusLine " + $own)}
      else
        .sl = {st: "near-miss", d: ("the project statusLine is kept as it is ("
               + (if ($csl | iscmd) then "it runs under " + ($csl.shell | tostring) else "not a command statusLine" end)
               + "): the context % is not recorded")}
      end' 2>/dev/null | sed $'s/\r$//'
}

# statusline_shadowed — prints the command of a statusLine that
# .claude/settings.local.json sets, other than the framework's: Claude Code
# runs that one instead of the project's (settings precedence), so the
# context % is not recorded for that developer. Never changed here. Only the
# CR jq writes at the end of its line on Windows is removed: a CR inside the
# command is part of it, so "context-statu<CR>sline.sh" is not the
# framework's script, and it is reported.
statusline_shadowed() {
  local f="$PROJECT/.claude/settings.local.json" c
  [ -f "$f" ] && command -v jq >/dev/null 2>&1 || return 1
  c="$(jq -r 'if type == "object" and .statusLine != null
              then (.statusLine.command // "(no command)" | tostring) else empty end' "$f" 2>/dev/null | sed $'s/\r$//')"
  [ -n "$c" ] || return 1
  case "$c" in *context-statusline.sh*) return 1 ;; esac
  printf '%s\n' "$c"
}

# --check: the decisions above, recorded; nothing below it runs.
if [ "$CHECK" -eq 1 ]; then
  REL_DEST=".claude/settings.json"
  MERGED=""
  if [ -L "$DEST" ] && [ ! -f "$DEST" ]; then
    check_fault settings "$REL_DEST" "it is a symbolic link; a run refuses to write through it"
  elif [ -e "$DEST" ] && [ ! -f "$DEST" ]; then
    check_fault settings "$REL_DEST" "it exists and is not a regular file; a run refuses to replace it"
  elif [ ! -f "$DEST" ]; then
    record settings absent "$REL_DEST" "a run writes it from settings.example.json"
  elif settings_current; then
    record settings current "$REL_DEST" "the template, rendered for framework root $ROOT"
    if ! command -v jq >/dev/null 2>&1; then
      record hook unchecked "$REL_DEST" "jq is not installed: the entries are not listed"
    elif ! MERGED="$(merge_settings < "$DEST")"; then
      MERGED=""; check_fault hook "$REL_DEST" "the merge computation failed"
    fi
  elif [ -L "$DEST" ]; then
    check_fault settings "$REL_DEST" "it is a symbolic link; a run refuses to merge through it"
  elif ! command -v jq >/dev/null 2>&1; then
    check_fault settings "$REL_DEST" "jq is not installed to read it"
  elif ! settings_mergeable; then
    check_fault settings "$REL_DEST" "$(settings_refusal)"
  elif MERGED="$(merge_settings < "$DEST")"; then
    record settings customized "$REL_DEST" "the project's own settings, with the framework's entries checked one by one"
  else
    MERGED=""; check_fault settings "$REL_DEST" "the merge computation failed"
  fi
  if [ -n "$MERGED" ]; then
    while IFS=$'\t' read -r _st _d; do
      [ -n "$_st" ] && record hook "$_st" "$REL_DEST" "$_d"
    done < <(printf '%s\n' "$MERGED" \
      | jq -r 'def flat: gsub("[\t\n\r]"; " ");
               (.p[] | "present\t" + flat), (.a[] | "absent\t" + flat),
               (.u[] | "absent\t" + (.l + "  (a run updates the framework\u0027s earlier entry "
                 + ([(if .from != (.to // .from) or (.without // []) == [] then "under [" + .from + "]" else empty end),
                     (if (.without // []) != [] then "without " + (.without | join(", ")) else empty end)] | join(" "))
                 + " in place)" | flat)),
               (.w[] | "near-miss\t" + flat)' 2>/dev/null \
      | sed $'s/\r$//')
    while IFS=$'\t' read -r _st _d; do
      [ -n "$_st" ] && record statusline "$_st" "$REL_DEST" "$_d"
    done < <(printf '%s\n' "$MERGED" \
      | jq -r '.sl | select(. != null) | .st + "\t" + (.d | gsub("[\t\n\r]"; " "))' 2>/dev/null \
      | sed $'s/\r$//')
  fi
  while IFS= read -r _c; do
    [ -n "$_c" ] && record statusline shadowed .claude/settings.local.json \
      "$_c: Claude Code runs this one instead of the project statusLine, so the context % is not recorded for this developer"
  done <<< "$(statusline_shadowed)"
  while IFS= read -r _f; do
    [ -n "$_f" ] && record settings disabled "$_f" '"disableAllHooks": true'
  done <<< "$(hooks_disabled_in)"
  if lf_rule_present; then
    record gitattributes present .gitattributes "$LF_RULE"
  else
    record gitattributes missing .gitattributes "$LF_RULE"
  fi
  check_report
fi

# tmp_beside <kind> — sets TMP to a new, empty file beside settings.json,
# settings.json.iaeng-<kind>.XXXXXX, made by mktemp: a name no other file has
# and none can be known in advance. It gets the mode a plain write would have
# (mktemp makes it 0600), and it is removed on every exit, a signal included,
# unless it has been renamed over settings.json by then. Returns 1, TMP empty,
# when it cannot be made. Both writes below use it (WU-IAENG-441).
TMP=""
tmp_beside() {
  TMP="$(mktemp "$DEST.iaeng-$1.XXXXXX")" || { TMP=""; return 1; }
  trap 'rm -f "$TMP"' EXIT
  trap 'exit 1' HUP INT TERM
  chmod "$(umask -S | sed 's/x//g')" "$TMP" 2>/dev/null
  return 0
}

if [ -f "$DEST" ] && [ "$FORCE" -eq 0 ]; then
  if settings_current; then
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
  settings_mergeable || merge_by_hand "$(settings_refusal)"
  MERGED="$(merge_settings < "$DEST")" || merge_by_hand "the merge failed"
  # Only the CR jq writes at the end of a line on Windows is removed (Check
  # Convention, Shell Scripts, rule 3). The added, present and updated labels
  # are built from the framework's template. A near miss carries the project's
  # own matcher and command, so a tab, line feed or carriage return inside it
  # becomes a space, as --check's records do, rather than reaching the terminal
  # where a carriage return could draw over the line it is in.
  ADDED="$(printf '%s\n' "$MERGED" | jq -r '.a[]' | sed $'s/\r$//')"
  PRESENT="$(printf '%s\n' "$MERGED" | jq -r '.p[]' | sed $'s/\r$//')"
  NEAR="$(printf '%s\n' "$MERGED" | jq -r '.w[] | gsub("[\t\n\r]"; " ")' | sed $'s/\r$//')"
  UPDATED="$(printf '%s\n' "$MERGED" | jq -r '.u[] | .l + "  ("
    + ([(if .from != (.to // .from) or (.without // []) == [] then "matcher was [" + .from + "]" else empty end),
        (if (.without // []) != [] then "added: " + (.without | join(", ")) else empty end)] | join("; ")) + ")"' | sed $'s/\r$//')"
  # The statusLine is listed with the hook entries: added (installed, or
  # wrapped around the project's own) or present; a near miss is on stderr.
  # Its text holds a command read from the project's settings, so it is
  # flattened as --check's records are: no control character reaches the
  # terminal (SEC-IAENG-379-01).
  SL_ST="$(printf '%s\n' "$MERGED" | jq -r '.sl.st? // empty' | sed $'s/\r$//')"
  flat "$(printf '%s\n' "$MERGED" | jq -r '.sl.d? // empty' | sed $'s/\r$//')"; SL_D="$FLAT"
  case "$SL_ST" in
    absent) ADDED="${ADDED:+$ADDED$'\n'}statusLine: $SL_D" ;;
    present) PRESENT="${PRESENT:+$PRESENT$'\n'}statusLine: $SL_D" ;;
    near-miss) echo "! $DEST: statusLine: $SL_D (hooks/README.md, Context Status Line)." >&2 ;;
  esac
  if [ -n "$NEAR" ]; then
    {
      echo "! $DEST: these commands name a framework hook script but are not the framework's entry"
      echo "  (another matcher, another command, or another field such as its timeout). Check"
      echo "  each is not a weakened copy; the framework's own entry is in the file beside them"
      echo "  either way:"
      printf '%s\n' "$NEAR" | sed 's/^/    /'
    } >&2
  fi
  if [ -z "$ADDED" ] && [ -z "$UPDATED" ]; then
    echo "= $DEST: every IA Engineering hook entry is present exactly; left as it is."
    printf '%s\n' "$PRESENT" | sed 's/^/    present: /'
    finish; exit $?
  fi
  tmp_beside merge || merge_by_hand "no temporary file could be created beside it"
  if ! printf '%s\n' "$MERGED" | jq '.m' | sed $'s/\r$//' > "$TMP" || ! jq -e 'type == "object"' "$TMP" >/dev/null 2>&1; then
    rm -f "$TMP"
    merge_by_hand "the merged file could not be written"
  fi
  mv -f "$TMP" "$DEST" || { rm -f "$TMP"; merge_by_hand "the merged file could not replace it"; }
  if [ -z "$UPDATED" ]; then
    echo "+ $DEST: merged (framework root: $ROOT); every entry already in it is kept."
  else
    echo "+ $DEST: merged (framework root: $ROOT); the framework's earlier entries were updated in place, and every other entry is kept as it was."
  fi
  [ -z "$ADDED" ] || printf '%s\n' "$ADDED" | sed 's/^/    added:   /'
  [ -z "$UPDATED" ] || printf '%s\n' "$UPDATED" | sed 's/^/    updated: /'
  [ -z "$PRESENT" ] || printf '%s\n' "$PRESENT" | sed 's/^/    present: /'
  finish; rc=$?
  echo "  Review the diff, commit it, and restart the Claude Code session for the hooks to load."
  exit "$rc"
fi

# A NEW FILE, OR --force: WRITTEN BESIDE IT, THEN MOVED (WU-IAENG-441). The
# file is written to a temporary file in the same directory (tmp_beside),
# read back and compared with what was meant, then renamed over the
# path, as the merge above does. A symbolic link at the path is refused on
# this path too, dangling or not: a write would follow it to what it points
# at, and a rename would detach it.
if [ -L "$DEST" ]; then
  echo "! $DEST is a symbolic link. Not changed." >&2
  echo "  Replace the link with the file itself, or remove it, and re-run." >&2
  exit 1
fi
# Anything else at the path that is not a regular file (a directory, a
# device) is refused too: the rename would move the file into a directory
# rather than replace it.
if [ -e "$DEST" ] && [ ! -f "$DEST" ]; then
  echo "! $DEST exists and is not a regular file. Not changed." >&2
  echo "  Remove or rename what is there, and re-run." >&2
  exit 1
fi
write_fail() { rm -f "$TMP"; echo "! $DEST: $1. Not changed." >&2; exit 1; }
mkdir -p "$PROJECT/.claude"
tmp_beside write || write_fail "no temporary file could be created beside it"
if ! printf '%s\n' "$RENDERED" > "$TMP" || [ "$(cat "$TMP")" != "$RENDERED" ]; then
  write_fail "the file could not be written"
fi
mv -f "$TMP" "$DEST" || write_fail "the written file could not replace it"
echo "+ $DEST (framework root: $ROOT)"
echo "  Hooks: $HOOK_LIST"
finish; rc=$?
echo "  Restart the Claude Code session for the hooks to load."
exit "$rc"
