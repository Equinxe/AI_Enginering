#!/usr/bin/env bash
# IA Engineering — Claude Code PreToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Mechanically enforces Standards/CODE_QUALITY_STANDARD.md, No Inline
# Suppression: refuses an edit that writes a linter / type-checker / test
# disable directive into code. A rule that is wrong for the project is tuned in
# the tool's configuration file, where the change is a reviewed diff; a skipped
# or focused test is a red signal turned green without changing what it
# measured.
#
# NAMED EXEMPTION: documentation files (.md, .rst, .txt, .adoc). This
# framework's own Standard quotes every pattern below in order to forbid it;
# a hook that blocked the Standard from being written would be the joke
# version of itself. Code is never exempt, and there is no environment
# override — the one admissible inline case (a tool false positive that
# configuration cannot scope) is applied by a human, with the forcing
# constraint written on the preceding line, as the Standard requires.

# This hook's own directory, never the working directory (issue #344). It is
# taken from $0 when $0 holds a / or \, because the environment cannot set $0.
# A bare $0 means bash found the hook through PATH or in the working
# directory, where dirname "$0" would name the working directory; then
# BASH_SOURCE[0], the path bash found, is used. BASH_SOURCE is not taken first
# because bash 5.3 imports it from the environment (SEC-IAENG-400-01). Both
# separators count, as Git Bash's dirname reads both. Every file this hook
# loads, and the tests/ exemption below, come from here.
HOOKS_DIR="$0"
case "$HOOKS_DIR" in */*|*\\*) ;; *) HOOKS_DIR="${BASH_SOURCE[0]}" ;; esac
case "$HOOKS_DIR" in
  */*|*\\*) HOOKS_DIR="${HOOKS_DIR%[/\\]*}" ;;
  *) HOOKS_DIR=. ;;
esac
# shellcheck source=lib.sh
. "$HOOKS_DIR/lib.sh"

