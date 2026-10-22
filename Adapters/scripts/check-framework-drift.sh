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
# is covered by the same snapshot test). GIT_TERMINAL_PROMPT=0: --remote
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
#   --help
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
while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-}"; shift ;;
    --format=*) FORMAT="${1#--format=}" ;;
    --strict) STRICT=1 ;;
    --remote) REMOTE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "check-framework-drift.sh: unknown option '$1' (try --help)" >&2; exit 64 ;;
  esac
  shift
done
case "$FORMAT" in
  text|tsv) ;;
  *) echo "check-framework-drift.sh: --format takes text or tsv" >&2; exit 64 ;;
esac

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME="$FRAMEWORK/Adapters/ai-runtimes/claude-code"

# ------------------------------------------------------------- records ---

ROWS=""
# flat <text> — every control character (TAB, LF, CR, ESC, ...) becomes a
# space: a record is one line and carries no terminal escape.
# The C1 controls (U+0080-U+009F, CSI among them) are UTF-8 pairs \xc2\x80 to
# \xc2\x9f: a pair becomes one space. A lone byte in that range is part of
# another character and is left alone (SEC-IAENG-358-01).
C1_LEAD=$'\xc2'
flat() {
  FLAT="${1//[[:cntrl:]]/ }"
  FLAT="${FLAT//"$C1_LEAD"[$'\x80'-$'\x9f']/ }"
}
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
        order["file"] = "current absent stale modified customized project-owned indeterminate"
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

# ------------------------------------------------------- where we are ---

if ! PROJECT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  NA=1
  rec version indeterminate "." "not inside a git repository: run it from the root of the adopting project"
  finish
fi
cd "$PROJECT" || exit 1
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
if _top="$(git -C "$FRAMEWORK" rev-parse --show-toplevel 2>/dev/null)" && [ "$_top" -ef "$FRAMEWORK" ]; then
  FW_GIT=1
  FW_SHALLOW="$(git -C "$FRAMEWORK" rev-parse --is-shallow-repository 2>/dev/null || echo unknown)"
fi

# ------------------------------------------------------- A. version ---

if [ "$FW_GIT" -eq 0 ]; then
  rec version indeterminate "$REL" "the framework copy is not its own git checkout: no commit, tag or history to read"
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
run_check setup-project-bootstrap.sh bash "$SCRIPT_DIR/setup-project-bootstrap.sh" --check
while IFS=$'\t' read -r fam st path detail; do
  case "$fam" in ''|'#'*) continue ;; esac
  [ "$st" = fault ] && BOOT_FAULT=1
  case "$fam:$st" in
    file:current) rec file current "$path" "" ;;
    file:absent) rec file absent "$path" "re-run $BOOTSTRAP_CMD without --force: it writes what is absent and overwrites nothing" ;;
    file:customized) rec file customized "$path" "expected to differ: the project edits it after install" ;;
    file:differs)
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

# .claude/settings.json and its hook entries.
SETTINGS_ABSENT=0
HOOK_ENTRIES=0
run_check install-hooks.sh bash "$RUNTIME/install-hooks.sh" --check
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

run_check install-skills.sh bash "$RUNTIME/install-skills.sh" --check
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
    case "$RSTATUS" in
      ok) rec path ok "$RPATH" "" ;;
      broken) rec path broken "$RPATH" "$RWHY; named by $SF ($WHERE). The hook fails (exit 127) and its guard is silently gone: restore the file, or fix the entry (re-run $REL/Adapters/ai-runtimes/claude-code/install-hooks.sh for the framework's)" ;;
      *) rec path unresolved "$RPATH" "$RWHY; named by $SF ($WHERE)" ;;
    esac
  done <<< "$CMDS"
done

# --type=path expands a leading ~ as git itself does when it runs the hooks.
if HP="$(git config --type=path --get core.hooksPath 2>/dev/null)"; then
  case "$HP" in
    /*|[A-Za-z]:[/\\]*) HPA="$HP" ;;
    *) HPA="$PROJECT/$HP" ;;
  esac
  case "$HP" in
    [/\\][/\\]*) HPA="" ;;
  esac
  if [ -z "$HPA" ]; then
    rec path unresolved "$HP" "core.hooksPath is a network path: never touched by this check"
  elif [ -d "$HPA" ]; then
    rec path ok "$HP" ""
  else
    rec path broken "$HP" "core.hooksPath names a directory that does not exist: git runs no hook at all. Re-run $REL/Adapters/scripts/install.sh"
  fi
fi

finish
