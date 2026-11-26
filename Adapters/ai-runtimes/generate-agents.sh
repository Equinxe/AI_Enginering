#!/usr/bin/env bash
# IA Engineering — generate-agents.sh
#
# Generates runtime agent definitions from the Employee definitions, so that
# dispatching to a named Employee is a real mechanism rather than a rule the
# Main Agent has to be reminded of.
#
# THE PROBLEM THIS SOLVES
#
# Core/MAIN_AGENT_CONDUCT.md's Dispatch Discipline says every delegation must
# be framed as a named Employee carrying that Employee's Mission, Authority,
# Standards Applied, and Definition of Done — and that using a runtime's
# generic subagent instead is "the same violation as not delegating at all".
# Three separate conduct sections exist to hold that line: Dispatch Discipline
# itself, No Direct Implementation, and Git Execution via Named Employee. Each
# was written after the rule was broken in practice.
#
# The reason it kept being broken is structural. Under a runtime whose
# available agents are named "executor", "reviewer", and "coder", dispatching
# to a Backend Engineer requires the Main Agent to construct that Employee from
# prose every time, while a conveniently-named generic agent sits one keystroke
# away. The framework's answer was a stronger prohibition. The mechanical
# answer is to make the Employee exist as an agent the runtime can actually
# dispatch to.
#
# WHY THIS DOES NOT VIOLATE AI-AGNOSTICISM
#
# Core/AI_MANIFEST.md Principle X and Core/CAPABILITY_TIERS.md are strict that
# no framework document names a model. This script is not a framework document
# — it is an Adapter, and Core/GLOSSARY.md already defines an Adapter as
# AI-agnostic in the sense that matters (it works for any Employee) while not
# tool-agnostic (a GitHub Adapter assumes GitHub). Naming Opus and Sonnet in a
# claude-code target is the same category of statement as naming
# `.github/workflows/` in the GitHub Adapter.
#
# CAPABILITY_TIERS.md says exactly this: a project's own CLAUDE.md "may map
# these tiers to concrete models for its chosen AI runtime ... That mapping is
# project context, not part of this framework document." The mapping lives here
# and in --map or the project's .ia-engineering/tier-map, never in Core/.
#
# Adding a runtime means adding a target below. The Employee definitions, the
# roster, and the tiers do not change.
#
# GENERATED OUTPUT IS A BUILD ARTIFACT
#
# Regenerate it; do not hand-edit it and do not treat it as a source. An edited
# agent file is a second definition of an Employee that will silently diverge
# from Employees/ — precisely the duplication Registry/employees.yml was
# created to end. Every generated file says so in its own header.
#
# A PROJECT'S OWN AGENTS ARE NEVER REPLACED (WU-IAENG-454, issue #516)
#
# An existing Claude Code project often keeps agents of its own in
# .claude/agents/, under names the Employees take: code-reviewer.md,
# backend-engineer.md. An agent's path is written only when it holds nothing,
# or a file with the generated header: the file's first HTML comment, opened
# before any heading, holding the "GENERATED FILE" and "Generator:" lines that
# every generated agent has carried since this script's first version.
# Anything else there, a file without that header, a file that cannot be read
# or an entry that is not a regular file, is the project's own and is never
# replaced: the generation names it, writes the other agents and exits 1 with
# the command that regenerates, and --check, full or quick, reports it.
#
# Usage:
#   ./Adapters/ai-runtimes/generate-agents.sh [options]
#
#   --target <name>   runtime target (default: claude-code). Only claude-code
#                     exists today; --target list prints what is available.
#   --out <dir>       output directory (default: the target's convention,
#                     resolved against the PROJECT, not the framework)
#   --project <dir>   project root (default: the directory this was run from).
#                     Decides where agents are written and where the project
#                     roster is looked for. A relative value is read from the
#                     directory this was run from, never from the framework.
#   --roster <file>   an ADDITIONAL roster of Domain Employees, on top of the
#                     framework's. Default: <project>/.ia-engineering/Registry/
#                     employees.yml when it exists. A value naming a missing
#                     file is refused, never skipped. A relative value is read
#                     from the directory this was run from, as --project is.
#   --map <spec>      tier-to-capability mapping, as
#                     "strategic=X,standard=Y,lightweight=Z,frontier=W".
#                     Overrides the target's default. Frontier is never an
#                     Employee's default tier and this key is never written
#                     into any generated agent's `model:` field — it is
#                     recorded only in the printed tiers: summary below, for
#                     the Main Agent to pass as a per-dispatch Tier Override
#                     (Core/CAPABILITY_TIERS.md, Frontier Override).
#   --effort-map <spec>  tier-to-effort mapping, mirroring --map, as
#                     "strategic=high,standard=,lightweight=,frontier=high".
#                     Overrides the target's default. An empty value means
#                     "inherit the runtime's default effort" — no `effort:`
#                     frontmatter field is emitted for that tier. Values are
#                     validated against the runtime's accepted effort levels.
#   --dry-run         report what would be written, write nothing
#   --check           exit non-zero if any generated file would differ from
#                     what is on disk, or is missing. Resolves the mapping the
#                     same way as a generation, and says so when a file
#                     differs in its mapping only rather than in its Employee
#                     definition, or is the project's own (no generated
#                     header), which a generation never replaces. Ends with
#                     the command that regenerates, as it runs from the
#                     directory --check was run from.
#   --quick           with --check only: what can be told without generating
#                     anything. Each roster Employee's agent exists, carries
#                     the generated header, and names
#                     as its framework root this framework (-ef: the same
#                     directory, never a spelling), or, in the framework
#                     repository itself, names none. In an adopting project
#                     its header also records the framework commit in use
#                     (#471). A moved project, an agent from another clone,
#                     one written before agents named a root or recorded a
#                     commit, and one generated before an upgrade are stale.
#                     Any other content difference (another mapping, an edit)
#                     needs --check without it. A root that is a network path
#                     is never opened.
#   --format text|tsv with --check only (default text). tsv is for a caller:
#                     one record per roster Employee,
#                       agent TAB <status> TAB <path> TAB <detail>
#                     status current (full) or present (--quick), missing or
#                     stale; then "# generate-agents.sh --check: ..." and,
#                     when there is something to act on, "# regenerate: <cmd>".
#                     Every control character in a field is a space.
#   --print-tier-map  resolve the tier mapping exactly as a generation would
#                     (flags > the project's file > the target's defaults),
#                     print it, and stop: nothing is generated, written or
#                     checked. Three lines, themselves a valid tier-map file:
#                       # mapping: <flags|file|defaults ...>
#                       map=strategic=X,standard=Y,lightweight=Z,frontier=W
#                       effort-map=strategic=E,standard=,lightweight=,frontier=
#                     Refused together with --dry-run or a full --check, which
#                     it would otherwise silently not perform. It is how a
#                     session reads the mapping a Tier Override must use
#                     (claude-code/hooks/session-start.sh) instead of
#                     inferring one. With --check --quick it prints those
#                     three lines, then runs the quick check: session start
#                     asks both of one process.
#   --help
#
# A PROJECT'S OWN MAPPING: <project>/.ia-engineering/tier-map, optional, holds
# the --map and --effort-map values a project has decided on, so the plain
# command honours them on every regeneration:
#
#   map=strategic=X,standard=Y,lightweight=Z,frontier=W
#   effort-map=strategic=high,standard=,lightweight=,frontier=
#
# Precedence, per tier: flags > that file > the target's defaults. The summary
# prints which one applied ("mapping: flags|file|defaults ...").
#
# WHERE THE AGENTS ARE WRITTEN, and why it is not the framework directory:
#
# An AI runtime reads its agents from the PROJECT it is opened on. Until
# WU-IAENG-189 this script cd'd into the framework and resolved the default
# output there, so a project that imported the framework as a submodule and ran
# the documented command got 42 agent files inside ia-engineering/.claude/agents
# — a path its runtime never reads, in a directory the framework's own
# .gitignore excludes. The generator reported "42 written" and the adopter had
# no dispatchable Employees. Reproduced end to end before this change.
#
# Output is therefore resolved against --project, which defaults to the
# directory the script was RUN from. Running it inside the framework repository
# is unchanged: the project and the framework are the same directory.

set -uo pipefail

# Byte ordering everywhere, for the same reason validate-framework.sh pins it:
# this script emits files whose content and order must be identical on every
# platform, or --check reports drift that is really just a different locale's
# collation. See that script's comment for the concrete case (ML_ENGINEER.md
# versus MLOPS_ENGINEER.md ordering differently under Git Bash and Linux).
export LC_ALL=C

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# The framework's physical path (pwd -P), links resolved: the root a
# generation writes into every agent of an adopting project, and the one the
# quick check compares an agent's root with, by spelling too
# (SEC-IAENG-467-01). A logical path would depend on how the script was
# reached: a project behind a symbolic link (macOS /tmp is /private/tmp, a
# linked workspace) would be generated from the user's shell under one
# spelling and checked by session start under the other, and called stale at
# every session (Code Reviewer, PR #467). Git Bash resolves a junction the
# same way.
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# Captured BEFORE the cd into the framework: this is the project the caller
# meant, and the only directory whose .claude/agents a runtime will read.
INVOCATION_DIR="$(pwd)"

cd "$ROOT" || exit 2

ROSTER="Registry/employees.yml"
PROJECT=""
PROJECT_ROSTER=""

TARGET="claude-code"
OUT=""
MAP_OVERRIDE=""
EFFORT_MAP_OVERRIDE=""
DRY_RUN=0
CHECK=0
QUICK=0
FORMAT=text
PRINT_TIER_MAP=0

# Each value-taking flag asserts it HAS a value before shifting past it.
#
# Without the guard, `shift 2` on a trailing flag hung the script forever. When
# the flag is the last argument, $# is 1, so `shift 2` is out of range and
# fails — and a failed shift does not shift. The script sets `-uo pipefail` but
# not `-e`, so the failure was discarded, $1 stayed `--target`, and the loop
# spun with no output and no exit. `${2:-}` made it worse by masking the
# `set -u` error that would otherwise have surfaced it immediately.
#
# It is the only defect in this milestone that hangs rather than misreports,
# which makes it the only one invisible in a log. A trailing flag is the normal
# shape of a typo or a truncated shell-history recall, and
# Adapters/ai-runtimes/README.md documents `--check` for CI use — a job passing
# `--target "$SOMETHING_EMPTY"` would have burned its whole timeout budget with
# no diagnostic. Reproduced and confirmed before this change: all three flags
# hung until killed.
#
# `$2` is used unquoted-of-default deliberately: after the guard it is known to
# exist, so dropping `${2:-}` lets `set -u` catch any future variant that
# forgets the guard.
need_value() {
  if [ "$2" -lt 2 ]; then
    echo "Argument error: $1 requires a value." >&2
    echo "  Try --help. ($1 was the last argument, so there was nothing to read.)" >&2
    exit 2
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)  need_value --target "$#";  TARGET="$2"; shift 2 ;;
    --out)     need_value --out "$#";     OUT="$2"; shift 2 ;;
    --project) need_value --project "$#"; PROJECT="$2"; shift 2 ;;
    --roster)  need_value --roster "$#";  PROJECT_ROSTER="$2"; shift 2 ;;
    --map)     need_value --map "$#";     MAP_OVERRIDE="$2"; shift 2 ;;
    --effort-map) need_value --effort-map "$#"; EFFORT_MAP_OVERRIDE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --check)   CHECK=1; shift ;;
    --quick)   QUICK=1; shift ;;
    --format)  need_value --format "$#"; FORMAT="$2"; shift 2 ;;
    --print-tier-map) PRINT_TIER_MAP=1; shift ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}'; exit 0 ;;
    *) echo "Unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
done

case "$FORMAT" in
  text|tsv) ;;
  *) echo "Argument error: --format takes text or tsv." >&2; exit 2 ;;
