#!/usr/bin/env bash
# IA Engineering — check-framework-drift.sh
#
# Tells an adopting project how far it has drifted from the framework it
# imports, and what to do about each item. It is the last step of an upgrade
# (WU-IAENG-358, the adopter drift plan, WU-4).
#
# WHY IT EXISTS
#
# DEF-IAENG-REL014-01: a project on v0.0.13 that followed the upgrade note
# failed the required `Work Unit Exists` check (no Registry/work-units.yml),
# kept a pr-validation.yml 77 lines behind and had no control-path-guard.yml.
# Nothing told it. The installers already compared each file, but only when
# writing, and none could tell a file the project never touched but that is
# out of date (`stale`: copy it) from a file the project edited (`modified`:
# review it, never --force). That is the exact question the v0.0.14 note
# left to the adopter.
#
# WHAT IT REPORTS, IN FOUR FAMILIES
#
#   version  A. The framework checkout: the commit it is on and its tag (or
#               that it is not on a tag), the last tag KNOWN LOCALLY and how
#               many tags behind it is, and the submodule gitlink (`+` the
#               checkout is not the commit the project recorded: an upgrade
#               not committed; `-` not initialized). With --remote, the last
#               tag on the framework's remote too (`git ls-remote`, which
#               writes no ref).
#   file     B. Every file install.sh and setup-project-bootstrap.sh manage,
#               classified (below).
#   config   C. What the installers check besides files: .gitattributes and
#               .gitignore rules, core.hooksPath and the git hooks,
#               .claude/settings.json and its hook entries, the skills.
#   path     D. Every command in .claude/settings.json and
#               .claude/settings.local.json, the project's own included: the
#               script it names is resolved and checked to exist and be
#               readable — NEVER executed. Same for core.hooksPath. A hook
#               whose script is gone exits 127 and its guard disappears
#               without a sound.
#
# B AND C COME FROM THE INSTALLERS, NOT FROM A THIRD LIST
#
# It runs the installers' own --check (setup-project-bootstrap.sh --check,
# which runs install.sh --check; install-hooks.sh --check; install-skills.sh
# --check) and reads their records. The list of managed files is whatever
# install.sh --check reports, so this script cannot drift from what a run
# installs. What it adds is the classification of each file the installers
# call `differs`, which lives here alone (no installer sources a new file:
# install-hooks.sh is a control path):
#
#   current        identical to the template, line endings aside
#   absent         the template exists, the copy does not
#   stale          the copy is byte for byte an EARLIER version of the
#                  template: never edited by the project. Remedy: the exact cp.
#   modified       matches no version of the template: edited by the project,
#                  or the template was renamed (history is not followed across
#                  a rename). Remedy: review the diff; never --force.
#   customized     a file the project is expected to edit (installer's list)
#   project-owned  a file the bootstrap writes once and the project owns:
#                  presence only
#   indeterminate  could not be decided — said with its cause, never counted
#                  as current (Adapters/README.md, the Check Convention, 1)
#
# The algorithm for stale against modified: drop the CR that ends a line (only
# that one: a bare CR inside a line is content, SEC-IAENG-353-01), hash the
# copy with `git hash-object --stdin` — WITHOUT -w, so nothing is written —
# and look for that hash among the blobs the template has ever had:
# `git -C <framework> log --all --format= --raw --no-abbrev -- <template>`.
# A shallow framework checkout does not have that history: indeterminate.
# A framework that is a plain copy (not its own git checkout): same.
#
# READ-ONLY, AND TESTED TO BE (Adapters/scripts/tests/run.sh, WU-IAENG-358)
#
# No fetch, no git config write, no `hash-object -w`, no commit probe;
# GIT_OPTIONAL_LOCKS=0 (git's spelling of --no-optional-locks) for every git
# command here and in the installers it runs; this script creates no
# temporary file of its own (what the installers' --check do is theirs, and
# is covered by the same snapshot test), and writes nothing at all but the
# --quick result in a --cache-dir outside the project. GIT_TERMINAL_PROMPT=0: --remote
# never prompts.
# settings.json is parsed with jq, never evaluated. No network unless
# --remote. The records it prints carry text read from the project (a
# command, a git config value): every control character in them becomes a
# space, so one record is one line and the terminal gets no escape sequence
# (SEC-IAENG-355-02, SEC-IAENG-357-01).
#
# This is advice, not a gate. A falsified local check that says `current`
# must fool nobody: the required server-side checks remain the boundary.
#
# USAGE, from the root of the adopting project:
#
#   ./ia-engineering/Adapters/scripts/check-framework-drift.sh [options]
#
#   --format text|tsv   text (default) for a person; tsv for a caller:
#                       family TAB status TAB path TAB remedy, one item per
#                       line, then one `#` summary line
#   --strict            exit 1 on drift, 2 when something is indeterminate
#                       (2 wins: an incomplete evaluation is not a verdict)
#   --remote            also ask the framework's remote for its tags
#   --quick             the session-start form (below): A, B unclassified, D
#   --cache-dir DIR     --quick only, absolute: keep the --quick result there
#   --help
#
# --QUICK (WU-IAENG-359, the adopter drift plan §3.2)
#
# session-start.sh runs it on every session, under a time limit, and prints a
# line only for what is actionable. It covers A (version), B counted by the
# installers' plain diff — `differs`, not classified: telling stale from
# modified reads the framework's history, which is what costs — and D (paths).
# C is not evaluated; a `config not-evaluated` record says so. Measured on
# Windows (Git Bash), a full run takes 3 to 7 s, too slow for a session start.
#
# With --cache-dir, the result is kept in DIR (a user-level directory: never
# inside the project, refused there) with the list of every file it was read
# from. The next --quick replays it when the framework commit and the
# recorded gitlink are the same, every one of those files is still present or
# still absent, and none is newer than the kept result (one `find -newer`):
# an unchanged project costs a stat, not a check. A result with an
# indeterminate item is never kept. Without --cache-dir nothing is written.
# A file counts as changed when its mtime OR its inode change time is newer
# (content copied under an old mtime, a mode change). The cache is used only
# when the user alone could have written it; see THE CACHE IS TRUSTED below.
#
# Declared limits of what the kept result watches: core.hooksPath is watched
# in the project's config, ~/.gitconfig and $XDG_CONFIG_HOME/git/config, not
# in the system gitconfig, include.path / includeIf targets, config.worktree
# or GIT_CONFIG_GLOBAL; tags in packed-refs, refs/tags/ and reftable/, not a
# tag nested under refs/tags/<dir>/; and the framework's templates, install.sh
# and the bootstrap, not other uncommitted edits in the framework checkout.
# Any of those changed: run the full check (the session line names it).
#
# The summary line carries the denominators (the Check Convention, rule 3):
# "14 file(s) compared: 11 current, 1 absent, 1 stale, 1 modified", and the
# same for config items and command paths.
#
# EXIT CODES
#
#   0   always without --strict: the check advises, and a check that blocks
#       ends up bypassed
#   1   --strict, drift found (absent, stale, modified, missing, differs,
#       not-executable, shadowed, disabled, broken, behind, uncommitted)
#   2   --strict, something indeterminate
#   64  usage error
#
# In the framework repository itself it says "not applicable" and exits 0:
# validate-framework.sh §10 covers that checkout.
#
# Declared limits: only tags known locally are counted unless --remote; a
# template renamed in the framework's history reads as `modified`; a copy
# that matches a version of the template newer than the pinned commit (from
# --all) reads as `stale` too.

