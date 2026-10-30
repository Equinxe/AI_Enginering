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

echo "IA Engineering — read first, then say in one line what you read and what you are about to do (Core/AGENT_CONDUCT.md, Read First):"
echo

# --- CLAUDE.md ---------------------------------------------------------
# Mirrors the SESSION_STATE branch below: a project that has not yet
# finished Workflows/PROJECT_BOOTSTRAP.md Phase B (or the ONBOARDING.md
# Step 1 handoff that follows it) has no CLAUDE.md yet, and asserting one
# exists — as this line unconditionally did before WU-IAENG-302 — misleads
# the very first thing the model reads in the session.
if [ -f "$BASE/CLAUDE.md" ]; then
  echo "  1. CLAUDE.md — the project's stable contract."
else
  if [ -n "$ROOT" ] && [ -f "$ROOT/Templates/PROJECT_CLAUDE.md" ]; then
    echo "  1. CLAUDE.md does not exist yet — this project has not completed Workflows/PROJECT_BOOTSTRAP.md Phase B. It is created from $ROOT/Templates/PROJECT_CLAUDE.md at Workflows/ONBOARDING.md Step 1, once the Stack Decision ADR is Accepted."
  else
    echo "  1. CLAUDE.md does not exist yet and the framework's template was not found (looked for Core/AGENT_CONDUCT.md at ., ia-engineering/, \$IAENG_FRAMEWORK)."
  fi
