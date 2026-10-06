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
# transcript format is not — it is Claude Code's, not a published contract,
# and it will change. Keeping the parser beside the other Claude Code
# integrations means a change in that format is fixed in one runtime adapter,
# and a project on another runtime simply has no collector: the dashboard says
# the source is missing and renders the git half.
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
# HOW IT STAYS STREAMING
#
# A long session's transcript is tens of megabytes; a project's directory can
# be hundreds. Only lines carrying `"type":"assistant"` can hold usage or a
# dispatch, so one awk pass drops every other line before jq sees it — most
# of a transcript's bytes are tool results. One jq then reads line by line
# (-R with `fromjson?`, so a truncated last line written while a session is
# live is skipped instead of aborting the file), emits one short TSV record
# per relevant line, and awk aggregates. No transcript is held in memory.
# The one piece of state that grows with input is awk's set of seen message
# ids, and it is required:
# Claude Code writes one line per content block and repeats the same message,
# with the same usage, on each, so summing lines would count a message's
# tokens once per block. Per id the maximum of each counter is kept, since a
# streamed message's counters only grow.
#
# WHERE THE TRANSCRIPTS ARE
#
#   ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>/
#
# where <slug> is the project's absolute path in the platform's native form
# with every character outside [A-Za-z0-9] replaced by '-':
# C:\Developpement\AI_Enginering -> C--Developpement-AI-Enginering, and
# /home/me/app -> -home-me-app. Sessions started inside one of the project's
# runtime worktrees (.claude/worktrees/<name>) are stored under
# <slug>--claude-worktrees-<name> and are included. Main-session files are
# <dir>/<session>.jsonl; subagent files are <dir>/<session>/subagents/*.jsonl,
# each with a sibling .meta.json. Its agentType is the agent TYPE for a plain
# dispatch but the dispatch's NAME for a named teammate ("lexer-attack"), so
# a subagent file is attributed through its toolUseId to the dispatch that
# spawned it, then through a dispatch name, and only then to agentType as
# written.
#
# USAGE
#
#   usage-collect.sh --project-dir DIR [--transcripts-dir DIR]
#
# --transcripts-dir replaces the slug resolution with an explicit directory.
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

usage() {
  echo "Usage: $0 --project-dir DIR [--transcripts-dir DIR]" >&2
  echo "  Prints aggregate Claude Code usage (tokens, models, dispatches) for a project." >&2
}

PROJECT_DIR=""
TRANSCRIPTS_DIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir) [ "$#" -ge 2 ] || { usage; exit 2; }; PROJECT_DIR="$2"; shift 2 ;;
    --transcripts-dir) [ "$#" -ge 2 ] || { usage; exit 2; }; TRANSCRIPTS_DIR="$2"; shift 2 ;;
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
if [ -n "$TRANSCRIPTS_DIR" ]; then
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
  SLUG="$(printf '%s' "$ABS" | sed 's/[^A-Za-z0-9]/-/g')"
  BASE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
  LOOKED="$BASE/$SLUG"
  for d in "$BASE/$SLUG" "$BASE/$SLUG"--claude-worktrees-*; do
    [ -d "$d" ] && DIRS+=("$d")
  done
fi

if [ "${#DIRS[@]}" -eq 0 ]; then
  echo "usage-collect: no Claude Code transcripts for this project (looked for $LOOKED)." >&2
  exit 3
fi

FILES=()
while IFS= read -r f; do
  FILES+=("$f")
done < <(find "${DIRS[@]}" -type f -name '*.jsonl' 2>/dev/null | LC_ALL=C sort)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "usage-collect: $LOOKED exists but holds no .jsonl transcript." >&2
  exit 3
fi

# --- Extract -----------------------------------------------------------------

echo "usage-collect: reading ${#FILES[@]} transcript file(s)..." >&2

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