set -uo pipefail
export LC_ALL=C
export GIT_OPTIONAL_LOCKS=0
# --remote must never stop to ask for credentials: it fails instead.
export GIT_TERMINAL_PROMPT=0

FORMAT=text
STRICT=0
REMOTE=0
QUICK=0
CACHE_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-}"; shift ;;
    --format=*) FORMAT="${1#--format=}" ;;
    --strict) STRICT=1 ;;
    --remote) REMOTE=1 ;;
    --quick) QUICK=1 ;;
    --cache-dir) CACHE_DIR="${2:-}"; [ -n "$CACHE_DIR" ] || CACHE_DIR="(empty)"; shift ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "check-framework-drift.sh: unknown option '$1' (try --help)" >&2; exit 64 ;;
  esac
  shift
done
case "$FORMAT" in
  text|tsv) ;;
  *) echo "check-framework-drift.sh: --format takes text or tsv" >&2; exit 64 ;;
esac
if [ -n "$CACHE_DIR" ]; then
  # A relative directory would be read against the project: the result
  # would be written inside it.
  [ "$QUICK" -eq 1 ] || { echo "check-framework-drift.sh: --cache-dir goes with --quick only" >&2; exit 64; }
  case "$CACHE_DIR" in
    /*|[A-Za-z]:[/\\]*) ;;
    *) echo "check-framework-drift.sh: --cache-dir takes an absolute directory" >&2; exit 64 ;;
  esac
  # A backslash is a separator on Windows: C:\a\..\b is refused as C:/a/../b
  # is (issue #342). Held in a variable, as cache_dir_canon holds it.
  _bs="\\"
  case "/${CACHE_DIR//"$_bs"//}/" in
    */../*|*/./*) echo "check-framework-drift.sh: --cache-dir takes a directory without . or .. components" >&2; exit 64 ;;
  esac
fi
[ "$QUICK" -eq 1 ] && [ "$REMOTE" -eq 1 ] && { echo "check-framework-drift.sh: --quick never asks the remote" >&2; exit 64; }

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME="$FRAMEWORK/Adapters/ai-runtimes/claude-code"

# ------------------------------------------------------------- records ---

ROWS=""
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
# rec <family> <status> <path> <remedy>
rec() {
  local f2 f3 f4
  flat "$2"; f2="$FLAT"; flat "$3"; f3="$FLAT"; flat "$4"; f4="$FLAT"
  ROWS="$ROWS$1"$'\t'"$f2"$'\t'"$f3"$'\t'"$f4"$'\n'
}

# The statuses that need action. `indeterminate` is counted apart.
DRIFT_RE='^(absent|stale|modified|missing|differs|not-executable|shadowed|disabled|broken|behind|behind-remote|uncommitted|uninitialized)$'

finish() {
  local fam st path rem summary drift=0 indet=0
  # A family with nothing in it was not evaluated (the Check Convention,
  # rule 3): an empty set is never a clean one.
  if [ "$NA" -eq 0 ] && [[ "$ROWS" != file$'\t'* && "$ROWS" != *$'\n'file$'\t'* ]]; then
    rec file indeterminate "(none)" "no managed file was reported: install.sh --check gave no file record"
  fi
  while IFS=$'\t' read -r fam st path rem; do
    [ -z "$fam" ] && continue
    if [[ "$st" =~ $DRIFT_RE ]]; then drift=$((drift + 1)); fi
    [ "$st" = indeterminate ] && indet=$((indet + 1))
  done <<< "$ROWS"

  summary="# check-framework-drift: $drift to act on, $indet indeterminate."
  if [ "$NA" -eq 0 ]; then
    # Each family: its total (the denominator), then each status found, in
    # a fixed order so the line is stable for a caller.
    summary="$summary $(printf '%s' "$ROWS" | awk -F'\t' '
      BEGIN {
        split("version file config path", fams, " ")
        noun["version"] = "version item(s)"; noun["file"] = "file(s) compared"
        noun["config"] = "config item(s)"; noun["path"] = "command path(s)"
        order["version"] = "tagged untagged latest behind remote-same behind-remote recorded uncommitted uninitialized not-a-submodule indeterminate"
        order["file"] = "current absent stale modified differs customized project-owned indeterminate"
        order["config"] = "current present absent missing differs stale modified customized near-miss not-executable shadowed disabled placeholder not-applicable skipped not-evaluated indeterminate"
        order["path"] = "ok broken unresolved indeterminate"
      }
      NF { total[$1]++; c[$1 SUBSEP $2]++ }
      END {
        out = ""
        for (i = 1; i <= 4; i++) {
          f = fams[i]; s = ""; listed = 0
          k = split(order[f], st, " ")
          for (j = 1; j <= k; j++) if (c[f SUBSEP st[j]] > 0) { s = s (s == "" ? "" : ", ") c[f SUBSEP st[j]] " " st[j]; listed += c[f SUBSEP st[j]] }
          if (total[f] > listed) s = s (s == "" ? "" : ", ") (total[f] - listed) " other"
          out = out (out == "" ? "" : " ") (total[f] + 0) " " noun[f] ": " (s == "" ? "none" : s) "."
        }
        printf "%s", out
      }')"
  fi

  if [ "$FORMAT" = tsv ]; then
    printf '%s' "$ROWS"
  else
    while IFS=$'\t' read -r fam st path rem; do
      [ -z "$fam" ] && continue
      printf '  %-7s %-14s %s\n' "$fam" "$st" "$path"
      [ -n "$rem" ] && printf '          -> %s\n' "$rem"
    done <<< "$ROWS"
  fi
  printf '%s\n' "$summary"
  if [ "$QUICK" -eq 1 ]; then
    # An incomplete evaluation is not a result to replay.
    if [ "$CACHE_STATE" = miss ]; then
      [ "$indet" -eq 0 ] && cache_write "$CACHE_FILE" "$ROWS" 0
      # This run's stamp, and any left by a run the time limit cut.
      for _s in "$CACHE_FILE".*.stamp; do
        [ -e "$_s" ] && rm -f "$_s" 2>/dev/null
      done
    fi
    printf '# --quick: cache %s%s\n' "$CACHE_STATE" "${B_REPLAYED:+, file records replayed}"
  fi

  [ "$STRICT" -eq 1 ] || exit 0
  [ "$indet" -gt 0 ] && exit 2
  [ "$drift" -gt 0 ] && exit 1
  exit 0
}

NA=0
not_applicable() {
  NA=1
  rec version not-applicable "." "$1"
  finish
}

# ------------------------------------------------- the --quick cache ---
#
# The kept result, one file per project in --cache-dir:
#   iaeng-drift-cache 1
#   project TAB <project path>
#   key TAB <framework commit> <recorded gitlink>
#   watch TAB 1|0 TAB <absolute path>       present (1) or absent (0) then
#   row TAB <family> TAB <status> TAB <path> TAB <remedy>
#   end
# Its mtime is set to the moment the run that wrote it STARTED (touch -r of a
# stamp made first), so a file edited while that run read it is newer.
# Every row is flattened again when it is replayed: the file is read as data.
#
# B, the installers' records, costs most of a cold run (about 1.1 s of 1.6 s
# on Windows). It is also kept on its own, in the same format, as soon as it
# is complete (B_FILE): a run cut by session-start's time limit after B still
# leaves it, so the next session finishes within the limit and keeps the
# whole result; and an edit to settings.json does not run B again.

CACHE_STATE=off
CACHE_FILE=""
B_FILE=""
B_REPLAYED=""
CACHE_KEY=""
CACHE_MAGIC="iaeng-drift-cache 1"
STAMP=""
WATCH=()

# THE CACHE IS TRUSTED ONLY WHEN THE USER ALONE COULD HAVE WRITTEN IT
# (SEC-IAENG-359-01). Its text becomes an agent session's context, and its
# watch lines become find arguments, so a cache another account can write is
# not a cache: the directory is made 0700, and the directory and each file
# read must be owned by this user, not a symbolic link, and neither group-
# nor world-writable, or nothing is replayed (the run computes, as cold).
# On Git for Windows (noacl) every file reads as the user's and 0644/0755.

# untrusted <path>... — true when any path fails the rule above.
untrusted() {
  local p bad
  for p in "$@"; do
    { [ -O "$p" ] && [ ! -L "$p" ]; } || return 0
  done
  # Each path is absolute (callers pass CACHE_DIR and files in it).
  bad="$(find "$@" -prune \( -perm -020 -o -perm -002 \) -print 2>/dev/null)" || return 0
  [ -n "$bad" ]
}

# cache_dir_canon — CACHE_DIR made canonical, or emptied (no cache) when it
# has a . or .. component, cannot be resolved, or is the project or inside
# it (SEC-IAENG-359-03). Symbolic links are resolved in the part that exists
# (cd -P), so neither a link nor a .. can lead back into the project; the
# part that does not exist yet cannot be the project. session-start.sh's
# lib.sh iaeng_cache_dir applies the same rule to the directory it chooses:
# no new file is sourced by this control-path script. Every backslash is read
# as a separator, as Windows reads it, before the test and the walk (issue
# #342): split on / alone, a part still to be made such as "..\proj\cache"
# or "proj\cache" was kept as one name and made inside the project.
cache_dir_canon() {
  local bs="\\" p tail="" n canon
  p="${CACHE_DIR//"$bs"//}"
  p="${p%/}"
  case "/$p/" in */../*|*/./*) CACHE_DIR=""; return ;; esac
  while [ ! -d "$p" ]; do
    n="${p%/*}"
    { [ -z "$n" ] || [ "$n" = "$p" ]; } && { CACHE_DIR=""; return; }
    case "$n" in */*) ;; *) n="$n/" ;; esac
    # The root of a drive that does not exist (Q:/) gives itself back: the
    # walk would never end.
    [ "$n" = "$p" ] && { CACHE_DIR=""; return; }
    tail="${p##*/}${tail:+/$tail}"
    p="$n"
  done
  canon="$(cd -P "$p" 2>/dev/null && pwd -P)" || { CACHE_DIR=""; return; }
  # The part that exists resolved to the root: the join would give //<tail>,
  # a network (UNC) path on Windows that the test below never sees
  # (SEC-IAENG-399-01). Refused, as /<missing>/x already is. Not ${canon%/}:
  # for a // canon it gives / and /<tail>, the same // again.
  case "$canon" in *[!/]*) ;; *) CACHE_DIR=""; return ;; esac
  p="$canon"
  while :; do
    [ "$p" -ef "$PROJECT" ] && { CACHE_DIR=""; return; }
    n="${p%/*}"
    { [ -z "$n" ] || [ "$n" = "$p" ]; } && break
    p="$n"
  done
  CACHE_DIR="$canon${tail:+/$tail}"
}