esac
if [ "$CHECK" -eq 0 ] && { [ "$QUICK" -eq 1 ] || [ "$FORMAT" != text ]; }; then
  echo "Argument error: --quick and --format qualify --check, which was not given." >&2
  exit 2
fi
# --print-tier-map with --check --quick is allowed: neither generates, and
# session-start.sh asks both of one process instead of starting two.
if [ "$PRINT_TIER_MAP" -eq 1 ] && { [ "$DRY_RUN" -eq 1 ] || { [ "$CHECK" -eq 1 ] && [ "$QUICK" -eq 0 ]; }; }; then
  echo "Argument error: --print-tier-map only prints the resolved mapping; it does not" >&2
  echo "  generate, so it cannot be combined with --check or --dry-run. Run them separately." >&2
  echo "  (--check --quick generates nothing either, and can be combined with it.)" >&2
  exit 2
fi

# --- Targets ---------------------------------------------------------------
# One case block per runtime. A new runtime adds a branch here and nothing
# else: it reads the same Employee definitions through the same extraction.

case "$TARGET" in
  list)
    echo "Available targets:"
    echo "  claude-code   .claude/agents/<slug>.md, YAML frontmatter, model per tier"
    exit 0
    ;;
  claude-code)
    DEFAULT_OUT=".claude/agents"
    # Core/CAPABILITY_TIERS.md's two default execution tiers, plus the two
    # override-only tiers, mapped to this runtime's models.
    # Strategic Judgment is ambiguous tradeoffs and hard-to-reverse decisions;
    # Standard Execution is work against an existing contract or pattern;
    # Lightweight is mechanical and reached only through a per-Work-Unit
    # Tier Override, never as an Employee default. Frontier is reached only
    # by upgrading a Work Unit already at Strategic Judgment, with Director
    # approval recorded each time (Core/CAPABILITY_TIERS.md, Frontier
    # Override) — no Employee ever defaults to it, so it is never written as
    # any generated agent's `model:`. It exists here only so the printed
    # tiers: summary below gives the Main Agent a value to pass as a
    # per-dispatch Tier Override.
    MAP_STRATEGIC="opus"
    MAP_STANDARD="sonnet"
    MAP_LIGHTWEIGHT="haiku"
    MAP_FRONTIER="fable"
    # Per-tier effort, alongside the per-tier model above. Director decision,
    # 25 Sep 2026: Strategic Judgment runs at high effort; the other tiers
    # inherit the runtime's default effort — an empty value here means no
    # `effort:` frontmatter field is emitted, so the runtime's own default
    # applies. This is deliberately an Adapter concern, not a Core one:
    # Core/CAPABILITY_TIERS.md names no model and, by the same Principle X
    # (Core/AI_MANIFEST.md), no effort level either.
    EFFORT_STRATEGIC="high"
    EFFORT_STANDARD=""
    EFFORT_LIGHTWEIGHT=""
    EFFORT_FRONTIER=""
    # The two lines of this target's generated header (WU-IAENG-454): written
    # into every agent, and the lines a file at an agent's path must carry to
    # be replaced. Both are the words of this script's first version, so an
    # agent any earlier version generated is still recognised as one.
    GEN_HEADER_MARK="  GENERATED FILE — do not edit."
    GEN_HEADER_GENERATOR="  Generator: Adapters/ai-runtimes/generate-agents.sh --target claude-code"
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    echo "Run with '--target list' to see what is available." >&2
    echo "Adding a runtime means adding a case branch in this script; the" >&2
    echo "Employee definitions and Core/CAPABILITY_TIERS.md do not change." >&2
    exit 2
    ;;
esac

# --- Project -----------------------------------------------------------------
# Resolved before the mapping, because the project can record its own mapping
# (.ia-engineering/tier-map, below) and the file is looked for under it.

