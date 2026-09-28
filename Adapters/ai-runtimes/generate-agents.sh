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
# and in --map, never in Core/.
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
# Usage:
#   ./Adapters/ai-runtimes/generate-agents.sh [options]
#
#   --target <name>   runtime target (default: claude-code). Only claude-code
#                     exists today; --target list prints what is available.
#   --out <dir>       output directory (default: the target's convention,
#                     resolved against the PROJECT, not the framework)
#   --project <dir>   project root (default: the directory this was run from).
#                     Decides where agents are written and where the project
#                     roster is looked for.
#   --roster <file>   an ADDITIONAL roster of Domain Employees, on top of the
#                     framework's. Default: <project>/.ia-engineering/Registry/
#                     employees.yml when it exists. A value naming a missing
#                     file is refused, never skipped.
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
#                     what is on disk. For CI.
#   --help
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}'; exit 0 ;;
    *) echo "Unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
done

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
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    echo "Run with '--target list' to see what is available." >&2
    echo "Adding a runtime means adding a case branch in this script; the" >&2
    echo "Employee definitions and Core/CAPABILITY_TIERS.md do not change." >&2
    exit 2
    ;;
esac

if [ -n "$MAP_OVERRIDE" ]; then
  for pair in ${MAP_OVERRIDE//,/ }; do
    case "$pair" in
      strategic=*)   MAP_STRATEGIC="${pair#strategic=}" ;;
      standard=*)    MAP_STANDARD="${pair#standard=}" ;;
      lightweight=*) MAP_LIGHTWEIGHT="${pair#lightweight=}" ;;
      frontier=*)    MAP_FRONTIER="${pair#frontier=}" ;;
      *) echo "Unrecognised --map entry: $pair" >&2; exit 2 ;;
    esac
  done
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

if [ -n "$EFFORT_MAP_OVERRIDE" ]; then
  for pair in ${EFFORT_MAP_OVERRIDE//,/ }; do
    key="${pair%%=*}"
    value="${pair#*=}"
    case "$key" in
      strategic|standard|lightweight|frontier) ;;
      *) echo "Unrecognised --effort-map entry: $pair" >&2; exit 2 ;;
    esac
    if ! is_valid_effort "$value"; then
      echo "Invalid --effort-map value in '$pair': '$value'" >&2
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
fi

# --- Project, output, and rosters ------------------------------------------

PROJECT="${PROJECT:-$INVOCATION_DIR}"
if [ ! -d "$PROJECT" ]; then
  echo "generate-agents.sh: --project '$PROJECT' is not a directory." >&2
  exit 2
fi
PROJECT="$(cd "$PROJECT" && pwd)"

# Relative --out is the adopter's project path, not a path inside the
# framework. Absolute --out is taken as given.
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
DEFAULT_PROJECT_ROSTER="$PROJECT/.ia-engineering/Registry/employees.yml"
if [ -n "$PROJECT_ROSTER" ]; then
  if [ ! -f "$PROJECT_ROSTER" ]; then
    echo "generate-agents.sh: --roster '$PROJECT_ROSTER' does not exist." >&2
    echo "  Generating the framework roster alone would leave this project's Domain" >&2
    echo "  Employees undispatchable while reporting success. Fix the path or drop the flag." >&2
    exit 2
  fi
  PROJECT_ROSTER="$(cd "$(dirname "$PROJECT_ROSTER")" && pwd)/$(basename "$PROJECT_ROSTER")"
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

# --- Extraction ------------------------------------------------------------

# Prints one top-level section's body from an Employee definition, without its
# heading. Sections are delimited by "# Heading" lines.
section_of() {
  local file="$1" heading="$2"
  awk -v want="# $heading" '
    $0 == want { inside = 1; next }
    inside && /^# / { exit }
    inside { print }
  ' "$file" | sed 's/[[:space:]]*$//' | awk '
    # Trim leading and trailing blank lines and the horizontal rules that
    # separate sections in these documents.
    { lines[NR] = $0 }
    END {
      start = 1; end = NR
      while (start <= end && (lines[start] == "" || lines[start] == "---")) start++
      while (end >= start && (lines[end] == "" || lines[end] == "---")) end--
      for (i = start; i <= end; i++) print lines[i]
    }
  '
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's|/| |g; s/[^a-z0-9]\+/-/g; s/^-//; s/-$//'
}

# --- Generation ------------------------------------------------------------

WRITTEN=0
UNCHANGED=0
DIFFERENT=0

