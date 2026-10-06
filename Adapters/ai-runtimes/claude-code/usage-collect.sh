#!/usr/bin/env bash
# IA Engineering — usage-collect.sh (Claude Code runtime)
#
# Reads a project's Claude Code transcripts and prints AGGREGATES of them:
# API calls and tokens per day, model and agent, and subagent dispatches per
# agent type and requested model. It is the runtime-specific half of
# Adapters/scripts/usage-dashboard.sh, which calls it when it is present and
# renders what it prints. It can also be run on its own.
#
# WHY IT LIVES HERE AND NOT IN Adapters/scripts/
#
# Everything the dashboard reads from git is runtime-agnostic: an `Employee:`
# trailer means the same thing whichever AI runtime wrote the commit. The
# transcript format is not — it is Claude Code's, not a published contract
# ("the entry format is internal to Claude Code and changes between
# versions"), and it will change. Keeping the parser beside the other Claude
# Code integrations means a change in that format is fixed in one runtime
# adapter, and a project on another runtime simply has no collector: the
# dashboard says the source is missing and renders the git half.
#
# WHAT IT READS, AND WHAT IT NEVER EMITS
#
# Standards/DATA_PROTECTION_STANDARD.md. A transcript holds prompts, replies,
# tool inputs and tool outputs — file contents, command output, possibly
# secrets. This script extracts exactly these fields and nothing else:
#
#   assistant lines      message.id, message.model, the message.usage token
#                        counts, and the DATE (UTC) of the timestamp
#   tool_use blocks      named Agent or Task: the block id, input.subagent_type,
#                        input.model and input.name — never input.prompt,
#                        never input.description
#   subagent .meta.json  agentType and toolUseId
#
# Restricting the CHARACTERS of those fields is not enough: a model writes
# subagent_type and model itself, and "the password is hunter2" is made of
# ordinary characters. So every emitted string is SHAPE-validated instead
# (PR #196 review, F1):
#
#   agent type, dispatch name   ^[A-Za-z0-9][A-Za-z0-9:._@/-]{0,63}$
#   model                       the same, plus [ ] (the "[1m]" suffix)
#   day                         ^[0-9]{4}-[0-9]{2}-[0-9]{2}$, else "unknown"
#   token counts                numbers only, else 0
#
# One token, no space, at most 64 characters. A value that matches a
# credential pattern is counted under "(redacted)" whatever its shape — the
# data-policy scanner's families with lower length floors, more token
# families, and any unbroken alphanumeric run of 24 or more characters, which
# no model id or agent name has. Any other value outside the shape is counted
# under "(unrecognised)". The value itself is never printed.
#
# HOW IT STAYS STREAMING, AND INCREMENTAL
#
# A long session's transcript is tens of megabytes; a project's directory can
# be hundreds. Only lines carrying `"type":"assistant"` can hold usage or a
# dispatch, so awk drops every other line before jq sees it — most of a
# transcript's bytes are tool results. jq then reads line by line (-R with
# `fromjson?`), emits one short TSV record per relevant line, and awk
# aggregates. No transcript is held in memory.
#
# Records are kept per transcript file in a cache directory, with the file's
# size and the byte offset just past its last COMPLETE line. A transcript is
# append-only while its session lives, so a later run re-reads only the files
# whose size changed, and only from that offset; a file that shrank is read
# again from the start, and a file that disappeared (the runtime's retention
# sweep) is dropped. A line still being written — no newline yet — is left
# for the next run instead of being half-read. That is what lets
# usage-dashboard.sh --watch refresh every few seconds: after the first run, a
# cycle costs the files that grew, not the whole directory. Without
# --cache-dir the cache is a temporary directory and every run is a full one.
#
# The state that grows with input is the set of seen message ids, and it is
# required: Claude Code writes one line per content block and repeats the same
# message, with the same usage, on each, so summing lines would count a
# message's tokens once per block. Per id the maximum of each counter is kept,
# since a streamed message's counters only grow — which also makes re-reading
# a line harmless.
#
# Process count matters more than parsing on Windows, where each spawn of a
# native program costs about a quarter of a second: a native jq and grep per
# file was most of the run time. So all files read from the start go through
# ONE awk pass, the files that grew through one tail and awk each, and all of
# them through ONE jq; .meta.json files are read with bash builtins.
#
# WHERE THE TRANSCRIPTS ARE
#
#   ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>/
#
# where <slug> is the project's absolute path in the platform's native form
# with every character outside [A-Za-z0-9] replaced by '-':
# C:\Developpement\AI_Enginering -> C--Developpement-AI-Enginering, and
# /home/me/app -> -home-me-app. CLAUDE_CODE_PROJECT_DIR_NAME, when set, is
# the slug instead, as it is for the runtime. A slug over 200 characters is
# truncated by the runtime and suffixed with a hash; it is matched here by its
# first 200 characters. Sessions started inside one of the project's runtime
# worktrees (.claude/worktrees/<name>) are stored under
# <slug>--claude-worktrees-<name> and are included. Main-session files are
# <dir>/<session>.jsonl; subagent files are <dir>/<session>/subagents/*.jsonl,
# each with a sibling .meta.json. Its agentType is the agent TYPE for a plain
# dispatch but the dispatch's NAME for a named teammate ("lexer-attack"), so
# a subagent file is attributed through its toolUseId to the dispatch that
# spawned it, then through a dispatch name, and only then to agentType as
# written.
#
# The runtime deletes transcripts older than its cleanupPeriodDays setting
# (30 days by default), so what this reads is a rolling window, not history.
#
# USAGE
#
#   usage-collect.sh (--project-dir DIR | --transcripts-dir DIR)
#                    [--cache-dir DIR] [--list | --dirs]
#
# --transcripts-dir replaces the slug resolution with an explicit directory.
# --cache-dir keeps the per-file records between runs (see above).
# --list prints "<size> <TAB> <path>" for every transcript and exits: a cheap
#   fingerprint for a caller deciding whether anything changed.
# --dirs prints the transcript directories found, one per line, and exits.
#   usage-dashboard.sh --watch resolves them once and hands them to every
#   later run in IAENG_USAGE_TRANSCRIPT_DIRS (newline-separated), which then
#   replaces the resolution: on Windows, resolving costs several processes,
#   and a watch cycle runs every few seconds.
#
# OUTPUT (stdout, tab-separated, one record per line)
#
#   source    <transcript-dirs> <files> <api-calls> <dispatches>
#   call      <day> <model> <agent> <input> <output> <cache_creation> <cache_read> <calls>
#   dispatch  <subagent_type> <requested-model> <count>
#
# Exit 0 when transcripts were found and aggregated, 3 when none exist for the
# project (not an error: the dashboard reports the source as missing), 4 when
# the project's path is too long to name its directory and several candidates
# could be its own (the dashboard reports the source as ambiguous and counts
# nothing), 1 on an error (jq absent, an explicit --transcripts-dir that does
# not exist, a failed read — the cache index is then reset), 2 on a usage
# error.