# A relative --project or --roster names a path from the directory the script
# was run from, as every command-line path does (issue #418). They were read
# from the framework, because of the cd above: `--project .`, run from an
# adopter's root, wrote all its agents into the framework's own gitignored
# .claude/agents/ and exited 0, and session-start.sh, which passes --project .
# when CLAUDE_PROJECT_DIR is unset, showed the framework's tier map as the
# project's. Set in place, not through $(...): session start runs this, and on
# Windows every fork is part of its latency.
case "$PROJECT" in
  ""|/*|[A-Za-z]:[\\/]*) ;;
  *) PROJECT="$INVOCATION_DIR/$PROJECT" ;;
esac
case "$PROJECT_ROSTER" in
  ""|/*|[A-Za-z]:[\\/]*) ;;
  *) PROJECT_ROSTER="$INVOCATION_DIR/$PROJECT_ROSTER" ;;
esac

PROJECT="${PROJECT:-$INVOCATION_DIR}"
if [ ! -d "$PROJECT" ]; then
  echo "generate-agents.sh: --project '$PROJECT' is not a directory." >&2
  exit 2
fi
PROJECT="$(CDPATH='' cd -- "$PROJECT" && pwd)"

# --- Tier mapping: target defaults < project file < flags --------------------
#
# Core/CAPABILITY_TIERS.md: the tier-to-model mapping is PROJECT context. Until
# WU-IAENG-327 the only place a project could state it was the --map flag, so
# it lived in whoever remembered to type it: the documented command, run
# without the flag, silently reverted every Employee to the target defaults,
# and --check run the same way reported every agent stale and blamed
# Employees/ for a drift that was really a different mapping.
#
# <project>/.ia-engineering/tier-map records the choice where a clone inherits
# it. Two keys, same syntax as the flags, one per line:
#
#   map=strategic=X,standard=Y,lightweight=Z,frontier=W
#   effort-map=strategic=high,standard=,lightweight=,frontier=
#
# Blank lines and lines starting with # are ignored. Anything else — an
# unknown key, a line with no "=", a key given twice — is refused with exit 2,
# never skipped: a mapping file that is half-read is a mapping nobody chose.
#
# Precedence is per tier, layered: the target's defaults, then the file, then
# --map / --effort-map. A flag naming one tier overrides that tier only, the
# same way it always overrode the defaults one tier at a time.

TIER_MAP_FILE="$PROJECT/.ia-engineering/tier-map"
FILE_MAP=""
FILE_EFFORT_MAP=""
FILE_MAP_LINE=""
FILE_EFFORT_MAP_LINE=""
HAVE_TIER_MAP_FILE=0

if [ -f "$TIER_MAP_FILE" ]; then
  HAVE_TIER_MAP_FILE=1
  seen_map=0
  seen_effort=0
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    # A UTF-8 byte order mark on line 1 (Windows PowerShell 5.1's Out-File and
    # Set-Content -Encoding utf8 both write one) would otherwise turn a valid
    # first line into "<BOM>map=..." and fail as "not understood" while the
    # message shows nothing visibly wrong. Byte-wise under LC_ALL=C.
    [ "$lineno" -eq 1 ] && line="${line#$'\xef\xbb\xbf'}"
    # A CRLF checkout must not turn "high" into "high\r" and fail validation
    # with a message that shows nothing wrong.
    line="${line%$'\r'}"
    # Surrounding whitespace is insignificant; inner whitespace is not allowed
    # (the flag syntax has none), and is caught by validation below.
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in
      ""|"#"*) continue ;;
      map=*)
        if [ "$seen_map" -eq 1 ]; then
          echo "generate-agents.sh: $TIER_MAP_FILE line $lineno: 'map=' is given twice." >&2
          exit 2
        fi
        seen_map=1; FILE_MAP="${line#map=}"; FILE_MAP_LINE="$lineno" ;;
      effort-map=*)
        if [ "$seen_effort" -eq 1 ]; then
          echo "generate-agents.sh: $TIER_MAP_FILE line $lineno: 'effort-map=' is given twice." >&2
          exit 2
        fi
        seen_effort=1; FILE_EFFORT_MAP="${line#effort-map=}"; FILE_EFFORT_MAP_LINE="$lineno" ;;
      *)
        echo "generate-agents.sh: $TIER_MAP_FILE line $lineno is not understood: '$line'" >&2
        echo "  Accepted: 'map=<spec>' and 'effort-map=<spec>' (same syntax as --map and" >&2
        echo "  --effort-map), blank lines, and lines starting with #." >&2
        exit 2
        ;;
    esac
  done < "$TIER_MAP_FILE"
fi

# Accepted effort levels, verified against this runtime's own documentation
# (code.claude.com/docs/en/sub-agents.md, model-config.md) at the time of
# writing. An empty value is always accepted regardless of this list — it
# means "no effort: field", i.e. inherit the runtime's default.
is_valid_effort() {
  case "$1" in
    ""|low|medium|high|xhigh|max) return 0 ;;
    *) return 1 ;;
  esac
}

# apply_map <spec> <label> — label names the source in an error message:
# "--map" for the flag, "map= (<file> line N)" for the project file, so an
# error inside a value points at the line the same way a malformed line does.
apply_map() {
  local spec="$1" label="$2" pair
  for pair in ${spec//,/ }; do
    case "$pair" in
      strategic=*)   MAP_STRATEGIC="${pair#strategic=}" ;;
      standard=*)    MAP_STANDARD="${pair#standard=}" ;;
      lightweight=*) MAP_LIGHTWEIGHT="${pair#lightweight=}" ;;
      frontier=*)    MAP_FRONTIER="${pair#frontier=}" ;;
      *) echo "Unrecognised $label entry: $pair" >&2; exit 2 ;;
    esac
  done
}

apply_effort_map() {
  local spec="$1" label="$2" pair key value
  for pair in ${spec//,/ }; do
    # Pattern-matched like apply_map above, not split-then-validated: a
    # pattern requires the literal "key=", so a bare "strategic" (no "=")
    # falls straight to the catch-all "Unrecognised" error instead of being
    # read as key="strategic" value="strategic" and rejected two lines later
    # with the less clear "Invalid ... value" message.
    case "$pair" in
      strategic=*)   key=strategic;   value="${pair#strategic=}" ;;
      standard=*)    key=standard;    value="${pair#standard=}" ;;
      lightweight=*) key=lightweight; value="${pair#lightweight=}" ;;
      frontier=*)    key=frontier;    value="${pair#frontier=}" ;;
      *) echo "Unrecognised $label entry: $pair" >&2; exit 2 ;;
    esac
    if ! is_valid_effort "$value"; then
      echo "Invalid $label value in '$pair': '$value'" >&2
      echo "  Accepted: low, medium, high, xhigh, max, or empty (inherit)." >&2
      exit 2
    fi
    case "$key" in
      strategic)   EFFORT_STRATEGIC="$value" ;;
      standard)    EFFORT_STANDARD="$value" ;;
      lightweight) EFFORT_LIGHTWEIGHT="$value" ;;
      frontier)    EFFORT_FRONTIER="$value" ;;
    esac
  done
}

# File first, flags second: the order IS the precedence.
[ -n "$FILE_MAP" ]            && apply_map        "$FILE_MAP"            "map= ($TIER_MAP_FILE line $FILE_MAP_LINE)"
[ -n "$FILE_EFFORT_MAP" ]     && apply_effort_map "$FILE_EFFORT_MAP"     "effort-map= ($TIER_MAP_FILE line $FILE_EFFORT_MAP_LINE)"
[ -n "$MAP_OVERRIDE" ]        && apply_map        "$MAP_OVERRIDE"        "--map"
[ -n "$EFFORT_MAP_OVERRIDE" ] && apply_effort_map "$EFFORT_MAP_OVERRIDE" "--effort-map"

# One word first, so a log or a test can read the source without parsing the
# detail after it.
if [ -n "$MAP_OVERRIDE$EFFORT_MAP_OVERRIDE" ]; then
  if [ "$HAVE_TIER_MAP_FILE" -eq 1 ]; then
    MAPPING_SOURCE="flags (over $TIER_MAP_FILE, per tier)"
  else
    MAPPING_SOURCE="flags (over the $TARGET defaults, per tier)"
  fi
elif [ "$HAVE_TIER_MAP_FILE" -eq 1 ]; then
  MAPPING_SOURCE="file ($TIER_MAP_FILE)"
else
  MAPPING_SOURCE="defaults (target $TARGET; no .ia-engineering/tier-map in the project)"
fi

# --print-tier-map: the resolved mapping, and nothing else (WU-IAENG-336).
#
# Before this, the Lightweight and Frontier values existed only in the tiers:
# summary of a generation run, which no session reads. A Main Agent applying
# a Tier Override therefore had no concrete model to pass and invented one: in
# an adopting project whose tier-map gave every tier claude-opus-5-5, it
# dispatched a Lightweight override with "sonnet" (issue #212). The session
# now asks this script for the mapping instead of a second parser re-reading
# the file, so the defaults, the file and the precedence stay in one place.
#
# The output is a valid tier-map file (the source line is a comment), which is
# what lets a test feed it back in and get the same mapping out.
if [ "$PRINT_TIER_MAP" -eq 1 ]; then
  echo "# mapping: $MAPPING_SOURCE"
  echo "map=strategic=$MAP_STRATEGIC,standard=$MAP_STANDARD,lightweight=$MAP_LIGHTWEIGHT,frontier=$MAP_FRONTIER"
  echo "effort-map=strategic=$EFFORT_STRATEGIC,standard=$EFFORT_STANDARD,lightweight=$EFFORT_LIGHTWEIGHT,frontier=$EFFORT_FRONTIER"
  # Alone, it stops here. With --check --quick (session start), the quick
  # check follows; nothing below the quick check runs in this mode.
  [ "$CHECK" -eq 1 ] || exit 0
fi

# --- Output and rosters ------------------------------------------------------
#
# Resolved before the framework root is (below): the quick check reads them
# and must not depend on it, for the reason --print-tier-map must not.

# Relative --out is the adopter's project path, not a path inside the
# framework. Absolute --out is taken as given. OUT_GIVEN keeps whether it was
# given, for the command that regenerates.
OUT_GIVEN="$OUT"
OUT="${OUT:-$DEFAULT_OUT}"
case "$OUT" in
  /*|[A-Za-z]:[\\/]*) ;;
  *) OUT="$PROJECT/$OUT" ;;
esac

if [ ! -f "$ROSTER" ]; then
  echo "generate-agents.sh: $ROSTER not found." >&2
  echo "  The roster is the list of Employees to generate. See Registry/README.md." >&2
  exit 1
fi

# Project roster — Domain Employees (Templates/DOMAIN_EMPLOYEE.md). Same
# resolution rule as the commit-msg hook and the Employee Trailer CI job: an
# explicitly named roster that does not exist is a broken configuration and is
# refused, because generating only the framework's Employees would silently
# leave the project's own undispatchable. Absence of the DEFAULT path is the
# ordinary case and is reported, not treated as an error.
ROSTER_GIVEN="$PROJECT_ROSTER"
DEFAULT_PROJECT_ROSTER="$PROJECT/.ia-engineering/Registry/employees.yml"
if [ -n "$PROJECT_ROSTER" ]; then
  if [ ! -f "$PROJECT_ROSTER" ]; then
    echo "generate-agents.sh: --roster '$PROJECT_ROSTER' does not exist." >&2
    echo "  Generating the framework roster alone would leave this project's Domain" >&2
    echo "  Employees undispatchable while reporting success. Fix the path or drop the flag." >&2
    exit 2
  fi
  PROJECT_ROSTER="$(CDPATH='' cd -- "$(dirname -- "$PROJECT_ROSTER")" && pwd)/$(basename "$PROJECT_ROSTER")"
elif [ -f "$DEFAULT_PROJECT_ROSTER" ]; then
  # No "only when the project is not the framework" guard. Registry/README.md
  # states that all three consumers — the commit-msg hook, the Employee
  # Trailer job, and this script — resolve the project roster the same way,
  # and the other two do it unconditionally. The guard made that statement
  # false for one of them, in the one repository where the difference is
  # invisible because the file does not exist. A rule with a silent exception
  # is a rule nobody can rely on.
  PROJECT_ROSTER="$DEFAULT_PROJECT_ROSTER"
fi

# One awk pass per roster, same shape validate-framework.sh uses. The base
# directory travels with each row because a roster's `file:` paths are relative
# to ITS OWN root: the framework's to the framework, a project's to the project.
#
# The agent's file name (the slug) is computed here too, once per roster, for
# the generation and the quick check alike, so the two can never look for two
# different files. It was `printf | tr | sed` per Employee: three processes
# each, 126 for the roster, which on Windows is seconds. The rule is the same,
# byte for byte under LC_ALL=C: lower-case A-Z, a slash read as a space, every
# run of characters other than a-z and 0-9 one hyphen, no hyphen at either end
# ("UX/UI Designer" is ux-ui-designer). The function is held once, here, and
# given to both awk programs that need it: this one and the quick check's.
AWK_SLUG='
    function slug(n,   s) {
      s = tolower(n)
      gsub(/\//, " ", s)
      gsub(/[^a-z0-9]+/, "-", s)
      sub(/^-/, "", s)
      sub(/-$/, "", s)
      return s
    }'
read_roster() {
  awk -v base="$2" -v label="$3" "$AWK_SLUG"'
    function emit() { if (name != "") print name "\t" file "\t" category "\t" tier "\t" base "\t" label "\t" slug(name) }
    /^  - name: / {
      emit()
      name = $0; sub(/^  - name: /, "", name); gsub(/\015/, "", name)
      file = ""; category = ""; tier = ""
      next
    }
    /^    file: /     { file = $0;     sub(/^    file: /, "", file);         gsub(/\015/, "", file) }
    /^    category: / { category = $0; sub(/^    category: /, "", category); gsub(/\015/, "", category) }
    /^    tier: /     { tier = $0;     sub(/^    tier: /, "", tier);         gsub(/\015/, "", tier) }
    END { emit() }
  ' "$1"
}

# --- A project's own agent: never replaced (WU-IAENG-454, #516) ---------------
#
# The generated header is the file's first HTML comment, opened by a line
# "<!--" before any "# " heading and closed by "-->", holding GEN_HEADER_MARK
# and GEN_HEADER_GENERATOR as lines of their own. header() reads one line, its
# line-ending carriage return already removed (Check Convention, Shell Scripts
# rule 3), and keeps the state in hs (0 before the comment, 1 inside, 2 past
# it), hm and hg (each line seen there): the file has the header when hm and
# hg are both set. Held once, here, and given to both awk programs that ask,
# own_entry's and the quick check's, so the two cannot disagree. Only the
# first comment counts: the lines quoted further down, in the project's own
# file, do not make it a generated one.
AWK_HEADER='
    function header(l) {
      if (hs == 0) {
        if (l == "<!--") hs = 1
        else if (l ~ /^# /) hs = 2
      } else if (hs == 1) {
        if (l == "-->") hs = 2
        else if (l == hmark) hm = 1
        else if (l == hgen) hg = 1
      }
    }'

# The reason each kind of path that is never replaced is reported with, by
# --check, the quick check, and the generation that leaves it.
OWN_WHY_FILE="not a generated agent: it has no generated header, so it is the project's own file, which a generation never replaces. Rename it, its file and the name: in its frontmatter, or move it elsewhere; its Employee's agent is written once that name is free"
OWN_WHY_ENTRY="not a generated agent: it is not a regular file, which a generation never replaces. Move it elsewhere; its Employee's agent is written once that name is free"
OWN_WHY_UNREAD="it cannot be read, so it is not known to be a generated agent, and a generation never replaces it. Make it readable, or move it elsewhere"

# own_entry <path> — true when something is at <path> that a generation must
# never replace, with OWN_WHY its reason: an entry that is not a regular file
# (a directory, a dangling link: mv would move the agent into the one and
# replace the other), a file that cannot be read, or a file without the
# generated header, the project's own. False, OWN_WHY empty, when nothing is
# there or the file is a generated agent. One awk process, which reads no
# further than the header; asked only for a path whose content differs from
# the agent's, since a current agent is the agent, header included. The path
# reaches awk through the environment: -v would read its backslashes as
# escapes (C:\Users\..., an --out this script accepts).
own_entry() {
  OWN_WHY=""
  if ! [ -e "$1" ] && ! [ -L "$1" ]; then
    return 1
  fi
  if ! [ -f "$1" ]; then
    OWN_WHY="$OWN_WHY_ENTRY"
    return 0
  fi
  HF="$1" awk -v hmark="$GEN_HEADER_MARK" -v hgen="$GEN_HEADER_GENERATOR" "$AWK_HEADER"'
    BEGIN {
      f = ENVIRON["HF"]; n = 0
      while ((rc = (getline l < f)) > 0) {
        n++
        sub(/\r$/, "", l)
        header(l)
        if (hs == 2) break
      }
      if (rc < 0 && n == 0) exit 2
      exit (hm && hg) ? 0 : 1
    }'
  case "$?" in
    0) return 1 ;;
    1) OWN_WHY="$OWN_WHY_FILE" ;;
    *) OWN_WHY="$OWN_WHY_UNREAD" ;;
  esac
  return 0
}

# Both rosters' rows, the framework's first.
roster_rows() {
  read_roster "$ROSTER" "$ROOT" "$ROSTER"
  if [ -n "$PROJECT_ROSTER" ]; then
    # Labelled by the path an adopter would type, so a generated Domain
    # Employee's header points at the roster that actually declared it.
    read_roster "$PROJECT_ROSTER" "$PROJECT" "${PROJECT_ROSTER#"$PROJECT"/}"
  fi
}

# --- What --check reports, and the command that regenerates ------------------
#
# Every field of a record goes through flat(), the record sanitiser of the TSV
# emitters, the same block byte for byte (Adapters/scripts/tests/run.sh
# compares it, WU-IAENG-434): a record is one line, and nothing read from an
# agent file, such as the root it names, reaches a terminal or a session's
# context as an escape sequence. It sets FLAT in place: no process.
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

# report <status> <dest> [<detail>] — one agent's result. In text, a missing
# file is "missing:", one that differs "differs:", a current one nothing (as
# --check always printed). In tsv, one record per agent, its path relative to
# the project when it is inside it.
report() {
  local st="$1" p="$2" d="${3:-}"
  flat "$d"; d="$FLAT"
  if [ "$FORMAT" = tsv ]; then
    case "$p" in "$PROJECT"/*) p="${p#"$PROJECT"/}" ;; esac
    flat "$p"; p="$FLAT"
    printf 'agent\t%s\t%s\t%s\n' "$st" "$p" "$d"
    return 0
  fi
  case "$st" in
    missing) echo "  missing: $p" ;;
    stale) echo "  differs: $p${d:+ ($d)}" ;;
  esac
  return 0
}

# sh_word <text> — SH_WORD is the text as one shell word: as it is when it
# holds only characters no shell reads specially, otherwise in single quotes,
# each ' written '\''. A path with a space or a non-ASCII letter (C:/Users/
# Jérôme/my app) is quoted, so the command runs as printed.
SQ="'"
SQ_ESCAPED="'\\''"
sh_word() {
  case "$1" in
    ''|*[!A-Za-z0-9_./:=,+@%-]*) SH_WORD="$SQ${1//"$SQ"/"$SQ_ESCAPED"}$SQ" ;;
    *) SH_WORD="$1" ;;
  esac
}

# below <dir> <ancestor> — true when <ancestor> is <dir> or one of its
# parents, by identity (-ef); BELOW is then <dir>'s path under it ("" for the
# same directory). Walked by parameter expansion, not dirname and basename:
# no process per level.
below() {
  local p="$1" rel="" parent
  BELOW=""
  while :; do
    if [ "$p" -ef "$2" ]; then BELOW="$rel"; return 0; fi
    parent="${p%/*}"
    [ "$parent" = "$p" ] && return 1
    [ -n "$parent" ] || parent=/
    [ "$parent" = "$p" ] && return 1
    rel="${p##*/}${rel:+/$rel}"
    p="$parent"
  done
}