fi
if [ -f "$STATE" ]; then
  echo "  2. .ia-engineering/SESSION_STATE.md — where things actually stand. Never committed."
  LAST="$(grep -m1 -E '^_Last updated:' "$STATE" | sed 's/^_//; s/_$//')"
  [ -n "$LAST" ] && echo "     $LAST"
  NEXT="$(awk '/^## Next Step/{f=1; next} /^## /{f=0} f && NF' "$STATE" | head -5)"
  if [ -n "$NEXT" ]; then
    echo "     Next Step, as recorded:"
    printf '%s\n' "$NEXT" | sed 's/^/       /'
  fi
  BLOCKED="$(awk '/^## Blocked On/{f=1; next} /^## /{f=0} f && NF' "$STATE" | head -3)"
  if [ -n "$BLOCKED" ] && ! grep -qiE '^\[?nothing' <<< "$BLOCKED"; then
    echo "     Blocked on:"
    printf '%s\n' "$BLOCKED" | sed 's/^/       /'
  fi

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
    echo "  2. .ia-engineering/SESSION_STATE.md does not exist. Create it before any other action with $ROOT/Adapters/scripts/create-session-state.sh, which writes the Template block of $ROOT/Templates/SESSION_STATE.md with today's date (after the project's first commit); it is gitignored and refused by the pre-commit hook."
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
GEN="${ROOT:+$ROOT/Adapters/ai-runtimes/generate-agents.sh}"
if [ -n "$GEN" ] && [ -f "$GEN" ]; then
  TIER_OUT="$(bash "$GEN" --target claude-code --project "$BASE" --print-tier-map 2>&1)"
  TIER_RC=$?
  if [ "$TIER_RC" -eq 0 ]; then
    TIER_SRC="$(sed -n 's/^# mapping: //p' <<< "$TIER_OUT")"
    TIER_MAP="$(grep -m1 '^map=' <<< "$TIER_OUT")"
    TIER_EFFORT="$(grep -m1 '^effort-map=' <<< "$TIER_OUT")"
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
# beside the cache it leaves the next session two files: bg-<project>, one
# line, "started <pid>" then "done <exit>"; and bg-<project>.tsv, its output.
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
  DRIFT_RUN="bash $DRIFT_SHOWN/Adapters/scripts/check-framework-drift.sh"
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

  # d_bg_load — what the background run of an earlier session left, read
  # only when the user alone could have written it. DRIFT_BGS is "" (nothing
  # readable as this hook's own), running, ended (started, gone, no report:
  # stopped from outside), done, or failed <exit>: the status line is matched
  # whole, so no text of it reaches the session. D_BGV is 1 when that run's
  # output is in DRIFT_OUT, at most 400 lines, for d_result to read as it
  # reads a run's. It is a file, so it is read as data: every control
  # character but the TAB that separates fields becomes a space again, the
  # C1 pairs as the script flattens them (SEC-IAENG-357-01, -358-01).
  d_bg_load() {
    local l="" n=0 c1=$'\xc2' LC_ALL=C
    local -a fs=()
    DRIFT_BGS=""; D_BGV=0; DRIFT_OUT=""
    [ -n "$DRIFT_BG" ] || return 0
    [ -f "$DRIFT_BG" ] && fs+=("$DRIFT_BG")
    [ -f "$DRIFT_BGV" ] && fs+=("$DRIFT_BGV")
    [ "${#fs[@]}" -gt 0 ] || return 0
    iaeng_untrusted "$DRIFT_CACHE" "${fs[@]}" && return 0
    if [ -f "$DRIFT_BG" ] && { IFS= read -r l < "$DRIFT_BG" || [ -n "$l" ]; }; then
      if [[ "$l" =~ ^started\ ([0-9]{1,10})$ ]]; then
        if kill -0 "${BASH_REMATCH[1]}" 2>/dev/null; then DRIFT_BGS=running; else DRIFT_BGS=ended; fi
      elif [[ "$l" =~ ^done\ ([0-9]{1,3})$ ]]; then
        if [ "${BASH_REMATCH[1]}" = 0 ]; then DRIFT_BGS="done"; else DRIFT_BGS="failed ${BASH_REMATCH[1]}"; fi
      fi
    fi
    if [ -f "$DRIFT_BGV" ]; then
      while [ "$n" -lt 400 ] && IFS= read -r l; do
        l="${l//[$'\x01'-$'\x08'$'\x0b'-$'\x1f'$'\x7f']/ }"
        l="${l//"$c1"[$'\x80'-$'\x9f']/ }"
        DRIFT_OUT="$DRIFT_OUT$l"$'\n'; n=$((n + 1))
      done < "$DRIFT_BGV"
      D_BGV=1
    fi
    return 0
  }
  # d_bg_write <file> <text> — through a new file renamed into place, never
  # through a link, only into a cache directory the user alone owns, made
  # 0700 here when no run made it yet (as drift_once makes it).
  d_bg_write() {
    [ -n "$1" ] && [ -n "$DRIFT_CACHE" ] && [ ! -L "$1" ] || return 0
    if [ ! -d "$DRIFT_CACHE" ]; then
      mkdir -p "${DRIFT_CACHE%/*}" 2>/dev/null
      mkdir -m 700 "$DRIFT_CACHE" 2>/dev/null
    fi
    [ -d "$DRIFT_CACHE" ] && ! iaeng_untrusted "$DRIFT_CACHE" || return 0
    { (umask 077; printf '%s\n' "$2" > "$1.$$.tmp") && mv -f "$1.$$.tmp" "$1"; } 2>/dev/null
    [ -e "$1.$$.tmp" ] && rm -f "$1.$$.tmp" 2>/dev/null
    return 0
  }
  # d_bg_start — the check again, exactly as the hook runs it, bounded at
  # 300 s and detached: every descriptor goes to /dev/null, so Claude Code,
  # which waits for the hook's output to close, does not wait for it. The
  # script keeps its result in the cache itself (--cache-dir); this subshell
  # keeps the output of a run that exited 0 for the next session, then its
  # exit status. $BASHPID is bash 4: on bash 3.2 "started " is written, which
  # d_bg_load reads as nothing, so a second run may start; never a fault.
  d_bg_start() {
    [ -n "$DRIFT_BG" ] || return 0
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
  # d_result — reads DRIFT_OUT, the tsv output of a run that exited 0, into
  # DRIFT_LINES (one line per family, each begun with D_HEAD) or DRIFT_ONCE.
  # Every field arrives flattened: the script turns each control character
  # into a space (SEC-IAENG-357-01).
  d_result() {
    D_VER=""; D_ABS=(); D_DIF=(); D_BRK=(); D_FILES=0; D_INDET=""; D_ACT=""; D_SUM=0
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
            path:broken) d_r="${d_r%%;*}"; d_cap "${d_r%%:*}"; D_BRK+=("$d_p ($D_CAPPED)") ;;
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
      DRIFT_LINES+=("$D_HEAD: ${#D_BRK[@]} hook command(s) or core.hooksPath name a path that does not work, so that guard is silently off: $(d_list 2 "${D_BRK[@]}"). Run: $DRIFT_RUN")
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