# watch_add <path> — a file the --quick result is read from, made absolute.
watch_add() {
  [ "$CACHE_STATE" = miss ] || return 0
  case "$1" in
    ''|[/\\][/\\]*) return 0 ;;
    /*|[A-Za-z]:[/\\]*) WATCH+=("$1") ;;
    *) WATCH+=("$PROJECT/$1") ;;
  esac
}

# cache_replay <file> <keep> — the kept result, when nothing it was read from
# changed; its rows are recorded. keep=1 adds its watched files to WATCH, so
# a result built on a replayed segment watches them too.
cache_replay() {
  local file="$1" keep="$2" line tag a b c d rows="" ended=0 newer p wset=$'\n'
  local -a present=() listed=()
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  untrusted "$CACHE_DIR" "$file" && return 1
  {
    IFS= read -r line && [ "$line" = "$CACHE_MAGIC" ] || return 1
    IFS= read -r line && [ "$line" = "project"$'\t'"$PROJECT" ] || return 1
    IFS= read -r line && [ "$line" = "key"$'\t'"$CACHE_KEY" ] || return 1
    while IFS=$'\t' read -r tag a b c d; do
      case "$tag" in
        watch)
          # Every line is checked before any reaches find (SEC-IAENG-359-04,
          # CWE-88): a watch path is absolute, so it never begins with - ( !
          # and cannot be read as a find primary (-exec, -delete, -fprint);
          # a network path is never touched. One bad line, no replay.
          case "$a" in 0|1) ;; *) return 1 ;; esac
          case "$b" in
            [/\\][/\\]*) return 1 ;;
            /*|[A-Za-z]:[/\\]*) ;;
            *) return 1 ;;
          esac
          if [ -e "$b" ] || [ -L "$b" ]; then
            [ "$a" = 1 ] || return 1
            present+=("$b")
          else
            [ "$a" = 0 ] || return 1
          fi
          listed+=("$b")
          wset="$wset$b"$'\n' ;;
        row)
          # A row about a file or a resolved path is replayed only if the
          # result watched that path: a hand-written cache that reports a
          # file current without watching it is not a result.
          case "$a:$b" in
            file:*|path:ok|path:broken)
              case "$c" in /*|[A-Za-z]:[/\\]*) p="$c" ;; *) p="$PROJECT/$c" ;; esac
              [[ "$wset" == *$'\n'"$p"$'\n'* ]] || return 1 ;;
          esac
          rows="$rows$a"$'\t'"$b"$'\t'"$c"$'\t'"$d"$'\n' ;;
        end) ended=1; break ;;
        *) return 1 ;;
      esac
    done
  } < "$file"
  [ "$ended" -eq 1 ] || return 1
  # Every path was checked absolute above, so none can be read as an option.
  # Content changed under an old mtime (cp -p, rsync -a, unzip, a copy in
  # Explorer) or a mode changed (chmod a-r) still moves the inode's change
  # time, which no user can set back: -cnewer compares it with the kept
  # result's mtime, the moment its run started (SEC-IAENG-359-02).
  if [ "${#present[@]}" -gt 0 ]; then
    newer="$(find "${present[@]}" -prune \( -newer "$file" -o -cnewer "$file" \) -print 2>/dev/null)" || return 1
    [ -z "$newer" ] || return 1
  fi
  while IFS=$'\t' read -r a b c d; do
    [ -n "$a" ] && rec "$a" "$b" "$c" "$d"
  done <<< "$rows"
  if [ "$keep" -eq 1 ]; then
    for p in ${listed[@]+"${listed[@]}"}; do WATCH+=("$p"); done
  fi
  return 0
}

# cache_write <file> <rows> <first> — keeps the rows and the files they were
# read from (WATCH from index <first>), stamped with the run's start.
cache_write() {
  local file="$1" rows="$2" first="$3" tmp="$1.$$.tmp" l i
  [ -n "$STAMP" ] && [ -f "$STAMP" ] || return 0
  {
    printf '%s\n' "$CACHE_MAGIC" "project"$'\t'"$PROJECT" "key"$'\t'"$CACHE_KEY"
    for (( i = first; i < ${#WATCH[@]}; i++ )); do
      if [ -e "${WATCH[i]}" ] || [ -L "${WATCH[i]}" ]; then
        printf 'watch\t1\t%s\n' "${WATCH[i]}"
      else
        printf 'watch\t0\t%s\n' "${WATCH[i]}"
      fi
    done
    while IFS= read -r l; do
      [ -n "$l" ] && printf 'row\t%s\n' "$l"
    done <<< "$rows"
    printf 'end\n'
  } > "$tmp" 2>/dev/null \
    && touch -r "$STAMP" "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$file" 2>/dev/null
  [ -e "$tmp" ] && rm -f "$tmp" 2>/dev/null
  return 0
}

# ------------------------------------------------------- where we are ---

if ! PROJECT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  NA=1
  rec version indeterminate "." "not inside a git repository: run it from the root of the adopting project"
  finish
fi
# A root git names but this shell cannot enter is indeterminate, like the
# case above, and is reported the same way: through finish, so the exit code
# is the contract's (0 without --strict, 2 with it), never 1, which means
# drift (Standards/CODE_QUALITY_STANDARD.md, The Check Convention, Shell
# Scripts rule 1).
if ! cd "$PROJECT"; then
  NA=1
  rec version indeterminate "$PROJECT" "the project root git reported cannot be entered: nothing was compared"
  finish
fi
PROJECT="$(pwd)"

[ "$FORMAT" = text ] && printf 'IA Engineering — framework drift (read-only): %s\n' "$PROJECT"

if [ "$FRAMEWORK" -ef "$PROJECT" ]; then
  not_applicable "this is the framework repository itself; validate-framework.sh covers it"
fi

# The framework's path relative to the project, by walking and comparing
# identity (-ef), as install.sh does: immune to case and to /c/ against C:/.
REL=""
_probe="$FRAMEWORK"; _rel=""
while :; do
  if [ "$_probe" -ef "$PROJECT" ]; then REL="$_rel"; break; fi
  _parent="$(dirname "$_probe")"
  [ "$_parent" = "$_probe" ] && break
  _rel="$(basename "$_probe")${_rel:+/$_rel}"
  _probe="$_parent"
done
unset _probe _rel _parent
if [ -z "$REL" ]; then
  NA=1
  rec version indeterminate "$FRAMEWORK" "the framework is not inside this project; import it as Workflows/ONBOARDING.md Step 1 says"
  finish
fi

STACK="<stack>"
if [ -f .ia-engineering/stack ]; then
  IFS= read -r _s < .ia-engineering/stack || true
  _s="${_s%$'\r'}"
  [[ "$_s" =~ ^[a-z0-9-]+$ ]] && STACK="$_s"
fi
BOOTSTRAP_CMD="$REL/Adapters/scripts/setup-project-bootstrap.sh $STACK"

# Is the framework its own git checkout? `git -C` on a plain copy would find
# the PROJECT's repository and read the wrong history.
FW_GIT=0
FW_SHALLOW=false
if [ "$QUICK" -eq 1 ]; then
  # One git command for the checkout, its git directory and its commit. On
  # Git for Windows every fork costs 50 to 90 ms: --quick counts them.
  # --quick reads no history, so shallow does not matter to it.
  if _q="$(git -C "$FRAMEWORK" rev-parse --show-toplevel --absolute-git-dir HEAD 2>/dev/null)"; then
    { IFS= read -r _top; IFS= read -r FW_GITDIR; IFS= read -r FW_HEAD; } <<< "$_q"
    [ "$_top" -ef "$FRAMEWORK" ] && [ -n "$FW_HEAD" ] && FW_GIT=1
  fi
  # The gitlink the project recorded: "160000 <sha> <stage>TAB<path>".
  GL_MODE=""; GL_SHA=""
  read -r GL_MODE GL_SHA _ <<< "$(git ls-files -s -- "$REL" 2>/dev/null)"
  if [ -n "$CACHE_DIR" ] && [ "$FW_GIT" -eq 1 ]; then
    # Never inside the project: --quick writes nowhere the project can see.
    cache_dir_canon
  fi
  if [ -n "$CACHE_DIR" ] && [ "$FW_GIT" -eq 1 ]; then
    CACHE_FILE="$CACHE_DIR/drift-${PROJECT//[^A-Za-z0-9._-]/_}.tsv"
    B_FILE="$CACHE_DIR/drift-${PROJECT//[^A-Za-z0-9._-]/_}.files.tsv"
    CACHE_KEY="$FW_HEAD ${GL_MODE:--}:${GL_SHA:--}"
    if cache_replay "$CACHE_FILE" 0; then
      CACHE_STATE=hit
      finish
    fi
    ROWS=""
    CACHE_STATE=miss
    # The cache directory itself 0700, where the filesystem honours it (Git
    # for Windows' noacl mount refuses the mode and still creates it: hence
    # the -d test after, not &&). Its parents are ordinary user directories.
    if [ ! -d "$CACHE_DIR" ]; then
      mkdir -p "${CACHE_DIR%/*}" 2>/dev/null
      mkdir -m 700 "$CACHE_DIR" 2>/dev/null
    fi
    if [ -d "$CACHE_DIR" ] && ! untrusted "$CACHE_DIR"; then
      STAMP="$CACHE_FILE.$$.stamp"
      { umask 077; : > "$STAMP"; } 2>/dev/null || STAMP=""
    else
      # Not the user's alone: nothing is read from it or written to it.
      CACHE_STATE=refused
    fi
    watch_add "$SCRIPT_DIR/check-framework-drift.sh"
    # Tags known locally: a fetch rewrites packed-refs, adds to refs/tags, or
    # (reftable backend) rewrites reftable/.
    watch_add "$FW_GITDIR/packed-refs"
    watch_add "$FW_GITDIR/refs/tags"
    watch_add "$FW_GITDIR/reftable"
  fi
elif _top="$(git -C "$FRAMEWORK" rev-parse --show-toplevel 2>/dev/null)" && [ "$_top" -ef "$FRAMEWORK" ]; then
  FW_GIT=1
  FW_SHALLOW="$(git -C "$FRAMEWORK" rev-parse --is-shallow-repository 2>/dev/null || echo unknown)"
fi

# quick_version — A in two git commands at most: the tags and their commits
# in one for-each-ref, the gitlink from the ls-files above. The records and
# their remedies are the full run's.
quick_version() {
  local t o p n=0 exact="" base="" last="" behind=-1 desc short="${FW_HEAD:0:7}"
  local -a tags=()
  while IFS=$'\t' read -r t o p; do
    [ -n "$t" ] || continue
    tags+=("$t")
    [ -z "$last" ] && last="$t"
    if [ -z "$exact" ] && { [ "$o" = "$FW_HEAD" ] || [ "$p" = "$FW_HEAD" ]; }; then
      exact="$t"
    fi
  done < <(git -C "$FRAMEWORK" for-each-ref --sort=-v:refname --format='%(refname:short)%09%(objectname)%09%(*objectname)' refs/tags 2>/dev/null)
  if [ -n "$exact" ]; then
    rec version tagged "$REL" "$exact ($short)"
    base="$exact"
  elif desc="$(git -C "$FRAMEWORK" describe --tags HEAD 2>/dev/null)"; then
    base="${desc%-*-g*}"
    rec version untagged "$REL" "$desc: not on a tag; nearest tag $base"
  else
    rec version untagged "$REL" "$short: no tag is reachable from this commit"
  fi
  if [ -z "$last" ]; then
    rec version indeterminate "$REL" "no tag is known locally; nothing to count from"
  elif [ -z "$base" ]; then
    rec version indeterminate "$REL" "last tag known locally: $last; the checkout descends from no tag, so tags behind cannot be counted"
  else
    for t in "${tags[@]}"; do
      [ "$t" = "$base" ] && { behind=$n; break; }
      n=$((n + 1))
    done
    if [ "$behind" -eq 0 ]; then
      rec version latest "$REL" "last tag known locally: $last (0 tag(s) behind)"
    elif [ "$behind" -gt 0 ]; then
      rec version behind "$REL" "last tag known locally: $last, $behind tag(s) behind. Upgrade: git -C $REL checkout $last, read the 'Upgrading from' notes (git -C $REL show $last:CHANGELOG.md), commit the gitlink, then run this check again"
    else
      rec version indeterminate "$REL" "the nearest tag $base is not among the tags known locally"
    fi
  fi
  if [ "$GL_MODE" = 160000 ]; then
    if [ "$GL_SHA" = "$FW_HEAD" ]; then
      rec version recorded "$REL" "the checkout is the commit the project recorded"
    else
      rec version uncommitted "$REL" "the checkout is not the commit the project recorded (gitlink +): an upgrade not committed. git add $REL and commit it, or git submodule update to go back"
    fi
  else
    rec version not-a-submodule "$REL" "the framework is not recorded as a submodule (a copied or linked reference): no gitlink to compare"
  fi
}

# ------------------------------------------------------- A. version ---

if [ "$FW_GIT" -eq 0 ]; then
  rec version indeterminate "$REL" "the framework copy is not its own git checkout: no commit, tag or history to read"
elif [ "$QUICK" -eq 1 ]; then
  quick_version
else
  HEAD_SHA="$(git -C "$FRAMEWORK" rev-parse --short HEAD 2>/dev/null)"
  if EXACT="$(git -C "$FRAMEWORK" describe --tags --exact-match HEAD 2>/dev/null)"; then
    rec version tagged "$REL" "$EXACT ($HEAD_SHA)"
    BASE_TAG="$EXACT"
  elif DESC="$(git -C "$FRAMEWORK" describe --tags HEAD 2>/dev/null)"; then
    BASE_TAG="$(git -C "$FRAMEWORK" describe --tags --abbrev=0 HEAD 2>/dev/null)"
    rec version untagged "$REL" "$DESC: not on a tag; nearest tag $BASE_TAG"
  else
    BASE_TAG=""
    rec version untagged "$REL" "$HEAD_SHA: no tag is reachable from this commit"
  fi

  LAST_TAG="$(git -C "$FRAMEWORK" for-each-ref --sort=-v:refname --format='%(refname:short)' refs/tags 2>/dev/null | head -n 1)"
  if [ -z "$LAST_TAG" ]; then
    rec version indeterminate "$REL" "no tag is known locally${FW_SHALLOW:+ (shallow: $FW_SHALLOW)}; nothing to count from"
  elif [ -z "$BASE_TAG" ]; then
    rec version indeterminate "$REL" "last tag known locally: $LAST_TAG; the checkout descends from no tag, so tags behind cannot be counted"
  else
    BEHIND=0
    while IFS= read -r _t; do
      [ "$_t" = "$BASE_TAG" ] && break
      BEHIND=$((BEHIND + 1))
    done < <(git -C "$FRAMEWORK" for-each-ref --sort=-v:refname --format='%(refname:short)' refs/tags 2>/dev/null)
    if [ "$BEHIND" -eq 0 ]; then
      rec version latest "$REL" "last tag known locally: $LAST_TAG (0 tag(s) behind)"
    else
      rec version behind "$REL" "last tag known locally: $LAST_TAG, $BEHIND tag(s) behind. Upgrade: git -C $REL checkout $LAST_TAG, read the 'Upgrading from' notes (git -C $REL show $LAST_TAG:CHANGELOG.md), commit the gitlink, then run this check again"
    fi
  fi

  if [ "$REMOTE" -eq 1 ]; then
    if REMOTE_TAGS="$(git -C "$FRAMEWORK" ls-remote --tags --refs origin 2>/dev/null)"; then
      R_LAST="$(printf '%s\n' "$REMOTE_TAGS" | sed -n 's|.*refs/tags/||p' | sort -V -r | head -n 1)"
      if [ -z "$R_LAST" ]; then
        rec version indeterminate "$REL" "--remote: the remote lists no tag"
      elif [ "$R_LAST" = "$LAST_TAG" ]; then
        rec version remote-same "$REL" "last tag on the remote: $R_LAST, as known locally"
      else
        rec version behind-remote "$REL" "last tag on the remote: $R_LAST; known locally: ${LAST_TAG:-none}. Fetch it: git -C $REL fetch --tags"
      fi
    else
      rec version indeterminate "$REL" "--remote: git ls-remote origin failed (no remote, or the network)"
    fi
  fi

  # The gitlink: what the project recorded against what is checked out.
  if [ "$(git ls-files -s -- "$REL" 2>/dev/null | cut -c1-6)" = "160000" ]; then
    SUB="$(git submodule status -- "$REL" 2>/dev/null | head -n 1)"
    case "${SUB:0:1}" in
      " ") rec version recorded "$REL" "the checkout is the commit the project recorded" ;;
      "+") rec version uncommitted "$REL" "the checkout is not the commit the project recorded (gitlink +): an upgrade not committed. git add $REL and commit it, or git submodule update to go back" ;;
      "-") rec version uninitialized "$REL" "the submodule is not initialized (gitlink -): git submodule update --init" ;;
      *) rec version indeterminate "$REL" "git submodule status gave no readable state" ;;
    esac
  else
    rec version not-a-submodule "$REL" "the framework is not recorded as a submodule (a copied or linked reference): no gitlink to compare"
  fi
fi

# --------------------------------------- B and C: the installers' records ---

# classify <copy> <template path inside the framework> — sets CLASS and WHY.
classify() {
  local copy="$1" tpl="$2" h blobs
  if [ "$FW_GIT" -eq 0 ]; then
    CLASS=indeterminate; WHY="the framework copy is not a git checkout: no history to tell stale from modified"; return
  fi
  if [ "$FW_SHALLOW" != false ]; then
    CLASS=indeterminate; WHY="the framework history is shallow: stale or modified cannot be told. git -C $REL fetch --unshallow, then run this check again"; return
  fi
  if ! h="$(sed $'s/\r$//' "$copy" | git -C "$FRAMEWORK" hash-object --stdin 2>/dev/null)" || [ -z "$h" ]; then
    CLASS=indeterminate; WHY="could not hash $copy"; return
  fi
  if ! blobs="$(git -C "$FRAMEWORK" log --all --format= --raw --no-abbrev -- "$tpl" 2>/dev/null)"; then
    CLASS=indeterminate; WHY="could not read the history of $tpl"; return
  fi
  if [[ "$blobs" == *" $h "* ]]; then
    CLASS=stale; WHY=""
  elif [ -z "$blobs" ] && [ -e "$FRAMEWORK/$tpl" ]; then
    # A template with no committed history (added to the checkout, never
    # committed): nothing to compare against, so nothing is concluded. A
    # path with no history AND no template is a file the project added to
    # an installed skill, which is its own edit: modified.
    CLASS=indeterminate; WHY="the template $tpl has no committed history in the framework checkout: stale or modified cannot be told"
  else
    CLASS=modified; WHY=""
  fi
}

# run_check <label> <command...> — the installer's records on stdout; its
# exit code in CHECK_RC. Its stderr carries the same faults as records.
run_check() {
  local label="$1"; shift
  CHECK_OUT="$("$@" 2>/dev/null)"
  CHECK_RC=$?
  case "$CHECK_RC" in
    0|1|3) ;;
    *) rec config indeterminate "$label" "$label --check exited $CHECK_RC: its items were not evaluated" ;;
  esac
}

BOOT_FAULT=0
B_DONE=0
B_ROWS0=${#ROWS}
B_WATCH0=${#WATCH[@]}
if [ "$CACHE_STATE" = miss ] && cache_replay "$B_FILE" 1; then
  # The installers' records, kept by an earlier run: nothing to run again.
  B_DONE=1
  B_REPLAYED=1
  CHECK_OUT=""; CHECK_RC=0
else
  watch_add "$SCRIPT_DIR/setup-project-bootstrap.sh"
  watch_add "$SCRIPT_DIR/install.sh"
  watch_add .ia-engineering/stack
  run_check setup-project-bootstrap.sh bash "$SCRIPT_DIR/setup-project-bootstrap.sh" --check
fi
while IFS=$'\t' read -r fam st path detail; do
  case "$fam" in ''|'#'*) continue ;; esac
  [ "$st" = fault ] && BOOT_FAULT=1
  if [ "$QUICK" -eq 1 ]; then
    # --quick keeps the files (B) and leaves the rest (C) to a full run.
    case "$fam" in file|project-file) ;; *) continue ;; esac
    watch_add "$path"
    [ "$fam" = file ] && watch_add "$detail"
  fi
  case "$fam:$st" in
    file:current) rec file current "$path" "" ;;
    file:absent) rec file absent "$path" "re-run $BOOTSTRAP_CMD without --force: it writes what is absent and overwrites nothing" ;;
    file:customized) rec file customized "$path" "expected to differ: the project edits it after install" ;;
    file:differs)
      if [ "$QUICK" -eq 1 ]; then
        rec file differs "$path" "differs from $detail, line endings aside; --quick reads no history: run $REL/Adapters/scripts/check-framework-drift.sh to tell stale (copy it) from modified (review it)"
        continue
      fi
      classify "$path" "${detail#"$REL"/}"
      case "$CLASS" in
        stale) rec file stale "$path" "never edited, an earlier version of the template: cp $detail $path" ;;
        modified) rec file modified "$path" "edited by the project, or the template was renamed: review diff $detail $path; never --force" ;;
        *) rec file indeterminate "$path" "$WHY" ;;
      esac ;;
    project-file:present) rec file project-owned "$path" "" ;;
    project-file:absent) rec file absent "$path" "re-run $BOOTSTRAP_CMD without --force: it writes what is absent and overwrites nothing" ;;
    file:fault|project-file:fault) rec file indeterminate "$path" "$detail" ;;
    git-hooks:unchecked)
      if [ "$path" = "commit probes" ]; then
        rec config skipped "$path" "not run by a check: the probes run the hooks and write a blob"
      else
        rec config not-evaluated "$path" "$detail"
      fi ;;
    todo:placeholder) rec config placeholder "$path" "$detail" ;;
    gitattributes:present|gitignore:present) rec config present "$path: $detail" "" ;;
    gitattributes:missing|gitignore:missing) rec config missing "$path: $detail" "re-run $REL/Adapters/scripts/install.sh without --force" ;;
    *:fault) rec config indeterminate "$path" "$detail" ;;
    *:absent|*:missing|*:differs) rec config "$st" "$path" "${detail:+$detail; }re-run $REL/Adapters/scripts/install.sh without --force" ;;
    *:not-executable) rec config not-executable "$path" "chmod +x $path, and git update-index --chmod=+x if it is tracked" ;;
    *:shadowed) rec config shadowed "$path" "$detail" ;;
    *) rec config "$st" "$path" "" ;;
  esac
done <<< "$CHECK_OUT"
if [ "$CHECK_RC" -eq 1 ] && [ "$BOOT_FAULT" -eq 0 ]; then
  rec config indeterminate setup-project-bootstrap.sh "setup-project-bootstrap.sh --check exited 1 without a fault record"
fi
# B kept on its own, now: a run cut after this point still leaves it.
if [ "$CACHE_STATE" = miss ] && [ "$B_DONE" -eq 0 ] \
   && [[ "${ROWS:B_ROWS0}" != *$'\t'indeterminate$'\t'* ]]; then
  cache_write "$B_FILE" "${ROWS:B_ROWS0}" "$B_WATCH0"
fi

# .claude/settings.json and its hook entries.
SETTINGS_ABSENT=0
HOOK_ENTRIES=0
CHECK_OUT=""
[ "$QUICK" -eq 1 ] || run_check install-hooks.sh bash "$RUNTIME/install-hooks.sh" --check
while IFS=$'\t' read -r fam st path detail; do
  case "$fam" in ''|'#'*) continue ;; esac
  case "$fam:$st" in
    settings:absent) SETTINGS_ABSENT=1; rec config absent "$path" "re-run $REL/Adapters/ai-runtimes/claude-code/install-hooks.sh: no framework hook runs in Claude Code" ;;
    settings:current) rec config current "$path" "" ;;
    settings:customized) rec config customized "$path" "the project's own settings; the framework entries are checked one by one" ;;
    settings:disabled) rec config disabled "$path" "\"disableAllHooks\": true turns every hook off, the framework's included: remove it" ;;
    hook:present) HOOK_ENTRIES=$((HOOK_ENTRIES + 1)); rec config present "hook: $detail" "" ;;
    hook:absent) HOOK_ENTRIES=$((HOOK_ENTRIES + 1)); rec config absent "hook: $detail" "re-run $REL/Adapters/ai-runtimes/claude-code/install-hooks.sh: it merges the missing entry" ;;
    hook:near-miss) rec config near-miss "hook: $detail" "information: the framework's own entry runs beside it" ;;
    hook:unchecked) rec config indeterminate "hook entries" "$detail" ;;
    statusline:present) rec config present "statusLine: $detail" "" ;;
    statusline:absent) rec config absent "statusLine: $detail" "re-run $REL/Adapters/ai-runtimes/claude-code/install-hooks.sh: it installs the context statusLine, wrapping the project's own" ;;
    statusline:near-miss) rec config near-miss "statusLine: $detail" "information: the project's own statusLine is kept; the context % is not recorded" ;;
    statusline:shadowed) rec config near-miss "$path: statusLine $detail" "information: this developer's own statusLine runs instead; the installer never changes settings.local.json" ;;
    gitattributes:present) rec config present "$path: $detail" "" ;;
    gitattributes:missing) rec config missing "$path: $detail" "re-run $REL/Adapters/ai-runtimes/claude-code/install-hooks.sh" ;;
    *:fault) rec config indeterminate "$path" "$detail" ;;
    *) rec config "$st" "$path" "$detail" ;;
  esac
done <<< "$CHECK_OUT"
# An absent settings.json yields no hook record at all: say the entries were
# not evaluated, so "0 hook entries" never reads as clean (issue #282).
if [ "$SETTINGS_ABSENT" -eq 1 ] && [ "$HOOK_ENTRIES" -eq 0 ]; then
  rec config not-evaluated "hook entries" "settings.json is absent, so no framework hook entry is installed; the absent settings record above is the drift"
fi

CHECK_OUT=""
[ "$QUICK" -eq 1 ] || run_check install-skills.sh bash "$RUNTIME/install-skills.sh" --check
while IFS=$'\t' read -r fam st path detail; do
  case "$fam" in ''|'#'*) continue ;; esac
  case "$fam:$st" in
    skill:differs)
      # Every file of the installed skill against the history of its
      # counterpart: stale only if each one is a version the template had.
      SK_CLASS=stale; SK_WHY=""; SK_N=0
      while IFS= read -r -d '' _f; do
        SK_N=$((SK_N + 1))
        classify "$_f" "${detail#"$REL"/}/${_f#"$path"/}"
        case "$CLASS" in
          modified) [ "$SK_CLASS" = stale ] && SK_CLASS=modified ;;
          indeterminate) SK_CLASS=indeterminate; SK_WHY="$WHY" ;;
        esac
      done < <(find "$path" -type f -print0 2>/dev/null)
      [ "$SK_N" -eq 0 ] && { SK_CLASS=indeterminate; SK_WHY="no file in $path to compare"; }
      case "$SK_CLASS" in
        stale) rec config stale "$path" "never edited, an earlier version of the skill: cp -R $detail/. $path/" ;;
        modified) rec config modified "$path" "edited by the project: review diff -r $detail $path; never --force" ;;
        *) rec config indeterminate "$path" "$SK_WHY" ;;
      esac ;;
    skill:current) rec config current "$path" "" ;;
    skill:absent) rec config absent "$path" "re-run $REL/Adapters/ai-runtimes/claude-code/install-skills.sh without --force" ;;
    skill:not-applicable) rec config not-applicable "$path" "$detail" ;;
    gitattributes:present) rec config present "$path: $detail" "" ;;
    gitattributes:missing) rec config missing "$path: $detail" "re-run $REL/Adapters/ai-runtimes/claude-code/install-skills.sh" ;;
    *:fault) rec config indeterminate "$path" "$detail" ;;
    *) rec config "$st" "$path" "$detail" ;;
  esac
done <<< "$CHECK_OUT"

# ------------------------------------------------- D. broken paths ---

# words <command> — splits a command the way a shell would split plain words
# and quotes, WITHOUT evaluating anything: no expansion, no globbing, no
# substitution. Stops at the first unquoted operator (; | & < > ( )). Sets
# WORDS; resolve_command refuses a word that only a shell could expand.
words() {
  local s="$1" i c q="" w="" have=0
  WORDS=()
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    if [ "$q" = "'" ]; then
      if [ "$c" = "'" ]; then q=""; else w="$w$c"; fi
      continue
    fi
    if [ "$q" = '"' ]; then
      # Inside double quotes a backslash escapes only $ ` " \ (as in bash);
      # before anything else it is itself.
      if [ "$c" = "\\" ] && [ $((i + 1)) -lt ${#s} ] && [[ "${s:i+1:1}" == [\$\`\"\\] ]]; then
        i=$((i + 1)); w="$w${s:i:1}"
      elif [ "$c" = '"' ]; then q=""; else w="$w$c"; fi
      continue
    fi
    if [ "$c" = "\\" ] && [ $((i + 1)) -lt ${#s} ]; then
      i=$((i + 1)); w="$w${s:i:1}"; have=1; continue
    fi
    case "$c" in
      "'"|'"') q="$c"; have=1 ;;
      ' '|$'\t') [ "$have" -eq 1 ] && WORDS+=("$w"); w=""; have=0 ;;
      ';'|'|'|'&'|'<'|'>'|'('|')') break ;;
      *) w="$w$c"; have=1 ;;
    esac
  done
  [ "$have" -eq 1 ] && WORDS+=("$w")
  return 0
}

# resolve_command <command> — sets RSTATUS (ok|broken|unresolved), RPATH, RWHY.
resolve_command() {
  local k=0 n cand
  words "$1"
  n=${#WORDS[@]}
  # Leading NAME=value assignments and the wrappers that only run what follows.
  while [ "$k" -lt "$n" ]; do
    case "${WORDS[k]}" in
      [A-Za-z_]*=*|env|exec|command|nohup) k=$((k + 1)) ;;
      *) break ;;
    esac
  done
  # When the script word cannot be told for sure, the answer is `unresolved`,
  # never `broken`: a false `broken` sends its reader after a hook that works.
  case "${WORDS[k]:-}" in
    bash|sh|zsh|dash|*/bash|*/sh|*/zsh|*/dash)
      # A shell: short flags may be combined (-lc, -ec); one that holds c runs
      # inline code. -o/+o and -O/+O take an argument, and long options other than the
      # three below are not known here: unresolved.
      k=$((k + 1))
      while [ "$k" -lt "$n" ]; do
        case "${WORDS[k]}" in
          --login|--norc|--noprofile) k=$((k + 1)) ;;
          -o|+o|-O|+O|--*) RSTATUS=unresolved; RPATH="(none)"; RWHY="a shell option this check does not interpret (${WORDS[k]})"; return ;;
          -*c*|+*c*) RSTATUS=unresolved; RPATH="(inline code)"; RWHY="the shell runs inline code (${WORDS[k]}), not a script file"; return ;;
          -[a-zA-Z]*|+[a-zA-Z]*) k=$((k + 1)) ;;
          *) break ;;
        esac
      done
      cand="${WORDS[k]:-}"
      [ -n "$cand" ] || { RSTATUS=unresolved; RPATH="(none)"; RWHY="a shell with no script named"; return; }
      ;;
    node|python|python3|py|pwsh|powershell|ruby|perl|deno|bun|*/node|*/python|*/python3)
      # Any option (-m module, -c / -e code, -File, ...) or a subcommand
      # (deno run, bun x) and the script word is not certain: unresolved.
      k=$((k + 1))
      cand="${WORDS[k]:-}"
      case "$cand" in
        -*|'') RSTATUS=unresolved; RPATH="${cand:-(none)}"; RWHY="an interpreter option or no script word: not resolved, never run"; return ;;
      esac
      case "$cand" in
        */*|*.js|*.mjs|*.cjs|*.ts|*.py|*.rb|*.pl|*.ps1) ;;
        *) RSTATUS=unresolved; RPATH="$cand"; RWHY="not a script path (a subcommand or a module): not resolved, never run"; return ;;
      esac
      ;;
    '') RSTATUS=unresolved; RPATH="(none)"; RWHY="no command word"; return ;;
    *)
      cand="${WORDS[k]}"
      case "$cand" in
        */*|\\\\*) ;;
        *) RSTATUS=unresolved; RPATH="$cand"; RWHY="a command looked up on PATH, not a file path: not resolved"; return ;;
      esac ;;
  esac
  cand="${cand//\$\{CLAUDE_PROJECT_DIR\}/$PROJECT}"
  cand="${cand//\$CLAUDE_PROJECT_DIR/$PROJECT}"
  case "$cand" in
    *'$'*|*'`'*|*'*'*|*'?'*|'~'*)
      RSTATUS=unresolved; RPATH="$cand"; RWHY="the path needs a shell to expand it: not resolved, never run"; return ;;
    # A network path is never stat-ed: on Windows that opens an SMB
    # connection and can hand the user's NTLM hash to the named host
    # (SEC-IAENG-358-02). Windows reads / and \ alike, so any two of them
    # in any order (//, \\, /\, \/) open a UNC path.
    [/\\][/\\]*)
      RSTATUS=unresolved; RPATH="$cand"; RWHY="a network path: never touched by this check"; return ;;
  esac
  case "$cand" in
    /*|[A-Za-z]:[/\\]*) RPATH="$cand" ;;
    *) RPATH="$PROJECT/$cand" ;;
  esac
  if [ ! -e "$RPATH" ]; then
    RSTATUS=broken; RWHY="not found"
  elif [ -d "$RPATH" ]; then
    RSTATUS=broken; RWHY="a directory, not a script"
  elif [ ! -r "$RPATH" ]; then
    RSTATUS=broken; RWHY="not readable"
  else
    RSTATUS=ok; RWHY=""
  fi
  case "$RPATH" in "$PROJECT"/*) RPATH="${RPATH#"$PROJECT"/}" ;; esac
}

for SF in .claude/settings.json .claude/settings.local.json; do
  watch_add "$SF"
  [ -e "$SF" ] || [ -L "$SF" ] || continue
  if [ -L "$SF" ]; then
    rec path indeterminate "$SF" "a symbolic link: not followed, its commands are not resolved"
    continue
  fi
  if ! command -v jq >/dev/null 2>&1; then
    rec path indeterminate "$SF" "jq is not installed: the commands in this file are not resolved"
    continue
  fi
  if ! CMDS="$(jq -r 'paths(strings) as $p | select($p[-1] == "command")
                     | ($p | map(tostring) | join(".") | gsub("[[:cntrl:]]"; " "))
                       + "\t" + (getpath($p) | gsub("[[:cntrl:]]"; " "))' "$SF" 2>/dev/null)"; then
    rec path indeterminate "$SF" "not valid JSON: the commands in this file are not resolved"
    continue
  fi
  CMDS="${CMDS//$'\r'/}"
  while IFS=$'\t' read -r WHERE CMD; do
    [ -z "$WHERE" ] && continue
    resolve_command "$CMD"
    case "$RSTATUS" in ok|broken) watch_add "$RPATH" ;; esac
    case "$RSTATUS" in
      ok) rec path ok "$RPATH" "" ;;
      broken) rec path broken "$RPATH" "$RWHY; named by $SF ($WHERE). The hook fails (exit 127) and its guard is silently gone: restore the file, or fix the entry (re-run $REL/Adapters/ai-runtimes/claude-code/install-hooks.sh for the framework's)" ;;
      *) rec path unresolved "$RPATH" "$RWHY; named by $SF ($WHERE)" ;;
    esac
  done <<< "$CMDS"
done

# Where core.hooksPath is read from, for the --quick result: the project's
# config and the user's.
if [ "$CACHE_STATE" = miss ]; then
  if _gd="$(git rev-parse --git-common-dir 2>/dev/null)"; then watch_add "$_gd/config"; fi
  if [ -n "${HOME:-}" ]; then watch_add "$HOME/.gitconfig"; fi
  _xdg="${XDG_CONFIG_HOME:-${HOME:+$HOME/.config}}"
  if [ -n "$_xdg" ]; then watch_add "$_xdg/git/config"; fi
  unset _gd _xdg
fi
# --type=path expands a leading ~ as git itself does when it runs the hooks.
if HP="$(git config --type=path --get core.hooksPath 2>/dev/null)"; then
  case "$HP" in
    /*|[A-Za-z]:[/\\]*) HPA="$HP" ;;
    *) HPA="$PROJECT/$HP" ;;
  esac
  case "$HP" in
    [/\\][/\\]*) HPA="" ;;
  esac
  watch_add "$HPA"
  if [ -z "$HPA" ]; then
    rec path unresolved "$HP" "core.hooksPath is a network path: never touched by this check"
  elif [ "$HP" = "$REL/Adapters/git-hooks" ] || [ "$HP" = "./$REL/Adapters/git-hooks" ]; then
    # The relative value install.sh wrote before WU-IAENG-414 (issue #368).
    # It works in this checkout, so the directory test below calls it fine.
    # git reads it from the root of each worktree, though, and a linked
    # worktree has the framework submodule empty: git runs no hook there.
    rec path broken "$HP" "core.hooksPath is relative: a linked git worktree, where the framework submodule is empty, runs no hook at all. Re-run $REL/Adapters/scripts/install.sh"
  elif [ -d "$HPA" ]; then
    rec path ok "$HP" ""
  else
    rec path broken "$HP" "core.hooksPath names a directory that does not exist: git runs no hook at all. Re-run $REL/Adapters/scripts/install.sh"
  fi
fi

# An empty family is never a clean one (the Check Convention, rule 3).
if [ "$QUICK" -eq 1 ]; then
  rec config not-evaluated "(--quick)" "hook entries, skills, git hooks and .gitattributes are checked by a run without --quick: $REL/Adapters/scripts/check-framework-drift.sh"
fi

finish