set -uo pipefail

err() { printf 'usage-collect: ERROR: %s\n' "$1" >&2; }

# A literal tab and newline, set once: `IFS="$(printf '\t')"` in a read loop
# would fork on every iteration.
TAB=$'\t'
NL=$'\n'

# Everything this script writes — the cache, its index (which holds local
# paths), the per-run work files — is owner-only (PR #204 review, F1).
umask 077

usage() {
  echo "Usage: $0 (--project-dir DIR | --transcripts-dir DIR) [--cache-dir DIR] [--list]" >&2
  echo "  Prints aggregate Claude Code usage (tokens, models, dispatches) for a project." >&2
}

PROJECT_DIR=""
TRANSCRIPTS_DIR=""
CACHE_DIR=""
LIST_ONLY=""
DIRS_ONLY=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir) [ "$#" -ge 2 ] || { usage; exit 2; }; PROJECT_DIR="$2"; shift 2 ;;
    --transcripts-dir) [ "$#" -ge 2 ] || { usage; exit 2; }; TRANSCRIPTS_DIR="$2"; shift 2 ;;
    --cache-dir) [ "$#" -ge 2 ] || { usage; exit 2; }; CACHE_DIR="$2"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --dirs) DIRS_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument '$1'"; usage; exit 2 ;;
  esac
done

if [ -z "$PROJECT_DIR" ] && [ -z "$TRANSCRIPTS_DIR" ]; then
  usage
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  err "jq is required and was not found on PATH."
  exit 1
fi

# --- Locate the transcript directories -------------------------------------