# ONE jq READS EVERYTHING (WU-IAENG-444). Develop started a jq for the object
# check, one per field and one for the text: five, and on Windows a process is
# the hooks' latency under load (Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md,
# The Edit Guard Starts a Quarter of the Processes). This program makes the same
# object check, then prints F, the tool name, the file path, the cwd and the
# text, separated by \037, the unit separator (not \001, which bash uses for
# its own quoting). A field is what `jq -r '<path> // empty'` printed for it,
# the text what the text jq below printed, and the command substitution strips
# the text's trailing newlines as it stripped them before.
#
# Anything this cannot reproduce exactly sends the payload to the code below,
# which is the code before WU-IAENG-444: no jq, a payload that is not one
# object (the refusal is iaeng_require_object's), a field that is not a string
# or null, or that holds a \037 or a line break (its own command substitution
# stripped trailing line breaks), a tool_input that is not an object or null,
# and a text value that is an array or an object (`join` refuses it; a number
# or a boolean it renders as -r did). jq's error or a missing F means that
# path, never an allow.
# The program is read from a quoted here-document: no process, and a few
# hundred bytes, far from the 64 KiB here-string window (below).
IFS= read -r -d '' FAST_READ <<'JQ' || :
if length == 1 and (.[0] | type == "object") then
  .[0] as $o | $o.tool_input as $ti
  | def line: (. // "") | if test("[\u001f\n]") then error("not one line") else . end;
  "F\u001f" + ($o.tool_name | line) + "\u001f" + ($ti.file_path | line) + "\u001f" + ($o.cwd | line) + "\u001f"
  + ([$ti.new_string, $ti.content, (($ti.edits // []) | .[] | .new_string)] | map(select(. != null)) | join("\n"))
else "S" end
JQ
FAST=""
if iaeng_have_jq; then
  FAST="$(printf '%s' "$IAENG_INPUT" | jq -sj "$FAST_READ" 2>/dev/null)" || FAST=""
fi

if [ "${FAST:0:2}" = "F"$'\037' ]; then
  rest="${FAST:2}"
  TOOL="${rest%%$'\037'*}"; rest="${rest#*$'\037'}"
  FILE="${rest%%$'\037'*}"; rest="${rest#*$'\037'}"
  CWD="${rest%%$'\037'*}"; TEXT="${rest#*$'\037'}"
else
  FAST=""
  # Unreadable payload is refused BEFORE any field is read: an empty TOOL or TEXT
  # below means "nothing to check" and exits 0, which an unparseable payload would
  # otherwise be mistaken for.
  iaeng_require_object
  TOOL="$(iaeng_field '.tool_name')"
fi
case "$TOOL" in ""|Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

[ -n "$FAST" ] || FILE="$(iaeng_field '.tool_input.file_path')"

# NAMED EXEMPTIONS — three, all by path, none a fall-through.
#
# 1. Documentation. Standards/CODE_QUALITY_STANDARD.md quotes every directive
#    below in order to forbid it; a hook that stopped the Standard from being
#    written would be the joke version of itself.
# 2. This hook's own test corpus, the tests/ directory next to this hook. A
#    test that proves a directive is refused has to contain that directive.
#    Found by this hook refusing the very file that tests it: the same shape
#    as (1), one level down. Scoped to that one directory rather than to any
#    hooks/tests/ directory or any path containing the word test, because a
#    directory whose whole contents become exempt is how the synthetic-fixture
#    marker was defeated before it was anchored
#    (Standards/DATA_PROTECTION_STANDARD.md, Synthetic Fixtures).
#
# Code is never exempt, and there is no environment override. Note that this
# file is not exempt from itself: its own comments name the directives
# obliquely for that reason, and the rule they implement is stated in full in
# the Standard.
#
# `shopt -s nocasematch` rather than ${FILE,,}: the lowercasing expansion is
# bash 4.0+, and macOS still ships bash 3.2 as /bin/bash. There it is not a
# runtime error but a PARSE error, so bash exits 2 before running a line, and
# Claude Code reads exit 2 from a PreToolUse hook as *block*. Every Edit and
# Write would have been refused, with no reason text, on every macOS machine.
# It was the only bash-4 construct in any hook. (`mapfile` in
# Adapters/github-actions/pr-validation.yml is also bash 4, and stays: that
# one runs on ubuntu-latest, where the version is known.)
shopt -s nocasematch
case "$FILE" in
  *.md|*.rst|*.txt|*.adoc) exit 0 ;;
esac
shopt -u nocasematch

# The two path exemptions compare CANONICAL paths, not suffixes. A suffix match
# exempted any file that merely ended in the same words (evil/Adapters/scripts/
# <the pattern file's name>, src/hooks/tests/anything), and the pattern-file
# match was case-insensitive as well. The edit's path is made absolute (a
# relative one against the payload's cwd), `.` and `..` are resolved, and it is
# compared with the framework's OWN files, which this hook locates from its own
# directory — so the same rule holds in this repository and under an adopter's
# ia-engineering/. Symlinks are not resolved: a link inside tests/ that points
# elsewhere is still exempt, which is the same reach the write already has.
#
# 2. (continued) the hooks/tests/ directory next to this hook.
# 3. The pattern file (Adapters/scripts/suppression-patterns.tsv): it quotes
#    every directive in order to forbid it, and exempting it also lets a deleted
#    copy be restored through Write.
#
# iaeng_canon_to <var> <path> [<base>] sets <var> to the canonical path: each
# path converted by cygpath where there is one (its own path when cygpath
# fails), backslashes read as separators where there is not, then the walk.
iaeng_canon_to() {
  local p="$2" base="${3:-}"
  if command -v cygpath >/dev/null 2>&1; then
    p="$(cygpath -u -- "$p" 2>/dev/null)" || p="$2"
    [ -z "$base" ] || base="$(cygpath -u -- "$base" 2>/dev/null)" || base="${3:-}"
  else
    p="${p//\\//}"
    base="${base//\\//}"
  fi
  canon_walk "$1" "$p" "$base"
}

# canon_walk <var> <path> <base> — <path> made absolute against <base> (the
# working directory when empty), with `.`, `..` and empty segments resolved.
# No process. Locals are named _cw_* so that no caller's <var> is shadowed.
canon_walk() {
  local _cw_p="$2" _cw_seg _cw_n _cw_r=""
  local _cw_out=()
  case "$_cw_p" in /*) ;; *) _cw_p="${3:-$PWD}/$_cw_p" ;; esac
  set -f
  local IFS=/
  for _cw_seg in $_cw_p; do
    case "$_cw_seg" in
      ''|.) ;;
      ..) _cw_n=${#_cw_out[@]}; if [ "$_cw_n" -gt 0 ]; then unset "_cw_out[$((_cw_n - 1))]"; fi ;;
      *) _cw_out+=("$_cw_seg") ;;
    esac
  done
  set +f
  for _cw_seg in ${_cw_out[@]+"${_cw_out[@]}"}; do _cw_r="$_cw_r/$_cw_seg"; done
  printf -v "$1" '%s' "${_cw_r:-/}"
}

# canon_three — CANON, PAT_CANON and HOOKS_CANON with ONE cygpath for every
# conversion, where iaeng_canon_to starts one per path and per base: four, each
# in its own command substitution (WU-IAENG-444). cygpath prints one line per
# path. Returns 1, and the per-path conversion runs instead, when there is no
# cygpath (no conversion then starts a process anyway), when it fails, when a
# path holds a carriage return or a line break, or when it does not print one
# line per path. A line break would split a path over two lines. A carriage
# return is the platform's: Git for Windows' bash strips a CR before the final
# line feed of a command substitution, so the per-path conversion of a path
# ending in CR loses it, where the line read here would keep it.
canon_three() {
  local args=("$FILE") out rest base=""
  local conv=()
  command -v cygpath >/dev/null 2>&1 || return 1
  [ -z "$CWD" ] || args+=("$CWD")
  args+=("$PATTERNS" "$HOOKS_DIR_CANON")
  case "${args[*]}" in *[$'\r\n']*) return 1 ;; esac
  out="$(cygpath -u -- "${args[@]}" 2>/dev/null)" || return 1
  rest="$out"$'\n'
  while [ -n "$rest" ]; do conv+=("${rest%%$'\n'*}"); rest="${rest#*$'\n'}"; done
  [ "${#conv[@]}" -eq "${#args[@]}" ] || return 1
  [ -z "$CWD" ] || base="${conv[1]}"
  canon_walk CANON "${conv[0]}" "$base"
  canon_walk PAT_CANON "${conv[${#conv[@]} - 2]}" ""
  canon_walk HOOKS_CANON "${conv[${#conv[@]} - 1]}" ""
}

# exemption_named — true when the edit's path, or what it is resolved against,
# names `tests` or the pattern file, so that either path exemption could apply
# (WU-IAENG-444). The canonical path is made of the segments of the file path,
# of the payload's cwd (or of the working directory when there is none, the
# base the walk uses then) and of the prefix cygpath gives a drive or a mount;
# cygpath changes nothing else. CANON can equal the pattern file's canonical
# path only if its last segment is that file's name, and it can be inside
# tests/ only if it has a segment `tests`. So when none of the three names
# either, no exemption applies, and the conversion, which starts a cygpath per
# path and a shell for pwd, is not made. Only a mount whose POSIX target itself
# names `tests` or the pattern file could supply them, and there skipping can
# only refuse an edit the exemption would have allowed: never the reverse.
exemption_named() {
  case "$FILE" in *tests*|*suppression-patterns.tsv*) return 0 ;; esac
  if [ -n "$CWD" ]; then
    case "$CWD" in *tests*|*suppression-patterns.tsv*) return 0 ;; esac
  else
    case "$PWD" in *tests*|*suppression-patterns.tsv*) return 0 ;; esac
  fi
  return 1
}

# The pattern file, by this hook's own directory. Reading it needs no
# canonical path; the exemptions below make one only when one could apply.
PATTERNS="$HOOKS_DIR/../../../scripts/suppression-patterns.tsv"
if [ -n "$FILE" ]; then
  [ -n "$FAST" ] || CWD="$(iaeng_field '.cwd')"
fi
CANON="" PAT_CANON="" HOOKS_CANON=""
if [ -n "$FILE" ] && exemption_named; then
  # HOOKS_DIR made absolute, for the pattern file and the tests/ exemption.
  HOOKS_DIR_CANON="$(CDPATH='' cd -- "${HOOKS_DIR:-/}" && pwd)"
  PATTERNS="$HOOKS_DIR_CANON/../../../scripts/suppression-patterns.tsv"
  if ! canon_three; then
    iaeng_canon_to CANON "$FILE" "$CWD"
    iaeng_canon_to PAT_CANON "$PATTERNS"
    iaeng_canon_to HOOKS_CANON "$HOOKS_DIR_CANON"
  fi
  [ "$CANON" != "$PAT_CANON" ] || exit 0
  case "$CANON" in "$HOOKS_CANON"/tests/*) exit 0 ;; esac
fi

# Every string the edit would write. With jq: new_string, content, and each
# MultiEdit edit's new_string. Without jq: the raw payload, JSON escapes still
# encoded. That is NOT a safe over-approximation: a directive containing an
# escaped character (a tab) and the line-anchored rules do not match the encoded
# form, so this mode can under-block. Install jq (hooks/README.md, Fail closed).
# The one jq read above has already made the first; it is made here only when
# that read sent the payload this way.
if [ -n "$FAST" ]; then
  :
elif iaeng_have_jq; then
  TEXT="$(printf '%s' "$IAENG_INPUT" \
    | jq -r '.tool_input | [.new_string?, .content?, (.edits[]?.new_string?)] | .[] | select(. != null)' 2>/dev/null)"
else
  TEXT="$IAENG_INPUT"
fi
[ -n "$TEXT" ] || exit 0

# CASE-INSENSITIVE. The filename exemption above folds case and the directives
# it guards did not, so the upper-case spelling of the Python lint pragma was
# allowed while the lower-case one was refused — and the tool honours both,
# making it a live suppression and the second spelling anyone reaching for a
# bypass would try. Blanket -i rather than deciding per tool which spellings
# are honoured: it errs toward blocking, which is the direction these hooks
# fail in by design, and the cost of over-blocking is a rename, not a lost
# control.
# grep's OWN exit status, from PIPESTATUS, not the pipeline's. Under the
# `set -o pipefail` this hook inherits from lib.sh, grep -q closing the pipe on
# its first match makes the printf take SIGPIPE, and pipefail reports that as
# the pipeline's failure — so a directive near the top of a payload larger than
# the ~64 KB pipe buffer read as ABSENT and the edit was ALLOWED. A 64 KB source
# file is ordinary, not adversarial, so this bypassed the control with no
# obfuscation at all. TROUBLESHOOTING X. The fix of that day, a here-string,
# never finishes on Git for Windows for a text of 65,536 to 65,663 bytes, so
# such an edit waited for the guard's 120 s timeout (WU-IAENG-444; the same
# window as Governance/BLOCKING_HOOK_LATENCY_MEASUREMENT.md, Here-strings of
# 64 KiB). A pipe finishes at every size, and PIPESTATUS[1] is grep's status
# whatever happened to the printf. The text is followed by one line feed, as
# the here-string added one.
# THE PATTERNS LIVE IN ONE DATA FILE, Adapters/scripts/suppression-patterns.tsv
# (label<TAB>ERE), read by this hook and by check-inline-suppression.sh. This
# hook sees only Edit/Write/MultiEdit; a directive written through the Bash
# tool, by a human, or by another runtime never reaches it, and the Pull
# Request check reads the same list where those paths meet. Two copies of the
# list would drift.
#
# FAIL CLOSED when the file is missing: an absent pattern list is not an empty
# one, and a hook that allowed everything because its data was gone is the
# defect Adapters/README.md's Check Convention names. Same shape as the lexer
# check in block-escape-hatches.sh. The pattern file itself is exempt by path
# (below, with the other named exemptions) because it quotes every directive;
# that also lets a deleted file be restored through an Edit or Write.
check() {
  local rc st
  printf '%s\n' "$TEXT" | grep -qiE -- "$1"
  st=("${PIPESTATUS[@]}")
  rc="${st[1]}"
  # rc 2 is a pattern grep could not compile: an unreadable rule is a failure,
  # not a rule that matched nothing.
  [ "$rc" -le 1 ] || iaeng_block "suppression-patterns.tsv holds a pattern grep cannot compile: $1" "Fix the row."
  return "$rc"
}

if [ ! -f "$PATTERNS" ]; then
  iaeng_block "Adapters/scripts/suppression-patterns.tsv is missing — cannot tell which edits are suppressions" \
    "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression. Restore the file; the hook reads its patterns from it and fails closed without it."
fi

# ONE grep FOR EVERY ROW (WU-IAENG-444). The rows are read first, in bash, and
# when every one is well formed, one grep gets every pattern with -e. grep
# exits 1 only when no pattern matches any line, which is when every per-row
# grep below would have exited 1: the edit is allowed here. Anything else (a
# match, a pattern it cannot compile, a malformed row, no row) goes to the
# per-row loop, which refuses as it did, with the first matching row's label.
# The loop runs only on a refusal, so the common path starts one grep, not one
# per row.
FAST_RE=()
while IFS= read -r row || [ -n "$row" ]; do
  row="${row%$'\r'}"
  case "$row" in ''|'#'*) continue ;; esac
  case "$row" in *$'\t'*) ;; *) FAST_RE=(); break ;; esac
  label="${row%%$'\t'*}"
  re="${row#*$'\t'}"
  if [ -z "$label" ] || [ -z "$re" ]; then FAST_RE=(); break; fi
  FAST_RE+=(-e "$re")
done < "$PATTERNS"
if [ "${#FAST_RE[@]}" -gt 0 ]; then
  printf '%s\n' "$TEXT" | grep -qiE "${FAST_RE[@]}"
  FAST_ST=("${PIPESTATUS[@]}")
  [ "${FAST_ST[1]}" != 1 ] || exit 0
fi

SEEN=0
while IFS= read -r row || [ -n "$row" ]; do
  row="${row%$'\r'}"
  case "$row" in ''|'#'*) continue ;; esac
  case "$row" in *$'\t'*) ;; *) iaeng_block "malformed row in suppression-patterns.tsv (no TAB): $row" "Each row is label<TAB>ERE." ;; esac
  label="${row%%$'\t'*}"
  re="${row#*$'\t'}"
  if [ -z "$label" ] || [ -z "$re" ]; then
    iaeng_block "malformed row in suppression-patterns.tsv (empty label or pattern): $row" "Each row is label<TAB>ERE."
  fi
  SEEN=$((SEEN + 1))
  if check "$re"; then
    iaeng_block "inline suppression: ${label} (${FILE:-unknown file}) — a red signal turned green without changing what it measured" \
      "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression (Standards/TESTING_STANDARD.md for skipped tests). Configure the rule for the project, or satisfy it; a tool false positive that configuration cannot scope is applied by a human with the constraint named on the preceding line."
  fi
done < "$PATTERNS"

[ "$SEEN" -gt 0 ] || iaeng_block "suppression-patterns.tsv holds no patterns" "An empty list would allow everything; restore it."

exit 0
