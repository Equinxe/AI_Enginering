#!/usr/bin/env bash
# IA Engineering — validate-framework.sh
#
# The mechanical cross-reference check.
#
# Governance/CONTRIBUTING.md Section 3 and Governance/DEPRECATION_POLICY.md
# ("Required Step: Cross-Reference Check") both require, as a Definition of
# Done item, that a contributor search the whole repository for every reference
# to what they changed and update each one. Both documents are explicit that
# this is not optional cleanup, and both name the reason: this repository has
# repeatedly shipped a change and forgotten the document that referenced it.
# Three instances are on record — the ADR trigger list that
# Core/ORCHESTRATION.md Step 2 had to cross-reference, the security-sensitive
# QA trigger that Core/AGENT_CHAINS.md's Review Chain had to cross-reference,
# and stale roster counts in VERSION.md and README.md. All three were found
# afterward, by a dedicated audit.
#
# A check that only a careful human performs is a check the framework does not
# actually have. This script is that check, executed.
#
# It validates DERIVED against AUTHORITATIVE, never the reverse. Where the
# Registry and a governed document disagree, the document is right and the
# Registry is stale (see Registry/README.md, "Authority — the Registry Never
# Wins"). Every failure below therefore names the document to fix.
#
# Usage:
#   ./Adapters/scripts/validate-framework.sh              # validate; exit 1 on failure
#   ./Adapters/scripts/validate-framework.sh --verbose    # also print passing checks
#   ./Adapters/scripts/validate-framework.sh --regenerate-roster
#                                                         # rewrite Registry/employees.yml
#                                                         # from the Employee definitions
#
# Run from anywhere; paths resolve against the repository root.

set -uo pipefail

VERBOSE=0
REGENERATE=0

for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --regenerate-roster) REGENERATE=1 ;;
    --help|-h)
      sed -n '2,34p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

# Resolve the repository root from this script's own location, so the script
# behaves the same however it is invoked.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT" || exit 2

ROSTER="Registry/employees.yml"

FAILURES=0
CHECKS=0

# --- Reporting -------------------------------------------------------------

section() {
  printf '\n== %s\n' "$1"
}

pass() {
  CHECKS=$((CHECKS + 1))
  if [ "$VERBOSE" -eq 1 ]; then
    printf '   ok    %s\n' "$1"
  fi
}

fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  printf '   FAIL  %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '         %s\n' "$2"
  fi
  # Surface as an annotation when running under GitHub Actions.
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error::$1 ${2:-}"
  fi
}

# --- Roster helpers --------------------------------------------------------
# The parsing contract lives in Registry/README.md: each entry's first line is
# "  - name: <Name>" — two leading spaces, unquoted, no trailing comment.
# "tr -d" strips a carriage return left by a CRLF checkout, which would
# otherwise make every name comparison fail.

roster_names() {
  printf '%s\n' "$ROSTER_NAMES"
}

# The roster is flattened once, into one tab-separated record per Employee:
#   name <TAB> file <TAB> category <TAB> tier
#
# Every later check reads that in-memory table instead of re-parsing the file.
# An earlier version called a per-Employee awk lookup for each field, which is
# 4 processes x 42 Employees before a single check has run; on Windows, where
# process creation is expensive, the script took minutes. This is one awk pass.
flatten_roster() {
  awk '
    /^  - name: / {
      if (name != "") print name "\t" file "\t" category "\t" tier
      name = $0; sub(/^  - name: /, "", name); gsub(/\015/, "", name)
      file = ""; category = ""; tier = ""
      next
    }
    /^    file: /     { file = $0;     sub(/^    file: /, "", file);         gsub(/\015/, "", file) }
    /^    category: / { category = $0; sub(/^    category: /, "", category); gsub(/\015/, "", category) }
    /^    tier: /     { tier = $0;     sub(/^    tier: /, "", tier);         gsub(/\015/, "", tier) }
    END { if (name != "") print name "\t" file "\t" category "\t" tier }
  ' "$ROSTER"
}

employee_tier_from_file() {
  grep -m1 'Default Complexity Tier:' "$1" \
    | sed 's/.*Default Complexity Tier: //' | tr -d '\015'
}

employee_name_from_file() {
  head -1 "$1" | sed 's/^# //' | tr -d '\015'
}

