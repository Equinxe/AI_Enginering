#!/usr/bin/env bash
# IA Engineering — Claude Code SessionStart hook (matcher: startup|resume|clear|compact)
#
# Mechanically enforces Core/AGENT_CONDUCT.md, Read First: whatever this hook
# prints to stdout is added to the model's context at the start of the
# session, so the reading order is not something the model has to remember —
# it is the first thing it sees. It prints the pointers and the *current*
# state, never a copy of CLAUDE.md (one fact, one place — Templates/SESSION_STATE.md).

# This hook's own directory, never the working directory (issue #344). It is
# taken from $0 when $0 holds a / or \, because the environment cannot set $0.
# A bare $0 means bash found the hook through PATH or in the working
# directory, where dirname "$0" would name the working directory; then
# BASH_SOURCE[0], the path bash found, is used. BASH_SOURCE is not taken first
# because bash 5.3 imports it from the environment (SEC-IAENG-400-01). Both
# separators count, as Git Bash's dirname reads both. Every file this hook
# loads or runs comes from here.
HOOKS_DIR="$0"
case "$HOOKS_DIR" in */*|*\\*) ;; *) HOOKS_DIR="${BASH_SOURCE[0]}" ;; esac
case "$HOOKS_DIR" in
  */*|*\\*) HOOKS_DIR="${HOOKS_DIR%[/\\]*}" ;;
  *) HOOKS_DIR=. ;;
esac
# shellcheck source=lib.sh
. "$HOOKS_DIR/lib.sh"

BASE="${CLAUDE_PROJECT_DIR:-.}"
ROOT="$(iaeng_framework_root || true)"
STATE="$BASE/.ia-engineering/SESSION_STATE.md"