# dir_is_this_project <dir> — whose transcripts a directory holds, from the
# first "cwd" recorded in one of its .jsonl files: 0 this project's root
# ($ABS), 2 one of its runtime worktrees, 1 another project, 3 cannot tell
# (no cwd in the first 50 lines of any file). Builtins only.
RE_CWD='"cwd":"([^"]*)"'
dir_is_this_project() {
  local f line cwd n
  for f in "$1"/*.jsonl; do
    [ -f "$f" ] || continue
    n=0
    while [ "$n" -lt 50 ] && IFS= read -r line; do
      n=$((n + 1))
      if [[ "$line" =~ $RE_CWD ]]; then
        cwd="${BASH_REMATCH[1]//\\\\/\\}"
        [ "$cwd" = "$ABS" ] && return 0
        case "$cwd" in
          "$ABS/.claude/worktrees/"*|"$ABS\\.claude\\worktrees\\"*) return 2 ;;
        esac
        return 1
      fi
    done < "$f"
  done
  return 3
}

DIRS=()
LOOKED=""
if [ -z "$TRANSCRIPTS_DIR" ] && [ -n "${IAENG_USAGE_TRANSCRIPT_DIRS:-}" ]; then
  # Resolved once by the caller (usage-dashboard.sh --watch); a directory
  # that has since disappeared is skipped, as the slug resolution would.
  while IFS= read -r d; do
    [ -n "$d" ] && [ -d "$d" ] && DIRS+=("$d")
  done <<< "$IAENG_USAGE_TRANSCRIPT_DIRS"
  LOOKED="the directories resolved when the watch started"
elif [ -n "$TRANSCRIPTS_DIR" ]; then
  if [ ! -d "$TRANSCRIPTS_DIR" ]; then
    err "--transcripts-dir '$TRANSCRIPTS_DIR' does not exist. An explicit directory that is absent is a mistake to report, not an empty source to render."
    exit 1
  fi
  DIRS+=("$TRANSCRIPTS_DIR")
  LOOKED="$TRANSCRIPTS_DIR"
else
  if ! ABS="$(CDPATH='' cd -- "$PROJECT_DIR" 2>/dev/null && pwd -P)"; then
    err "--project-dir '$PROJECT_DIR' does not exist."
    exit 1
  fi
  # The runtime names the directory after the NATIVE path. Under Git Bash or
  # Cygwin `pwd` prints /c/..., which would slug to -c-... and match nothing.
  if command -v cygpath >/dev/null 2>&1; then
    ABS="$(cygpath -w "$ABS")"
  fi
  # Pattern substitution, not a sed pipeline: no process.
  SLUG="${ABS//[^A-Za-z0-9]/-}"
  BASE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
  # The runtime honours CLAUDE_CODE_PROJECT_DIR_NAME only when CLAUDE_CONFIG_DIR
  # is set, and only for a plain name that is not a reserved Windows device;
  # anywhere else it keeps writing under the path's slug, so that is where
  # the transcripts are (PR #204 review, F7).
  NAMED=""
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [[ "${CLAUDE_CODE_PROJECT_DIR_NAME:-}" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
    NAMED="$CLAUDE_CODE_PROJECT_DIR_NAME"
    shopt -s nocasematch
    [[ "$NAMED" =~ ^(con|prn|aux|nul|com[0-9]|lpt[0-9])$ ]] && NAMED=""
    shopt -u nocasematch
  fi
  # Past 200 characters the runtime keeps the first 200 and appends "-" and a
  # hash of the full path. Another project can share those 200 characters, so
  # a candidate is kept only when its transcripts say they were recorded in
  # this project or one of its worktrees (PR #204 review, F2).
  # IAENG_USAGE_SLUG_MAX lowers the 200 for tests, which cannot create
  # 200-character paths on every platform.
  SLUG_MAX=200
  [[ "${IAENG_USAGE_SLUG_MAX:-}" =~ ^[1-9][0-9]{0,2}$ ]] && SLUG_MAX=$((10#$IAENG_USAGE_SLUG_MAX))
  if [ -n "$NAMED" ]; then
    LOOKED="$BASE/$NAMED"
    [ -d "$BASE/$NAMED" ] && DIRS+=("$BASE/$NAMED")
  elif [ "${#SLUG}" -gt "$SLUG_MAX" ]; then
    # The cwd filter runs first: another project's directory is skipped and
    # said so. What remains must be unambiguous — at most one directory
    # recorded in the project root itself (any number of its worktrees), and
    # none whose owner cannot be read. Otherwise the collector refuses to
    # guess: exit 4, and the dashboard reports the source as ambiguous
    # (PR #204 code review, M1).
    LOOKED="$BASE/${SLUG:0:$SLUG_MAX}-<hash>"
    ROOTS=0
    UNKNOWN=0
    for d in "$BASE/${SLUG:0:$SLUG_MAX}-"*; do
      [ -d "$d" ] || continue
      dir_is_this_project "$d"
      case "$?" in
        0) ROOTS=$((ROOTS + 1)); DIRS+=("$d") ;;
        2) DIRS+=("$d") ;;
        1) echo "usage-collect: skipped $d: its transcripts were recorded in another project." >&2 ;;
        *) UNKNOWN=$((UNKNOWN + 1)); echo "usage-collect: cannot tell which project $d belongs to." >&2 ;;
      esac
    done
    if [ "$ROOTS" -gt 1 ] || [ "$UNKNOWN" -gt 0 ]; then
      echo "usage-collect: AMBIGUOUS: the project's path is longer than the runtime keeps in a directory name, and $((ROOTS + UNKNOWN)) candidate directories could be this project's. Refusing to guess. Pass --transcripts-dir, or set CLAUDE_CODE_PROJECT_DIR_NAME (with CLAUDE_CONFIG_DIR) for this project." >&2
      exit 4
    fi
  else
    LOOKED="$BASE/$SLUG"
    for d in "$BASE/$SLUG" "$BASE/$SLUG"--claude-worktrees-*; do
      [ -d "$d" ] && DIRS+=("$d")
    done
  fi
fi

if [ "${#DIRS[@]}" -eq 0 ]; then
  echo "usage-collect: no Claude Code transcripts for this project (looked for $LOOKED)." >&2
  exit 3
fi

if [ -n "$DIRS_ONLY" ]; then
  printf '%s\n' "${DIRS[@]}"
  exit 0
fi

# <size> <TAB> <path>. GNU find prints both in one process; BSD find has no
# -printf, and BSD stat does the same job there. Under --watch this runs every
# cycle, so it is one process, not a pipeline: on Windows each process costs a
# quarter of a second and more. A path holding a tab or a newline cannot be
# carried on a line; it is listed as a bare "S" — skipped, and said so — and
# never silently dropped with everything after it (PR #204 review, F8).
# The modification time rides along (seconds, possibly fractional), so a
# rewrite that keeps the size is not taken for "unchanged" (code review m1).
LISTING="$(find "${DIRS[@]}" -type f -name '*.jsonl' \( -path "*$NL*" -o -path "*$TAB*" \) -printf 'S\n' \
  -o -type f -name '*.jsonl' -printf '%s\t%T@\t%p\n' 2>/dev/null)"
if [ -z "$LISTING" ]; then
  LISTING="$(find "${DIRS[@]}" -type f -name '*.jsonl' \( -path "*$NL*" -o -path "*$TAB*" \) -exec printf 'S\n' \; \
    -o -type f -name '*.jsonl' -exec stat -f '%z%t%m%t%N' {} + 2>/dev/null)"
fi

if [ -z "$LISTING" ]; then
  echo "usage-collect: $LOOKED exists but holds no .jsonl transcript." >&2
  exit 3
fi

if [ -n "$LIST_ONLY" ]; then
  printf '%s\n' "$LISTING"
  exit 0
fi

# --- The cache ---------------------------------------------------------------
#
# The cache keeps only shaped records and the index; the per-run work files
# (plan, file map, offsets) live in a directory of their own, removed on exit
# (PR #204 review, F1). The cache is still treated as untrusted on every read
# (F3): an index line is used only if its numbers are numbers, and every
# cached record passes the same shape checks again before it is aggregated.

WORKD="$(mktemp -d "${TMPDIR:-/tmp}/obs330-work.XXXXXX")" || { err "cannot create a temporary directory"; exit 1; }
if [ -n "$CACHE_DIR" ]; then
  CACHE="$CACHE_DIR/v1"
  trap 'rm -rf "$WORKD"' EXIT
else
  CACHE="$WORKD/cache"
  trap 'rm -rf "$WORKD"' EXIT
fi
REC="$CACHE/rec"
INDEX="$CACHE/index.tsv"
if [ ! -d "$REC" ] && ! mkdir -p "$REC"; then
  err "cannot create the cache directory $CACHE."
  exit 1
fi
[ -f "$INDEX" ] || : > "$INDEX"

# The plan, one line per file, from the previous index and the listing.
# The index line is: idx size offset mtime head path, where "head" is the
# first session id or uuid on the file's first line (an id, never content).
#
#   N idx 0   size mtime -    path   new; shrank; or same size with a new
#                                    mtime: read from the start
#   C idx off size mtime head path   grew: an append if the first line is
#                                    still the same (decided below), else a
#                                    replaced file, read from the start
#   K idx off size mtime head path   unchanged: same size, same mtime
#   X idx                            gone: drop its records
#
# THE APPEND-ONLY ASSUMPTION. Reading a grown file from its last offset is
# right only if the bytes before that offset did not change. Claude Code
# appends to a session's transcript and never rewrites it; that is the
# assumption, and it is checked as far as is cheap: a file that shrank, kept
# its size under a new mtime, or no longer starts with the same first-line id
# is read again from the start. An edit in the middle that keeps the first
# line and grows the file is not detected (code review m1).
#
# It prints the number of transcripts and the number skipped. An index line
# with a field of the wrong shape is ignored: its file is read again as new
# (PR #204 review, F3).
PLAN="$WORKD/plan.tsv"
COUNTS="$(F_INDEX="$INDEX" F_PLAN="$PLAN" awk -F '\t' -v OFS='\t' '
  BEGIN {
    f = ENVIRON["F_INDEX"]; planf = ENVIRON["F_PLAN"]
    while ((getline line < f) > 0) {
      k = split(line, p, "\t")
      if (k != 6 || p[1] !~ /^[0-9]+$/ || p[2] !~ /^[0-9]+$/ || p[3] !~ /^[0-9]+$/ \
          || p[4] !~ /^[0-9]+(\.[0-9]+)?$/ || p[5] !~ /^[A-Za-z0-9_-]+$/ || p[6] == "") continue
      oidx[p[6]] = p[1]; osize[p[6]] = p[2]; ooff[p[6]] = p[3]; omt[p[6]] = p[4]; ohead[p[6]] = p[5]
      if (p[1] + 0 > max) max = p[1] + 0
    }
    printf "" > planf
  }
  $0 == "" { next }
  $0 == "S" { skipped++; next }
  NF != 3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+(\.[0-9]+)?$/ || $3 == "" { skipped++; next }
  {
    size = $1; mt = $2; path = $3; seen[path] = 1; n++
    if (!(path in oidx)) print "N", ++max, 0, size, mt, "-", path > planf
    else if (size + 0 < ooff[path] + 0 || size + 0 < osize[path] + 0) print "N", oidx[path], 0, size, mt, "-", path > planf
    else if (size + 0 == osize[path] + 0) {
      if (mt == omt[path]) print "K", oidx[path], ooff[path], size, mt, ohead[path], path > planf
      else print "N", oidx[path], 0, size, mt, "-", path > planf
    }
    else print "C", oidx[path], ooff[path], size, mt, ohead[path], path > planf
  }
  END { for (path in oidx) if (!(path in seen)) print "X", oidx[path] > planf; print (n + 0) " " (skipped + 0) }
' <<< "$LISTING")"
NFILES="${COUNTS% *}"
NSKIPPED="${COUNTS#* }"
if [ "${NSKIPPED:-0}" != 0 ]; then
  echo "usage-collect: WARNING: skipped $NSKIPPED transcript file(s) whose path holds a tab or a newline; their usage is not counted." >&2
fi
if [ "${NFILES:-0}" = 0 ]; then
  echo "usage-collect: $LOOKED holds no readable .jsonl transcript." >&2
  exit 3
fi

# The label of a subagent file, from its .meta.json, into META_JSON: a
# variable, not printed for $(...) to capture, because a command substitution
# is a fork and a fork per file was a minute on Windows. Only TWO fields are
# taken, with builtins: agentType and toolUseId, each kept only if it has the
# shape of one. The rest of the file — its free-text "description", which the
# model writes — is never copied anywhere (PR #204 review, F1). The result is
# rebuilt as a tiny JSON object; jq shape-checks it again. A missing
# .meta.json is "{}": the unknown bucket; a main session is "".
RE_AGENT_TYPE='"agentType"[[:space:]]*:[[:space:]]*"([^"]*)"'
RE_TOOL_USE_ID='"toolUseId"[[:space:]]*:[[:space:]]*"([^"]*)"'
META_JSON=""
meta_of() {
  local f="$1" meta raw="" at="" tu=""
  META_JSON=""
  case "$f" in
    */subagents/*)
      meta="${f%.jsonl}.meta.json"
      META_JSON="{}"
      [ -f "$meta" ] || return 0
      IFS= read -r -d '' raw < "$meta" || true
      if [[ "$raw" =~ $RE_AGENT_TYPE ]]; then
        at="(unrecognised)"
        [[ "${BASH_REMATCH[1]}" =~ ^[A-Za-z0-9][A-Za-z0-9:._@/-]{0,63}$ ]] && at="${BASH_REMATCH[0]}"
      fi
      if [[ "$raw" =~ $RE_TOOL_USE_ID ]] && [[ "${BASH_REMATCH[1]}" =~ ^[A-Za-z0-9_-]{1,128}$ ]]; then
        tu="${BASH_REMATCH[0]}"
      fi
      raw=""
      META_JSON="{"
      [ -n "$at" ] && META_JSON="$META_JSON\"agentType\":\"$at\""
      [ -n "$at" ] && [ -n "$tu" ] && META_JSON="$META_JSON,"
      [ -n "$tu" ] && META_JSON="$META_JSON\"toolUseId\":\"$tu\""
      META_JSON="$META_JSON}"
      ;;
  esac
}

# head_of <file> — into HEAD_ID: the first sessionId or uuid on the file's
# first line (at most 4096 bytes read), or "-". An identifier, never content;
# builtins only.
RE_HEAD='"(sessionId|uuid)":"([A-Za-z0-9_-]{1,64})"'
HEAD_ID="-"
head_of() {
  local first=""
  HEAD_ID="-"
  IFS= read -r -n 4096 first < "$1" || true
  [[ "$first" =~ $RE_HEAD ]] && HEAD_ID="${BASH_REMATCH[2]}"
}

FULLMAP="$WORKD/full.tsv"      # path idx size meta, files read from 0
TAILS="$WORKD/tails.tsv"       # idx off size path, files read from an offset
OFFS="$WORKD/offsets.tsv"      # idx offset, written by the prefilter
PLAN2="$WORKD/plan2.tsv"       # act idx off size mtime head path, for the new index
: > "$FULLMAP"; : > "$TAILS"; : > "$OFFS"; : > "$PLAN2"
DROPS=()
RECS=()
READS=0
while IFS="$TAB" read -r act idx off size mt head path; do
  # The idx becomes a file name under rec/ and the offset an arithmetic
  # operand: neither is used unless it is a plain number (F3). The plan has
  # already dropped such index lines; this is the second, local check.
  [[ "$idx" =~ ^[0-9]{1,9}$ ]] || continue
  if [ "$act" = X ]; then
    DROPS+=("$REC/$idx.tsv")
    continue
  fi
  [[ "$off" =~ ^[0-9]{1,15}$ ]] || continue
  if [ "$act" = C ]; then
    # Grown: an append only if the first line still names the same session.
    head_of "$path"
    if [ "$HEAD_ID" = "$head" ]; then act=T; else act=N; off=0; fi
  fi
  case "$act" in
    N) : > "$REC/$idx.tsv"
       head_of "$path"
       meta_of "$path"
       printf '%s\t%s\t%s\t%s\n' "$path" "$idx" "$size" "$META_JSON" >> "$FULLMAP"
       printf 'N\t%s\t0\t%s\t%s\t%s\t%s\n' "$idx" "$size" "$mt" "$HEAD_ID" "$path" >> "$PLAN2"
       READS=$((READS + 1)) ;;
    T) printf '%s\t%s\t%s\t%s\n' "$idx" "$off" "$size" "$path" >> "$TAILS"
       printf 'T\t%s\t%s\t%s\t%s\t%s\t%s\n' "$idx" "$off" "$size" "$mt" "$head" "$path" >> "$PLAN2"
       RECS+=("$REC/$idx.tsv")
       READS=$((READS + 1)) ;;
    K) printf 'K\t%s\t%s\t%s\t%s\t%s\t%s\n' "$idx" "$off" "$size" "$mt" "$head" "$path" >> "$PLAN2"
       RECS+=("$REC/$idx.tsv") ;;
  esac
done < "$PLAN"
[ "${#DROPS[@]}" -eq 0 ] || rm -f "${DROPS[@]}"

# --- Extract -----------------------------------------------------------------

# The two fixed labels a file can carry before resolution. Written once, so
# the bucket the page shows and the bucket awk resolves cannot drift (F7).
MAIN_LABEL="main session"
UNKNOWN_SUBAGENT="subagent (type unknown)"

# Credential families, after the data-policy scanner's SECRET_PATTERNS
# (Adapters/scripts/data-policy-scan.sh) with lower length floors, since a
# shape-valid value is at most 64 characters, plus further token families and
# a generic rule: any unbroken alphanumeric run of 24+ characters. The longest
# run in a real model id is the 8-digit date of claude-haiku-4-5-20251001.
# Only ever matched, never printed. usage-dashboard.sh applies the same
# expression to git trailer values; tests/run.sh asserts the two are equal.
SECRET_RE='AKIA[0-9A-Z]{12,}|ASIA[0-9A-Z]{12,}|gh[pousr]_[A-Za-z0-9]{16,}|xox[baprs]-|xapp-|sk_(live|test)_|rk_(live|test)_|sk-ant-|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{20,}|eyJ[A-Za-z0-9_-]+\.|hf_[A-Za-z0-9]{20,}|glpat-|npm_[A-Za-z0-9]{20,}|BEGIN.*PRIVATE|[A-Za-z0-9]{24,}'

# The shared shape filters (F1, F2, F6). `$secret` is a jq variable. The
# credential test runs BEFORE the shape test, so a token with a character the
# shape refuses (hf_..., npm_...) still reports as redacted, not unrecognised.
JQ_SHAPES="$(cat <<'JQ'
def agent_shape: if type != "string" then "(unrecognised)" elif test($secret) then "(redacted)"
                 elif test("^[A-Za-z0-9][A-Za-z0-9:._@/-]{0,63}$") then . else "(unrecognised)" end;
def model_shape: if type != "string" then "(unrecognised)" elif test($secret) then "(redacted)"
                 elif test("^[A-Za-z0-9][A-Za-z0-9:._@/\\[\\]-]{0,63}$") then . else "(unrecognised)" end;
def id_shape: if type == "string" and test("^[A-Za-z0-9_-]{1,128}$") then . else "" end;
def day_shape: if type == "string" and (.[0:10] | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) then .[0:10] else "unknown" end;
def count: (numbers | select(. >= 0) | floor) // 0;
JQ
)"

# The prefilter writes a marker line before each file's lines — "\036M <idx>"
# for a main session, "\036S <idx> <meta-json>" for a subagent — and jq
# carries the current file through a `foreach`. Every record it prints is
# prefixed with the file's idx, so the splitter can file it under that file.
#
# One record per relevant line: `C` is an API call's usage, `D` a dispatch.
# Held in a quoted heredoc: it is a jq program, and `$agent`, `$toolu`, `$m`,
# `$u`, `$l` and `$r` are jq variables, not shell ones.
JQ_EXTRACT="$JQ_SHAPES
$(cat <<'JQ'
# A marker's idx is a file name under rec/: digits or nothing (F9). Records
# with an empty idx are neither stored nor counted.
def digits: if test("^[0-9]{1,9}$") then . else "" end;
def meta_label:
  (fromjson? // {}) as $mj
  | if ($mj | type) != "object" then {agent: $unknown, toolu: ""}
    else {agent: (if $mj.agentType == null then $unknown else ($mj.agentType | agent_shape) end),
          toolu: ($mj.toolUseId | id_shape)} end;
def extract($agent; $toolu):
fromjson? | select(type == "object" and .type == "assistant") |
(
  select((.message.usage? | type) == "object" and .message.model? != "<synthetic>")
  | .message as $m | $m.usage as $u | ($m.id | id_shape) as $id
  | select($id != "")
  | ["C", $id, (.timestamp | day_shape), ($m.model // "unknown" | model_shape), $agent, $toolu,
     ($u.input_tokens | count), ($u.output_tokens | count),
     ($u.cache_creation_input_tokens | count), ($u.cache_read_input_tokens | count)]
  | @tsv
),
(
  .message.content? | arrays | .[]
  | select(type == "object" and .type == "tool_use"
           and (.name == "Agent" or .name == "Task"))
  | ["D", (.id | id_shape),
     (.input.subagent_type // "general-purpose" | agent_shape),
     (.input.model // "inherit" | model_shape),
     (if .input.name == null then "" else (.input.name | agent_shape) end)]
  | @tsv
);
foreach inputs as $l ({idx: "", agent: $main, toolu: "", line: null};
  if ($l | startswith("\u001eM ")) then {idx: ($l[3:] | digits), agent: $main, toolu: "", line: null}
  elif ($l | startswith("\u001eS ")) then
    ($l[3:]) as $r | ($r | index(" ")) as $p
    | {idx: ($r[:$p] | digits)} + ($r[$p + 1:] | meta_label) + {line: null}
  else .line = $l end;
  select(.line != null) | .idx as $i | .agent as $a | .toolu as $t
  | .line | extract($a; $t) | "\($i)\t\(.)")
JQ
)"

# The prefilter, shared by both read modes. Each line is held until the next
# one arrives; at the end of a file the held line is kept only if the bytes
# counted equal the bytes expected, which is true exactly when the file ended
# in a newline. Otherwise it is a line being written: it is dropped, and the
# recorded offset stops before it so the next run reads it whole. LC_ALL=C so
# that length() counts bytes. The offset of each file goes to F_OFFS.
AWK_PREFILTER_FUNCS="$(cat <<'AWK'
  function start(i, b, size, m) {
    cur = i; base = b; want = size - b; sum = 0; held = ""; hasheld = 0
    if (m == "") print "\036M " i; else print "\036S " i " " m
  }
  # A transcript line that starts with the marker byte is dropped: it could
  # otherwise pose as a file marker and relabel the lines after it (F9).
  function take(line) { if (substr(line, 1, 1) != "\036" && line ~ /"type": ?"assistant"/) print line }
  function line_in() {
    if (hasheld) take(held)
    held = $0; hasheld = 1; sum += length($0) + 1
  }
  function finish() {
    if (cur == "") return
    if (hasheld) { if (sum == want) take(held); else sum -= length(held) + 1 }
    print cur "\t" (base + sum) >> offf
    cur = ""
  }
AWK
)"

extract() {
  # Files read from the start: one awk over all of them. Names reach it as
  # arguments and the map through the environment (not -v, which would
  # process backslashes in a Windows path).
  if [ -s "$FULLMAP" ]; then
    local full=()
    while IFS="$TAB" read -r p _; do full+=("$p"); done < "$FULLMAP"
    F_MAP="$FULLMAP" F_OFFS="$OFFS" LC_ALL=C awk "$AWK_PREFILTER_FUNCS"'
      BEGIN { mapf = ENVIRON["F_MAP"]; offf = ENVIRON["F_OFFS"] }
      FILENAME == mapf {
        split($0, q, "\t"); fidx[q[1]] = q[2]; fsize[q[1]] = q[3]; fmeta[q[1]] = q[4]; next
      }
      FNR == 1 { finish(); start(fidx[FILENAME], 0, fsize[FILENAME], fmeta[FILENAME]) }
      { line_in() }
      END { finish() }
    ' "$FULLMAP" "${full[@]}" || return 1
  fi
  # Files that grew: from the recorded offset, one tail and awk each. The
  # offset was checked to be digits; 10# keeps a leading zero from reading as
  # octal. A failing read fails the whole run (PR #204 review, F8).
  local idx off size path
  while IFS="$TAB" read -r idx off size path; do
    meta_of "$path"
    tail -c +"$((10#$off + 1))" "$path" \
      | F_IDX="$idx" F_BASE="$off" F_SIZE="$size" F_MJ="$META_JSON" F_OFFS="$OFFS" \
        LC_ALL=C awk "$AWK_PREFILTER_FUNCS"'
          BEGIN { offf = ENVIRON["F_OFFS"]; start(ENVIRON["F_IDX"], ENVIRON["F_BASE"] + 0, ENVIRON["F_SIZE"] + 0, ENVIRON["F_MJ"]) }
          { line_in() }
          END { finish() }
        ' || return 1
  done < "$TAILS"
}


# --- Store, index and aggregate: one awk -------------------------------------
#
# Reads the cached records of every file it was not asked to re-read from the
# start (unchanged and grown files), then — on stdin — the new records, each
# prefixed with its file's idx. A new record is appended to its file's cache
# and aggregated with the rest; a file's records are contiguous in the
# stream, so each cache file is opened once. At the end it writes the new
# index (read files at their new offset, or where they started when nothing
# complete was read) and prints the aggregate. One process instead of a
# splitter, an index writer and an aggregator.
#
# C: id day model agent toolu input output cache_creation cache_read
# D: tool-id subagent_type model name
# A subagent file's label is resolved at the end, once every dispatch is
# known: its spawning tool_use id first, then a dispatch name, then as written.
store_and_aggregate() {
  F_REC="$REC" F_PLAN="$PLAN2" F_OFFS="$OFFS" F_INDEX="$INDEX_NEW" F_SECRET="$SECRET_RE" \
  F_MAIN="$MAIN_LABEL" F_UNKNOWN="$UNKNOWN_SUBAGENT" \
  awk -F '\t' -v OFS='\t' -v ndirs="${#DIRS[@]}" -v nfiles="$NFILES" '
    BEGIN {
      recd = ENVIRON["F_REC"]; planf = ENVIRON["F_PLAN"]; offf = ENVIRON["F_OFFS"]; indexf = ENVIRON["F_INDEX"]
      secret = ENVIRON["F_SECRET"]; mainl = ENVIRON["F_MAIN"]; unknownl = ENVIRON["F_UNKNOWN"]
      name_re = "^[A-Za-z0-9][-A-Za-z0-9:._@/]*$"
      model_re = "^[A-Za-z0-9][][A-Za-z0-9:._@/-]*$"
    }
    # A cached record is input like any other: every field passes the same
    # shapes the extraction applied before it is counted (PR #204 review, F3).
    function bucket(s) { return s == "(unrecognised)" || s == "(redacted)" }
    function shaped(s, re) {
      if (bucket(s)) return s
      if (length(s) > 64 || s !~ re) return "(unrecognised)"
      if (s ~ secret) return "(redacted)"
      return s
    }
    function num(s) { return (s ~ /^[0-9]+$/ && length(s) <= 15) ? s + 0 : 0 }
    function okid(s) { return s ~ /^[A-Za-z0-9_-]+$/ && length(s) <= 128 }
    function agg(line,   f, k, id, i, v, key, a) {
      k = split(line, f, "\t")
      if (f[1] == "C" && k == 10) {
        id = f[2]
        if (!okid(id)) return
        if (!(id in seen)) {
          seen[id] = 1; order[++n] = id
          day[id] = (f[3] ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) ? f[3] : "unknown"
          model[id] = shaped(f[4], model_re)
          a = f[5]
          agent[id] = (a == mainl || a == unknownl) ? a : shaped(a, name_re)
          toolu[id] = okid(f[6]) ? f[6] : ""
        }
        for (i = 7; i <= 10; i++) { v = num(f[i]); if (v > val[id, i]) val[id, i] = v }
      } else if (f[1] == "D" && k == 5) {
        if (f[2] != "" && !okid(f[2])) return
        key = (f[2] == "" ? "anon" (++anon) : f[2])
        if (key in dseen) return
        dseen[key] = 1; nd++
        dcount[shaped(f[3], name_re) OFS shaped(f[4], model_re)]++
        if (f[2] != "") dtype[f[2]] = shaped(f[3], name_re)
        if (f[5] != "" && !bucket(f[5]) && shaped(f[5], name_re) == f[5]) byname[f[5]] = shaped(f[3], name_re)
      }
    }
    { sub(/\r$/, "") }
    /^[0-9]/ {
      i = index($0, "\t"); fid = substr($0, 1, i - 1); rest = substr($0, i + 1)
      if (fid != cur) { if (cur != "") close(out); cur = fid; out = recd "/" fid ".tsv" }
      print rest >> out
      agg(rest)
      next
    }
    { agg($0) }
    END {
      if (cur != "") close(out)
      while ((getline line < offf) > 0) { sub(/\r$/, "", line); split(line, p, "\t"); noff[p[1]] = p[2] }
      # plan2: act idx off size mtime head path -> index: idx size off mtime head path
      printf "" > indexf
      while ((getline line < planf) > 0) {
        split(line, p, "\t")
        if (p[1] == "K") print p[2], p[4], p[3], p[5], p[6], p[7] > indexf
        else if (p[1] == "N" || p[1] == "T") print p[2], p[4], ((p[2] in noff) ? noff[p[2]] : p[3]), p[5], p[6], p[7] > indexf
      }
      close(indexf)
      for (k = 1; k <= n; k++) {
        id = order[k]
        a = agent[id]
        if (toolu[id] != "" && (toolu[id] in dtype)) a = dtype[toolu[id]]
        else if (a in byname) a = byname[a]
        g = day[id] OFS model[id] OFS a
        if (!(g in calls)) gorder[++ng] = g
        calls[g]++
        for (i = 7; i <= 10; i++) sum[g, i] += val[id, i]
      }
      print "source", ndirs, nfiles, n + 0, nd + 0
      for (k = 1; k <= ng; k++) {
        g = gorder[k]
        print "call", g, sum[g, 7] + 0, sum[g, 8] + 0, sum[g, 9] + 0, sum[g, 10] + 0, calls[g]
      }
      for (d in dcount) print "dispatch", d, dcount[d]
    }
  ' "$@"
}

# The new index is written beside the work files and moved over the old one
# only when every stage succeeded. Otherwise the old index is removed, so the
# next run reads everything again rather than trusting offsets that may have
# moved past records that were never stored (code review suggestion).
INDEX_NEW="$WORKD/index.tsv"
if [ "$READS" -gt 0 ]; then
  [ -n "$CACHE_DIR" ] || echo "usage-collect: reading $READS transcript file(s)..." >&2
  extract | jq -n -R -r --arg main "$MAIN_LABEL" --arg unknown "$UNKNOWN_SUBAGENT" \
      --arg secret "$SECRET_RE" "$JQ_EXTRACT" \
    | store_and_aggregate ${RECS[@]+"${RECS[@]}"} -
  STAGES="${PIPESTATUS[*]}"
elif [ "${#RECS[@]}" -gt 0 ]; then
  store_and_aggregate "${RECS[@]}"
  STAGES="$?"
else
  store_and_aggregate /dev/null
  STAGES="$?"
fi
if [ "${STAGES//[ 0]/}" != "" ]; then
  rm -f "$INDEX"
  err "reading the transcripts failed (stage exit codes: $STAGES); the cache index was reset."
  exit 1
fi
if ! mv -f "$INDEX_NEW" "$INDEX"; then
  rm -f "$INDEX"
  err "cannot update the cache index $INDEX; it was reset."
  exit 1
fi
