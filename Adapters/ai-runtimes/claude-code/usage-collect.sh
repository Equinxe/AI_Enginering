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
# project (not an error: the dashboard reports the source as missing), 1 on an
# error (jq absent, an explicit --transcripts-dir that does not exist), 2 on a
# usage error.

set -uo pipefail

err() { printf 'usage-collect: ERROR: %s\n' "$1" >&2; }

# A literal tab, set once: `IFS="$(printf '\t')"` in a read loop would fork
# on every iteration.
TAB=$'\t'

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
  SLUG="${CLAUDE_CODE_PROJECT_DIR_NAME:-$SLUG}"
  BASE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
  LOOKED="$BASE/$SLUG"
  if [ "${#SLUG}" -gt 200 ]; then
    for d in "$BASE/${SLUG:0:200}"*; do
      [ -d "$d" ] && DIRS+=("$d")
    done
  else
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
# quarter of a second and more.
LISTING="$(find "${DIRS[@]}" -type f -name '*.jsonl' -printf '%s\t%p\n' 2>/dev/null)"
if [ -z "$LISTING" ]; then
  LISTING="$(find "${DIRS[@]}" -type f -name '*.jsonl' -exec stat -f '%z%t%N' {} + 2>/dev/null)"
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

if [ -n "$CACHE_DIR" ]; then
  CACHE="$CACHE_DIR/v1"
else
  CACHE="$(mktemp -d "${TMPDIR:-/tmp}/obs330-collect.XXXXXX")" || { err "cannot create a temporary directory"; exit 1; }
  trap 'rm -rf "$CACHE"' EXIT
fi
REC="$CACHE/rec"
WORKD="$CACHE/work"
INDEX="$CACHE/index.tsv"
if { [ ! -d "$REC" ] || [ ! -d "$WORKD" ]; } && ! mkdir -p "$REC" "$WORKD"; then
  err "cannot create the cache directory $CACHE."
  exit 1
fi
[ -f "$INDEX" ] || : > "$INDEX"

# The plan, one line per file, from the previous index and the listing:
#   N idx 0 size path      new, or shrank: read from the start
#   T idx off size path    grew: read from the last complete line
#   K idx off size path    unchanged
#   X idx                  gone: drop its records
# It prints the number of transcripts.
PLAN="$WORKD/plan.tsv"
NFILES="$(F_INDEX="$INDEX" F_PLAN="$PLAN" awk -F '\t' -v OFS='\t' '
  BEGIN {
    f = ENVIRON["F_INDEX"]; planf = ENVIRON["F_PLAN"]
    while ((getline line < f) > 0) {
      split(line, p, "\t")
      oidx[p[4]] = p[1]; osize[p[4]] = p[2]; ooff[p[4]] = p[3]
      if (p[1] + 0 > max) max = p[1] + 0
    }
    printf "" > planf
  }
  $0 == "" { next }
  {
    size = $1; path = $2; seen[path] = 1; n++
    if (!(path in oidx)) print "N", ++max, 0, size, path > planf
    else if (size + 0 == osize[path] + 0) print "K", oidx[path], ooff[path], size, path > planf
    else if (size + 0 < ooff[path] + 0) print "N", oidx[path], 0, size, path > planf
    else print "T", oidx[path], ooff[path], size, path > planf
  }
  END { for (path in oidx) if (!(path in seen)) print "X", oidx[path] > planf; print n + 0 }
' <<< "$LISTING")"