# logical_root — true when this script was reached through a path to this
# framework other than its physical one, FW_LOGICAL being that path (#476).
# SCRIPT_DIR keeps the path the script was run by, links included (pwd
# without -P), and the framework is the directory that holds its
# Adapters/ai-runtimes. ROOT is physical (pwd -P), so a framework directory
# that is a symbolic link or a junction into the project is not under the
# project by ROOT: the walks up from ROOT, which name the framework's
# directory in the project, miss it, and the walks up from FW_LOGICAL find
# it. Taken only when it is this framework (-ef). Parameter expansion, not
# a process: the quick check of session start asks it for its command.
logical_root() {
  if [ -z "${FW_LOGICAL_DONE:-}" ]; then
    FW_LOGICAL_DONE=1
    FW_LOGICAL="${SCRIPT_DIR%/Adapters/ai-runtimes}"
    if [ "$FW_LOGICAL" = "$SCRIPT_DIR" ] || [ -z "$FW_LOGICAL" ] || ! [ "$FW_LOGICAL" -ef "$ROOT" ]; then
      FW_LOGICAL=""
    fi
  fi
  [ -n "$FW_LOGICAL" ]
}

# The command that regenerates exactly what was checked, run from the
# directory this was run from (issue #412). It printed a fixed
# `./Adapters/ai-runtimes/generate-agents.sh`, which exists only inside the
# framework: from an adopter's root, where the README runs the generator, it
# exited 127, and from inside the framework it targeted the framework. Now:
# this script by the path that reaches it from there, the project when it is
# not that directory, and every option that decided what was compared.
#
# A framework directory that is a link (#476) is reached through the link
# when this script was run through it: the agents the command writes then
# name the framework's directory in the project, as the ones checked do. By
# the framework's physical path, they would not.
REMEDY=""
make_remedy() {
  local cmd
  if below "$ROOT" "$INVOCATION_DIR"; then
    sh_word "./${BELOW:+$BELOW/}Adapters/ai-runtimes/generate-agents.sh"
  elif logical_root && below "$FW_LOGICAL" "$INVOCATION_DIR"; then
    sh_word "./${BELOW:+$BELOW/}Adapters/ai-runtimes/generate-agents.sh"
  else
    sh_word "$ROOT/Adapters/ai-runtimes/generate-agents.sh"
  fi
  cmd="$SH_WORD"
  sh_word "$TARGET"; cmd="$cmd --target $SH_WORD"
  if ! [ "$PROJECT" -ef "$INVOCATION_DIR" ]; then sh_word "$PROJECT"; cmd="$cmd --project $SH_WORD"; fi
  if [ -n "$OUT_GIVEN" ]; then sh_word "$OUT"; cmd="$cmd --out $SH_WORD"; fi
  if [ -n "$ROSTER_GIVEN" ]; then sh_word "$PROJECT_ROSTER"; cmd="$cmd --roster $SH_WORD"; fi
  if [ -n "$MAP_OVERRIDE" ]; then sh_word "$MAP_OVERRIDE"; cmd="$cmd --map $SH_WORD"; fi
  if [ -n "$EFFORT_MAP_OVERRIDE" ]; then sh_word "$EFFORT_MAP_OVERRIDE"; cmd="$cmd --effort-map $SH_WORD"; fi
  REMEDY="$cmd"
}

# --- --check --quick: present, and naming this framework (WU-IAENG-434) ------
#
# .claude/agents/ is per clone: gitignored, never committed, and since
# WU-IAENG-430 each agent of an adopting project names the absolute framework
# root of the clone that generated it. So a fresh clone or a second machine
# has no agent at all, and a moved project, or agents copied from another
# clone, name a framework that is not this one. That root may still exist (the
# old clone, a copy left behind), so it is compared by identity with this
# framework (-ef), never trusted because the directory is there: an Employee
# would read every Standard from it.
#
# Session start asks this on every session (claude-code/hooks/session-start.sh),
# so it costs what it must and no more: no agent is generated, and ONE awk
# process reads the rosters and every agent's root line (each file only up to
# that line). A root that is a network path (// or \\, any mix) is
# never handed to -ef: stat on Windows would open an SMB connection to the
# host it names (SEC-IAENG-358-02).
#
# Identity alone is not enough (SEC-IAENG-467-01): -ef follows a symbolic
# link, and under Git Bash a Windows junction, so a root that reaches this
# framework through a link passed, and the link could then be pointed at other
# Standards. A root is current only when it is also written as the generator
# writes this framework (shown_root, below): another spelling of the same
# directory is stale, as the full --check already says ("framework location
# only"). Windows paths are compared without letter case, as Windows reads
# them. That spelling is computed once, and only when an agent names a root.

# shown_root — SHOWN_ROOT is this framework's root as a generated agent names
# it, and the function is true when that path is this framework (-ef). Under
# Git Bash, pwd's /c/... or /tmp/... are MSYS spellings a Windows program does
# not read, so the root is written as cygpath -m gives it, C:/...; cygpath
# runs under a UTF-8 locale, not the LC_ALL=C exported above, which wrote
# Développement as D\351veloppement and cut a path off at 日本 (Code Reviewer
# F1 on PR #456). Elsewhere pwd's path is already native.
shown_root() {
  SHOWN_ROOT="$ROOT"
  if command -v cygpath > /dev/null 2>&1; then
    SHOWN_ROOT="$(LC_ALL=C.UTF-8 cygpath -m "$ROOT" 2> /dev/null)"
  fi
  [ -n "$SHOWN_ROOT" ] && [ "$SHOWN_ROOT" -ef "$ROOT" ]
}

# same_spelling <a> <b> — true when two roots are written alike: without
# letter case where Windows reads paths (cygpath is there), exactly elsewhere.
same_spelling() {
  if command -v cygpath > /dev/null 2>&1; then
    [ "${1,,}" = "${2,,}" ]
  else
    [ "$1" = "$2" ]
  fi
}

# framework_commit — FW_COMMIT is the commit this framework checkout is on,
# or empty when it is not the top of a git checkout of its own (#471). That
# test matters: a framework copied into the project, not a submodule, would
# otherwise give the PROJECT's HEAD, which moves with every project commit.
# One git process, asked only where an agent records or is given a commit.
framework_commit() {
  local top="" sha=""
  FW_COMMIT=""
  { IFS= read -r top; IFS= read -r sha; } \
    < <(git -C "$ROOT" rev-parse --show-toplevel HEAD 2> /dev/null)
  [ -n "$top" ] && [ "$top" -ef "$ROOT" ] || return 0
  case "${#sha}:$sha" in
    40:*[!0-9a-f]*|64:*[!0-9a-f]*) return 0 ;;
    40:*|64:*) FW_COMMIT="$sha" ;;
  esac
  return 0
}