# Exact-line membership test, in pure bash. Used in the hot loops in place of
# "printf | grep -qxF", which spawns two processes per comparison — roughly
# 500 of them across the Employee and metadata checks, and slow enough on
# Windows to dominate the script's runtime.
has_line() {
  local haystack="$1" needle="$2"
  case "
$haystack
" in
    *"
$needle
"*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Regeneration ----------------------------------------------------------
# Only employees.yml is regenerable: name, path, category, and tier are all
# mechanically extractable from the Employee definitions. chains.yml,
# workflows.yml, and work-units.yml encode sequence, gate placement, and
# history — editorial content no heading contains.

regenerate_roster() {
  local tmp f name category tier
  tmp="$(mktemp)"
  # Preserve the header comment block verbatim: it documents the parsing
  # contract every shell consumer depends on.
  awk '/^employees:$/ { print; exit } { print }' "$ROSTER" > "$tmp"
  for f in Employees/*/*.md; do
    name="$(employee_name_from_file "$f")"
    category="$(basename "$(dirname "$f")")"
    tier="$(employee_tier_from_file "$f")"
    printf '  - name: %s\n    file: %s\n    category: %s\n    tier: %s\n' \
      "$name" "$f" "$category" "$tier" >> "$tmp"
  done
  mv "$tmp" "$ROSTER"
  echo "Regenerated $ROSTER from $(find Employees -name '*.md' | wc -l | tr -d ' ') Employee definitions."
  echo "Review the diff before committing."
}

if [ "$REGENERATE" -eq 1 ]; then
  regenerate_roster
  exit 0
fi

echo "IA Engineering — framework validation"
echo "Repository: $ROOT"

# Parse the roster once. Everything downstream reads these two variables.
if [ -f "$ROSTER" ]; then
  ROSTER_TABLE="$(flatten_roster)"
  ROSTER_NAMES="$(printf '%s\n' "$ROSTER_TABLE" | cut -f1)"
else
  ROSTER_TABLE=""
  ROSTER_NAMES=""
fi

# ==========================================================================
section "1. Registry parsing contract"
# ==========================================================================
# Every shell consumer (the commit-msg hook, the employee-trailer CI job) reads
# the roster with grep and sed. If the file is reformatted — re-indented,
# quoted, a trailing comment added — those consumers match nothing and silently
# accept any Employee name. The contract is checked here so a break surfaces at
# validation time rather than as a hook that quietly stopped enforcing.

if [ ! -f "$ROSTER" ]; then
  fail "$ROSTER is missing" "Every mechanical consumer resolves the roster here; without it the commit-msg hook fails closed and no commit can land."
else
  pass "$ROSTER exists"

  BAD_SHAPE="$(grep -nE '^ *-? *name:' "$ROSTER" | grep -vE '^[0-9]+:  - name: [^\"#]+$' || true)"
  if [ -n "$BAD_SHAPE" ]; then
    fail "roster entries violate the parsing contract" "Expected '  - name: <Name>' (two spaces, unquoted, no trailing comment). Offending: $(echo "$BAD_SHAPE" | tr '\n' ' ')"
  else
    pass "all name: lines match the contract"
  fi

  if grep -q '\015' "$ROSTER"; then
    fail "$ROSTER contains CRLF line endings" "Shell consumers extract names with sed; a trailing carriage return makes the comparison match nothing, rejecting all valid Employees. .gitattributes enforces LF for Registry/ — re-checkout the file."
  else
    pass "$ROSTER is LF-only"
  fi
fi

ROSTER_COUNT="$(roster_names | wc -l | tr -d ' ')"

for field in file category tier; do
  field_count="$(grep -cE "^    $field: " "$ROSTER")"
  if [ "$field_count" -ne "$ROSTER_COUNT" ]; then
    fail "roster has $ROSTER_COUNT entries but $field_count '$field:' lines" "Every entry needs name, file, category, and tier."
  else
    pass "every entry declares $field"
  fi
done

# ==========================================================================
section "2. Registry roster vs. Employees/ definitions"
# ==========================================================================
# The Employee definitions are authoritative. Each registry field restates
# something one of them says, so each is checked back against it.

EMPLOYEE_FILE_COUNT="$(find Employees -name '*.md' | wc -l | tr -d ' ')"

if [ "$ROSTER_COUNT" -ne "$EMPLOYEE_FILE_COUNT" ]; then
  fail "roster lists $ROSTER_COUNT Employees but Employees/ holds $EMPLOYEE_FILE_COUNT files" "Run --regenerate-roster, or look for an Employee added without a registry entry."
else
  pass "roster count matches Employees/ file count ($ROSTER_COUNT)"
fi

while IFS=$'\t' read -r name file category tier; do
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    fail "roster entry '$name' points at a missing file" "file: ${file:-<empty>}"
    continue
  fi

  actual_name="$(employee_name_from_file "$file")"
  if [ "$actual_name" != "$name" ]; then
    fail "roster name '$name' does not match its definition's title" "$file declares '# $actual_name'. The definition is authoritative — fix the registry entry."
  else
    pass "$name: title matches definition"
  fi

  actual_category="$(basename "$(dirname "$file")")"
  if [ "$actual_category" != "$category" ]; then
    fail "roster category for '$name' is '$category' but the file lives in '$actual_category'" "$file"
  fi

  actual_tier="$(employee_tier_from_file "$file")"
  if [ -z "$actual_tier" ]; then
    fail "$file declares no Default Complexity Tier" "Governance/CONTRIBUTING.md Section 2 requires it in every Employee's Metadata, and Core/ORCHESTRATION.md Step 4 reads it before every dispatch."
  elif [ "$actual_tier" != "$tier" ]; then
    fail "roster tier for '$name' is '$tier' but the definition says '$actual_tier'" "$file is authoritative — fix the registry entry."
  fi
done < <(printf '%s\n' "$ROSTER_TABLE")

# An Employee with no registry entry is invisible to the commit-msg hook: its
# name is rejected in a commit trailer even though the Employee formally exists.
for f in Employees/*/*.md; do
  name="$(employee_name_from_file "$f")"
  if ! has_line "$ROSTER_NAMES" "$name"; then
    fail "$f ('$name') has no entry in $ROSTER" "The commit-msg hook would reject 'Employee: $name' even though the Employee exists. Run --regenerate-roster."
  fi
done

# ==========================================================================
section "3. Roster counts quoted in prose"
# ==========================================================================
# VERSION.md and README.md both state the roster size in text. Governance/
# CONTRIBUTING.md Section 2 requires updating VERSION.md in the same Work Unit
# as an Employee addition, calling a mismatched count "exactly the kind of
# drift this repository has caught and fixed before".

check_quoted_count() {
  local file="$1" pattern="$2" label="$3" found
  found="$(grep -ohE "$pattern" "$file" | grep -ohE '[0-9]+' | head -1)"
  if [ -z "$found" ]; then
    fail "$file: could not find the $label count" "Expected text matching /$pattern/. If the wording changed, update this check."
  elif [ "$found" -ne "$ROSTER_COUNT" ]; then
    fail "$file states $found Employees, but the roster has $ROSTER_COUNT" "Governance/CONTRIBUTING.md Section 2 requires this updated in the same Work Unit as the roster change."
  else
    pass "$file $label count is $ROSTER_COUNT"
  fi
}

check_quoted_count VERSION.md 'Employees \([0-9]+\)' "Employees section"
check_quoted_count README.md '[0-9]+ AI Employee definitions' "README roster"

# ==========================================================================
section "4. Tier assignment vs. Core/CAPABILITY_TIERS.md"
# ==========================================================================
# CAPABILITY_TIERS.md's Default Tier Assignment table names every Strategic
# Judgment Employee explicitly and folds the rest into "All other Employees".
# Nothing previously compared that table to the per-file declarations, so a new
# Strategic Judgment Employee could be dispatched at Standard capability with
# both documents looking correct in isolation.

TIERS_DOC="Core/CAPABILITY_TIERS.md"
if [ ! -f "$TIERS_DOC" ]; then
  fail "$TIERS_DOC is missing" "Core/ORCHESTRATION.md Step 4 selects execution capability from it before every dispatch."
else
  TABLE_ROW="$(grep -E '^\| Strategic Judgment \|' "$TIERS_DOC" | head -1)"
  if [ -z "$TABLE_ROW" ]; then
    fail "$TIERS_DOC has no Strategic Judgment row in its tier-assignment table" "If the table's shape changed, update this check."
  else
    TABLE_NAMES="$(echo "$TABLE_ROW" | awk -F'|' '{print $3}' | tr ',' '\n' \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort)"
    FILE_NAMES="$(printf '%s\n' "$ROSTER_TABLE" \
      | awk -F'\t' '$4 == "Strategic Judgment" { print $1 }' | sort)"

    if [ "$TABLE_NAMES" = "$FILE_NAMES" ]; then
      pass "Strategic Judgment table matches all $(echo "$FILE_NAMES" | wc -l | tr -d ' ') per-file declarations"
    else
      only_table="$(comm -23 <(echo "$TABLE_NAMES") <(echo "$FILE_NAMES") | tr '\n' ' ')"
      only_files="$(comm -13 <(echo "$TABLE_NAMES") <(echo "$FILE_NAMES") | tr '\n' ' ')"
      fail "$TIERS_DOC's Strategic Judgment list disagrees with the Employee definitions" "Table only: ${only_table:-none}. Definitions only: ${only_files:-none}. The definitions are authoritative."
    fi
  fi
fi

# ==========================================================================
section "5. Dispatch triggers in Core/EMPLOYEE_SELECTION.md"
# ==========================================================================
# EMPLOYEE_SELECTION.md exists to stop the Main Agent defaulting to a familiar
# Employee: a roster audit found 96% of credited commits going to 4 of the 42.
# An Employee with no trigger there is one the Main Agent has no concrete
# reason to ever reach for — the exact gap that document closes. Governance/
# CONTRIBUTING.md Section 2 requires adding the trigger in the same Work Unit
# as the Employee.

SELECTION_DOC="Core/EMPLOYEE_SELECTION.md"
if [ ! -f "$SELECTION_DOC" ]; then
  fail "$SELECTION_DOC is missing" "Core/MAIN_AGENT_CONDUCT.md's Employee Selection section requires the Main Agent to check it before every dispatch."
else
  # One pass over the document collects every bolded Employee name it names;
  # the roster is then checked against that set in memory.
  TRIGGERED="$(grep -ohE '^- \*\*[^*]+\*\*' "$SELECTION_DOC" | sed 's/^- \*\*//; s/\*\*$//')"
  missing_triggers=""
  while IFS= read -r name; do
    if ! has_line "$TRIGGERED" "$name"; then
      missing_triggers="$missing_triggers$name; "
    fi
  done < <(roster_names)
  if [ -n "$missing_triggers" ]; then
    fail "$SELECTION_DOC has no dispatch trigger for: $missing_triggers" "Governance/CONTRIBUTING.md Section 2 requires a 'dispatch this Employee when...' entry for every Employee."
  else
    pass "every Employee has a dispatch trigger"
  fi
fi

# ==========================================================================
section "6. Employee definition completeness"
# ==========================================================================
# Governance/CONTRIBUTING.md Section 2 enumerates the sections every Employee
# definition must carry, and states a proposal missing any of them "is
# incomplete — return it for revision rather than merging a partial Employee
# definition". Nothing enforced that, so the requirement held only as long as a
# reviewer remembered to check it by hand.

EMPLOYEE_SECTIONS="Mission|Responsibilities|Authority|Standards Applied|Inputs|Process|Outputs|Definition of Done|Escalation Rules|Failure Modes|Metadata"

IFS='|' read -ra REQUIRED_EMPLOYEE_SECTIONS <<< "$EMPLOYEE_SECTIONS"

for f in Employees/*/*.md; do
  # One grep collects the file's top-level headings; the required set is then
  # checked against them in memory, rather than grepping the file once per
  # required section.
  headings="$(grep -oE '^# .+$' "$f" | sed 's/^# //' | tr -d '\015')"
  missing=""
  for s in "${REQUIRED_EMPLOYEE_SECTIONS[@]}"; do
    has_line "$headings" "$s" || missing="$missing$s, "
  done
  if [ -n "$missing" ]; then
    fail "$f is missing required sections: ${missing%, }" "Governance/CONTRIBUTING.md Section 2 lists every mandatory section."
  else
    pass "$(basename "$f"): all required sections present"
  fi
done

# ==========================================================================
section "7. Workflow and Standard completeness"
# ==========================================================================
# The structural requirements in Governance/CONTRIBUTING.md Section 3, applied.

for f in Workflows/*.md; do
  missing=""
  for s in Purpose Trigger Actors Escalation Metadata; do
    grep -qE "^# $s" "$f" || missing="$missing$s, "
  done
  # A Workflow needs a container heading for its numbered steps, so a step is
  # never an orphaned subsection under Prerequisites — which is what
  # PROJECT_BOOTSTRAP.md was until WU-IAENG-140.
  #
  # "Ceremonies" is accepted alongside "Steps" because SPRINT_CEREMONY.md is
  # correct to use it: its units are Scrum ceremonies (Planning, Standup,
  # Review, Retrospective), recurring events rather than a one-pass sequence of
  # steps. Forcing "Steps" onto it would rename the domain's own vocabulary to
  # satisfy a checker. The requirement is a container heading, not a specific
  # word for it.
  grep -qE '^# (Steps|Ceremonies)' "$f" || missing="${missing}Steps (or Ceremonies), "
  # A Workflow must state how it ends; either heading is accepted.
  grep -qE '^# (Exit Criteria|Coverage Checklist)' "$f" || missing="${missing}Exit Criteria, "
  if [ -n "$missing" ]; then
    fail "$f is missing required sections: ${missing%, }" "Governance/CONTRIBUTING.md Section 3 defines the Workflow document shape."
  else
    pass "$(basename "$f"): Workflow shape ok"
  fi
done

for f in Standards/*.md; do
  missing=""
  for s in Purpose Rationale Metadata; do
    grep -qE "^# $s" "$f" || missing="$missing$s, "
  done
  # Standards/STANDARDS_FIRST.md is the hierarchy itself, not a Standard
  # applying it, so it has no external standard to reference.
  if [ "$f" != "Standards/STANDARDS_FIRST.md" ]; then
    grep -qE '^# Official References' "$f" || missing="${missing}Official References, "
  fi
  if [ -n "$missing" ]; then
    fail "$f is missing required sections: ${missing%, }" "Governance/CONTRIBUTING.md Section 3 defines the Standard document shape, grounded in Standards/STANDARDS_FIRST.md's hierarchy."
  else
    pass "$(basename "$f"): Standard shape ok"
  fi
done

# ==========================================================================
section "8. Document metadata"
# ==========================================================================
# Governance/VERSIONING_POLICY.md's "Document-Internal Version Field Policy"
# makes Version a per-document revision counter carried by every governed
# document. A document with no Version has no revision history at all.

META_COUNT=0
for f in Core/*.md Standards/*.md Workflows/*.md Templates/*.md Governance/*.md Employees/*/*.md; do
  [ -f "$f" ] || continue
  META_COUNT=$((META_COUNT + 1))
  # One grep per file collects the metadata field names present; membership is
  # then tested in memory rather than grepping each file three times.
  fields="$(grep -oE '^(Owner|Version|Status): ' "$f" | sed 's/: $//' | tr -d '\015')"
  for field in Owner Version Status; do
    if ! has_line "$fields" "$field"; then
      fail "$f has no '$field:' metadata field" "Governance/VERSIONING_POLICY.md requires a Version field on every governed document; Owner and Status accompany it throughout the repository."
    fi
  done
done
pass "metadata fields checked across $META_COUNT governed documents"

# ==========================================================================
section "9. Internal cross-references resolve"
# ==========================================================================
# The literal cross-reference check: every backtick-quoted path pointing into
# the framework's own directories must exist. Restricted to paths starting with
# a known top-level directory, which excludes the illustrative paths in
# Examples/ (ADR-SHOP-007..., docs/api/tasks.md) that name artifacts of a
# fictional project rather than files of this repository.
#
# Three paths are legitimately absent from THIS repository, and each is exempt
# for a stated reason rather than because the check was inconvenient:
#
#   Governance/DEPRECATED.md   Governance/DEPRECATION_POLICY.md states it "is
#                              created the first time any artifact is
#                              deprecated", and that "until then, its absence
#                              itself indicates the framework has deprecated
#                              nothing". Its absence carries meaning.
#   Governance/charters/       Templates/PROJECT_CHARTER.md says charters are
#                              stored there "within the project repository" —
#                              the adopting project's, not the framework's.
#                              This repository is not a project with a charter.
#   Governance/incidents/      Templates/INCIDENT_REPORT.md names it explicitly
#                              as "a future location [that] is planned but not
#                              yet available", pointing at docs/incidents/ for
#                              now. A forward reference the document itself
#                              labels as not-yet-existing.
#
# If one of these ever becomes real, delete its line — the check then starts
# verifying it like any other path.
KNOWN_ABSENT="Governance/DEPRECATED.md
Governance/charters/
Governance/incidents/"

broken=""
# The backticks in the pattern below are literal markdown backticks — the
# framework quotes every internal path as `Core/...` — not command
# substitution. Single quotes are exactly right; expansion is what must NOT
# happen here, so SC2016 is a false positive. The directive has to sit in front
# of the whole compound command, which is why it precedes the loop rather than
# the line it concerns.
# shellcheck disable=SC2016
while IFS= read -r ref; do
  if has_line "$KNOWN_ABSENT" "$ref"; then continue; fi
  [ -e "$ref" ] || broken="$broken$ref; "
done < <(grep -rhoE '`(Core|Standards|Employees|Workflows|Templates|Examples|Governance|Adapters|Registry|Prompts)/[A-Za-z0-9_/.-]*`' \
           --include='*.md' . | tr -d '`' | sort -u)

if [ -n "$broken" ]; then
  fail "documents reference paths that do not exist: $broken" "Governance/DEPRECATION_POLICY.md's Cross-Reference Check requires every reference to be updated or removed when its target moves."
else
  pass "every framework path referenced in prose resolves"
fi

# Bare filenames in Depends On lists resolve against the referring document's
# own directory.
broken_local=""
while IFS= read -r f; do
  while IFS= read -r ref; do
    if [ ! -e "$(dirname "$f")/$ref" ] && [ ! -e "$ref" ]; then
      broken_local="$broken_local$f -> $ref; "
    fi
  done < <(sed -n '/^Depends On:/,/^Referenced By:/p' "$f" \
            | grep -oE '^- [A-Za-z0-9_.-]+\.md$' | sed 's/^- //')
done < <(find Core Standards Workflows Templates Governance Employees -name '*.md')

if [ -n "$broken_local" ]; then
  fail "Depends On entries that resolve nowhere: $broken_local" "A bare filename in Depends On is read relative to the referring document's directory."
else
  pass "every Depends On entry resolves"
fi

# README.md and CLAUDE.md both print the repository's top-level layout. Both
# were missing Registry/ after WU-IAENG-137 added it, and both had advertised
# Prompts/ since the first commit while it held only a placeholder — a
# directory a reader is told to expect is a directory that should exist.
# Compared in both directions: nothing listed that is absent, nothing present
# that goes unlisted.
TOP_DIRS="$(find . -maxdepth 1 -type d \
  -not -name '.' -not -name '.git' -not -name '.github' -not -name '.omc' -not -name '.claude' \
  | sed 's|^\./||' | sort)"

for doc in README.md CLAUDE.md; do
  # Each block lists one directory per line as "Name/" or "Name/  — description".
  listed="$(grep -oE '^[A-Z][A-Za-z]*/' "$doc" | tr -d '/' | sort -u)"
  if [ -z "$listed" ]; then
    fail "$doc has no recognisable repository-structure listing" "If its shape changed, update this check."
    continue
  fi
  missing="$(comm -23 <(printf '%s\n' "$TOP_DIRS") <(printf '%s\n' "$listed") | tr '\n' ' ')"
  phantom="$(comm -13 <(printf '%s\n' "$TOP_DIRS") <(printf '%s\n' "$listed") | tr '\n' ' ')"
  if [ -n "$missing" ]; then
    fail "$doc's structure listing omits directories that exist: $missing" "A reader following the listing would not know these are part of the framework."
  fi
  if [ -n "$phantom" ]; then
    fail "$doc lists directories that do not exist: $phantom" "A reader is told to expect these."
  fi
  if [ -z "$missing" ] && [ -z "$phantom" ]; then
    pass "$doc's structure listing matches the repository"
  fi
done

# ==========================================================================
section "10. Adapter / installed-copy parity"
# ==========================================================================
# This repository installs its own Adapters into .github/, making it the
# framework's first consumer. If the shipped Adapter and the installed copy
# drift, the repository stops testing what it distributes. Both sides are
# LF-normalized via .gitattributes, so a difference here is real content drift
# rather than a line-ending artifact.

check_parity() {
  local adapter="$1" installed="$2"
  if [ ! -f "$adapter" ]; then
    fail "$adapter is referenced as an Adapter but does not exist" ""
    return
  fi
  if [ ! -f "$installed" ]; then
    # Not every Adapter belongs in this repository: ci-build-test.yml and
    # ghcr-publish.yml target a bootstrapped application project, and this
    # repository ships no application to build or containerize.
    pass "$(basename "$adapter"): not installed in this repository (expected)"
    return
  fi
  if diff -q "$adapter" "$installed" > /dev/null 2>&1; then
    pass "$(basename "$adapter"): installed copy is identical"
  else
    fail "$adapter and $installed have drifted" "$(diff "$adapter" "$installed" | head -4 | tr '\n' ' ')"
  fi
}

for adapter in Adapters/github-actions/*.yml; do
  check_parity "$adapter" ".github/workflows/$(basename "$adapter")"
done

# The GitHub templates were outside this check until WU-IAENG-141, and both had
# in fact drifted: PULL_REQUEST_TEMPLATE.md differed from its Adapter on every
# line (a CRLF checkout, now fixed by .gitattributes), and ISSUE_TEMPLATE/ had
# simply never been installed here at all — the framework shipped
# Workflows/PROJECT_BOOTSTRAP.md Step 6's issue templates for other projects
# while not using them itself.
check_parity "Adapters/github/PULL_REQUEST_TEMPLATE.md" ".github/PULL_REQUEST_TEMPLATE.md"

for tmpl in Adapters/github/ISSUE_TEMPLATE/*; do
  [ -f "$tmpl" ] || continue
  base="$(basename "$tmpl")"
  # config.yml is deliberately not byte-identical: the Adapter ships OWNER/REPO
  # placeholders and instructs the adopting project to replace them. An
  # installed copy that still said OWNER/REPO would be the actual defect, so
  # what is checked here is that the substitution happened.
  if [ "$base" = "config.yml" ]; then
    if [ ! -f ".github/ISSUE_TEMPLATE/config.yml" ]; then
      pass "config.yml: not installed in this repository (expected)"
    elif grep -q 'OWNER/REPO' .github/ISSUE_TEMPLATE/config.yml; then
      fail ".github/ISSUE_TEMPLATE/config.yml still contains the OWNER/REPO placeholder" "The Adapter instructs the adopting project to replace it; an unreplaced placeholder points contributors at a repository that does not exist."
    else
      pass "config.yml: placeholders replaced with real values"
    fi
    continue
  fi
  check_parity "$tmpl" ".github/ISSUE_TEMPLATE/$base"
done

# ==========================================================================
section "11. Shipped scripts are executable in the index"
# ==========================================================================
# The file mode git records, not the mode on this machine.
#
# A Windows checkout does not carry the executable bit, so a script created
# there lands in the index as 100644 and is checked out non-executable on every
# Linux clone. For a git hook that is the worst possible failure shape: git
# skips a non-executable hook silently — no error, no output, the commit simply
# succeeds unvalidated.
#
# Every one of the eight shipped scripts was 100644 until WU-IAENG-150,
# including both git hooks, which have been in the repository since v0.0.9.
# Adapters/README.md's old install instructions ran `chmod +x` on the hooks,
# which masked it for them; setup-branch-protection.sh and
# setup-project-bootstrap.sh were documented as direct `./...` invocations with
# no chmod, so those could not have run at all on a fresh Linux clone. The bug
# surfaced only when this milestone's own CI job tested `-x` on a Linux runner.
#
# Checked here rather than left to install.sh's chmod, because a chmod at
# install time is a workaround: the mode belongs in the repository, so a clone
# is correct before anything is run.

if git rev-parse --git-dir > /dev/null 2>&1; then
  not_exec=""
  while IFS= read -r line; do
    mode="${line%% *}"
    path="${line#*$'\t'}"
    [ "$mode" = "100755" ] || not_exec="$not_exec$path ($mode); "
  done < <(git ls-files -s Adapters/git-hooks Adapters/scripts Adapters/ai-runtimes 2>/dev/null \
             | grep -E '\.sh$|git-hooks/[a-z-]+$')
  if [ -n "$not_exec" ]; then
    fail "shipped scripts are not executable in the git index: $not_exec" "Run 'git update-index --chmod=+x <path>'. A non-executable git hook is skipped by git without any error, so the commit lands unvalidated."
  else
    pass "every shipped script and hook is mode 100755 in the index"
  fi
else
  pass "not a git repository — index modes skipped"
fi

# ==========================================================================
section "12. Unresolved work markers in shipped code"
# ==========================================================================
# Adapters/ ships as executable code installed into other projects. A TODO left
# in it is not a note to ourselves — it is a step the adopting project silently
# does not get. This check exists because exactly that happened:
# setup-project-bootstrap.sh carried a TODO disabling its issue-template
# installation, gated on files that had already shipped in v0.0.10, so
# Workflows/PROJECT_BOOTSTRAP.md's Coverage Checklist could not be satisfied by
# running the very script it points to.
#
# What counts as a marker is its SYNTAX, not the bare word. Matching the word
# alone produced two false positives: this script, for naming the words it
# searches for, and setup-project-bootstrap.sh's header, for explaining in
# prose that a marker used to be there. False positives on every run train the
# reader to ignore this check, which is how a real marker gets missed.
#
# The pattern below therefore requires a marker word either to open a comment
# (immediately after the comment character) or to be followed by a colon or an
# opening parenthesis, which is how a scope is attached. A mid-sentence mention
# does neither. A bare mid-comment mention with no punctuation slips through;
# that is the accepted cost of a check whose warnings stay credible.
#
# Deliberately not restated here: an example of the syntax. Spelling one out is
# what made this comment self-matching in the first place — a checker's own
# documentation cannot contain specimens of what it searches for.
#
# One exemption, matched literally below: the adopter-facing placeholder in the
# Generic CI fallback, which exists precisely to be filled in by the project
# that installs it.

markers="$(grep -rnE '(#[[:space:]]*(TODO|FIXME|XXX|HACK)\b|\b(TODO|FIXME|XXX|HACK)[(:])' \
  Adapters/git-hooks Adapters/scripts Adapters/github-actions Adapters/ai-runtimes Registry 2>/dev/null \
  | grep -vF 'TODO(adopting project)' || true)"
if [ -n "$markers" ]; then
  fail "unresolved work markers in shipped Adapter code" "$(echo "$markers" | head -5 | tr '\n' ' ') — a TODO in an Adapter is a step the adopting project does not get."
else
  pass "no unresolved work markers in shipped Adapter code"
fi

# ==========================================================================
section "13. Registry: chains, workflows, Work Units"
# ==========================================================================
# Validated when present, so the Registry can grow one file at a time without
# this script hard-failing on the files not yet written.

if [ -f Registry/chains.yml ]; then
  bad_actors=""
  while IFS= read -r actor; do
    case "$actor" in
      "Main Agent"|"Director"|"Engineer") continue ;;
    esac
    roster_names | grep -qxF "$actor" || bad_actors="$bad_actors$actor; "
  done < <(grep -E '^ +- employee: ' Registry/chains.yml | sed 's/^ *- employee: //' | tr -d '\015' | sort -u)
  if [ -n "$bad_actors" ]; then
    fail "Registry/chains.yml names non-Employees: $bad_actors" "A chain step dispatches to a real Employee, or to the framework roles Main Agent / Director / Engineer. Core/MAIN_AGENT_CONDUCT.md's Dispatch Discipline is the reason: a step with no named Employee has no accountable owner."
  else
    pass "every chain step names a real Employee or framework role"
  fi

  missing_wf=""
  while IFS= read -r wf; do
    [ -f "$wf" ] || missing_wf="$missing_wf$wf; "
  done < <(grep -E '^ +workflow: ' Registry/chains.yml | sed 's/^ *workflow: //' | tr -d '\015' | sort -u)
  if [ -n "$missing_wf" ]; then
    fail "Registry/chains.yml references missing workflow documents: $missing_wf" "Each chain is governed by a Workflow document."
  else
    pass "every chain's workflow document exists"
  fi

  # Every named chain in Core/AGENT_CHAINS.md must appear, or a runtime reading
  # the Registry would silently not know a chain exists.
  while IFS= read -r chain; do
    grep -qF "name: $chain" Registry/chains.yml \
      || fail "Core/AGENT_CHAINS.md defines '$chain' but Registry/chains.yml has no entry" "A runtime reading the Registry would not know this chain exists."
  done < <(grep -oE '^# [A-Za-z]+ Chain$' Core/AGENT_CHAINS.md | sed 's/^# //')
  pass "Registry/chains.yml covers every named chain"
else
  pass "Registry/chains.yml not present (skipped)"
fi

if [ -f Registry/workflows.yml ]; then
  missing_doc=""
  while IFS= read -r wf; do
    [ -f "$wf" ] || missing_doc="$missing_doc$wf; "
  done < <(grep -E '^    file: ' Registry/workflows.yml | sed 's/^    file: //' | tr -d '\015')
  if [ -n "$missing_doc" ]; then
    fail "Registry/workflows.yml references missing documents: $missing_doc" ""
  else
    pass "every workflow entry points at a real document"
  fi

  for f in Workflows/*.md; do
    grep -qF "$f" Registry/workflows.yml \
      || fail "$f has no entry in Registry/workflows.yml" "A runtime reading the Registry would not know this Workflow exists."
  done
  pass "Registry/workflows.yml covers every Workflow document"

  # The declared step_count against the document's actual numbered headings.
  # This is the check that catches the most likely drift by far: a step added to
  # or removed from a Workflow document while the Registry keeps the old shape.
  # An entry claiming 10 steps for a document that now has 11 would leave
  # anything reading the Registry — including a gate lookup — one step short,
  # and every other check here would still pass.
  for f in Workflows/*.md; do
    declared="$(grep -A3 "file: $f" Registry/workflows.yml | grep -m1 'step_count:' \
                  | sed 's/.*step_count: //' | tr -d '\015')"
    actual="$(grep -cE '^## (Step|Ceremony) [0-9]+' "$f")"
    if [ -z "$declared" ]; then
      fail "Registry/workflows.yml declares no step_count for $f" ""
    elif [ "$declared" != "$actual" ]; then
      fail "Registry/workflows.yml says $f has $declared steps; the document has $actual" "The document is authoritative — update the registry entry, including its steps list and any gate step numbers, which shift when a step is inserted."
    else
      pass "$(basename "$f"): step_count $declared matches the document"
    fi
  done
else
  pass "Registry/workflows.yml not present (skipped)"
fi

if [ -f Registry/work-units.yml ]; then
  bad_id="$(grep -E '^  - id: ' Registry/work-units.yml | sed 's/^  - id: //' | tr -d '\015' \
    | grep -vE '^WU-[A-Za-z0-9]+-[0-9]+$' || true)"
  if [ -n "$bad_id" ]; then
    fail "Registry/work-units.yml has malformed IDs: $(echo "$bad_id" | tr '\n' ' ')" "Templates/WORK_UNIT.md defines the format as WU-[project]-[number]."
  else
    pass "every Work Unit ID matches WU-[project]-[number]"
  fi

  dupes="$(grep -E '^  - id: ' Registry/work-units.yml | sed 's/^  - id: //' | tr -d '\015' \
    | sort | uniq -d)"
  if [ -n "$dupes" ]; then
    fail "Registry/work-units.yml has duplicate IDs: $(echo "$dupes" | tr '\n' ' ')" "Templates/WORK_UNIT.md: IDs are unique per project."
  else
    pass "no duplicate Work Unit IDs"
  fi

  bad_owner=""
  while IFS= read -r owner; do
    roster_names | grep -qxF "$owner" || bad_owner="$bad_owner$owner; "
  done < <(grep -E '^    employee: ' Registry/work-units.yml | sed 's/^    employee: //' | tr -d '\015' | sort -u)
  if [ -n "$bad_owner" ]; then
    fail "Registry/work-units.yml credits non-Employees: $bad_owner" "A Work Unit's owner must be a real Employee, matching the 'Employee:' commit trailer the work landed under."
  else
    pass "every Work Unit credits a real Employee"
  fi
else
  pass "Registry/work-units.yml not present (skipped)"
fi

# ==========================================================================
printf '\n== Result\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '   %s checks passed.\n' "$CHECKS"
  exit 0
fi
printf '   %s of %s checks failed.\n' "$FAILURES" "$CHECKS"
echo "   Each failure names the authoritative document to fix. The Registry is"
echo "   derived; where the two disagree, the document wins (Registry/README.md)."
exit 1