generate_claude_code() {
  local name="$1" file="$2" category="$3" tier="$4" from_roster="$5" source_label="$6"
  local slug model effort effort_note dest tmp

  slug="$(slugify "$name")"
  case "$tier" in
    "Strategic Judgment") model="$MAP_STRATEGIC"; effort="$EFFORT_STRATEGIC" ;;
    "Standard Execution") model="$MAP_STANDARD"; effort="$EFFORT_STANDARD" ;;
    *)
      echo "  ! $name has tier '$tier', which is neither default tier." >&2
      echo "    Core/CAPABILITY_TIERS.md defines exactly two Employee defaults;" >&2
      echo "    Lightweight Execution is a per-Work-Unit override, never a" >&2
      echo "    default. Fix the Employee definition, not this script." >&2
      DIFFERENT=$((DIFFERENT + 1))
      return
      ;;
  esac
  effort_note=""
  [ -n "$effort" ] && effort_note=", effort: $effort"

  dest="$OUT/$slug.md"
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
    mission="$(section_of "$file" "Mission" | head -1)"
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
    cat <<HEADER
<!--
  GENERATED FILE — do not edit.

  Source:    $source_label
  Generator: Adapters/ai-runtimes/generate-agents.sh --target claude-code
  Roster:    $from_roster
  Tier:      $tier -> $model$effort_note

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

    local s
    for s in "Mission" "Responsibilities" "Authority" "Standards Applied" "Inputs" "Process" "Outputs" "Output Format" "Definition of Done" "Escalation Rules" "Failure Modes"; do
      local body
      body="$(section_of "$file" "$s")"
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
    if [ -f "$dest" ] && diff -q "$tmp" "$dest" > /dev/null 2>&1; then
      UNCHANGED=$((UNCHANGED + 1))
    else
      DIFFERENT=$((DIFFERENT + 1))
      echo "  differs: $dest"
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
echo "  tiers:   Strategic Judgment -> $MAP_STRATEGIC (effort: ${EFFORT_STRATEGIC:-inherit}), Standard Execution -> $MAP_STANDARD (effort: ${EFFORT_STANDARD:-inherit})"
echo "           Lightweight via Tier Override -> $MAP_LIGHTWEIGHT (effort: ${EFFORT_LIGHTWEIGHT:-inherit})"
echo "           Frontier via Tier Override, Director approval each time -> $MAP_FRONTIER (effort: ${EFFORT_FRONTIER:-inherit})"
echo

# One awk pass per roster, same shape validate-framework.sh uses. The base
# directory travels with each row because a roster's `file:` paths are relative
# to ITS OWN root: the framework's to the framework, a project's to the project.
read_roster() {
  awk -v base="$2" -v label="$3" '
    function emit() { if (name != "") print name "\t" file "\t" category "\t" tier "\t" base "\t" label }
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

# Process substitution, NOT a pipe: a pipe puts the loop in a subshell, where
# every WRITTEN/UNCHANGED/DIFFERENT increment is discarded and the summary
# reports 0 for a run that wrote 42 files. That is the same defect class the
# Check Convention names (Adapters/README.md) — a report of something that did
# not happen — and it was introduced and caught in this Work Unit.
while IFS=$'\t' read -r name file category tier base roster_label; do
  [ -n "$name" ] || continue

  # A roster entry with no `file:` names an Employee whose definition the
  # generator cannot read. Reported, never silently skipped to a default.
  if [ -z "$file" ]; then
    echo "  ! $name: the roster entry has no 'file:' — skipped" >&2
    DIFFERENT=$((DIFFERENT + 1))
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
    continue
  fi
  case "$TARGET" in
    # $source_file is absolute so the -f test and the read work from any
    # directory; $source_label is the roster-relative form the roster itself
    # declares, and it is what the generated header records. Passing the
    # absolute path into the header made every generated file differ between
    # machines, which breaks the --check mode Adapters/ai-runtimes/README.md
    # recommends adopters wire into CI. Introduced by WU-IAENG-189 and caught
    # by review before it left the branch.
    claude-code) generate_claude_code "$name" "$source_file" "$category" "$tier" "$roster_label" "$file" ;;
  esac
done < <(
  read_roster "$ROSTER" "$ROOT" "$ROSTER"
  if [ -n "$PROJECT_ROSTER" ]; then
    # Labelled by the path an adopter would type, so a generated Domain
    # Employee's header points at the roster that actually declared it.
    read_roster "$PROJECT_ROSTER" "$PROJECT" "${PROJECT_ROSTER#"$PROJECT"/}"
  fi
)

echo
if [ "$CHECK" -eq 1 ]; then
  echo "Result: $UNCHANGED current, $DIFFERENT stale or missing"
  if [ "$DIFFERENT" -gt 0 ]; then
    echo "  Generated agents are out of date with Employees/. Regenerate:"
    echo "    ./Adapters/ai-runtimes/generate-agents.sh --target $TARGET"
    exit 1
  fi
  exit 0
fi

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

if [ "$DRY_RUN" -eq 0 ] && [ "$WRITTEN" -gt 0 ]; then
  echo
  echo "These are build artifacts. Regenerate after editing any Employee"
  echo "definition; do not hand-edit them. Whether to commit them is the"
  echo "project's call — this repository does not, and .gitignore reflects that."
fi

[ "$DIFFERENT" -gt 0 ] && exit 1
exit 0