# a_flat <text> — A_FLAT is the text with every control character a space,
# the C1 pairs \xc2\x80 to \xc2\x9f included, read byte by byte as the record
# sanitiser reads them (SEC-IAENG-358-01): what is printed of a path never
# carries a terminal escape into the session.
a_flat() {
  local LC_ALL=C c1=$'\xc2'
  A_FLAT="${1//[[:cntrl:]]/ }"
  A_FLAT="${A_FLAT//"$c1"[$'\x80'-$'\x9f']/ }"
}
# a_sq <text> — A_SQ is the text as one single-quoted shell word, so a path
# with a space runs as printed.
a_sq() {
  local q="'" e="'\\''"
  A_SQ="$q${1//"$q"/"$e"}$q"
}
# a_word <path> — A_WORD is the path as one shell word that runs as printed
# (issue #417): flattened, and single-quoted only when it holds a character a
# shell reads specially, a space included. An absolute path printed bare
# split at the space of C:/Users/my name/... and exited 127. No process.
a_word() {
  a_flat "$1"; A_WORD="$A_FLAT"
  case "$A_WORD" in
    *[!A-Za-z0-9_./:=,+@%-]*) a_sq "$A_WORD"; A_WORD="$A_SQ" ;;
  esac
}
# a_cmd <framework file> — A_CMD_WORD is that file as one shell word that
# runs as printed from the project root: ./<its path from the project root>
# when the framework is inside the project, its own path otherwise (a_word).
a_cmd() {
  local p="$1"
  case "$p" in "$BASE"/*) p="./${p#"$BASE"/}" ;; esac
  a_word "$p"; A_CMD_WORD="$A_WORD"
}

# ss_unfilled <text> — true when the text is one bracketed span and nothing
# else, the shape of a template placeholder: "[The very next concrete
# action ...]". Text of its own that merely opens with a bracket, "[WU-12]
# merge it", has a "]" before its end and is not one (issue #367). The
# shape is all it reads, so an entry of the project's own written wholly in
# brackets, "[PR #12 waiting for the Director]", has it too: SS_FIRST is the
# text's first line, cut at 160 bytes, which the line then shows, so such an
# entry is read, not hidden.
ss_unfilled() {
  local t="$1"
  [ "${#t}" -ge 2 ] && [ "${t:0:1}" = "[" ] && [ "${t: -1}" = "]" ] || return 1
  SS_FIRST="${1%%$'\n'*}"
  [ "${#SS_FIRST}" -gt 160 ] && SS_FIRST="${SS_FIRST:0:160}..."
  t="${t:1:${#t}-2}"
  [[ "$t" != *"]"* ]]
}

echo "IA Engineering — read first, then say in one line what you read and what you are about to do (Core/AGENT_CONDUCT.md, Read First):"
echo

# --- CLAUDE.md ---------------------------------------------------------
# Mirrors the SESSION_STATE branch below: a project that has not yet
# finished Workflows/ONBOARDING.md Step 1 has no CLAUDE.md yet, and
# asserting one exists — as this line unconditionally did before
# WU-IAENG-302 — misleads the very first thing the model reads in the
# session. Nor does it say the project skipped Workflows/PROJECT_BOOTSTRAP.md
# Phase B: an existing project that adopts the framework has no Phase A or B,
# so that line sent it to a workflow that does not apply (issue #367). Both
# routes are named, since the hook cannot tell them apart.
if [ -f "$BASE/CLAUDE.md" ]; then
  echo "  1. CLAUDE.md — the project's stable contract."
else
  if [ -n "$ROOT" ] && [ -f "$ROOT/Templates/PROJECT_CLAUDE.md" ]; then
    echo "  1. CLAUDE.md does not exist yet. The DevOps Engineer writes it from $ROOT/Templates/PROJECT_CLAUDE.md after the adoption commit ($ROOT/Workflows/ONBOARDING.md Step 1 item 2): from the Project Charter and the Stack Decision ADR in a new project, from the project's code, its existing documents and the Director in an existing one."
  else
    echo "  1. CLAUDE.md does not exist yet and the framework's template was not found (looked for Core/AGENT_CONDUCT.md at ., ia-engineering/, \$IAENG_FRAMEWORK)."
  fi
fi
if [ -f "$STATE" ]; then
  echo "  2. .ia-engineering/SESSION_STATE.md — where things actually stand. Never committed."
  LAST="$(grep -m1 -E '^_Last updated:' "$STATE" | sed 's/^_//; s/_$//')"
  [ -n "$LAST" ] && echo "     $LAST"
  # Each section read whole, its line-ending CRs dropped, so a placeholder
  # is seen as one even past the lines shown. A section shaped as the
  # template's placeholder is read as unfilled: copied as it stood, it read
  # as the Next Step to take (issue #367). Its first line is still shown,
  # since the shape alone cannot tell the placeholder from an entry written
  # in brackets. At most five lines of the Next Step and three of Blocked On
  # are shown, cut in the shell.
  NEXT="$(awk '/^## Next Step/{f=1; next} /^## /{f=0} { sub(/\r$/, "") } f && NF' "$STATE")"
  if [ -n "$NEXT" ] && ss_unfilled "$NEXT"; then
    echo "     Next Step: read as not filled in: one bracketed text, the shape of the template's placeholder. It begins: $SS_FIRST"
    echo "       Write the next concrete step there, outside brackets."
  elif [ -n "$NEXT" ]; then
    echo "     Next Step, as recorded:"
    n_i=0
    while IFS= read -r n_l && [ "$n_i" -lt 5 ]; do
      printf '       %s\n' "$n_l"; n_i=$((n_i + 1))
    done <<< "$NEXT"
  fi
  # Nothing is said when a line of it begins "Nothing" or "[Nothing", in any
  # letter case, as the grep it replaces read it.
  BLOCKED="$(awk '/^## Blocked On/{f=1; next} /^## /{f=0} { sub(/\r$/, "") } f && NF' "$STATE")"
  shopt -s nocasematch
  case $'\n'"$BLOCKED" in
    $'\n'|*$'\n'nothing*|*$'\n''[nothing'*) ;;
    *)
      if ss_unfilled "$BLOCKED"; then
        echo "     Blocked On: read as not filled in: one bracketed text, the shape of the template's placeholder. It begins: $SS_FIRST"
        echo "       Write there, outside brackets, what waits on whom, or \"Nothing\"."
      else
        echo "     Blocked on:"
        n_i=0
        while IFS= read -r n_l && [ "$n_i" -lt 3 ]; do
          printf '       %s\n' "$n_l"; n_i=$((n_i + 1))
        done <<< "$BLOCKED"
      fi ;;
  esac
  shopt -u nocasematch

  # mtime is computed once and used by both Warning 1 and Warning 2: it is
  # the file's own record of when it was last touched, independent of
  # whether the header inside it was updated in the same edit (Warning 2
  # exists because it often was not).
  STATE_MTIME="$(iaeng_file_mtime "$STATE")"

  # --- Warning 1: behind the repository -----------------------------------
  # A future HEAD_TS (clock skew, or a deliberately future-dated commit) is
  # never compared against mtime at all: a clamp-and-compare against a
  # live-read "now" looked right (a file touched in the same second passed)
  # but was not — "now" moves forward on every invocation while mtime stays
  # fixed, so it silently re-warned a second later with no edit made. A
  # future HEAD_TS is instead reported as its own, distinct condition.
  if [ -n "$STATE_MTIME" ] && git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    HEAD_TS="$(iaeng_head_commit_time "$BASE")"
    NOW="$(iaeng_now)"
    if [ -n "$HEAD_TS" ] && [ -n "$NOW" ] && [ "$HEAD_TS" -gt "$NOW" ]; then
      HEAD_CDATE="$(git -C "$BASE" log -1 --format=%cd 2>/dev/null)"
      echo "     WARNING: HEAD's last commit is dated after the system clock ($HEAD_CDATE vs. $(date 2>/dev/null)) — cannot verify SESSION_STATE.md's freshness; check it by hand."
    elif [ -n "$HEAD_TS" ] && [ "$STATE_MTIME" -lt "$HEAD_TS" ]; then
      BEHIND="$(git -C "$BASE" rev-list --count --since="@$STATE_MTIME" HEAD 2>/dev/null)"
      if [ -n "$BEHIND" ] && iaeng_is_int "$BEHIND"; then
        echo "     WARNING: SESSION_STATE.md is $BEHIND commit(s) behind the repository — refresh it before acting."
      else
        echo "     WARNING: SESSION_STATE.md is behind the repository (commit count unavailable) — refresh it before acting."
      fi
    fi
  fi

  # --- Warning 2: header not refreshed on the last edit -------------------
  # The header is free-text ("DD Month YYYY, morning/evening by ..."), so
  # this parses defensively: an unparsable header is reported as such, never
  # silently skipped — that silence is exactly the failure mode this Work
  # Unit exists to catch (the header can go stale while the body keeps
  # moving, and nothing said so).
  if [ -n "$STATE_MTIME" ]; then
    HEADER_DATE="$(printf '%s' "$LAST" | grep -oE '[0-9]{1,2} [A-Za-z]+ [0-9]{4}' | head -1)"
    if [ -n "$HEADER_DATE" ]; then
      HEADER_YMD="$(iaeng_ymd_from_header_date "$HEADER_DATE")"
      MTIME_YMD="$(date -r "$STATE" +%Y-%m-%d 2>/dev/null)"
      if [ -n "$HEADER_YMD" ] && [ -n "$MTIME_YMD" ]; then
        if [[ "$HEADER_YMD" < "$MTIME_YMD" ]]; then
          echo "     WARNING: the _Last updated: header ($HEADER_DATE) was not refreshed on the file's last edit ($MTIME_YMD) — update it every time the body changes."
        fi
      else
        echo "     WARNING: the _Last updated: header's date could not be parsed for freshness comparison — verify it was refreshed by hand."
      fi
    else
      echo "     WARNING: no parsable date found in the _Last updated: header — verify it was refreshed by hand."
    fi
  fi

  # No size check. SESSION_STATE.md has no size limit, by Director decision
  # (22 October 2026): it is the agent's memory of what was done, and the
  # one file allowed to grow long and keep its history. The 15,000-character
  # warning that stood here (WU-IAENG-287) was removed by WU-IAENG-368.
else
  if [ -n "$ROOT" ] && [ -f "$ROOT/Templates/SESSION_STATE.md" ]; then
    a_cmd "$ROOT/Adapters/scripts/create-session-state.sh"
    echo "  2. .ia-engineering/SESSION_STATE.md does not exist. Create it before any other action: from the project root, run $A_CMD_WORD, which writes the Template block of $ROOT/Templates/SESSION_STATE.md with today's date (after the project's first commit); it is gitignored and refused by the pre-commit hook."
  else
    echo "  2. .ia-engineering/SESSION_STATE.md does not exist and the framework's template was not found (looked for Core/AGENT_CONDUCT.md at ., ia-engineering/, \$IAENG_FRAMEWORK)."
  fi
fi
echo "  3. The Employee Brief for the Work Unit, and the Standards it names."
if [ -n "$ROOT" ] && [ -f "$ROOT/Core/MAIN_AGENT_CONDUCT.md" ]; then
  echo "  The Main Agent follows $ROOT/Core/MAIN_AGENT_CONDUCT.md: delegate every Work Unit to its named Employee, and present the plan to the Director before executing."
fi
echo

# --- Tier map in force (WU-IAENG-336) ----------------------------------------
# The project's tier map decides which concrete model each tier runs on. The
# two default tiers reach the session through the generated agents' model:
# lines; the override-only tiers (Lightweight, Frontier) reached it nowhere —
# they were printed in generate-agents.sh's summary and then lost, so a Main
# Agent applying a Lightweight Tier Override in a project mapping every tier
# to claude-opus-5-5 dispatched with "sonnet" (issue #212). The mapping is
# resolved by the generator itself (--print-tier-map: flags > file > target
# defaults), never re-parsed here, so there is one parser and one set of
# defaults. A file the generator refuses is reported, not skipped: a session
# told nothing would go back to inventing a model.
#
# The same call checks the agents (WU-IAENG-434): --check --quick, below. Run
# from the project, with --project ., so the command it prints to regenerate
# them runs as printed from where a session works.
GEN="${ROOT:+$ROOT/Adapters/ai-runtimes/generate-agents.sh}"
if [ -n "$GEN" ] && [ -f "$GEN" ]; then
  # Claude Code watches only the agents directories that existed when the
  # session started: one created later is loaded by the next session. Read
  # before anything can create it.
  A_DIR_AT_START=0
  [ -d "$BASE/.claude/agents" ] && A_DIR_AT_START=1
  TIER_OUT="$(CDPATH='' cd -- "$BASE" 2>&1 && bash "$GEN" --target claude-code --project . --print-tier-map --check --quick --format tsv 2>&1)"
  TIER_RC=$?
  # One pass over the output, in the shell: no process per line read. The
  # map lines, the quick check's records, its summary and its command.
  TIER_MAP=""; TIER_SRC=""; TIER_EFFORT=""
  A_SUM=""; A_CMD=""; A_WHY=""; A_MISS=(); A_STALE=(); A_OLD=(); A_NOREAD=()
  while IFS= read -r t_l; do
    case "$t_l" in
      map=*) [ -n "$TIER_MAP" ] || TIER_MAP="$t_l" ;;
      effort-map=*) [ -n "$TIER_EFFORT" ] || TIER_EFFORT="$t_l" ;;
      '# mapping: '*) [ -n "$TIER_SRC" ] || TIER_SRC="${t_l#'# mapping: '}" ;;
      '# generate-agents.sh --check --quick: '*) A_SUM="$t_l" ;;
      '# regenerate: '*) [ -n "$A_CMD" ] || A_CMD="${t_l#'# regenerate: '}" ;;
      agent$'\t'*)
        # agent TAB status TAB path TAB detail. Only the file's name is
        # shown: the generator writes <slug>.md, the slug made of a-z, 0-9
        # and - alone, and flattens every field. No other text of a record,
        # the root an agent names included, reaches the session. The detail
        # only sorts a stale agent: its framework commit is not the one in
        # use (#471), git gives no commit for this framework (no upgrade is
        # needed for that: a copied framework, or a checkout git refuses to
        # read), or its framework root is not this framework.
        a_r="${t_l#agent$'\t'}"; a_s="${a_r%%$'\t'*}"; a_r="${a_r#*$'\t'}"
        a_p="${a_r%%$'\t'*}"; a_d=""
        case "$a_r" in *$'\t'*) a_d="${a_r#*$'\t'}" ;; esac
        a_p="${a_p##*/}"; a_p="${a_p%.md}"
        case "$a_s:$a_d" in
          missing:*) A_MISS+=("$a_p") ;;
          'stale:it was generated from framework commit '*', and git gives no commit for this framework'*) A_NOREAD+=("$a_p") ;;
          'stale:it was generated from framework commit '*|'stale:it records no framework commit'*) A_OLD+=("$a_p") ;;
          stale:*) A_STALE+=("$a_p") ;;
        esac ;;
      *) [ -n "$A_WHY" ] || A_WHY="$t_l" ;;
    esac
  done <<< "$TIER_OUT"
  # 0 or 1 is the quick check's verdict; the map is printed either way. Any
  # other exit, or no map line, is a refusal.
  if [ "$TIER_RC" -le 1 ] && [ -n "$TIER_MAP" ]; then
    tier_of() { sed -n "s/.*[=,]$1=\([^,]*\).*/\1/p" <<< "$TIER_MAP"; }
    T_STRATEGIC="$(tier_of strategic)"
    T_STANDARD="$(tier_of standard)"
    T_LIGHTWEIGHT="$(tier_of lightweight)"
    echo "Tier map in force — mapping: $TIER_SRC"
    echo "  $TIER_MAP"
    echo "  $TIER_EFFORT"
    echo "  A Tier Override (Core/CAPABILITY_TIERS.md) runs the Work Unit on the model this map gives the target tier — never on a model or alias of the Main Agent's own choosing. When that model is the one the Employee's generated agent already pins, dispatch with no model parameter; otherwise pass exactly that value, and if the dispatch cannot take it, stop and ask the Director rather than substitute one (Adapters/ai-runtimes/README.md, How a per-Work-Unit Execution tier is actually run)."
    if [ -n "$T_LIGHTWEIGHT" ] && [ "$T_LIGHTWEIGHT" = "$T_STANDARD" ] && [ "$T_LIGHTWEIGHT" = "$T_STRATEGIC" ]; then
      echo "  Here Strategic Judgment, Standard Execution and Lightweight Execution all map to $T_LIGHTWEIGHT: an override between them changes no model — dispatch without a model parameter."
    fi
  else
    echo "WARNING: the tier map could not be resolved — $(head -1 <<< "$TIER_OUT")"
    echo "  Fix .ia-engineering/tier-map (Adapters/ai-runtimes/README.md). Until then a Tier Override has no model to use: ask the Director rather than pick one."
  fi
  echo

  # --- The Employees' agents, present and naming this framework (WU-IAENG-434)
  # .claude/agents/ is per clone, gitignored and never committed, so a fresh
  # clone or a second machine has none, and since WU-IAENG-430 an adopting
  # project's agents name the absolute framework root of the clone that
  # generated them. Session start checks each agent's framework root is the
  # project's framework, by identity (generate-agents.sh --check --quick),
  # never because that directory exists: a moved project or a copied clone
  # would otherwise send every Employee to read the Standards somewhere else.
  # Said at every session until they are regenerated, with the command that
  # regenerates them, as the generator prints it. Nothing when every agent is
  # present and names this framework. Their content is compared by
  # check-framework-drift.sh without --quick, which costs a generation. When
  # the tier map was refused, the generator stopped before this check, and the
  # warning above says what to fix first.
  #
  # An upgrade that changes only Employees/ left every agent naming this root,
  # so nothing was said while each Employee followed its old definition
  # (#471). Each agent of an adopting project now records the framework
  # commit it was generated from, and the quick check compares it with the
  # commit in use: one that differs, or that an agent does not record, is
  # stale too, detected with no command to type (Director decision, 18
  # November 2026). An agent recording a commit while git gives none for
  # this framework has its own clause: no upgrade need be the cause.
  if [ "$TIER_RC" -le 1 ] && [ -n "$TIER_MAP" ]; then
    a_flat "$GEN"; a_sq "$A_FLAT"; A_GEN="$A_SQ"
    A_N="${A_SUM#*to act on. }"; A_N="${A_N%% agent(s)*}"
    case "$A_N" in ''|*[!0-9]*) A_N="" ;; esac
    # Every case where an Employee cannot be dispatched by name ends on the
    # same rule: no generic agent in its place (Core/MAIN_AGENT_CONDUCT.md,
    # Dispatch Discipline), and a failure goes to the Director.
    A_RULE="Until a named Employee can be dispatched, dispatch none, and never a generic agent in its place (Core/MAIN_AGENT_CONDUCT.md, Dispatch Discipline). If the command fails, stop and report it to the Director."
    if [ -z "$A_N" ]; then
      # No verdict is never silence: the check did not run to its end.
      a_flat "$A_WHY"; A_WHY="$A_FLAT"
      [ "${#A_WHY}" -gt 160 ] && A_WHY="${A_WHY:0:160}..."
      echo "IA Engineering agents: not checked (${A_WHY:-the check gave no result}). Until the check passes, dispatch no Employee, and never a generic agent in its place, and report the cause to the Director. Check them by hand: bash $A_GEN --check --quick"
      echo
    elif [ "${#A_MISS[@]}" -gt 0 ] || [ "${#A_STALE[@]}" -gt 0 ] || [ "${#A_OLD[@]}" -gt 0 ] || [ "${#A_NOREAD[@]}" -gt 0 ]; then
      # a_list <items...> — "a, b, c and 2 more".
      a_list() {
        local out="" i=0 x
        for x in "$@"; do
          i=$((i + 1))
          [ "$i" -le 3 ] && out="${out:+$out, }$x"
        done
        [ "$i" -gt 3 ] && out="$out and $((i - 3)) more"
        printf '%s' "$out"
      }
      A_TXT=""
      if [ "${#A_MISS[@]}" -gt 0 ]; then
        A_TXT="${#A_MISS[@]} of $A_N roster Employees have no agent in .claude/agents/ ($(a_list "${A_MISS[@]}"))"
      fi
      if [ "${#A_STALE[@]}" -gt 0 ]; then
        A_TXT="${A_TXT:+$A_TXT; }${#A_STALE[@]} of $A_N agents are stale ($(a_list "${A_STALE[@]}")): the framework root each one names is not this project's framework, so its Employee would read the framework somewhere else. The project moved, or they were generated in another clone or before agents named a root"
      fi
      if [ "${#A_OLD[@]}" -gt 0 ]; then
        A_TXT="${A_TXT:+$A_TXT; }${#A_OLD[@]} of $A_N agents are stale ($(a_list "${A_OLD[@]}")): they were not generated from the framework commit in use, but before an upgrade or before agents recorded their commit, so each Employee may follow a definition the upgrade changed"
      fi
      if [ "${#A_NOREAD[@]}" -gt 0 ]; then
        a_cmd "$ROOT"
        A_TXT="${A_TXT:+$A_TXT; }${#A_NOREAD[@]} of $A_N agents are stale ($(a_list "${A_NOREAD[@]}")): each records a framework commit, but git gives none for this framework: it was copied in rather than checked out, or git refuses to read its checkout (git -C $A_CMD_WORD rev-parse --show-toplevel says which)"
      fi
      a_flat "$A_CMD"; A_CMD="$A_FLAT"
      echo "IA Engineering agents: $A_TXT. Agents are generated in each clone and never committed. Regenerate them before dispatching any Employee: ${A_CMD:-bash $A_GEN}"
      # A stale agent may mean a moved project, whose core.hooksPath still
      # names the old path, so no git hook runs until install.sh rewrites it
      # (QA-467-02, #470): said in one sentence, with the path from the
      # project root, quoted only when it needs it. Not for an agent that is
      # stale by its commit alone: its root is this framework.
      A_MOVED=""
      if [ "${#A_STALE[@]}" -gt 0 ]; then
        a_cmd "$ROOT/Adapters/scripts/install.sh"
        A_MOVED="If the project moved, also re-run $A_CMD_WORD: core.hooksPath still names the old path, so no git hook runs. "
      fi
      # The restart clause only when the directory did not exist at session
      # start: a file added to a directory that did is loaded within seconds.
      if [ "$A_DIR_AT_START" -eq 0 ]; then
        echo "  .claude/agents/ did not exist when this session started, so Claude Code loads the agents only in a new session: run the command, then ask the Director to restart the session. $A_MOVED$A_RULE"
      else
        echo "  $A_MOVED$A_RULE"
      fi
      echo
    fi
  fi