# The meta-json of a subagent file, read with builtins into META_JSON — a
# variable, not printed for $(...) to capture, because a command substitution
# is a fork and a fork per file was a minute on Windows. A missing .meta.json
# is "{}": the unknown bucket; a main session is "". Tabs and newlines are
# flattened so it fits a line; it is parsed again, and shape-checked, by jq.
META_JSON=""
meta_of() {
  local f="$1" meta
  META_JSON=""
  case "$f" in
    */subagents/*)
      meta="${f%.jsonl}.meta.json"
      META_JSON="{}"
      if [ -f "$meta" ]; then
        IFS= read -r -d '' META_JSON < "$meta" || true
        META_JSON="${META_JSON//$'\r'/ }"; META_JSON="${META_JSON//$'\n'/ }"; META_JSON="${META_JSON//$'\t'/ }"
        [ -n "$META_JSON" ] || META_JSON="{}"
      fi
      ;;
  esac
}

FULLMAP="$WORKD/full.tsv"      # path idx size meta, files read from 0
TAILS="$WORKD/tails.tsv"       # idx off size path, files read from an offset
OFFS="$WORKD/offsets.tsv"      # idx offset, written by the prefilter
: > "$FULLMAP"; : > "$TAILS"; : > "$OFFS"
DROPS=()
RECS=()
READS=0
while IFS="$TAB" read -r act idx off size path; do
  case "$act" in
    N) : > "$REC/$idx.tsv"
       meta_of "$path"
       printf '%s\t%s\t%s\t%s\n' "$path" "$idx" "$size" "$META_JSON" >> "$FULLMAP"
       READS=$((READS + 1)) ;;
    T) printf '%s\t%s\t%s\t%s\n' "$idx" "$off" "$size" "$path" >> "$TAILS"
       RECS+=("$REC/$idx.tsv")
       READS=$((READS + 1)) ;;
    K) RECS+=("$REC/$idx.tsv") ;;
    X) DROPS+=("$REC/$idx.tsv") ;;
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
  if ($l | startswith("\u001eM ")) then {idx: $l[3:], agent: $main, toolu: "", line: null}
  elif ($l | startswith("\u001eS ")) then
    ($l[3:]) as $r | ($r | index(" ")) as $p
    | {idx: $r[:$p]} + ($r[$p + 1:] | meta_label) + {line: null}
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
  function take(line) { if (line ~ /"type": ?"assistant"/) print line }
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
    ' "$FULLMAP" "${full[@]}"
  fi
  # Files that grew: from the recorded offset, one tail and awk each.
  local idx off size path
  while IFS="$TAB" read -r idx off size path; do
    meta_of "$path"
    tail -c +"$((off + 1))" "$path" \
      | F_IDX="$idx" F_BASE="$off" F_SIZE="$size" F_MJ="$META_JSON" F_OFFS="$OFFS" \
        LC_ALL=C awk "$AWK_PREFILTER_FUNCS"'
          BEGIN { offf = ENVIRON["F_OFFS"]; start(ENVIRON["F_IDX"], ENVIRON["F_BASE"] + 0, ENVIRON["F_SIZE"] + 0, ENVIRON["F_MJ"]) }
          { line_in() }
          END { finish() }
        '
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
  F_REC="$REC" F_PLAN="$PLAN" F_OFFS="$OFFS" F_INDEX="$INDEX" \
  awk -F '\t' -v OFS='\t' -v ndirs="${#DIRS[@]}" -v nfiles="$NFILES" '
    BEGIN { recd = ENVIRON["F_REC"]; planf = ENVIRON["F_PLAN"]; offf = ENVIRON["F_OFFS"]; indexf = ENVIRON["F_INDEX"] }
    function agg(line,   f, id, i, v, key) {
      split(line, f, "\t")
      if (f[1] == "C") {
        id = f[2]
        if (!(id in seen)) {
          seen[id] = 1; order[++n] = id
          day[id] = f[3]; model[id] = f[4]; agent[id] = f[5]; toolu[id] = f[6]
        }
        for (i = 7; i <= 10; i++) { v = f[i] + 0; if (v > val[id, i]) val[id, i] = v }
      } else if (f[1] == "D") {
        key = (f[2] == "" ? "anon" (++anon) : f[2])
        if (key in dseen) return
        dseen[key] = 1; nd++
        dcount[f[3] OFS f[4]]++
        if (f[2] != "") dtype[f[2]] = f[3]
        if (f[5] != "" && f[5] != "(unrecognised)" && f[5] != "(redacted)") byname[f[5]] = f[3]
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
      printf "" > indexf
      while ((getline line < planf) > 0) {
        split(line, p, "\t")
        if (p[1] == "K") print p[2], p[4], p[3], p[5] > indexf
        else if (p[1] == "N" || p[1] == "T") print p[2], p[4], ((p[2] in noff) ? noff[p[2]] : p[3]), p[5] > indexf
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

if [ "$READS" -gt 0 ]; then
  [ -n "$CACHE_DIR" ] || echo "usage-collect: reading $READS transcript file(s)..." >&2
  if ! extract | jq -n -R -r --arg main "$MAIN_LABEL" --arg unknown "$UNKNOWN_SUBAGENT" \
        --arg secret "$SECRET_RE" "$JQ_EXTRACT" \
      | store_and_aggregate ${RECS[@]+"${RECS[@]}"} -; then
    err "extracting the transcripts failed."
    exit 1
  fi
elif [ "${#RECS[@]}" -gt 0 ]; then
  store_and_aggregate "${RECS[@]}"
else
  store_and_aggregate /dev/null
fi
