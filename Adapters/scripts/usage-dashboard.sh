#!/usr/bin/env bash
# IA Engineering — usage-dashboard.sh
#
# Builds ONE self-contained static HTML page showing how a project actually
# uses its Employees and Agent Chains: which Employees are dispatched and
# commit most, which are never used, which chain steps are never exercised,
# which models do the work, and how many tokens it takes per day.
#
# WHY THIS EXISTS
#
# The roster (Registry/employees.yml) and the chains (Registry/chains.yml) are
# design decisions: forty-odd Employees and six chains, each a claim that the
# work needs that role at that step. Nothing measured whether the claims held.
# An Employee that is never dispatched is either a gap in Core/EMPLOYEE_SELECTION.md's
# triggers, a chain that routes around it, or a role the work does not need,
# and those are three different decisions — but all three start with seeing
# the zero. This page makes the zero visible. It informs roster and chain
# tuning; it decides nothing (Governance/DISPATCH_IN_PRACTICE.md, Measuring
# Usage).
#
# WHAT IT READS
#
#   git (runtime-agnostic)   per commit: the `Employee:`, `Work Unit:` and
#                            `Co-Authored-By:` trailers, and the numstat line
#                            counts — never the rest of the message, never a
#                            diff. Non-merge commits only.
#   Registry/employees.yml   the framework roster, plus the project roster
#                            (.ia-engineering/Registry/employees.yml) unioned
#                            in exactly as check-employee-trailers.sh does
#   Registry/chains.yml      chain steps, in order
#   Registry/work-units.yml  the PROJECT's own registry, never the framework's
#                            read on its behalf (WU-IAENG-320)
#   AI-runtime transcripts   through a runtime collector, when one is present:
#                            Adapters/ai-runtimes/claude-code/usage-collect.sh.
#                            Absent collector or absent transcripts is a
#                            source reported as missing, not an error.
#
# Standards/DATA_PROTECTION_STANDARD.md: the page holds aggregates only —
# counts, token totals, names of Employees, models, agent types and Work Unit
# IDs. No prompt, reply, commit-message body, file content or secret is read
# into it. The default output path is gitignored (.ia-engineering/usage/), and
# the page makes no network request: inline CSS, inline JS, inline SVG.
#
# USAGE
#
#   usage-dashboard.sh [--project-dir DIR] [--out FILE] [--since REF]
#                      [--transcripts-dir DIR] [--prices FILE] [--open]
#
#   --project-dir      the project's git work tree (default: the one containing
#                      the current directory)
#   --out              output file (default: <project>/.ia-engineering/usage/dashboard.html)
#   --since            start of the "range" columns (default: the latest v* tag
#                      reachable from HEAD; all-time columns are always shown)
#   --transcripts-dir  passed to the runtime collector instead of its own lookup
#   --prices           a TSV of USD prices per million tokens, one model per
#                      line: <model-id> <input> <output> <cache-write> <cache-read>.
#                      Without it the page shows no cost, and says so.
#   --open             open the page in the default browser afterwards
#                      ($IAENG_USAGE_OPENER, when set, is used as the opener)
#
# Requires bash, git, awk and jq — the framework's existing dependencies.
#
# Exit 0 when the page was written, 1 when it could not be (not a git work
# tree, a dependency or the roster missing, a bad --since ref, a write
# failure), 2 on a usage error.

set -uo pipefail

err() { printf 'usage-dashboard: ERROR: %s\n' "$1" >&2; }
note() { printf 'usage-dashboard: %s\n' "$1" >&2; }

usage() {
  cat >&2 <<'USAGE'
Usage: usage-dashboard.sh [--project-dir DIR] [--out FILE] [--since REF]
                          [--transcripts-dir DIR] [--prices FILE] [--open]
  Builds a self-contained HTML usage dashboard (Employees, chains, models,
  tokens, Work Units) for a project. Aggregates only; no network.
USAGE
}

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)"
COLLECTOR="$FRAMEWORK_DIR/Adapters/ai-runtimes/claude-code/usage-collect.sh"

PROJECT_ARG=""
OUT=""
SINCE=""
TRANSCRIPTS_DIR=""
PRICES=""
OPEN=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir|--out|--since|--transcripts-dir|--prices)
      if [ "$#" -lt 2 ]; then err "$1 needs a value"; usage; exit 2; fi
      case "$1" in
        --project-dir) PROJECT_ARG="$2" ;;
        --out) OUT="$2" ;;
        --since) SINCE="$2" ;;
        --transcripts-dir) TRANSCRIPTS_DIR="$2" ;;
        --prices) PRICES="$2" ;;
      esac
      shift 2 ;;
    --open) OPEN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument '$1'"; usage; exit 2 ;;
  esac
done

for dep in git awk jq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    err "$dep is required and was not found on PATH."
    exit 1
  fi
done

# --- The project ---------------------------------------------------------------

START_DIR="${PROJECT_ARG:-.}"
if [ ! -d "$START_DIR" ]; then
  err "--project-dir '$START_DIR' does not exist."
  exit 1
fi
if ! PROJECT="$(git -C "$START_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  err "'$START_DIR' is not inside a git work tree. The dashboard reads Employee and Work Unit trailers from git history; there is nothing to measure without one. Pass --project-dir <your project>."
  exit 1
fi
if ! git -C "$PROJECT" rev-parse -q --verify HEAD >/dev/null; then
  err "$PROJECT has no commits yet; there is no history to measure."
  exit 1
fi