if [ "$QUICK" -eq 1 ]; then
  if [ "$FORMAT" = text ]; then
    echo "IA Engineering — checking agent definitions, quick: each one present and naming"
    echo "this framework as its root. Their content is compared by --check without --quick."
    echo "  project: $PROJECT"
    echo "  output:  $OUT"
    if [ "$ROOT" -ef "$PROJECT" ]; then
      echo "  framework root they must name: none (this is the framework repository)"
    else
      echo "  framework root they must name: $ROOT"
      framework_commit
      echo "  framework commit they must record: ${FW_COMMIT:-none (git gives none: the framework is not a git checkout of its own, or git refuses to read it)}"
    fi
    echo
  fi
  # One awk process for the rosters and the agents (Code Reviewer, PR #467):
  # it reads each roster entry's name, makes its agent's file name with the
  # generation's own slug(), and reads that file's root line. One line per
  # roster Employee, in roster order: the agent's path, TAB, 1 when the file
  # carries the generated header and 0 otherwise (WU-IAENG-454: read with
  # own_entry's header(), on the lines read for the root anyway), TAB, the
  # framework commit its header records ("-" when none: TAB is a white space
  # to read, so an empty field would vanish), TAB, the root it names, empty
  # when it names none, \001 when the file cannot be opened (missing, or
  # unreadable: told apart below). The first of each line only, as
  # location_of and commit_of read them; a CR ending the line is not part of
  # it.
  #
  # A path holding something a generation never replaces is stale, with
  # own_entry's reason: an entry that is not a regular file, or a file
  # without the generated header, the project's own. An unreadable file keeps
  # its own reason, below.
  #
  # An agent whose root is this framework is then compared by commit
  # (#471): an upgrade that changes only Employees/ leaves every root as it
  # was. Its header records the commit it was generated from; one recording
  # another, or none, is stale. The commit in use is read once, and only
  # when an agent gets that far.
  Q_N=0; Q_PRESENT=0; Q_MISSING=0; Q_STALE=0
  Q_ADOPTER=1
  [ "$ROOT" -ef "$PROJECT" ] && Q_ADOPTER=0
  while IFS=$'\t' read -r q_dest q_gen q_commit q_root; do
    [ "$q_commit" = - ] && q_commit=""
    [ -n "$q_dest" ] || continue
    Q_N=$((Q_N + 1))
    if [ "$q_root" = $'\001' ] && ! [ -e "$q_dest" ] && ! [ -L "$q_dest" ]; then
      Q_MISSING=$((Q_MISSING + 1)); report missing "$q_dest"; continue
    fi
    q_why=""
    if [ "$q_gen" != 1 ] && ! [ -f "$q_dest" ]; then
      q_why="$OWN_WHY_ENTRY"
    elif [ "$q_gen" != 1 ] && [ "$q_root" != $'\001' ]; then
      q_why="$OWN_WHY_FILE"
    else
      case "$q_root" in
        $'\001') q_why="it cannot be read" ;;
        "")
          [ "$ROOT" -ef "$PROJECT" ] \
            || q_why="it names no framework root: it was written before agents named one, or for the framework repository itself" ;;
        [/\\][/\\]*) q_why="its framework root $q_root is a network path, never opened here" ;;
        /*|[A-Za-z]:[/\\]*)
          if ! [ "$q_root" -ef "$ROOT" ]; then
            q_why="its framework root $q_root is not this project's framework: the project moved, or it was generated in another clone"
          else
            if [ -z "${Q_SHOWN_DONE:-}" ]; then
              Q_SHOWN_DONE=1
              Q_SHOWN=""
              shown_root && Q_SHOWN="$SHOWN_ROOT"
            fi
            if [ -z "$Q_SHOWN" ]; then
              q_why="this framework's root cannot be written as a path that names it, so no agent's root can be confirmed"
            elif ! same_spelling "$q_root" "$Q_SHOWN"; then
              q_why="its framework root $q_root reaches this framework, but is not written as the generator writes it ($Q_SHOWN): through a link, which can be pointed elsewhere, or another spelling"
            fi
          fi ;;
        *) q_why="its framework root $q_root is not an absolute path" ;;
      esac
    fi
    if [ -z "$q_why" ] && [ "$Q_ADOPTER" -eq 1 ]; then
      if [ -z "${Q_COMMIT_DONE:-}" ]; then
        Q_COMMIT_DONE=1
        framework_commit
        Q_COMMIT="$FW_COMMIT"
      fi
      if [ "$q_commit" != "$Q_COMMIT" ]; then
        if [ -z "$q_commit" ]; then
          q_why="it records no framework commit: it was generated before agents recorded one"
        elif [ -z "$Q_COMMIT" ]; then
          q_why="it was generated from framework commit $q_commit, and git gives no commit for this framework: it is not a git checkout of its own (copied in), or git refuses to read it (dubious ownership, say)"
        else
          q_why="it was generated from framework commit $q_commit, and the framework is now at $Q_COMMIT: upgraded since, so its Employee definition may have changed"
        fi
      fi
    fi
    if [ -n "$q_why" ]; then
      Q_STALE=$((Q_STALE + 1)); report stale "$q_dest" "$q_why"
    else
      Q_PRESENT=$((Q_PRESENT + 1)); report present "$q_dest"
    fi
  done < <(Q_OUT="$OUT" awk -v hmark="$GEN_HEADER_MARK" -v hgen="$GEN_HEADER_GENERATOR" "$AWK_SLUG$AWK_HEADER"'
    # The output directory through the environment, not -v: -v reads its
    # backslashes as escapes, and C:\Users\... is a path this script accepts
    # (Code Reviewer, PR #467).
    BEGIN { out = ENVIRON["Q_OUT"] }
    # The header, where the commit line is, comes before the root line, so
    # reading up to the root line reads both. Sets c, the commit, to "-"
    # when there is none, and hm and hg through header().
    function root_of(f,   line, r, n, rc) {
      r = ""; n = 0; c = "-"; hs = 0; hm = 0; hg = 0
      while ((rc = (getline line < f)) > 0) {
        n++
        sub(/\r$/, "", line)
        if (hs < 2) header(line)
        if (c == "-" && line ~ /^  Framework: ./) {
          c = line; sub(/^  Framework: /, "", c); gsub(/\t/, " ", c)
        }
        if (line ~ /^Framework root: `.*`$/) {
          r = line; sub(/^Framework root: `/, "", r); sub(/`$/, "", r); break
        }
      }
      if (rc < 0 && n == 0) r = "\001"
      close(f)
      return r
    }
    function emit(   d, r) {
      if (name == "") return
      d = out "/" slug(name) ".md"
      r = root_of(d)
      print d "\t" ((hm && hg) ? 1 : 0) "\t" c "\t" r
    }
    /^  - name: / { emit(); name = $0; sub(/^  - name: /, "", name); gsub(/\015/, "", name); next }
    END { emit() }
  ' "$ROSTER" ${PROJECT_ROSTER:+"$PROJECT_ROSTER"})
  Q_ACT=$((Q_MISSING + Q_STALE))
  [ "$Q_ACT" -gt 0 ] && make_remedy
  if [ "$FORMAT" = tsv ]; then
    echo "# generate-agents.sh --check --quick: $Q_ACT to act on. $Q_N agent(s): $Q_PRESENT present, $Q_MISSING missing, $Q_STALE stale."
    [ "$Q_ACT" -gt 0 ] && echo "# regenerate: $REMEDY"
  else
    echo
    echo "Result (quick): $Q_PRESENT present, $Q_ACT stale or missing, of $Q_N roster Employee(s)"
    if [ "$Q_ACT" -gt 0 ]; then
      echo "  Agents are generated per clone and never committed. Regenerate:"
      echo "    $REMEDY"
    fi
  fi
  [ "$Q_ACT" -gt 0 ] && exit 1
  exit 0
fi

# --- The one-suite rule, read from the brief template (WU-IAENG-453) --------
#
# Issue #373. The rule that an Employee runs at most one full test suite at a
# time lived in Templates/EMPLOYEE_BRIEF.md only, so an Employee dispatched
# without a brief built from that template never read it. In an adopter's
# acceptance run, Employees ran their suites side by side: 25 to 48 bash.exe
# at once on one Windows machine. Every generated agent now states the rule
# in its "Test Runs" section.
#
# Read from the template at each generation, never copied here: one source,
# so a change to the rule's words changes every generated agent, and --check
# calls each agent stale until it is regenerated. The line is the one that
# begins with ONE_SUITE_PREFIX; its line-ending carriage return is removed
# (Check Convention, Shell Scripts rule 3), so a CRLF checkout writes the same
# agents. A template that is missing, or that holds the line zero times or
# twice, stops the run with exit 2, a condition not evaluated: an agent
# without the rule is not written, and no agent is called current or stale
# against a rule that could not be read. Read after the quick check, which
# generates nothing and so needs no template.
ONE_SUITE_SOURCE="Templates/EMPLOYEE_BRIEF.md"
ONE_SUITE_PREFIX="- Run at most one full test suite at a time. "
if [ ! -f "$ONE_SUITE_SOURCE" ]; then
  echo "generate-agents.sh: $ROOT/$ONE_SUITE_SOURCE not found. Every agent states the one-suite rule read from it: nothing was generated or checked." >&2
  exit 2
fi
ONE_SUITE_RULE="$(awk -v p="$ONE_SUITE_PREFIX" '{ sub(/\r$/, "") } index($0, p) == 1' "$ONE_SUITE_SOURCE")"
ONE_SUITE_N="$(printf '%s\n' "$ONE_SUITE_RULE" | grep -c .)"
if [ "$ONE_SUITE_N" -ne 1 ]; then
  echo "generate-agents.sh: $ROOT/$ONE_SUITE_SOURCE has $ONE_SUITE_N lines that begin with \"$ONE_SUITE_PREFIX\", one expected. Every agent states that rule: nothing was generated or checked." >&2
  exit 2
fi
unset ONE_SUITE_N

# --- Where an adopting project's agents read the framework (WU-IAENG-430) ----
#
# Every generated agent names framework documents by their path from the
# framework root: Core/AGENT_CONDUCT.md, Standards/COMMIT_STANDARD.md, and
# whatever its Employee definition cites. In this repository that root is the
# working directory of every session and of every worktree, so the paths
# resolve. In an adopting project they resolved nowhere (issue #449): not from
# the project root, where the framework sits under ia-engineering/, and not
# from a linked git worktree, the directory Claude Code gives an Employee
# dispatched with `isolation: worktree`. A worktree shares the clone's config
# but not its initialised submodule, so ia-engineering/ is empty there.
# Measured on develop 75765ba: 741 framework paths named by 42 agents, 741
# unresolved from the worktree. The Code Reviewer and the QA Engineer reviewed
# without the Standards they apply.
#
# So an adopting project's agents carry one more section, "Where the Framework
# Is", naming the framework root as the absolute path of the checkout that
# generated them: the main checkout's framework, the same one git already runs
# the hooks from in every worktree (install.sh writes an absolute
# core.hooksPath for that reason, WU-IAENG-414). A path naming the main
# checkout reads from any worktree, needs no network, no disk and no cleanup.
#
# Initialising the submodule in each worktree was measured and rejected: 10.7 s
# and 5.6 MiB per worktree from a local one-commit fixture (a real one clones
# the framework, history included, from its remote), and `git worktree remove`
# then refuses, exit 128, "working trees containing submodules cannot be moved
# or removed", so every worktree would need --force to be removed.
#
# The path is written as the runtime's file tools take it. Under Git Bash, pwd
# says /c/Users/... or even /tmp/..., MSYS spellings a Windows program does not
# read; cygpath -m gives C:/Users/..., which the runtime's file tools and Git
# Bash both open. Elsewhere pwd's path is already native.
#
# cygpath runs under a UTF-8 locale, not the LC_ALL=C exported above. Under C,
# it writes a non-ASCII character in a single-byte charset and stops at the
# first one it cannot write at all: .../Développement/... came out as
# D\351veloppement, a directory that does not exist, and .../日本/... was cut
# off there, so a moved project could truncate to the same root and --check
# called it current (Code Reviewer F1 on PR #456). The file is read as UTF-8,
# and C.UTF-8 gives those bytes. Then the written root must BE the framework
# (-ef): a root no program can open is refused, never written, because an
# Employee told to read there would read nothing and believe the instruction.
# All of it runs after --print-tier-map has exited: that mode names no root,
# and session-start.sh calls it on every session, so a refusal here must not
# take the tier map in force down with it.
#
# The framework repository itself gets no such section: its agents stay
# byte-identical, because there the paths already resolve. That is decided by
# identity (-ef, device and inode), not by comparing spellings, for the reason
# install.sh gives (WU-IAENG-362): the same directory can be spelled in two
# letter cases. The framework's path inside the project is found by walking up
# from the framework the same way, so a nested import (vendor/ia-engineering)
# reads right too; a framework outside the project leaves it empty.
#
# A framework directory that is a symbolic link or a junction (#476) is not
# under the project by ROOT, which is physical: the walk up from ROOT left the
# path empty, so the agents lost the sentence naming the ia-engineering/
# prefix. The path is then found by walking up the path this script was run
# by (logical_root), as the documented command, the drift check and session
# start run it, and as the command --check prints does. The root the agents
# name stays ROOT, never the link (SEC-IAENG-467-01). No entry of the project
# is opened to look for the link: a link there could name a network path
# (SEC-IAENG-358-02).
#
# A moved project, or agents copied from another clone, name a root that is
# not this one. --check reports that as its own kind of difference ("framework
# location only"), never as an Employee definition out of date.
FRAMEWORK_SHOWN=""
FRAMEWORK_REL=""
if ! [ "$ROOT" -ef "$PROJECT" ]; then
  _probe="$ROOT"
  _rel=""
  while :; do
    _parent="$(dirname "$_probe")"
    # dirname of the root is the root: the framework is not inside the project.
    [ "$_parent" = "$_probe" ] && break
    _rel="$(basename "$_probe")${_rel:+/$_rel}"
    _probe="$_parent"
    if [ "$_probe" -ef "$PROJECT" ]; then
      FRAMEWORK_REL="$_rel"
      break
    fi
  done
  unset _probe _rel _parent
  if [ -z "$FRAMEWORK_REL" ] && logical_root && below "$FW_LOGICAL" "$PROJECT"; then
    FRAMEWORK_REL="$BELOW"
  fi
  if ! shown_root; then
    FRAMEWORK_SHOWN="$SHOWN_ROOT"
    echo "generate-agents.sh: cannot write the framework root as a path that names it." >&2
    echo "  The framework is $ROOT; the native form computed for it is" >&2
    echo "  '$FRAMEWORK_SHOWN', which is not that directory. Every agent would tell its" >&2
    echo "  Employee to read the framework where it is not, so nothing was written." >&2
    exit 2
  fi
  FRAMEWORK_SHOWN="$SHOWN_ROOT"
fi

# The framework commit an adopting project's agents record in their header,
# "  Framework: <commit>", for the quick check that session start runs to
# compare with the commit in use (#471, Director decision, 18 November 2026:
# an automatic signal). Without it, an upgrade that changed only Employees/
# left every agent naming the same root, and nothing said they were stale.
# None in the framework repository, whose agents stay byte-identical and
# would otherwise change with every commit; none either when the framework is
# not a git checkout of its own (framework_commit).
GEN_COMMIT=""
COMMIT_HEADER=""
if [ -n "$FRAMEWORK_SHOWN" ]; then
  framework_commit
  GEN_COMMIT="$FW_COMMIT"
  [ -n "$GEN_COMMIT" ] && COMMIT_HEADER="  Framework: $GEN_COMMIT"$'\n'
fi

# --- Extraction ------------------------------------------------------------

# Sections needed out of every Employee definition, in the order
# generate_claude_code() consumes them. One shared list, so the extractor and
# the consumer never drift apart.
SECTION_NAMES=(
  "Mission" "Responsibilities" "Authority" "Standards Applied" "Inputs"
  "Process" "Outputs" "Output Format" "Definition of Done" "Escalation Rules"
  "Failure Modes"
)

# Extracts every section in SECTION_NAMES from one Employee definition in a
# SINGLE awk pass, populating the SECTION_BODIES array (same order as
# SECTION_NAMES) with each body: heading stripped, leading/trailing blank
# lines and "---" rules trimmed — same trimming rule the old three-stage
# pipeline applied.
#
# Was section_of(): one "awk | sed | awk" command substitution PER SECTION,
# called 12 times per Employee (11 sections + one extra Mission read for the
# description line) — about 2,000 process creations for 42 Employees. On
# Windows/Git Bash (MSYS fork emulation plus antivirus scanning of every new
# process) that made a single --dry-run take minutes; Linux CI never saw it,
# because a fork() there costs microseconds. The fix is not "a faster awk" —
# it is not re-invoking awk per section at all. One awk process reads the
# file once, buffers every wanted section's lines in a 2-D array keyed by
# (heading, line number) — SUBSEP-joined subscripts, POSIX awk since the One
# True Awk, portable to gawk/mawk/BSD awk without extensions — and prints
# them back separated by ASCII Unit Separator (0x1F, chosen because it cannot
# occur in these markdown files: verified with
# `grep -rlP '[\x1e\x1f]' Employees/ Registry/`, no match).
#
# The separator byte is generated ONCE by bash ($'\x1f') and handed to awk
# through -v, never spelled as an escape inside the awk program text: awk's
# only portable string escapes are POSIX's \\, \", \t, \n, \r and octal
# \ddd — "\x1f" is a gawk-only extension (and warns even there under
# --posix). Passing the literal byte sidesteps the portability question
# entirely instead of relying on an escape awk may not support.
#
# Bash then splits that single output on the same byte with one
# `read -d '' -a`: `VAR=x read ...` scopes IFS to that one command, so it
# does not leak into the caller, and the trailing NUL the caller appends
# gives `read -d ''` (NUL-delimited) something to stop on for the whole
# multi-line, multi-section blob in one read. Output is byte-identical to
# the old pipeline; see the generator's own commit message for the diff
# proof.
#
# CONTRACT: this function returns through the CALLER's SECTION_BODIES
# array, not through stdout or an explicit `declare -g`, relying on bash's
# dynamic scoping of `local` — a `local` variable is visible to every
# function the declaring function calls, until it returns. That only works
# if the caller has ALREADY run `local SECTION_BODIES=()` (or equivalent)
# before calling extract_sections(); skip that and the `read -a` below
# creates SECTION_BODIES as a genuine global instead, which happens to
# still work for a single-threaded top-to-bottom script but leaks state
# between calls and between this script and anything sourcing it later.
# generate_claude_code() does the required pre-declaration; keep that
# invariant if extract_sections() ever gets a second caller.
extract_sections() {
  local file="$1" us want_joined
  us=$'\x1f'
  want_joined="$(IFS="$us"; echo "${SECTION_NAMES[*]}")"

  IFS="$us" read -r -d '' -a SECTION_BODIES < <(
    awk -v want_joined="$want_joined" -v us="$us" '
      BEGIN {
        n = split(want_joined, order, us)
        for (i = 1; i <= n; i++) wanted[order[i]] = 1
        cur = ""
      }
      /^# / {
        h = $0
        sub(/^# /, "", h)
        # FIRST occurrence only, matching the old section_of(): it started
        # "inside" on the first exact-text match and, once inside, EXITED
        # entirely at the very next "# " line — so a repeated heading later
        # in the file never contributed anything, because old section_of()
        # had already returned. Marking done[h] the moment a wanted heading
        # is seen (not when its capture ends) is what makes a SECOND
        # occurrence of the SAME heading fall to the else branch below
        # instead of reopening capture and concatenating both bodies.
        if ((h in wanted) && !(h in done)) {
          cur = h
          done[h] = 1
        } else {
          cur = ""
        }
        next
      }
      cur != "" {
        line = $0
        sub(/[[:space:]]*$/, "", line)
        cnt[cur]++
        lines[cur, cnt[cur]] = line
      }
      END {
        for (i = 1; i <= n; i++) {
          name = order[i]
          c = cnt[name] + 0
          start = 1; end = c
          while (start <= end && (lines[name, start] == "" || lines[name, start] == "---")) start++
          while (end >= start && (lines[name, end] == "" || lines[name, end] == "---")) end--
          for (j = start; j <= end; j++) print lines[name, j]
          if (i < n) printf "%s", us
        }
      }
    ' "$file"
    printf '\0'
  )

  # Pad to exactly one element per SECTION_NAMES entry, IMMEDIATELY after the
  # read and before anything else touches the array.
  #
  # `read -a` drops a TRAILING empty field the same way `IFS=, read -a arr
  # <<< "a,b,"` yields two elements, not three: leading/trailing runs of the
  # split character are trimmed, so a run of IFS characters right before the
  # NUL that ends the read never produces a final empty element. That is
  # exactly what a missing LAST wanted section produces: awk emits no `print`
  # for it, so the byte stream ends "...<US><NUL>" with nothing between the
  # last delimiter and the terminator. Reachable in practice — an adopter's
  # PROJECT_ROSTER can name a Domain Employee file that simply omits Failure
  # Modes, the last entry in SECTION_NAMES — and it silently shrinks
  # SECTION_BODIES to one element short of SECTION_NAMES. Every consumer
  # below indexes both arrays in lockstep, so the missing element is not read
  # as "empty" — it is read as UNBOUND under `set -u`, and this script does
  # not set `-e` but does set `-u` (see the top of the file), so that one
  # Employee aborts the entire run instead of just omitting one heading from
  # one generated file.
  #
  # `${SECTION_BODIES[i]:-}` is the fix, not a defensive nicety on top of one:
  # default-value expansion is exempt from `set -u`'s unbound-variable error
  # by design, so re-assigning through it both (a) forces every index in
  # range to exist, however it got short, and (b) never itself trips the
  # thing it is here to prevent.
  local si
  for ((si = 0; si < ${#SECTION_NAMES[@]}; si++)); do
    SECTION_BODIES[si]="${SECTION_BODIES[si]:-}"
  done

  # `read -a` preserves the trailing newline awk's own last `print` left on
  # each non-empty section (the old section_of() lost it for free: its
  # result went through a command substitution, and $(...) strips ALL
  # trailing newlines). Without this, generate_claude_code()'s
  # `printf '%s\n' "$body"` added a SECOND newline on top of the one already
  # there, leaving a stray blank line before every section that follows a
  # non-empty one — caught by the before/after diff this Work Unit's commit
  # message documents, not by inspection.
  local i
  for i in "${!SECTION_BODIES[@]}"; do
    while [[ "${SECTION_BODIES[i]}" == *$'\n' ]]; do
      SECTION_BODIES[i]="${SECTION_BODIES[i]%$'\n'}"
    done
  done
}

# --- Generation ------------------------------------------------------------

WRITTEN=0
UNCHANGED=0
DIFFERENT=0
# The subset of DIFFERENT whose only difference is the tier mapping (see
# without_mapping below). Lets --check say which of the two causes it found.
MAPPING_DRIFT=0
# The subset of DIFFERENT that names another framework root, alone or beside
# a mapping difference (see without_location below), and the part of it that
# differs in nothing else.
LOCATION_DRIFT=0
LOCATION_ONLY=0
# The part of LOCATION_DRIFT that differs in the mapping too: neither "mapping
# only" nor "location only" (DEF-IAENG-456-01: it was counted as mapping only,
# and the lines of the summary added up to more than the agents that differ).
MAPPING_AND_LOCATION=0
# The subset of DIFFERENT that names this framework's root but records
# another of its commits (#471), alone or beside a mapping difference, and
# the part of it that also differs in the mapping.
COMMIT_DRIFT=0
MAPPING_AND_COMMIT=0
# The subset of DIFFERENT with no file on disk.
MISSING=0
# The subset of DIFFERENT whose path holds something a generation never
# replaces (own_entry, WU-IAENG-454): the project's own, left as it is.
OWN=0

# The "Where the Framework Is" section of an adopting project's agents, built
# once (see "Where an adopting project's agents read the framework" above). The
# root is on a line of its own, "Framework root: `<path>`", the one line
# without_location and location_of read it from. Every sentence speaks to the
# Employee reading the file, who may be in the main checkout or in a worktree.
#
# Interpolated values sit on lines of their own, so a long root or framework
# path does not run one sentence past the wrapping width (Prompt Engineer,
# PR #456). The prefix sentence names the framework's directory apart from
# the project's own .ia-engineering/, one dot away; and the project-path
# sentence keeps a project's own Core/ or Templates/ (a .NET or Django layout)
# from being read under the framework root.
LOCATION_SECTION=""
if [ -n "$FRAMEWORK_SHOWN" ]; then
  if [ -n "$FRAMEWORK_REL" ]; then
    _imported="This project imports IA Engineering at
\`$FRAMEWORK_REL/\`.
Read every framework file from the framework root of the project's main
checkout:"
    _prefix="So does such a path written with the prefix
\`$FRAMEWORK_REL/\`,
the framework's directory in the project, which is not the project's own
\`.ia-engineering/\`.
"
    _regenerate="from the main checkout with
\`./$FRAMEWORK_REL/Adapters/ai-runtimes/generate-agents.sh\`."
  else
    _imported="This project uses IA Engineering from outside its own tree. Read every
framework file from this framework root:"
    _prefix=""
    _regenerate="with that framework's
\`Adapters/ai-runtimes/generate-agents.sh\`, run from the project root."
  fi
  LOCATION_SECTION="## Where the Framework Is

$_imported

Framework root: \`$FRAMEWORK_SHOWN\`

A framework path in this definition or in your brief, such as \`Core/…\`,
\`Standards/…\`, \`Templates/…\`, \`Workflows/…\`, \`Employees/…\`, \`Registry/…\`
or \`Adapters/…\`, names the file at that path under the framework root.
${_prefix}For example, \`Core/AGENT_CONDUCT.md\` is
\`$FRAMEWORK_SHOWN/Core/AGENT_CONDUCT.md\`.
Read it there, by that absolute path.

Only framework documents are read there. A path to one of the project's own
files stays under your working directory, even when its first directory has
a framework name such as \`Core/\` or \`Templates/\`, and so does everything
under \`.ia-engineering/\`.

Never look for a framework file under your working directory. In a git
worktree, where an Employee usually works, a framework imported as a submodule
is an empty directory, because the submodule is not initialised there: a file
missing under your working directory is not missing from the framework. If the
framework root above does not exist, stop and report it: the project moved, or
this definition was generated in another clone. It is regenerated $_regenerate
"
  unset _imported _prefix _regenerate
fi

# Prints a generated agent file with the framework root its "Where the
# Framework Is" section names replaced by a fixed token, everywhere in the
# file, and the framework commit its header records (the first
# "  Framework: " line) left out: a file written before agents recorded a
# commit has no such line, and its only difference is then that line's
# absence, a commit-only difference too (Code Reviewer, PR #502). Two files
# equal under this filter differ in the root or the commit only. The root is
# read from the file's own "Framework root:" line, so each side is normalised
# by its own value, and the comparison is by text (index), never by regular
# expression: a path is full of characters a regex reads as operators.
without_location() {
  awk '
    !commit && /^  Framework: / { commit = 1; next }
    root == "" && /^Framework root: `.*`$/ {
      root = $0
      sub(/^Framework root: `/, "", root)
      sub(/`$/, "", root)
    }
    root != "" {
      out = ""
      rest = $0
      while ((i = index(rest, root)) > 0) {
        out = out substr(rest, 1, i - 1) "<framework root>"
        rest = substr(rest, i + length(root))
      }
      $0 = out rest
    }
    { print }
  ' "$1"
}

# The framework root a generated file names, or nothing.
location_of() {
  awk '/^Framework root: `.*`$/ { sub(/^Framework root: `/, ""); sub(/`$/, ""); print; exit }' "$1"
}

# The framework commit a generated file's header records, or nothing.
commit_of() {
  awk '/^  Framework: / { sub(/^  Framework: /, ""); print; exit }' "$1"
}

# Reads a generated agent file on stdin (without_location's output, so the
# framework root is already set aside) and prints it with what the MAPPING
# decides removed:
# `model:` and `effort:` inside the frontmatter, and the " -> <model>..." tail
# of the header's `Tier:` line. Two files equal under this filter differ in
# mapping only — their Employee definition, roster, and template are the same.
#
# The tier NAME on the `Tier:` line is kept, deliberately. It is the only
# place a generated file records which tier the roster gave the Employee, so
# dropping the whole line made a roster tier change (Standard Execution to
# Strategic Judgment, under a mapping that gives both the same model) read as
# "mapping only" — the one drift this filter exists to tell apart from a
# roster or definition change. Code Reviewer finding M1 on PR #197.
without_mapping() {
  awk '
    /^---$/ && fm < 2 { fm++; print; next }
    fm == 1 && (/^model: / || /^effort: /) { next }
    /^  Tier:      / { sub(/ -> .*$/, ""); print; next }
    { print }
  '
}

generate_claude_code() {
  local name="$1" file="$2" category="$3" tier="$4" from_roster="$5" source_label="$6" slug="$7"
  local model effort effort_note dest tmp

  dest="$OUT/$slug.md"
  case "$tier" in
    "Strategic Judgment") model="$MAP_STRATEGIC"; effort="$EFFORT_STRATEGIC" ;;
    "Standard Execution") model="$MAP_STANDARD"; effort="$EFFORT_STANDARD" ;;
    *)
      echo "  ! $name has tier '$tier', which is neither default tier." >&2
      echo "    Core/CAPABILITY_TIERS.md defines exactly two Employee defaults;" >&2
      echo "    Lightweight Execution is a per-Work-Unit override, never a" >&2
      echo "    default. Fix the Employee definition, not this script." >&2
      DIFFERENT=$((DIFFERENT + 1))
      [ "$CHECK" -eq 1 ] && [ "$FORMAT" = tsv ] && report stale "$dest" "the roster gives it the tier '$tier', which is neither default tier: it cannot be generated"
      return
      ;;
  esac
  effort_note=""
  [ -n "$effort" ] && effort_note=", effort: $effort"

  # A missing agent is missing whatever it would contain: said before any
  # generation, which costs it nothing (a fresh clone has none of them).
  # Missing means nothing at all is there: a directory or a dangling link at
  # the path is an entry the generation leaves (own_entry, below).
  if [ "$CHECK" -eq 1 ] && ! [ -e "$dest" ] && ! [ -L "$dest" ]; then
    DIFFERENT=$((DIFFERENT + 1))
    MISSING=$((MISSING + 1))
    report missing "$dest"
    return
  fi

  # One awk pass for every section this Employee needs, instead of one
  # process substitution per section (see extract_sections() above). Kept
  # after the tier check, not before, so an invalid-tier entry that returns
  # early still costs zero extraction work — same as the pre-existing
  # early-return shape.
  local SECTION_BODIES=()
  extract_sections "$file"

  tmp="$(mktemp)"

  {
    echo "---"
    echo "name: $slug"
    # One line, no newlines: the runtime reads this as a YAML scalar.
    #
    # Every Mission opens "The <Name> <verb>s ...", so stripping that prefix
    # turns it into a predicate that reads correctly after the em dash. Without
    # it the description repeated the name ("Backend Engineer — Backend Engineer
    # designs and implements ...").
    #
    # Done with parameter expansion rather than sed on purpose. An earlier
    # version interpolated the Employee name into a sed s/// pattern, which
    # broke on the one name containing a slash: "UX/UI Designer" turned
    # s/^The UX/UI Designer // into a malformed expression and produced an
    # empty description, silently, for exactly one of the 42. Expansion has no
    # delimiter to collide with.
    local mission
    mission="$(printf '%s\n' "${SECTION_BODIES[0]:-}" | head -1)"
    mission="${mission#The "$name" }"
    mission="${mission#The }"
    mission="${mission%.}"
    printf 'description: %s — %s. %s\n' \
      "$name" "$mission" "Dispatch per Core/EMPLOYEE_SELECTION.md."
    echo "model: $model"
    # Only when the tier has a non-empty effort: an absent field means
    # "inherit the runtime's default effort", which is correct for every
    # tier except Strategic Judgment (Director decision, 25 Sep 2026 — see
    # Adapters/ai-runtimes/README.md).
    [ -n "$effort" ] && echo "effort: $effort"
    echo "---"
    echo
    # The two header lines own_entry reads, from the one place they are
    # spelled (the target's block above).
    cat <<HEADER
<!--
$GEN_HEADER_MARK

  Source:    $source_label
$GEN_HEADER_GENERATOR
  Roster:    $from_roster
  Tier:      $tier -> $model$effort_note
${COMMIT_HEADER}
  Edit the Employee definition and regenerate. An edited copy is a second
  definition of this Employee that will silently diverge from Employees/,
  which is the duplication Registry/employees.yml exists to end.
-->

# $name

You are the **$name**, an IA Engineering Employee in the $category category.

You are not a generic assistant and not a tool label. Core/MAIN_AGENT_CONDUCT.md's
Dispatch Discipline states that work completed by an unnamed or generic agent is
not a completed Work Unit — it has no accountable Employee, no verifiable
Definition of Done, and no traceable Standards Applied. You are the accountable
Employee. Every artifact you produce carries \`Employee: $name\` as its commit
trailer, and the commit-msg hook validates that name against the roster.

HEADER

    # Before the first section that names a framework path, so the root is
    # read before any path is. Empty in the framework repository itself.
    [ -n "$LOCATION_SECTION" ] && printf '%s\n' "$LOCATION_SECTION"

    local i s body
    for i in "${!SECTION_NAMES[@]}"; do
      s="${SECTION_NAMES[$i]}"
      body="${SECTION_BODIES[$i]:-}"
      if [ -n "$body" ]; then
        echo "## $s"
        echo
        printf '%s\n' "$body"
        echo
      fi
    done

    cat <<'FOOTER'
## Universal Conduct

Core/AGENT_CONDUCT.md applies to you in full, as it does to every Employee:

- Stay within your assigned responsibility. Escalate rather than exceed it.
- Never present an assumption as a fact. Request missing information instead.
- Produce reviewable work. Communicate blockers immediately.
- Stop when your Work Unit is complete, when another Employee becomes
  responsible, when human validation is required, when required information is
  missing, or when continuing would violate a Framework Standard.

Core/DECISION_TREE.md governs how you decide, and no Employee may bypass it.
Its first rule is the one most often skipped: if required information is
missing, stop immediately and request it. Never make assumptions.

Escalation is not failure. It is the correct engineering decision whenever
responsibility or authority is exceeded.

FOOTER

    # The rule's words are the template's, read once above (WU-IAENG-453),
    # and printed as data: its backticks are text, never a command.
    printf '%s\n' \
      "## Test Runs" \
      "" \
      "Every Employee shares one machine. This rule of $ONE_SUITE_SOURCE" \
      "binds every Work Unit that runs tests, whether or not your brief repeats it:" \
      "" \
      "$ONE_SUITE_RULE" \
      ""

    cat <<'FOOTER'
## Your Commit

One Work Unit, one commit, per Standards/COMMIT_STANDARD.md:

```
type(scope): description

[body — why this change exists]

Work Unit: WU-<project>-<number>

Employee: <your name, exactly as it appears above>
```

The blank line between the two trailers is deliberate. A git trailer token may
not contain whitespace, so `Work Unit:` is never parsed as a trailer, and one
unparseable line invalidates the whole block — putting them on consecutive
lines costs `Employee:` its parseability too. Separated, `Employee:` sits alone
in the final paragraph and `git log --format='%(trailers:key=Employee)'`
resolves it. See Standards/COMMIT_STANDARD.md, Trailers.

Do not quote an example trailer at column 0 anywhere in the body — every
matching line is validated, so an unindented example is read as a claim.
Indent it.

The Employee trailer is mandatory and is validated mechanically against
Registry/employees.yml. A commit without it is rejected by the commit-msg hook
and, if that hook was bypassed, by the Employee Trailer CI check.

## Your First and Last Actions

First: read the brief in full, the Standards it names, and — on a resumed
project — CLAUDE.md then .ia-engineering/SESSION_STATE.md. Then say, in one
line, what you read and what you are about to do (Core/AGENT_CONDUCT.md, Read
First).

Last: write your Work Unit Report per Templates/WORK_UNIT_REPORT.md — verdict
(COMPLETE / PARTIAL / BLOCKED), what was done, what was NOT done, the gate
evidence pasted rather than described, deviations from the brief, RISK lines
for every Medium-or-higher decision, open items filed as Issues, and the
Definition of Done item by item. A bare "Done" is a failed Work Unit: the Main
Agent has nothing to verify (Core/AGENT_CONDUCT.md, Reporting Contract).

Before any action that could damage the repository, working state, an output a
user relies on, or a security boundary, classify it per
Standards/RISK_STANDARD.md. High or Critical: stop, escalate with the
escalation block, wait for a confirmation that names the action. Never use an
escape hatch — --no-verify, --no-gpg-sign, a stash in place of a commit, a
force-push, a discard of work that is not yours (Standards/GIT_STANDARD.md).
A control in the way is a rule in the way: escalate the rule.
FOOTER
  } > "$tmp"

  if [ "$CHECK" -eq 1 ]; then
    local disk_root disk_commit
    if diff -q "$tmp" "$dest" > /dev/null 2>&1; then
      UNCHANGED=$((UNCHANGED + 1))
      report current "$dest"
    elif own_entry "$dest"; then
      # The project's own (WU-IAENG-454): a generation leaves it, so no
      # difference below applies to it, and none is reported.
      DIFFERENT=$((DIFFERENT + 1))
      OWN=$((OWN + 1))
      report stale "$dest" "$OWN_WHY"
    elif diff -q <(without_location "$tmp") <(without_location "$dest") > /dev/null 2>&1; then
      # Same content once each side's framework root and commit are set
      # aside: the agent names another checkout's framework (WU-IAENG-430),
      # or, naming this one, was generated from another of its commits
      # (#471). Equal under the filter but not before it means one of the
      # two differs.
      DIFFERENT=$((DIFFERENT + 1))
      disk_root="$(location_of "$dest")"
      if [ "$disk_root" = "$FRAMEWORK_SHOWN" ]; then
        COMMIT_DRIFT=$((COMMIT_DRIFT + 1))
        disk_commit="$(commit_of "$dest")"
        report stale "$dest" "framework commit only: generated from ${disk_commit:-none}; the framework is at ${GEN_COMMIT:-none}"
      else
        LOCATION_DRIFT=$((LOCATION_DRIFT + 1))
        LOCATION_ONLY=$((LOCATION_ONLY + 1))
        report stale "$dest" "framework location only: on disk ${disk_root:-none}; resolved ${FRAMEWORK_SHOWN:-none}"
      fi
    elif diff -q <(without_location "$tmp" | without_mapping) <(without_location "$dest" | without_mapping) > /dev/null 2>&1; then
      # Same content once the mapping lines are set aside: the Employee
      # definition did not change, the mapping did. Said so, rather than
      # sending the reader to Employees/ for a drift that is not there. The
      # framework root is set aside too, and named when it also differs.
      DIFFERENT=$((DIFFERENT + 1))
      MAPPING_DRIFT=$((MAPPING_DRIFT + 1))
      # Both halves of the mapping, on both sides: an effort-only drift would
      # otherwise print the same model twice and show no difference at all.
      local disk_model disk_effort
      disk_model="$(awk '/^---$/{n++; next} n==1 && /^model: /{sub(/^model: /, ""); print; exit}' "$dest")"
      disk_effort="$(awk '/^---$/{n++; next} n==1 && /^effort: /{sub(/^effort: /, ""); print; exit}' "$dest")"
      disk_root="$(location_of "$dest")"
      disk_commit="$(commit_of "$dest")"
      if [ "$disk_root" = "$FRAMEWORK_SHOWN" ] && [ "$disk_commit" = "$GEN_COMMIT" ]; then
        report stale "$dest" "mapping only: on disk $disk_model, effort: ${disk_effort:-inherit}; resolved $model, effort: ${effort:-inherit}"
      elif [ "$disk_root" = "$FRAMEWORK_SHOWN" ]; then
        # Counted apart, for the reason the location case below is: a
        # recorded mapping alone would not make it current.
        COMMIT_DRIFT=$((COMMIT_DRIFT + 1))
        MAPPING_AND_COMMIT=$((MAPPING_AND_COMMIT + 1))
        report stale "$dest" "mapping and framework commit: on disk $disk_model, effort: ${disk_effort:-inherit}, generated from ${disk_commit:-none}; resolved $model, effort: ${effort:-inherit}, the framework at ${GEN_COMMIT:-none}"
      else
        # Counted apart: it is not a "mapping only" difference, and it is
        # one of the agents the framework-location line counts.
        LOCATION_DRIFT=$((LOCATION_DRIFT + 1))
        MAPPING_AND_LOCATION=$((MAPPING_AND_LOCATION + 1))
        report stale "$dest" "mapping and framework location: on disk $disk_model, effort: ${disk_effort:-inherit}, root ${disk_root:-none}; resolved $model, effort: ${effort:-inherit}, root ${FRAMEWORK_SHOWN:-none}"
      fi
    else
      DIFFERENT=$((DIFFERENT + 1))
      report stale "$dest" "out of date with Employees/ or the roster"
    fi
    rm -f "$tmp"
    return
  fi

  # The identical-file test comes BEFORE the dry-run branch, not after. With
  # the order reversed, --dry-run never compared anything and reported every
  # file as "would be written" — 42 of them on a tree where --check found only
  # 2 stale. The two modes ask the same question and must not answer it
  # differently; the comment further down about not reporting what did not
  # happen was in the file while the branch above it did exactly that.
  if [ -f "$dest" ] && diff -q "$tmp" "$dest" > /dev/null 2>&1; then
    UNCHANGED=$((UNCHANGED + 1))
    rm -f "$tmp"
    return
  fi

  # Never over the project's own (WU-IAENG-454, issue #516): what is at the
  # path is replaced only when it is a generated agent. Asked before the
  # dry-run branch, for the reason the identical-file test is: --dry-run
  # answers what a generation would do. The summary prints the remedy.
  if own_entry "$dest"; then
    DIFFERENT=$((DIFFERENT + 1))
    OWN=$((OWN + 1))
    echo "  ! $dest: $OWN_WHY" >&2
    rm -f "$tmp"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $dest ($tier -> $model, $(wc -l < "$tmp" | tr -d ' ') lines)"
    rm -f "$tmp"
    WRITTEN=$((WRITTEN + 1))
    return
  fi

  mkdir -p "$OUT"
  mv "$tmp" "$dest"
  WRITTEN=$((WRITTEN + 1))
}

if [ "$FORMAT" = text ]; then
  echo "IA Engineering — generating agent definitions"
  echo "  target:  $TARGET"
  echo "  project: $PROJECT"
  echo "  output:  $OUT"
  echo "  roster:  $ROOT/$ROSTER ($(grep -cE '^  - name: ' "$ROSTER") Employees)"
  if [ -n "$PROJECT_ROSTER" ]; then
    echo "  project roster: $PROJECT_ROSTER ($(grep -cE '^  - name: ' "$PROJECT_ROSTER") Domain Employee(s))"
  else
    echo "  project roster: none (no .ia-engineering/Registry/employees.yml under the project — no Domain Employees)"
  fi
  if [ -n "$FRAMEWORK_SHOWN" ]; then
    echo "  framework root, named in every agent: $FRAMEWORK_SHOWN"
  fi
  echo "  mapping: $MAPPING_SOURCE"
  echo "  tiers:   Strategic Judgment -> $MAP_STRATEGIC (effort: ${EFFORT_STRATEGIC:-inherit}), Standard Execution -> $MAP_STANDARD (effort: ${EFFORT_STANDARD:-inherit})"
  echo "           Lightweight via Tier Override -> $MAP_LIGHTWEIGHT (effort: ${EFFORT_LIGHTWEIGHT:-inherit})"
  echo "           Frontier via Tier Override, Director approval each time -> $MAP_FRONTIER (effort: ${EFFORT_FRONTIER:-inherit})"
  echo
fi

# Process substitution, NOT a pipe: a pipe puts the loop in a subshell, where
# every WRITTEN/UNCHANGED/DIFFERENT increment is discarded and the summary
# reports 0 for a run that wrote 42 files. That is the same defect class the
# Check Convention names (Adapters/README.md) — a report of something that did
# not happen — and it was introduced and caught in this Work Unit.
ROWS_SEEN=0
while IFS=$'\t' read -r name file category tier base roster_label slug; do
  [ -n "$name" ] || continue
  ROWS_SEEN=$((ROWS_SEEN + 1))

  # A roster entry with no `file:` names an Employee whose definition the
  # generator cannot read. Reported, never silently skipped to a default.
  if [ -z "$file" ]; then
    echo "  ! $name: the roster entry has no 'file:' — skipped" >&2
    DIFFERENT=$((DIFFERENT + 1))
    [ "$CHECK" -eq 1 ] && [ "$FORMAT" = tsv ] && report stale "$OUT/$slug.md" "the roster entry has no file: it cannot be generated"
    continue
  fi
  # Two forms of the same path: the absolute one to read, the declared one to
  # record. See the call site below.
  case "$file" in
    /*|[A-Za-z]:[\\/]*) source_file="$file" ;;
    *) source_file="$base/$file" ;;
  esac
  if [ ! -f "$source_file" ]; then
    echo "  ! $name: $source_file is missing — skipped" >&2
    DIFFERENT=$((DIFFERENT + 1))
    [ "$CHECK" -eq 1 ] && [ "$FORMAT" = tsv ] && report stale "$OUT/$slug.md" "its definition $source_file is missing: it cannot be generated"
    continue
  fi
  case "$TARGET" in
    # $source_file is absolute so the -f test and the read work from any
    # directory; $source_label is the roster-relative form the roster itself
    # declares, and it is what the generated header records. Passing the
    # absolute path into the header made every generated file differ between
    # machines (WU-IAENG-189, caught by review before it left the branch).
    # That still holds for the framework repository's own agents, which name
    # no root and may be committed and checked in CI. An adopting project's
    # agents differ per clone anyway, by the framework root they name
    # (WU-IAENG-430): they stay uncommitted and --check runs in each clone.
    claude-code) generate_claude_code "$name" "$source_file" "$category" "$tier" "$roster_label" "$file" "$slug" ;;
  esac
done < <(roster_rows)

if [ "$CHECK" -eq 1 ]; then
  [ "$DIFFERENT" -gt 0 ] && make_remedy
  if [ "$FORMAT" = tsv ]; then
    echo "# generate-agents.sh --check: $DIFFERENT to act on. $ROWS_SEEN agent(s): $UNCHANGED current, $MISSING missing, $((DIFFERENT - MISSING)) stale."
    [ "$DIFFERENT" -gt 0 ] && echo "# regenerate: $REMEDY"
    [ "$DIFFERENT" -gt 0 ] && exit 1
    exit 0
  fi
  echo
  echo "Result: $UNCHANGED current, $DIFFERENT stale or missing"
  if [ "$DIFFERENT" -gt 0 ]; then
    # Five groups that never overlap, so their counts add up to DIFFERENT
    # (DEF-IAENG-456-01): mapping only (root and commit unchanged), every
    # agent naming another root (with or without a mapping difference),
    # every agent naming this root but another commit (#471, the same), every
    # path holding the project's own (WU-IAENG-454), and the rest.
    MAPPING_ONLY=$((MAPPING_DRIFT - MAPPING_AND_LOCATION - MAPPING_AND_COMMIT))
    if [ "$MAPPING_ONLY" -gt 0 ]; then
      echo "  $MAPPING_ONLY differ in the tier mapping only (model/effort), not in their"
      echo "  Employee definition: they were generated with a different mapping than the"
      echo "  one resolved now (mapping: $MAPPING_SOURCE)."
      echo "  Either regenerate with the resolved mapping, or record the mapping they were"
      echo "  generated with in .ia-engineering/tier-map (Adapters/ai-runtimes/README.md)."
    fi
    if [ "$LOCATION_DRIFT" -gt 0 ]; then
      echo "  $LOCATION_DRIFT name a framework root other than this one (${FRAMEWORK_SHOWN:-none}):"
      echo "  the project moved, or they were generated in another clone. An Employee"
      echo "  reading them looks for the framework where it is not. Regenerate them here."
      if [ "$MAPPING_AND_LOCATION" -gt 0 ]; then
        echo "  $MAPPING_AND_LOCATION of them also differ in the tier mapping (model/effort): the"
        echo "  regeneration writes the mapping resolved now (mapping: $MAPPING_SOURCE)."
      fi
    fi
    if [ "$COMMIT_DRIFT" -gt 0 ]; then
      echo "  $COMMIT_DRIFT were generated from another commit of this framework (now"
      echo "  ${GEN_COMMIT:-none}): it was upgraded since, and session start reports them as"
      echo "  stale until they are regenerated. Their content differs in nothing else."
      if [ "$MAPPING_AND_COMMIT" -gt 0 ]; then
        echo "  $MAPPING_AND_COMMIT of them also differ in the tier mapping (model/effort): the"
        echo "  regeneration writes the mapping resolved now (mapping: $MAPPING_SOURCE)."
      fi
    fi
    if [ "$OWN" -gt 0 ]; then
      echo "  $OWN are the project's own, not generated agents (no generated header): a"
      echo "  generation never replaces them, so each one's Employee has no agent until"
      echo "  it is renamed, its file and the name: in its frontmatter, or moved elsewhere."
    fi
    if [ "$DIFFERENT" -gt $((MAPPING_ONLY + LOCATION_DRIFT + COMMIT_DRIFT + OWN)) ]; then
      echo "  $((DIFFERENT - MAPPING_ONLY - LOCATION_DRIFT - COMMIT_DRIFT - OWN)) out of date with Employees/ or the roster, or missing."
    fi
    echo "  Regenerate, from the directory this check was run from:"
    echo "    $REMEDY"
    exit 1
  fi
  exit 0
fi

echo

# Under --dry-run nothing was written, so the summary must not say it was.
# The counter is shared between the two modes, and reporting "42 written" for a
# run that touched no file is a report of something that did not happen —
# small, but the same category as every other finding in this milestone.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Result: $WRITTEN would be written, $UNCHANGED already current (nothing was written)"
else
  echo "Result: $WRITTEN written, $UNCHANGED already current"
fi
[ "$DIFFERENT" -gt 0 ] && echo "        $DIFFERENT skipped — see the warnings above" >&2

# The project's own, left in place (WU-IAENG-454): what to do, and the command
# that then writes the agents it kept out, as --check prints it.
if [ "$OWN" -gt 0 ]; then
  make_remedy
  {
    echo
    echo "$OWN path(s) in $OUT hold the project's own, not a generated agent, and"
    echo "were left as they are: a generation replaces only a file with the generated"
    echo "header. Each one's Employee has no agent until the path is free: rename the"
    echo "project's agent, its file and the name: in its frontmatter, or move it elsewhere."
    echo "  Regenerate, from the directory this was run from:"
    echo "    $REMEDY"
  } >&2
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$WRITTEN" -gt 0 ]; then
  echo
  echo "These are build artifacts, generated in each clone. Regenerate after"
  echo "editing any Employee definition, after a framework upgrade and after the"
  echo "project moves; do not hand-edit them. .gitignore keeps them out, and an"
  echo "adopting project never commits them: the pre-commit hook install.sh"
  echo "installs refuses them. A session started before .claude/agents/ existed"
  echo "loads them only once it is restarted."
fi

[ "$DIFFERENT" -gt 0 ] && exit 1
exit 0