# ONE jq process reads every file. Spawning a native jq (and a grep) per file
# cost about 0.25 s each on Windows, which across a few hundred transcripts
# and their .meta.json files was most of the run time; the parsing itself is
# a few seconds. So awk prefilters every transcript in one pass and writes a
# marker line before each file's lines — "\036M" for a main session, or
# "\036S <meta-json>" for a subagent — and jq carries the current file's
# label through a `foreach`.
#
# One record per relevant line: `C` is an API call's usage, `D` a dispatch.
# Held in a quoted heredoc: it is a jq program, and `$agent`, `$toolu`, `$m`,
# `$u` and `$l` are jq variables, not shell ones.
JQ_EXTRACT="$JQ_SHAPES
$(cat <<'JQ'
def meta_label:
  (.[3:] | fromjson? // {}) as $mj
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
foreach inputs as $l ({agent: $main, toolu: "", line: null};
  if $l == "\u001eM" then {agent: $main, toolu: "", line: null}
  elif ($l | startswith("\u001eS ")) then ($l | meta_label) + {line: null}
  else .line = $l end;
  select(.line != null) | .agent as $a | .toolu as $t | .line | extract($a; $t))
JQ
)"

# path <TAB> meta-json, one line per subagent file, read with bash builtins
# only (no process per file). A missing .meta.json is "{}": the unknown bucket.
METAMAP="$(mktemp "${TMPDIR:-/tmp}/obs326-meta.XXXXXX")" || { err "cannot create a temporary file"; exit 1; }
trap 'rm -f "$METAMAP"' EXIT
for f in "${FILES[@]}"; do
  case "$f" in
    */subagents/*)
      meta="${f%.jsonl}.meta.json"
      mj="{}"
      if [ -f "$meta" ]; then
        IFS= read -r -d '' mj < "$meta" || true
        mj="${mj//$'\r'/ }"; mj="${mj//$'\n'/ }"; mj="${mj//$'\t'/ }"
      fi
      printf '%s\t%s\n' "$f" "$mj" >> "$METAMAP"
      ;;
  esac
done

extract() {
  # The awk prefilter keeps only lines that can hold usage or a dispatch.
  # File names reach it as arguments and the map through the environment
  # (not -v, which would process backslashes in a Windows path).
  F_META="$METAMAP" awk '
    BEGIN { mapf = ENVIRON["F_META"] }
    FILENAME == mapf { i = index($0, "\t"); meta[substr($0, 1, i - 1)] = substr($0, i + 1); next }
    FNR == 1 { if (FILENAME in meta) print "\036S " meta[FILENAME]; else print "\036M" }
    /"type": ?"assistant"/ { print }
  ' "$METAMAP" "${FILES[@]}" \
    | jq -n -R -r --arg main "$MAIN_LABEL" --arg unknown "$UNKNOWN_SUBAGENT" \
        --arg secret "$SECRET_RE" "$JQ_EXTRACT"
}

# --- Aggregate -----------------------------------------------------------------

# C: id day model agent toolu input output cache_creation cache_read
# D: tool-id subagent_type model name
# A subagent file's label is resolved at the end, once every dispatch is
# known: its spawning tool_use id first, then a dispatch name, then as written.
extract | awk -F '\t' -v OFS='\t' -v ndirs="${#DIRS[@]}" -v nfiles="${#FILES[@]}" '
  { sub(/\r$/, "") }
  $1 == "C" {
    id = $2
    if (!(id in seen)) {
      seen[id] = 1; order[++n] = id
      day[id] = $3; model[id] = $4; agent[id] = $5; toolu[id] = $6
    }
    for (i = 7; i <= 10; i++) {
      v = $i + 0
      if (v > val[id, i]) val[id, i] = v
    }
    next
  }
  $1 == "D" {
    key = ($2 == "" ? "anon" NR : $2)
    if (key in dseen) next
    dseen[key] = 1; nd++
    dcount[$3 OFS $4]++
    if ($2 != "") dtype[$2] = $3
    if ($5 != "" && $5 != "(unrecognised)" && $5 != "(redacted)") byname[$5] = $3
    next
  }
  END {
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
'