OUT="${OUT:-$PROJECT/.ia-engineering/usage/dashboard.html}"

if [ -n "$PRICES" ] && [ ! -f "$PRICES" ]; then
  err "--prices '$PRICES' does not exist."
  exit 1
fi

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/obs326-usage.XXXXXX")" || { err "cannot create a temporary directory"; exit 1; }
trap 'rm -rf "$TMPD"' EXIT

# Sources, for the page header: name <TAB> found|missing|error <TAB> detail.
SOURCES="$TMPD/sources.tsv"
: > "$SOURCES"
source_line() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$SOURCES"; }

# first_file <candidate...> — the first candidate that names an existing file.
first_file() {
  local c
  for c in "$@"; do
    if [ -n "$c" ] && [ -f "$c" ]; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

# Paths shown on the page are relative to the project, or to the framework,
# so the page does not carry the local directory layout of the machine.
show_path() {
  case "$1" in
    "$PROJECT"/*) printf '%s' "${1#"$PROJECT"/}" ;;
    "$FRAMEWORK_DIR"/*) printf 'framework:%s' "${1#"$FRAMEWORK_DIR"/}" ;;
    *) printf '%s' "$(basename -- "$1")" ;;
  esac
}

# --- Rosters ---------------------------------------------------------------------
# The same resolution as check-employee-trailers.sh, with the framework this
# script belongs to as the last candidate: a project that vendors the
# framework under ia-engineering/ finds it there, and a run from anywhere else
# still has the roster the script shipped with.

ROSTER_TSV="$TMPD/roster.tsv"
if ! ROSTER="$(first_file "${IAENG_REGISTRY:-}" "$PROJECT/Registry/employees.yml" \
    "$PROJECT/ia-engineering/Registry/employees.yml" "$FRAMEWORK_DIR/Registry/employees.yml")"; then
  err "Could not locate Registry/employees.yml (looked at \$IAENG_REGISTRY, the project's Registry/ and ia-engineering/Registry/, and $FRAMEWORK_DIR/Registry/). Without the roster, never-used Employees cannot be shown."
  exit 1
fi
grep -E '^  - name: ' "$ROSTER" | sed 's/^  - name: //' | tr -d '\r' | sed 's/$/\tframework/' > "$ROSTER_TSV"
if [ ! -s "$ROSTER_TSV" ]; then
  err "$ROSTER yielded no Employee names (parsing contract: '  - name: <Name>')."
  exit 1
fi
source_line "Employee roster" found "$(show_path "$ROSTER") ($(grep -c . "$ROSTER_TSV") Employees)"

PROJECT_ROSTER=""
if [ -n "${IAENG_PROJECT_ROSTER:-}" ]; then
  if [ ! -f "$IAENG_PROJECT_ROSTER" ]; then
    err "IAENG_PROJECT_ROSTER is set to '$IAENG_PROJECT_ROSTER' but no such file exists; fix the path or unset it."
    exit 1
  fi
  PROJECT_ROSTER="$IAENG_PROJECT_ROSTER"
elif [ -f "$PROJECT/.ia-engineering/Registry/employees.yml" ]; then
  PROJECT_ROSTER="$PROJECT/.ia-engineering/Registry/employees.yml"
fi
if [ -n "$PROJECT_ROSTER" ]; then
  before="$(grep -c . "$ROSTER_TSV")"
  grep -E '^  - name: ' "$PROJECT_ROSTER" | sed 's/^  - name: //' | tr -d '\r' | sed 's/$/\tproject/' >> "$ROSTER_TSV"
  source_line "Project roster" found "$(show_path "$PROJECT_ROSTER") ($(( $(grep -c . "$ROSTER_TSV") - before )) Domain Employees)"
else
  source_line "Project roster" missing "no .ia-engineering/Registry/employees.yml (no Domain Employees)"
fi

# --- Chains ----------------------------------------------------------------------
# chain <TAB> employee|gate <TAB> name <TAB> always|conditional, in file order.
# A step is conditional when it carries a `when:` other than `Always`.

CHAINS_TSV="$TMPD/chains.tsv"
: > "$CHAINS_TSV"
if CHAINS="$(first_file "$PROJECT/Registry/chains.yml" "$PROJECT/ia-engineering/Registry/chains.yml" \
    "$FRAMEWORK_DIR/Registry/chains.yml")"; then
  tr -d '\r' < "$CHAINS" | awk -v OFS='\t' '
    function flush() { if (kind != "") print chain, kind, name, cond; kind = "" }
    /^  - name: /         { flush(); chain = substr($0, 11); next }
    /^      - employee: / { flush(); kind = "employee"; name = substr($0, 19); cond = "always"; next }
    /^      - gate: /     { flush(); kind = "gate"; name = substr($0, 15); cond = "always"; next }
    /^        when: /     { if (kind != "" && substr($0, 15) != "Always") cond = "conditional"; next }
    END { flush() }
  ' > "$CHAINS_TSV"
  source_line "Agent Chains" found "$(show_path "$CHAINS") ($(cut -f1 "$CHAINS_TSV" | sort -u | grep -c .) chains)"
else
  source_line "Agent Chains" missing "no Registry/chains.yml"
fi

# --- Work Unit registry ------------------------------------------------------------

WUS_TSV="$TMPD/wus.tsv"
: > "$WUS_TSV"
if WUS="$(first_file "${IAENG_REGISTRY_WORK_UNITS:-}" "$PROJECT/Registry/work-units.yml")"; then
  tr -d '\r' < "$WUS" | awk -v OFS='\t' '
    /^  - id: /       { id = substr($0, 9); next }
    /^    employee: / { if (id != "") { print id, substr($0, 15); id = "" } }
  ' > "$WUS_TSV"
  source_line "Work Unit registry" found "$(show_path "$WUS") ($(grep -c . "$WUS_TSV") Work Units)"
else
  source_line "Work Unit registry" missing "no Registry/work-units.yml in the project"
fi

# --- Git history ---------------------------------------------------------------------

if [ -z "$SINCE" ]; then
  SINCE="$(git -C "$PROJECT" describe --tags --abbrev=0 --match 'v*' HEAD 2>/dev/null || true)"
fi
INRANGE="$TMPD/inrange.txt"
if [ -n "$SINCE" ]; then
  if ! git -C "$PROJECT" rev-parse -q --verify "$SINCE^{commit}" >/dev/null; then
    err "--since '$SINCE' is not a commit in $PROJECT."
    exit 1
  fi
  RANGE_LABEL="since $SINCE"
  if ! git -C "$PROJECT" rev-list --no-merges "$SINCE..HEAD" > "$INRANGE"; then
    err "git rev-list failed over $SINCE..HEAD."
    exit 1
  fi
else
  RANGE_LABEL="all time (no release tag)"
  if ! git -C "$PROJECT" rev-list --no-merges HEAD > "$INRANGE"; then
    err "git rev-list failed."
    exit 1
  fi
fi

BODIES="$TMPD/bodies.txt"
NUMSTAT="$TMPD/numstat.txt"
if ! git -C "$PROJECT" log --no-merges --format='%x1e%H%n%B' > "$BODIES" \
  || ! git -C "$PROJECT" log --no-merges --format='%x1e%H' --numstat > "$NUMSTAT"; then
  err "git log failed in $PROJECT."
  exit 1
fi

# sha <TAB> in-range <TAB> employee <TAB> work-unit <TAB> model <TAB> added <TAB> deleted
# Only the three trailer lines are taken from each message; the rest of the
# body is read past and never written anywhere.
COMMITS_TSV="$TMPD/commits.tsv"
{
  sed 's/^/R\t/' "$INRANGE"
  sed 's/^/N\t/' "$NUMSTAT"
  sed 's/^/B\t/' "$BODIES"
} | tr -d '\r' | awk -F '\t' -v OFS='\t' '
  function flush() {
    if (sha == "") return
    print sha, (sha in inr ? 1 : 0), (emp == "" ? "(none)" : emp), (wu == "" ? "(none)" : wu),
          (model == "" ? "(none)" : model), add[sha] + 0, del[sha] + 0
    sha = ""
  }
  $1 == "R" { inr[$2] = 1; next }
  $1 == "N" {
    if (substr($2, 1, 1) == "\036") { cur = substr($2, 2); next }
    if ($2 ~ /^[0-9]+$/) add[cur] += $2
    if ($3 ~ /^[0-9]+$/) del[cur] += $3
    next
  }
  $1 == "B" {
    line = substr($0, 3)
    if (substr(line, 1, 1) == "\036") { flush(); sha = substr(line, 2); emp = wu = model = ""; next }
    if (emp == "" && line ~ /^Employee: /) emp = substr(line, 11)
    else if (wu == "" && line ~ /^Work Unit: /) wu = substr(line, 12)
    else if (model == "" && tolower(line) ~ /^co-authored-by: /) { model = substr(line, 17); sub(/ *<.*$/, "", model) }
  }
  END { flush() }
' > "$COMMITS_TSV"
source_line "Git history" found "$(grep -c . "$COMMITS_TSV") non-merge commits; range: $RANGE_LABEL"

# --- AI-runtime transcripts -------------------------------------------------------------

USAGE_TSV="$TMPD/usage.tsv"
: > "$USAGE_TSV"
if [ -f "$COLLECTOR" ]; then
  collect_args=(--project-dir "$PROJECT")
  [ -n "$TRANSCRIPTS_DIR" ] && collect_args+=(--transcripts-dir "$TRANSCRIPTS_DIR")
  bash "$COLLECTOR" "${collect_args[@]}" > "$USAGE_TSV" 2> "$TMPD/collect.err"
  rc=$?
  case "$rc" in
    0)
      read -r _ ndirs nfiles ncalls ndisp < <(grep -m1 '^source' "$USAGE_TSV")
      source_line "Claude Code transcripts" found "$nfiles files in $ndirs director$( [ "$ndirs" = 1 ] && echo y || echo ies); $ncalls API calls, $ndisp dispatches" ;;
    3)
      : > "$USAGE_TSV"
      source_line "Claude Code transcripts" missing "none found for this project" ;;
    *)
      : > "$USAGE_TSV"
      note "the Claude Code collector failed (exit $rc); the page is built without transcript data: $(head -c 300 "$TMPD/collect.err")"
      source_line "Claude Code transcripts" error "collector exit $rc; see the command's output" ;;
  esac
else
  source_line "Claude Code transcripts" missing "no runtime collector installed"
fi

PRICES_TSV="$TMPD/prices.tsv"
: > "$PRICES_TSV"
if [ -n "$PRICES" ]; then
  tr -d '\r' < "$PRICES" | grep -vE '^[[:space:]]*(#|$)' > "$PRICES_TSV" || true
  source_line "Prices" found "$(grep -c . "$PRICES_TSV") model price line(s), USD per million tokens"
else
  source_line "Prices" missing "no --prices file; no cost is shown"
fi

# --- Aggregate ---------------------------------------------------------------------------

# The `Engineer` placeholder in Registry/chains.yml stands for whichever
# implementing Employee the work needs (that file's header lists them). Its
# usage is the sum of theirs, labelled as such on the page.
ENGINEERS="Backend Engineer|Frontend Engineer|iOS Engineer|Android Engineer|Cross-Platform Engineer|Database Engineer|Event-Driven Engineer|Integration Engineer"

JQ_BUILD="$(cat <<'JQ'
def rows($s): $s | split("\n") | map(select(length > 0) | split("\t"));
def slug: ascii_downcase | gsub("/"; " ") | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | rtrimstr("-");
def clip: tostring | if length > 80 then .[0:77] + "..." else . end;
def tally(f): reduce .[] as $x ({}; .[$x | f] += 1);

(rows($commits) | map({sha: .[0], inr: (.[1] == "1"), emp: (.[2] | clip), wu: (.[3] | clip),
                       model: (.[4] | clip), add: (.[5] | tonumber), del: (.[6] | tonumber)})) as $c
| (rows($usage)) as $u
| ($u | map(select(.[0] == "dispatch") | {type: .[1], model: .[2], n: (.[3] | tonumber)})) as $disp
| ($u | map(select(.[0] == "call") | {day: .[1], model: .[2], agent: .[3],
        input: (.[4] | tonumber), output: (.[5] | tonumber), cw: (.[6] | tonumber),
        cr: (.[7] | tonumber), calls: (.[8] | tonumber)})) as $calls
| (reduce $disp[] as $d ({}; .[$d.type] += $d.n)) as $dispByType
| ($c | tally(.emp)) as $commitsAll
| ($c | map(select(.inr)) | tally(.emp)) as $commitsRange
| (rows($wus)) as $wuRows
| ($wuRows | tally(.[1])) as $wuByEmp
| (reduce rows($roster)[] as $r ([]; if (map(.[0]) | index($r[0])) != null then . else . + [$r] end)) as $rosterRows
| ($rosterRows | map(.[0] | slug)) as $rosterSlugs
| ($rosterRows | map(.[0])) as $rosterNames
| ($rosterRows | map(.[0] as $n | {
      name: $n, roster: .[1],
      dispatches: ($dispByType[$n | slug] // 0),
      commits_range: ($commitsRange[$n] // 0),
      commits_all: ($commitsAll[$n] // 0),
      work_units: ($wuByEmp[$n] // 0)
    } | .activity = (.dispatches + .commits_all + .work_units)
      | .status = (if .activity == 0 then "never" elif (.dispatches + .commits_all) < 3 then "rare" else "used" end))
  | sort_by(-.dispatches, -.commits_all, -.work_units, .name)) as $employees
| ($employees | map({key: .name, value: .}) | from_entries) as $empIdx
| ($engineers | split("|") | map(select(. as $e | $rosterNames | index($e)))) as $engSet
| (rows($chains) | reduce .[] as $r ([];
      if (length > 0 and .[-1].name == $r[0]) then .[-1].steps += [$r] else . + [{name: $r[0], steps: [$r]}] end)
   | map(.steps |= (to_entries | map(.value as $s | {n: (.key + 1), kind: $s[1], name: $s[2], conditional: ($s[3] == "conditional")}
        | if .kind == "gate" then .
          elif .name == "Engineer" then
            .placeholder = true
            | .dispatches = ([$engSet[] | $empIdx[.].dispatches] | add // 0)
            | .commits_all = ([$engSet[] | $empIdx[.].commits_all] | add // 0)
            | .commits_range = ([$engSet[] | $empIdx[.].commits_range] | add // 0)
          else
            .dispatches = ($empIdx[.name].dispatches // 0)
            | .commits_all = ($empIdx[.name].commits_all // 0)
            | .commits_range = ($empIdx[.name].commits_range // 0)
            | .on_roster = ($empIdx[.name] != null)
          end
        | if .kind == "employee" then .exercised = ((.dispatches + .commits_all) > 0) else . end)))
   | map(.exercised = ([.steps[] | select(.kind == "employee" and .exercised)] | length)
         | .employee_steps = ([.steps[] | select(.kind == "employee")] | length))) as $chainList
| ($disp | map(select(.type as $t | $rosterSlugs | index($t) | not))
   | group_by(.type) | map({type: .[0].type, dispatches: (map(.n) | add)}) | sort_by(-.dispatches, .type)) as $otherAgents
| ($disp | sort_by(.type, .model)) as $dispModels
| ($c | map(select(.emp != "(none)" and (.emp as $e | $rosterNames | index($e) | not)))
   | group_by(.emp) | map({name: .[0].emp, commits: length}) | sort_by(-.commits)) as $unrostered
| ($c | group_by(.model) | map({model: .[0].model, commits_all: length, commits_range: (map(select(.inr)) | length)})
   | sort_by(-.commits_all)) as $commitModels
| (rows($prices) | map({key: .[0], value: {input: (.[1] | tonumber? // 0), output: (.[2] | tonumber? // 0),
                                             cw: (.[3] | tonumber? // 0), cr: (.[4] | tonumber? // 0)}}) | from_entries) as $price
| def sums: {calls: (map(.calls) | add // 0), input: (map(.input) | add // 0), output: (map(.output) | add // 0),
             cw: (map(.cw) | add // 0), cr: (map(.cr) | add // 0)}
            | .total = (.input + .output + .cw + .cr)
            | .cache_read_share = (if (.input + .cw + .cr) > 0 then (.cr / (.input + .cw + .cr)) else 0 end);
  def cost($m): if $price[$m] then ((.input * $price[$m].input + .output * $price[$m].output
                                      + .cw * $price[$m].cw + .cr * $price[$m].cr) / 1000000) else null end;
{
  generated: $generated, project: $project, range: $range_label,
  sources: (rows($sources) | map({name: .[0], status: .[1], detail: .[2]})),
  have_transcripts: (($calls | length) > 0 or ($disp | length) > 0),
  have_prices: (($price | length) > 0),
  employees: $employees,
  other_agents: $otherAgents,
  dispatch_models: $dispModels,
  unrostered: $unrostered,
  chains: $chainList,
  engineer_set: $engSet,
  commit_models: $commitModels,
  calls_by_model: ($calls | group_by(.model) | map(.[0].model as $m | sums + {model: $m} | .cost = cost($m)) | sort_by(-.calls)),
  tokens_by_day: ($calls | group_by(.day) | map(sums + {day: .[0].day}) | sort_by(.day) | reverse),
  tokens_by_agent: ($calls | group_by(.agent) | map(sums + {agent: .[0].agent}) | sort_by(-.total)),
  work_units: ($c | map(select(.wu != "(none)")) | group_by(.wu)
               | map(.[0].wu as $id | {id: $id,
                     employee: (($wuRows | map(select(.[0] == $id)) | .[0][1]) // .[0].emp),
                     commits: length, commits_range: (map(select(.inr)) | length),
                     lines: (map(.add + .del) | add)})
               | sort_by(-.commits, -.lines) | .[0:30]),
  totals: {
    roster: ($employees | length),
    never: ($employees | map(select(.status == "never")) | length),
    rare: ($employees | map(select(.status == "rare")) | length),
    dispatches: ($disp | map(.n) | add // 0),
    commits_all: ($c | length),
    commits_range: ($c | map(select(.inr)) | length),
    tokens: ($calls | sums)
  }
}
JQ
)"

DATA="$TMPD/data.json"
if ! jq -n \
    --rawfile commits "$COMMITS_TSV" --rawfile usage "$USAGE_TSV" --rawfile wus "$WUS_TSV" \
    --rawfile roster "$ROSTER_TSV" --rawfile chains "$CHAINS_TSV" --rawfile sources "$SOURCES" \
    --rawfile prices "$PRICES_TSV" --arg engineers "$ENGINEERS" \
    --arg generated "$(date -u '+%Y-%m-%d %H:%M UTC')" --arg project "$(basename -- "$PROJECT")" \
    --arg range_label "$RANGE_LABEL" \
    "$JQ_BUILD" > "$DATA"; then
  err "aggregating the collected data failed (jq). No page was written."
  exit 1
fi

# --- Render ------------------------------------------------------------------------------
# One jq program turns the aggregate into the page. Every string goes through
# @html; the embedded JSON copy has `<` escaped so it cannot close its script.

JQ_RENDER="$(cat <<'JQ'
def e: tostring | @html;
def commas: tostring as $s | if ($s | length) <= 3 then $s else ($s[0:-3] | commas) + "," + $s[-3:] end;
def n: if type == "number" then (round | commas) else e end;
def pct: (. * 1000 | round / 10 | tostring) + "%";
def usd: if . == null then "n/a" else ((. * 100 | round) / 100 | tostring | "$" + .) end;
def short: tostring | if length > 34 then .[0:31] + "..." else . end;

# cell: a number (sortable, right-aligned), a string, or {h: raw-html, v: sort-key}.
def cell: if type == "number" then "<td class=\"num\" data-v=\"\(.)\">\(n)</td>"
          elif type == "object" then "<td data-v=\"\(.v | e)\">\(.h)</td>"
          elif . == null then "<td data-v=\"\">n/a</td>"
          else "<td>\(e)</td>" end;
def table($caption; $heads; $rows):
  "<div class=\"tw\"><table class=\"sortable\"><caption>\($caption | e)</caption><thead><tr>"
  + ($heads | map("<th scope=\"col\" data-type=\"\(.[1])\"><button type=\"button\">\(.[0] | e)</button></th>") | join(""))
  + "</tr></thead><tbody>"
  + (if ($rows | length) == 0 then "<tr><td colspan=\"\($heads | length)\" class=\"empty\">No data.</td></tr>"
     else ($rows | map("<tr\(if .cls then " class=\"" + .cls + "\"" else "" end)>" + (.cells | map(cell) | join("")) + "</tr>") | join("")) end)
  + "</tbody></table></div>";
def barchart($title; $rows):
  ($rows | map(.value) | max // 0) as $max
  | if ($rows | length) == 0 then "<p class=\"empty\">\($title | e): no data.</p>" else
  "<figure><figcaption>\($title | e)</figcaption><svg role=\"img\" aria-label=\"\($title | e)\" viewBox=\"0 0 720 \(($rows | length) * 24 + 8)\" preserveAspectRatio=\"xMinYMin meet\">"
  + ([$rows | to_entries[] | .key as $i | .value as $r | ($i * 24 + 4) as $y
      | (if $max > 0 then ($r.value / $max * 360) else 0 end) as $w
      | "<g><title>\($r.label | e): \($r.value | n)</title>"
        + "<text x=\"236\" y=\"\($y + 15)\" class=\"lbl\" text-anchor=\"end\">\($r.label | short | e)</text>"
        + (if $w > 0 then "<rect x=\"244\" y=\"\($y + 3)\" width=\"\([$w, 2] | max)\" height=\"16\" rx=\"3\" class=\"bar\"/>" else "" end)
        + "<text x=\"\(250 + $w)\" y=\"\($y + 15)\" class=\"val\">\($r.value | n)</text></g>"] | join(""))
  + "</svg></figure>" end;
def badge: if . == "never" then {h: "<span class=\"badge never\">NEVER USED</span>", v: "0"}
           elif . == "rare" then {h: "<span class=\"badge rare\">rarely used</span>", v: "1"}
           else {h: "<span class=\"badge used\">used</span>", v: "2"} end;

. as $d
| $d.totals as $t
| "<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">"
+ "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
+ "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:\">"
+ "<title>Usage dashboard - \($d.project | e)</title><style>
:root{color-scheme:light;--surface:#fcfcfb;--panel:#f3f2ef;--text:#0b0b0b;--text2:#52514e;--rule:#d6d4cf;--bar:#2a78d6;--never-bg:#fde7e7;--never-fg:#8a1414;--rare-bg:#fff3d6;--rare-fg:#6b4a00;--used-fg:#1f5a1f;--focus:#2a78d6}
@media (prefers-color-scheme: dark){:root{color-scheme:dark;--surface:#1a1a19;--panel:#242422;--text:#ffffff;--text2:#c3c2b7;--rule:#45443f;--bar:#3987e5;--never-bg:#4a1c1c;--never-fg:#ffd2d2;--rare-bg:#3d3214;--rare-fg:#ffe7a8;--used-fg:#b9e6b9;--focus:#86b6ef}}
*{box-sizing:border-box}body{margin:0;background:var(--surface);color:var(--text);font:15px/1.5 system-ui,-apple-system,'Segoe UI',Roboto,sans-serif}
main{max-width:1100px;margin:0 auto;padding:24px}h1{font-size:1.6rem;margin:0 0 4px}h2{font-size:1.25rem;margin:40px 0 8px;padding-top:8px;border-top:1px solid var(--rule)}h3{font-size:1.05rem;margin:24px 0 6px}
p,li{color:var(--text)}.muted{color:var(--text2)}nav a{color:var(--text);margin-right:14px}a:focus,button:focus{outline:3px solid var(--focus);outline-offset:2px}
.tiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:12px;margin:16px 0}.tile{background:var(--panel);border-radius:8px;padding:12px}.tile .k{font-size:.85rem;color:var(--text2)}.tile .v{font-size:1.5rem;font-weight:650;font-variant-numeric:tabular-nums}
.tw{overflow-x:auto}table{border-collapse:collapse;width:100%;margin:8px 0 16px;font-variant-numeric:tabular-nums}caption{text-align:left;font-weight:600;padding:4px 0;color:var(--text)}
th,td{padding:5px 10px;border-bottom:1px solid var(--rule);text-align:left;vertical-align:top}td.num{text-align:right}th button{all:unset;cursor:pointer;font-weight:600;color:var(--text)}th[aria-sort] button::after{content:' \\2195';color:var(--text2)}
th[aria-sort=ascending] button::after{content:' \\2191'}th[aria-sort=descending] button::after{content:' \\2193'}
tr.never td{background:var(--never-bg)}tr.rare td{background:var(--rare-bg)}.badge{font-size:.8rem;font-weight:650;padding:1px 6px;border-radius:4px;white-space:nowrap}.badge.never{color:var(--never-fg);border:1px solid currentColor}.badge.rare{color:var(--rare-fg);border:1px solid currentColor}.badge.used{color:var(--used-fg)}
figure{margin:12px 0 20px}figcaption{font-weight:600;margin-bottom:4px}svg{width:100%;max-width:900px;height:auto;display:block}svg .lbl{font-size:13px;fill:var(--text)}svg .val{font-size:12px;fill:var(--text2)}svg .bar{fill:var(--bar)}
.src{list-style:none;padding:0}.src li{margin:2px 0}.st{display:inline-block;min-width:70px;font-weight:650}.st.found{color:var(--used-fg)}.st.missing{color:var(--text2)}.st.error{color:var(--never-fg)}.empty{color:var(--text2);font-style:italic}
footer{margin-top:48px;padding-top:12px;border-top:1px solid var(--rule)}
@media (forced-colors: active){svg .bar{fill:CanvasText}tr.never td,tr.rare td{background:Canvas}}
</style></head><body><main>"
+ "<header><h1>Usage dashboard: \($d.project | e)</h1>"
+ "<p class=\"muted\">Generated \($d.generated | e). Range columns: <strong>\($d.range | e)</strong>; all-time columns cover the whole history. Transcript data covers whatever the runtime has retained.</p>"
+ "<h2 id=\"sources\">Data sources</h2><ul class=\"src\">"
+ ($d.sources | map("<li><span class=\"st \(.status | e)\">\(.status | e)</span> <strong>\(.name | e)</strong> - \(.detail | e)</li>") | join(""))
+ "</ul></header>"
+ "<nav aria-label=\"Sections\"><a href=\"#agents\">Agents</a><a href=\"#chains\">Chains</a><a href=\"#models\">Models</a><a href=\"#tokens\">Tokens &amp; cache</a><a href=\"#workunits\">Work Units</a><a href=\"#limits\">Limits</a></nav>"
+ "<div class=\"tiles\">"
+ ([["Employees on roster", $t.roster], ["Never used", $t.never], ["Rarely used", $t.rare], ["Dispatches", $t.dispatches],
    ["Commits (\($d.range))", $t.commits_range], ["Commits (all time)", $t.commits_all], ["API calls", $t.tokens.calls],
    ["Tokens (all types)", $t.tokens.total]] | map("<div class=\"tile\"><div class=\"k\">\(.[0] | e)</div><div class=\"v\">\(.[1] | n)</div></div>") | join(""))
+ "<div class=\"tile\"><div class=\"k\">Cache-read share of input</div><div class=\"v\">\($t.tokens.cache_read_share | pct)</div></div></div>"

# --- Agents
+ "<section><h2 id=\"agents\">Agents</h2><p>Every Employee on the roster. <strong>NEVER USED</strong> means no dispatch in the transcripts, no commit trailer and no registered Work Unit; <strong>rarely used</strong> means fewer than 3 dispatches and commits together. Dispatches are matched to an Employee by its agent name (the slug generate-agents.sh gives it).</p>"
+ barchart("Dispatches per Employee (transcripts)"; [$d.employees[] | select(.dispatches > 0) | {label: .name, value: .dispatches}])
+ barchart("Commits per Employee, all time (Employee trailer)"; [$d.employees | sort_by(-.commits_all)[] | select(.commits_all > 0) | {label: .name, value: .commits_all}])
+ table("Employees: dispatches, commits and Work Units"; [["Employee", "text"], ["Status", "text"], ["Roster", "text"], ["Dispatches", "num"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"], ["Work Units registered", "num"]];
    [$d.employees[] | {cls: (if .status == "used" then null else .status end), cells: [.name, (.status | badge), .roster, .dispatches, .commits_range, .commits_all, .work_units]}])
+ table("Dispatched agent types that are not Employees"; [["Agent type", "text"], ["Dispatches", "num"]];
    [$d.other_agents[] | {cells: [.type, .dispatches]}])
+ table("Dispatches by agent type and requested model"; [["Agent type", "text"], ["Requested model", "text"], ["Dispatches", "num"]];
    [$d.dispatch_models[] | {cells: [.type, .model, .n]}])
+ (if ($d.unrostered | length) > 0 then table("Employee trailer names not on the roster"; [["Name in trailer", "text"], ["Commits", "num"]]; [$d.unrostered[] | {cells: [.name, .commits]}]) else "" end)
+ "</section>"

# --- Chains
+ "<section><h2 id=\"chains\">Chains coverage</h2><p>Each Agent Chain's steps in order, with the usage of the Employee at each step. A step is <strong>exercised</strong> when its Employee has at least one dispatch or commit; usage is per Employee, so it shows that the Employee works, not that it worked inside this chain. <em>Engineer</em> is the chain placeholder: its numbers are the sum over \($d.engineer_set | map(e) | join(", ")).</p>"
+ ($d.chains | map(. as $ch | "<h3>\($ch.name | e) - \($ch.exercised) of \($ch.employee_steps) Employee steps exercised</h3>"
    + table("\($ch.name) steps"; [["#", "num"], ["Step", "text"], ["When", "text"], ["Exercised", "text"], ["Dispatches", "num"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"]];
        [$ch.steps[] | if .kind == "gate" then {cls: null, cells: [.n, {h: "<em>\(.name | e) gate</em>", v: .name}, (if .conditional then "conditional" else "always" end), "gate", "", "", ""]}
          else {cls: (if .exercised then null else "never" end),
                cells: [.n, (.name + (if .placeholder then " (placeholder)" else "" end) + (if .on_roster == false then " (not on roster)" else "" end)),
                        (if .conditional then "conditional" else "always" end),
                        (if .exercised then {h: "yes", v: "1"} else {h: "<span class=\"badge never\">NEVER</span>", v: "0"} end),
                        .dispatches, .commits_range, .commits_all]} end]))
   | join(""))
+ (if ($d.chains | length) == 0 then "<p class=\"empty\">No chain registry found.</p>" else "" end)
+ "</section>"

# --- Models
+ "<section><h2 id=\"models\">Models mix</h2>"
+ barchart("Commits per model, all time (Co-Authored-By trailer)"; [$d.commit_models[] | {label: .model, value: .commits_all}])
+ table("Commits per model"; [["Model (Co-Authored-By)", "text"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"]];
    [$d.commit_models[] | {cells: [.model, .commits_range, .commits_all]}])
+ barchart("API calls per model (transcripts)"; [$d.calls_by_model[] | {label: .model, value: .calls}])
+ table("API calls and tokens per model"; [["Model (API id)", "text"], ["Calls", "num"], ["Input", "num"], ["Output", "num"], ["Cache write", "num"], ["Cache read", "num"], ["Cache-read share", "num"], ["Cost (USD)", "num"]];
    [$d.calls_by_model[] | {cells: [.model, .calls, .input, .output, .cw, .cr, {h: (.cache_read_share | pct), v: (.cache_read_share | tostring)}, (if .cost == null then null else {h: (.cost | usd), v: (.cost | tostring)} end)]}])
+ "</section>"

# --- Tokens
+ "<section><h2 id=\"tokens\">Tokens &amp; cache by day</h2><p>Days are UTC. Cache-read share = cache read / (input + cache write + cache read): the part of the input side served from the prompt cache.</p>"
+ barchart("Tokens per day, all types (latest 31 days)"; [$d.tokens_by_day[0:31][] | {label: .day, value: .total}])
+ table("Tokens per day"; [["Day (UTC)", "text"], ["Calls", "num"], ["Input", "num"], ["Output", "num"], ["Cache write", "num"], ["Cache read", "num"], ["Cache-read share", "num"]];
    [$d.tokens_by_day[] | {cells: [.day, .calls, .input, .output, .cw, .cr, {h: (.cache_read_share | pct), v: (.cache_read_share | tostring)}]}])
+ table("Tokens per agent (main session or subagent type)"; [["Agent", "text"], ["Calls", "num"], ["Output", "num"], ["All tokens", "num"], ["Cache-read share", "num"]];
    [$d.tokens_by_agent[] | {cells: [.agent, .calls, .output, .total, {h: (.cache_read_share | pct), v: (.cache_read_share | tostring)}]}])
+ "</section>"

# --- Work Units
+ "<section><h2 id=\"workunits\">Work Units</h2>"
+ barchart("Top Work Units by commits, all time"; [$d.work_units[0:15][] | {label: .id, value: .commits}])
+ table("Top 30 Work Units by commits"; [["Work Unit", "text"], ["Employee", "text"], ["Commits (\($d.range))", "num"], ["Commits (all time)", "num"], ["Lines changed", "num"]];
    [$d.work_units[] | {cells: [.id, .employee, .commits_range, .commits, .lines]}])
+ "</section>"

# --- Limits
+ "<footer><h2 id=\"limits\">What this cannot tell you</h2><ul>"
+ "<li><strong>Cost.</strong> " + (if $d.have_prices then "Cost is computed only for the models listed in the --prices file you supplied, at the prices it states; other models show n/a." else "No cost is shown: no prices are configured (pass --prices FILE). Token counts are not money." end) + "</li>"
+ "<li><strong>Time saved.</strong> There is no baseline of how long the work would have taken otherwise, so nothing here measures productivity or time saved.</li>"
+ "<li><strong>Quality.</strong> A dispatch or a commit is activity, not value. A rarely used Employee may be exactly as rare as its work; a frequently used one may be over-dispatched.</li>"
+ "<li><strong>Chain fidelity.</strong> Usage is per Employee, not per chain run: the page cannot show that a chain ran end to end, only which of its Employees work at all.</li>"
+ "<li><strong>Coverage of transcripts.</strong> Only the runtime transcripts still on this machine are counted; the runtime prunes old sessions, and other machines and other runtimes are not seen. Commit counts come from git and are complete for the history present.</li>"
+ "<li><strong>Content.</strong> By design the page holds no prompt, reply, message body or file content - aggregates only (Standards/DATA_PROTECTION_STANDARD.md).</li>"
+ "</ul><p class=\"muted\">Roster and chain changes remain Director decisions; this page informs them.</p></footer></main>"
+ "<script type=\"application/json\" id=\"usage-data\">" + ($d | tojson | gsub("<"; "\\u003c")) + "</script>"
+ "<script>(function(){document.querySelectorAll('table.sortable').forEach(function(t){var hs=t.querySelectorAll('th');hs.forEach(function(th,i){th.setAttribute('aria-sort','none');th.querySelector('button').addEventListener('click',function(){var asc=th.getAttribute('aria-sort')!=='ascending';hs.forEach(function(h){h.setAttribute('aria-sort','none')});th.setAttribute('aria-sort',asc?'ascending':'descending');var num=th.dataset.type==='num';var b=t.tBodies[0];var rs=Array.prototype.slice.call(b.rows);rs.sort(function(x,y){var a=x.cells[i],c=y.cells[i];if(!a||!c)return 0;var va=a.dataset.v!==undefined?a.dataset.v:a.textContent,vb=c.dataset.v!==undefined?c.dataset.v:c.textContent;var r=num?((parseFloat(va)||0)-(parseFloat(vb)||0)):va.localeCompare(vb);return asc?r:-r});rs.forEach(function(r){b.appendChild(r)})})})})})();</script>"
+ "</body></html>"
JQ
)"

OUT_DIR="$(dirname -- "$OUT")"
if ! mkdir -p "$OUT_DIR"; then
  err "cannot create $OUT_DIR."
  exit 1
fi
if ! jq -r "$JQ_RENDER" < "$DATA" > "$TMPD/page.html"; then
  err "rendering the page failed (jq). No page was written."
  exit 1
fi
if ! mv -f "$TMPD/page.html" "$OUT"; then
  err "cannot write $OUT."
  exit 1
fi

echo "Usage dashboard written: $OUT"
jq -r '"  Employees: \(.totals.roster) on roster, \(.totals.never) never used, \(.totals.rare) rarely used",
       "  Dispatches: \(.totals.dispatches); commits: \(.totals.commits_range) (\(.range)), \(.totals.commits_all) all time",
       "  API calls: \(.totals.tokens.calls); tokens: \(.totals.tokens.total); cache-read share: \(.totals.tokens.cache_read_share * 1000 | round / 10)%",
       (.sources[] | "  source \(.status): \(.name)")' < "$DATA"

if [ -n "$OPEN" ]; then
  if [ -n "${IAENG_USAGE_OPENER:-}" ]; then
    "$IAENG_USAGE_OPENER" "$OUT"
  else
    case "$(uname -s 2>/dev/null)" in
      MINGW*|MSYS*|CYGWIN*) cmd.exe //c start "" "$(cygpath -w "$OUT")" ;;
      Darwin) open "$OUT" ;;
      *) xdg-open "$OUT" >/dev/null 2>&1 ;;
    esac
  fi || note "could not open a browser; open $OUT yourself."
fi

exit 0