fi

if git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Repository state now:"
  git -C "$BASE" status --short --branch 2>/dev/null | head -15 | sed 's/^/  /'
  echo
fi

# --- Framework drift, at a glance (WU-IAENG-359) ----------------------------
# The Director's requirement (21 Oct 2026): checks run on their own in the
# flow of the session, never behind a flag a person must remember, and say
# nothing when everything is current. DEF-IAENG-REL014-01 is the case: an
# adopter one upgrade behind failed a required check and nothing told it.
#
# check-framework-drift.sh --quick (A version, B files by plain diff, D hook
# command paths) is read as tsv, and at most three lines are printed, one per
# family, only for what is actionable, each naming the command that explains
# it. Its result is kept in a user-level cache, so an unchanged project costs
# a stat (the script's header, --QUICK). Never in the framework repository,
# which validate-framework.sh covers. Bounded: TERM at 2.8 s, KILL 0.2 s later;
# `timeout` ends the whole process group, so no process of that run outlives
# the hook. A fault or an incomplete check is said ONCE (remembered beside the
# cache) and then not again until it changes or a run completes. Nothing here
# can fail the session.
#
# An overrun (WU-IAENG-418, issue #366). Under Git for Windows a cold --quick
# took 4.9 to 5.6 s in the 28 Oct rehearsal, and on a machine busy with other
# agents every process launch costs seconds, so even a cache hit can take
# 20 s: no run cut at 2.8 s ever kept anything, and every later session was
# cut too, in silence. Now the cut run is started again, detached from the
# hook's output and bounded at 300 s. It keeps its result in the cache, and
# beside the cache it leaves the next session two files, each beginning with
# a "project TAB <path>" line: bg-<project>, then "started <pid>" and later
# "done <exit>"; and bg-<project>.tsv, then its output.
# A session whose own run is cut again reports from that output, read and
# capped exactly as a run's (and said to come from an earlier run), so a
# verdict reaches the session even when no run fits the budget. A run still
# going is said once; a run that ended with no result is said at EVERY session
# until one completes: no result is never silence (Adapters/README.md, the
# Check Convention, rule 1). The command these lines name keeps its result in
# the same cache by hand. Declared limit: the result reported after an
# overrun is the earlier run's, so a change made since shows one session late.
DRIFT_SH="${ROOT:+$ROOT/Adapters/scripts/check-framework-drift.sh}"
if [ -n "$DRIFT_SH" ] && [ -f "$DRIFT_SH" ] && ! [ "$ROOT" -ef "$BASE" ]; then
  DRIFT_SHOWN="$ROOT"
  case "$ROOT" in "$BASE"/*) DRIFT_SHOWN="${ROOT#"$BASE"/}" ;; esac
  DRIFT_SHOWN="${DRIFT_SHOWN#./}"
  # Quoted only when it needs it, so a framework outside the project, or
  # imported under a name with a space, runs as printed too (issue #417).
  a_word "$DRIFT_SHOWN/Adapters/scripts/check-framework-drift.sh"
  DRIFT_RUN="bash $A_WORD"
  # The user's cache directory, or, when that lies inside the project (a
  # $HOME that is itself a repository, a dev container), a per-user one in
  # $TMPDIR; never one inside the project (lib.sh, iaeng_cache_dir). The
  # script applies the same rule again, and trusts the directory only when
  # the user alone can write it (SEC-IAENG-359-01, -03).
  DRIFT_CACHE=""
  D_PRIMARY=""
  if [ -n "${XDG_CACHE_HOME:-}" ]; then
    D_PRIMARY="$XDG_CACHE_HOME/ia-engineering"
  elif [ -n "${HOME:-}" ]; then
    D_PRIMARY="$HOME/.cache/ia-engineering"
  fi
  for d_c in "$D_PRIMARY" "${TMPDIR:-/tmp}/ia-engineering-${EUID:-0}"; do
    if [ -n "$d_c" ] && iaeng_cache_dir "$d_c" "$BASE" DRIFT_CACHE; then
      break
    fi
  done
  case "$BASE" in
    /*|[A-Za-z]:*) DRIFT_KEY="$BASE" ;;
    *) DRIFT_KEY="$PWD/$BASE" ;;
  esac
  DRIFT_SAID="${DRIFT_CACHE:+$DRIFT_CACHE/said-${DRIFT_KEY//[^A-Za-z0-9._-]/_}}"
  DRIFT_BG="${DRIFT_CACHE:+$DRIFT_CACHE/bg-${DRIFT_KEY//[^A-Za-z0-9._-]/_}}"
  DRIFT_BGV="${DRIFT_BG:+$DRIFT_BG.tsv}"
  # The command that runs the check as the hook does and keeps its result in
  # the cache the next session reads: what an overrun line tells a person to
  # run. Without a cache there is nothing to keep: the full check instead.
  DRIFT_FILL="$DRIFT_RUN"
  if [ -n "$DRIFT_CACHE" ]; then
    printf -v d_q '%q' "$DRIFT_CACHE"
    DRIFT_FILL="$DRIFT_RUN --quick --cache-dir $d_q"
  fi

  # drift_once <line> — prints it unless it is the line said last time. The
  # memory is read only when the user alone could have written it, and
  # written through a new file renamed into place: never through a link.
  drift_once() {
    local prev=""
    if [ -n "$DRIFT_SAID" ] && [ -f "$DRIFT_SAID" ] \
       && ! iaeng_untrusted "$DRIFT_CACHE" "$DRIFT_SAID"; then
      IFS= read -r prev < "$DRIFT_SAID" || true
    fi
    [ "$prev" = "$1" ] && return 0
    printf '%s\n\n' "$1"
    [ -n "$DRIFT_SAID" ] && [ ! -L "$DRIFT_SAID" ] || return 0
    if [ ! -d "$DRIFT_CACHE" ]; then
      mkdir -p "${DRIFT_CACHE%/*}" 2>/dev/null
      mkdir -m 700 "$DRIFT_CACHE" 2>/dev/null
    fi
    if [ -d "$DRIFT_CACHE" ] && ! iaeng_untrusted "$DRIFT_CACHE"; then
      { (umask 077; printf '%s\n' "$1" > "$DRIFT_SAID.$$.tmp") \
          && mv -f "$DRIFT_SAID.$$.tmp" "$DRIFT_SAID"; } 2>/dev/null
      [ -e "$DRIFT_SAID.$$.tmp" ] && rm -f "$DRIFT_SAID.$$.tmp" 2>/dev/null
      # The said-once memory and background-run files of projects gone or
      # quiet for 30 days are removed here, where a line is written, so a
      # session that says nothing starts no process for it: they piled up
      # from every rehearsal (issue #367). Regular files only (-type f is
      # false for a link), named as this hook names them, at the top of a
      # cache directory the user alone can write. A project still drifting
      # after 30 days hears its line once more.
      find "$DRIFT_CACHE" -maxdepth 1 -type f \( -name 'said-*' -o -name 'bg-*' \) \
        -mtime +30 -exec rm -f {} + 2>/dev/null
    fi
    return 0
  }
  # d_cap <text> — D_CAPPED: the text cut at 160 bytes. Every free-text
  # field printed here was read from the check or its cache, and becomes the
  # session's context: none can carry more than that (SEC-IAENG-359-01).
  d_cap() {
    D_CAPPED="$1"
    [ "${#D_CAPPED}" -gt 160 ] && D_CAPPED="${D_CAPPED:0:160}..."
    return 0
  }

  # The background run's two files begin with the project they are about:
  # their names are the path with every other character made "_", so two
  # projects can share them ("/w/a/b" and "/w/a_b"), and a file about another
  # project is not this one's (as the script's cache_replay checks its own).
  D_BGHEAD="project"$'\t'"$DRIFT_KEY"

  # d_bg_load — what the background run of an earlier session left, read
  # only when the user alone could have written it and it is about this
  # project. Called only where DRIFT_BG is set. DRIFT_BGS is "" (nothing
  # readable as this hook's own), running, ended (stopped from outside: gone
  # with no report, or started more than 6 minutes ago, past its own 300 s
  # bound, so a reused pid cannot keep it "running"), done, or failed <exit>.
  # The status line is matched whole, so no text of it reaches the session.
  # D_BGV is 1 when that run's output is in DRIFT_OUT, at most 400 lines, for
  # d_result to read as it reads a run's. It is a file, so it is read as
  # data: every control character but the TAB that separates fields becomes
  # a space again, the C1 pairs as the script flattens them
  # (SEC-IAENG-357-01, -358-01).
  d_bg_load() {
    local l="" p="" n=0 c1=$'\xc2' LC_ALL=C
    local -a fs=()
    DRIFT_BGS=""; D_BGV=0; DRIFT_OUT=""
    [ -f "$DRIFT_BG" ] && fs+=("$DRIFT_BG")
    [ -f "$DRIFT_BGV" ] && fs+=("$DRIFT_BGV")
    [ "${#fs[@]}" -gt 0 ] || return 0
    iaeng_untrusted "$DRIFT_CACHE" "${fs[@]}" && return 0
    if [ -f "$DRIFT_BG" ]; then
      { IFS= read -r p; IFS= read -r l; } < "$DRIFT_BG"
      if [ "$p" = "$D_BGHEAD" ]; then
        if [[ "$l" =~ ^started\ ([0-9]{1,10})$ ]]; then
          # DRIFT_BG is absolute (DRIFT_CACHE is canonical): never an option.
          if kill -0 "${BASH_REMATCH[1]}" 2>/dev/null \
             && [ -z "$(find "$DRIFT_BG" -mmin +6 2>/dev/null)" ]; then
            DRIFT_BGS=running
          else
            DRIFT_BGS=ended
          fi
        elif [[ "$l" =~ ^done\ ([0-9]{1,3})$ ]]; then
          if [ "${BASH_REMATCH[1]}" = 0 ]; then DRIFT_BGS="done"; else DRIFT_BGS="failed ${BASH_REMATCH[1]}"; fi
        fi
      fi
    fi
    if [ -f "$DRIFT_BGV" ]; then
      {
        IFS= read -r p
        if [ "$p" = "$D_BGHEAD" ]; then
          while [ "$n" -lt 400 ] && IFS= read -r l; do
            l="${l//[$'\x01'-$'\x08'$'\x0b'-$'\x1f'$'\x7f']/ }"
            l="${l//"$c1"[$'\x80'-$'\x9f']/ }"
            DRIFT_OUT="$DRIFT_OUT$l"$'\n'; n=$((n + 1))
          done
          D_BGV=1
        fi
      } < "$DRIFT_BGV"
    fi
    return 0
  }
  # d_bg_write <file> <text> — the project line, then the text, through a new
  # file renamed into place, never through a link, only into a cache
  # directory the user alone owns, made 0700 here when no run made it yet
  # (as drift_once makes it).
  d_bg_write() {
    [ -n "$1" ] && [ -n "$DRIFT_CACHE" ] && [ ! -L "$1" ] || return 0
    if [ ! -d "$DRIFT_CACHE" ]; then
      mkdir -p "${DRIFT_CACHE%/*}" 2>/dev/null
      mkdir -m 700 "$DRIFT_CACHE" 2>/dev/null
    fi
    [ -d "$DRIFT_CACHE" ] && ! iaeng_untrusted "$DRIFT_CACHE" || return 0
    { (umask 077; printf '%s\n%s\n' "$D_BGHEAD" "$2" > "$1.$$.tmp") && mv -f "$1.$$.tmp" "$1"; } 2>/dev/null
    [ -e "$1.$$.tmp" ] && rm -f "$1.$$.tmp" 2>/dev/null
    return 0
  }
  # d_bg_start — the check again, exactly as the hook runs it, bounded at
  # 300 s and detached: every descriptor goes to /dev/null, so Claude Code,
  # which waits for the hook's output to close, does not wait for it. The
  # script keeps its result in the cache itself (--cache-dir); this subshell
  # keeps the output of a run that exited 0 for the next session, then its
  # exit status. Called only where DRIFT_BG is set. $BASHPID is bash 4: on
  # bash 3.2 "started " is written, which d_bg_load reads as nothing, so a
  # second run may start; never a fault.
  d_bg_start() {
    (
      d_bg_write "$DRIFT_BG" "started ${BASHPID:-}"
      out="$(CDPATH='' cd -- "$BASE" 2>/dev/null && "$DRIFT_TO" -k 1 300 bash "$DRIFT_SH" "${DRIFT_ARGS[@]}" </dev/null 2>/dev/null)"
      rc=$?
      [ "$rc" -eq 0 ] && d_bg_write "$DRIFT_BGV" "$out"
      d_bg_write "$DRIFT_BG" "done $rc"
    ) </dev/null >/dev/null 2>&1 &
    return 0
  }

  # d_list <max> <items...> — "a, b, c and 2 more"; a name read from the
  # project is cut at 160 bytes (d_cap), so no line floods the context.
  d_list() {
    local max="$1" out="" i=0 x; shift
    for x in "$@"; do
      i=$((i + 1))
      d_cap "$x"
      [ "$i" -le "$max" ] && out="${out:+$out, }$D_CAPPED"
    done
    [ "$i" -gt "$max" ] && out="$out and $((i - max)) more"
    printf '%s' "$out"
  }
  # d_broken — one broken path (family D) of d_result's record into D_BRK:
  # the path and why, each cut at 160 bytes, then the outcome that applies,
  # in this hook's own words (issue #415). It said "so that guard is
  # silently off" of every one, while a guard whose entry has "onFailure":
  # "block" refuses every call it guards. check-framework-drift.sh writes a
  # hook command's record as "<why>; <outcome>; named by ...", the outcome
  # taken from the entry's "onFailure" and its event, and core.hooksPath's
  # as "<why>: ...". The record's outcome is matched, never printed. One in
  # another form (a background run of an older framework, a tampered cache)
  # gets the wording that is true of both outcomes.
  #
  # On another event, the record names the event in parentheses. A name of
  # letters alone is matched against a fixed list, what exit code 2 does on
  # it (Claude Code hooks reference, "Exit code 2 behavior per event" and
  # "Block the action when a hook fails", read 24 November 2026), and only
  # those words are printed; another name of letters alone is named as it
  # stands. A PreToolUse guard that refuses every call may refuse the drift
  # line's own command too: D_REFUSES is set, and the line then sends that
  # command to the Director, in a terminal, with TROUBLESHOOTING entry C.
  D_RE_EVENT='^its entry has "onFailure": "block", so a failure does what exit code 2 does on its event \(([A-Za-z]{1,40})\)'
  d_broken() {
    local why="${d_r%%;*}" rest="" out ev
    case "$d_r" in *'; '*) rest="${d_r#*; }" ;; esac
    case "$d_r" in
      'core.hooksPath is relative:'*)
        out="core.hooksPath is relative, so a linked git worktree runs no git hook" ;;
      'core.hooksPath names a directory that does not exist:'*)
        out="core.hooksPath names a directory that does not exist, so git runs no git hook" ;;
      *)
        d_cap "${why%%:*}"; out="$D_CAPPED"
        case "$rest" in
          'its entry has "onFailure": "block", so Claude Code refuses every call it guards'*)
            D_REFUSES=1
            out="$out; its entry has \"onFailure\": \"block\", so Claude Code refuses every call it guards" ;;
          'its entry has "onFailure": "block", so a failure does what exit code 2 does on its event'*)
            ev=""
            [[ "$rest" =~ $D_RE_EVENT ]] && ev="${BASH_REMATCH[1]}"
            case "$ev" in
              UserPromptSubmit) ev="so Claude Code blocks every prompt (UserPromptSubmit)" ;;
              PermissionRequest) ev="so Claude Code denies every permission request it handles (PermissionRequest)" ;;
              UserPromptExpansion) ev="so Claude Code blocks every prompt expansion it handles (UserPromptExpansion)" ;;
              PostToolBatch) ev="so Claude Code stops the agentic loop after every tool batch it handles (PostToolBatch)" ;;
              TaskCreated) ev="so Claude Code rolls back every task creation it handles (TaskCreated)" ;;
              ConfigChange) ev="so Claude Code blocks every configuration change it handles (ConfigChange)" ;;
              PreCompact) ev="so Claude Code blocks every compaction it handles (PreCompact)" ;;
              PreModelSwitch) ev="so Claude Code blocks every model switch it handles (PreModelSwitch)" ;;
              Elicitation|ElicitationResult) ev="so Claude Code declines every elicitation it handles ($ev)" ;;
              WorktreeCreate) ev="so every worktree creation it handles fails (WorktreeCreate)" ;;
              WorktreeRemove) ev="so every worktree removal it handles fails (WorktreeRemove)" ;;
              PostToolUse|PostToolUseFailure|PermissionDenied|Notification|SubagentStart|SessionStart|Setup|SessionEnd|CwdChanged|DirectoryAdded|FileChanged|PostCompact|PostModelSwitch|StopFailure|InstructionsLoaded|MessageDisplay)
                ev="which blocks nothing on $ev, so its check is off" ;;
              '') ev="so a failure does what exit code 2 does on its event" ;;
              *) ev="so a failure does what exit code 2 does on $ev" ;;
            esac
            out="$out; its entry has \"onFailure\": \"block\", $ev" ;;
          'the hook fails, so its check is silently off'*)
            out="$out; the hook fails, so its check is silently off" ;;
          *)
            out="$out; the hook fails: its check is off, or, for an entry with \"onFailure\": \"block\", every call it guards is refused" ;;
        esac ;;
    esac
    d_cap "$d_p"
    D_BRK+=("$D_CAPPED ($out)")
  }
  # d_result — reads DRIFT_OUT, the tsv output of a run that exited 0, into
  # DRIFT_LINES (one line per family, each begun with D_HEAD) or DRIFT_ONCE.
  # Every field arrives flattened: the script turns each control character
  # into a space (SEC-IAENG-357-01).
  d_result() {
    D_VER=""; D_ABS=(); D_DIF=(); D_BRK=(); D_FILES=0; D_INDET=""; D_ACT=""; D_SUM=0; D_REFUSES=0
    # The version line is built from fixed words, the tag and the count
    # alone: no text of the record (or of a cache) reaches it.
    D_RE_BEHIND='^last tag known locally: ([A-Za-z0-9._/+-]{1,64}), ([0-9]{1,4}) tag\(s\) behind'
    while IFS=$'\t' read -r d_f d_s d_p d_r; do
      case "$d_f" in
        '# check-framework-drift:'*)
          D_SUM=1
          D_ACT="${d_f#'# check-framework-drift: '}"; D_ACT="${D_ACT%% to act on*}"
          case "$D_ACT" in ''|*[!0-9]*) D_ACT="" ;; esac ;;
        ''|'#'*) ;;
        *)
          [ "$d_f" = file ] && D_FILES=$((D_FILES + 1))
          case "$d_f:$d_s" in
            version:behind)
              if [[ "$d_r" =~ $D_RE_BEHIND ]]; then
                D_VER="${D_VER:+$D_VER; }last tag known locally: ${BASH_REMATCH[1]}, ${BASH_REMATCH[2]} tag(s) behind"
              else
                D_VER="${D_VER:+$D_VER; }behind the last tag known locally"
              fi ;;
            version:uncommitted)
              D_VER="${D_VER:+$D_VER; }the checkout is not the commit the project recorded (gitlink +): an upgrade not committed" ;;
            version:uninitialized)
              D_VER="${D_VER:+$D_VER; }the submodule is not initialized (gitlink -)" ;;
            file:absent) D_ABS+=("$d_p") ;;
            file:differs|file:stale|file:modified) D_DIF+=("$d_p") ;;
            path:broken) d_broken ;;
            *:indeterminate)
              if [ -z "$D_INDET" ]; then
                d_cap "$d_p"; D_INDET="$D_CAPPED"
                d_cap "${d_r%%. *}"; D_INDET="$D_INDET: $D_CAPPED"
              fi ;;
          esac ;;
      esac
    done <<< "$DRIFT_OUT"
    if [ -n "$D_VER" ]; then
      DRIFT_LINES+=("$D_HEAD: the framework ($DRIFT_SHOWN): $D_VER. Run: $DRIFT_RUN")
    fi
    if [ "${#D_ABS[@]}" -gt 0 ] || [ "${#D_DIF[@]}" -gt 0 ]; then
      D_TXT=""
      [ "${#D_ABS[@]}" -gt 0 ] && D_TXT="absent: $(d_list 3 "${D_ABS[@]}")"
      [ "${#D_DIF[@]}" -gt 0 ] && D_TXT="${D_TXT:+$D_TXT; }differ from the framework: $(d_list 3 "${D_DIF[@]}")"
      DRIFT_LINES+=("$D_HEAD: $(( ${#D_ABS[@]} + ${#D_DIF[@]} )) of $D_FILES framework-managed file(s) to act on ($D_TXT). Run: $DRIFT_RUN, which tells a stale file (copy it) from a modified one (review it)")
    fi
    if [ "${#D_BRK[@]}" -gt 0 ]; then
      # Each item carries its own outcome, already cut: listed, not cut again.
      D_TXT=""; d_i=0
      for d_x in "${D_BRK[@]}"; do
        d_i=$((d_i + 1))
        [ "$d_i" -le 2 ] && D_TXT="${D_TXT:+$D_TXT, }$d_x"
      done
      [ "$d_i" -gt 2 ] && D_TXT="$D_TXT and $((d_i - 2)) more"
      # A guard that refuses every call can refuse this line's command too
      # (a Bash guard does): the remedy is then the Director's, from a
      # terminal (TROUBLESHOOTING.md entry C; DAILY_USE.md, Where a Human
      # Runs a Refused Command). Fixed words and the framework's path,
      # flattened as the command's own path is.
      D_TERM=""
      if [ "$D_REFUSES" -eq 1 ]; then
        a_flat "$DRIFT_SHOWN/Adapters/ai-runtimes/claude-code/TROUBLESHOOTING.md"
        D_TERM=" If such a guard refuses this command too, the Director runs it from a terminal and follows $A_FLAT, entry C."
      fi
      DRIFT_LINES+=("$D_HEAD: ${#D_BRK[@]} hook command(s) or core.hooksPath name a path that does not work: $D_TXT.$D_TERM Run: $DRIFT_RUN")
    fi
    if [ "$D_SUM" -eq 0 ]; then
      # Output cut short is not a result: nothing from it is shown.
      DRIFT_LINES=()
      DRIFT_ONCE="IA Engineering drift check: it gave no summary line, so nothing is reported (said once). Run it by hand: $DRIFT_RUN"
    elif [ "${#DRIFT_LINES[@]}" -eq 0 ] && [ -n "$D_ACT" ] && [ "$D_ACT" != 0 ]; then
      # A status this hook does not render is still never silence.
      DRIFT_LINES+=("$D_HEAD: $D_ACT item(s) to act on. Run: $DRIFT_RUN")
    elif [ "${#DRIFT_LINES[@]}" -eq 0 ] && [ -n "$D_INDET" ]; then
      DRIFT_ONCE="IA Engineering drift check: incomplete, $D_INDET (said once). Run: $DRIFT_RUN"
    fi
    return 0
  }

  DRIFT_TO=""
  if command -v timeout >/dev/null 2>&1; then DRIFT_TO=timeout
  elif command -v gtimeout >/dev/null 2>&1; then DRIFT_TO=gtimeout
  fi
  DRIFT_ONCE=""
  DRIFT_LINES=()
  # 1 once this session's run completed with a result, 2 once an earlier
  # background run's result was reported instead: either ends an episode.
  D_DONE=0
  D_BGV=0
  if [ -z "$DRIFT_TO" ]; then
    DRIFT_ONCE="IA Engineering drift check: not run at session start, no timeout command to bound it (said once). Run it by hand: $DRIFT_RUN"
  else
    DRIFT_ARGS=(--quick --format tsv)
    [ -n "$DRIFT_CACHE" ] && DRIFT_ARGS+=(--cache-dir "$DRIFT_CACHE")
    DRIFT_OUT="$(CDPATH='' cd -- "$BASE" 2>/dev/null && "$DRIFT_TO" -k 0.2 2.8 bash "$DRIFT_SH" "${DRIFT_ARGS[@]}" </dev/null 2>/dev/null)"
    DRIFT_RC=$?
    case "$DRIFT_RC" in
      0)
        D_HEAD="IA Engineering drift"
        d_result
        [ -z "$DRIFT_ONCE" ] && D_DONE=1 ;;
      124|137)
        D_OVER="IA Engineering drift check: not finished within the 3 s session-start budget"
        D_BGNOTE="$D_OVER; it goes on in the background (5 min at most) and keeps its result for the next session (said once). To see it now: $DRIFT_FILL"
        if [ -z "$DRIFT_BG" ]; then
          # No cache to keep a result in: running it again would keep nothing.
          DRIFT_ONCE="$D_OVER, so nothing is reported (said once). Run it by hand: $DRIFT_RUN"
        else
          d_bg_load
          if [ "$D_BGV" -eq 1 ]; then
            # For want of this session's result, the last one a background
            # run kept: read and capped as a run's, and said to be older.
            D_HEAD="IA Engineering drift, as found by the background run an earlier session started (this session's check did not finish within 3 s)"
            d_result
            [ -z "$DRIFT_ONCE" ] && D_DONE=2
          fi
          case "$DRIFT_BGS" in
            running)
              # Still going: its result is for the next session.
              [ "$D_BGV" -eq 1 ] || DRIFT_ONCE="$D_BGNOTE" ;;
            ended|failed*)
              # No run kept a result since: said at every session, first.
              if [ "$DRIFT_BGS" = ended ]; then D_WHY="stopped before it finished"; else D_WHY="did not finish (exit ${DRIFT_BGS#failed })"; fi
              if [ "${#DRIFT_LINES[@]}" -gt 0 ]; then D_SO="so what is reported comes from an older run"; else D_SO="so nothing is reported"; fi
              DRIFT_LINES=("$D_OVER, and the background run an earlier session started $D_WHY, $D_SO; it is started again. Run it by hand, which keeps its result for the next session: $DRIFT_FILL" ${DRIFT_LINES[@]+"${DRIFT_LINES[@]}"})
              d_bg_start ;;
            *)
              [ "$D_BGV" -eq 1 ] || DRIFT_ONCE="$D_BGNOTE"
              d_bg_start ;;
          esac
        fi ;;
      *)
        DRIFT_ONCE="IA Engineering drift check: it failed (exit $DRIFT_RC), so nothing is reported (said once). Run it by hand: $DRIFT_RUN" ;;
    esac
  fi
  if [ "${#DRIFT_LINES[@]}" -gt 0 ]; then
    printf '%s\n' "${DRIFT_LINES[@]:0:3}"
    echo
  fi
  if [ -n "$DRIFT_ONCE" ]; then
    drift_once "$DRIFT_ONCE"
  elif [ "$D_DONE" -ge 1 ]; then
    # A result reported: the next overrun or fault is said again.
    [ -n "$DRIFT_SAID" ] && [ -f "$DRIFT_SAID" ] && rm -f "$DRIFT_SAID" 2>/dev/null
    # This session's own result supersedes what a background run left.
    if [ "$D_DONE" -eq 1 ] && [ -n "$DRIFT_BG" ] && { [ -f "$DRIFT_BG" ] || [ -f "$DRIFT_BGV" ]; }; then
      rm -f "$DRIFT_BG" "$DRIFT_BGV" 2>/dev/null
    fi
  fi
fi

# --- Context alert threshold (WU-IAENG-380) ---------------------------------
# context-alert.sh --session-start prints a line only when the context alert
# would come after the estimated auto-compaction, or its threshold is not a
# number; otherwise nothing. Run here rather than from a SessionStart entry of
# its own, so the template keeps one SessionStart group. It reads only the
# environment, exits 0 on every path, and its stderr is dropped.
CTX_ALERT_SH="$HOOKS_DIR/context-alert.sh"
if [ -f "$CTX_ALERT_SH" ]; then
  CTX_WARN="$(bash "$CTX_ALERT_SH" --session-start </dev/null 2>/dev/null)"
  [ -n "$CTX_WARN" ] && printf '%s\n\n' "$CTX_WARN"
fi

echo "Rules enforced by hooks in this session (Adapters/ai-runtimes/claude-code/hooks/): no escape hatch in shell commands (Standards/GIT_STANDARD.md), no inline lint/test suppression in code (Standards/CODE_QUALITY_STANDARD.md), no stopping with uncommitted tracked changes unexplained (Core/AGENT_CONDUCT.md, Reporting Contract). Every Work Unit ends with a Work Unit Report (Templates/WORK_UNIT_REPORT.md) — a bare Done is a failed Work Unit."
exit 0
