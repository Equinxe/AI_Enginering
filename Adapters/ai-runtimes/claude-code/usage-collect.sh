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
#   tool_use blocks      named Agent or Task: the block id, input.subagent_type
#                        and input.model — never input.prompt, never
#                        input.description
#   subagent .meta.json  agentType
#
# Every string it emits (model, agent type) is reduced to the characters
# [A-Za-z0-9:._@/ -], so a free-text value cannot carry arbitrary content into
# the output even if a future transcript put some in those fields.
#
# HOW IT STAYS STREAMING
#
# A long session's transcript is tens of megabytes; a project's directory can
# be hundreds. jq reads each file line by line (-R with `fromjson?`, so a
# truncated last line written while a session is live is skipped instead of
# aborting the file), emits one short TSV record per relevant line, and awk
# aggregates. No transcript is held in memory. The one piece of state that
# grows with input is awk's set of seen message ids, and it is required:
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
# each with a sibling .meta.json naming its agent type.
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

# One record per relevant line: `C` is an API call's usage, `D` a dispatch.
# Held in a quoted heredoc: it is a jq program, and `$agent`, `$m` and `$u`
# are jq variables, not shell ones.
JQ_EXTRACT="$(cat <<'JQ'
def clean: tostring | gsub("[^A-Za-z0-9:._@/ -]"; "?");
fromjson? | select(type == "object") |
(
  select(.type == "assistant" and (.message.id? | type) == "string"
         and (.message.usage? | type) == "object"
         and .message.model? != "<synthetic>")
  | .message as $m | $m.usage as $u
  | ["C", ($m.id | clean), ((.timestamp // "") | tostring | .[0:10]),
     ($m.model // "unknown" | clean), $agent,
     ($u.input_tokens // 0), ($u.output_tokens // 0),
     ($u.cache_creation_input_tokens // 0), ($u.cache_read_input_tokens // 0)]
  | @tsv
),
(
  select(.type == "assistant") | .message.content? | arrays | .[]
  | select(type == "object" and .type == "tool_use"
           and (.name == "Agent" or .name == "Task"))
  | ["D", (.id // "" | clean),
     (.input.subagent_type // "general-purpose" | clean),
     (.input.model // "inherit" | clean)]
  | @tsv
)
JQ
)"

JQ_META='.agentType // "subagent (type unknown)" | tostring | gsub("[^A-Za-z0-9:._@/ -]"; "?")'

extract() {
  local f agent meta
  for f in "${FILES[@]}"; do
    agent="main session"
    case "$f" in
      */subagents/*)
        meta="${f%.jsonl}.meta.json"
        agent="subagent (type unknown)"
        if [ -f "$meta" ]; then
          agent="$(jq -r "$JQ_META" < "$meta" 2>/dev/null || echo "subagent (type unknown)")"
        fi
        ;;
    esac
    # stdin, not a path argument: a native jq on Windows would otherwise need
    # the MSYS path translated, and a redirect needs nothing.
    jq -R -r --arg agent "$agent" "$JQ_EXTRACT" < "$f"
  done
}

# --- Aggregate -----------------------------------------------------------------

extract | awk -F '\t' -v OFS='\t' -v ndirs="${#DIRS[@]}" -v nfiles="${#FILES[@]}" '
  $1 == "C" {
    id = $2
    if (!(id in seen)) {
      seen[id] = 1; order[++n] = id
      day[id] = $3; model[id] = $4; agent[id] = $5
    }
    for (i = 6; i <= 9; i++) {
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
    next
  }
  END {
    for (k = 1; k <= n; k++) {
      id = order[k]
      g = day[id] OFS model[id] OFS agent[id]
      if (!(g in calls)) gorder[++ng] = g
      calls[g]++
      for (i = 6; i <= 9; i++) sum[g, i] += val[id, i]
    }
    print "source", ndirs, nfiles, n + 0, nd + 0
    for (k = 1; k <= ng; k++) {
      g = gorder[k]
      print "call", g, sum[g, 6] + 0, sum[g, 7] + 0, sum[g, 8] + 0, sum[g, 9] + 0, calls[g]
    }
    for (d in dcount) print "dispatch", d, dcount[d]
  }
'
