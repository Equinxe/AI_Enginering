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
# ======================================================================
# THE CONVENTION EVERY CHECK IN THIS FILE FOLLOWS — read before adding one
# ======================================================================
#
# 1. AN UNEVALUATED CONDITION IS A FAILURE, NOT A PASS.
#    If a check could not run — its input was missing, its directory moved,
#    its pattern matched nothing — it must say so. It must not report
#    success. "Nothing objected" is not "everything passed".
#
# 2. EXCEPTIONS ARE NAMED ALLOW-LISTS, NEVER FALL-THROUGHS.
#    When something is legitimately exempt, name the thing (see
#    KNOWN_ABSENT and NOT_INSTALLED_HERE below). Never express the
#    exemption as a property of absence itself, because that quietly
#    exempts everything else that goes missing later.
#
# 3. EVERY SET-ITERATING CHECK REPORTS ITS DENOMINATOR.
#    Carry a count, fail at zero, and print the count on the passing line.
#    A verdict drawn from an empty set is indistinguishable from a verdict
#    drawn from a complete one.
#
# 4. A CLAIM ABOUT HOW A MECHANISM BEHAVES IS A TESTABLE CLAIM.
#    What it selects, what it accepts, what it costs, which direction it
#    fails in — write the claim with the test that establishes it, or do
#    not write it.
#
#    When the mechanism chooses among alternatives, enumerate the
#    alternatives before testing. Two of three agreeing is not a result.
#    The case worth running is the one that would show the claim false,
#    not the one that would show it true.
#
#    Rules 1 to 3 constrain code. This one constrains the PROSE that
#    describes code — comments, Standards text, commit bodies — which is
#    why it cannot be mechanised the way the others were, and why it is
#    written here rather than implemented below.
#
#    Evidence, three reversals in one review, each a confirmed test that
#    stopped short of the falsifying case:
#      "tail -1 reads the trailer"   — a message with claims at BOTH ends
#                                      was never tried; it was a live bypass.
#      "splitting it buys nothing"   — contiguous and renamed were measured,
#                                      separated was not. Separated was the
#                                      incumbent, and it was the only one
#                                      that worked: 28 of 30 commits.
#      "a false FAIL, not a false PASS" — reasoned about, never run. It was
#                                      a false PASS on a release gate.

# ATTRIBUTION AND SCOPE. Rule 4 was proposed by the code review that found
# all three reversals above; the wording is theirs, kept because the version
# written from the incidents alone was scoped to failure direction and would
# have caught only the third. It is recorded here and in Adapters/README.md
# on the Main Agent's authority, neither being a Standard. Moving it into
# Core/ or Standards/ makes it a rule about how this framework's authors
# reason rather than how its checks behave, which is a Director decision
# under Governance/CONTRIBUTING.md Section 1 — and one the reviewer cannot
# settle, since endorsing a rule distilled from their own findings is the
# same actor on both sides.
#
# WHY THIS IS WRITTEN DOWN RATHER THAN LEFT AS TASTE. The Automation
# milestone found and fixed eleven checks that reported success without
# evaluating anything. Zero of them were found by reading the diff — three
# by this repository's own CI, six by code review, two by an audit after
# the pattern was named. FOUR were introduced by the fixes to earlier
# instances of the same defect.
#
# A defect class that reproduces inside its own remediation is not a set of
# oversights. It is the default reasserting itself, because writing `pass`
# is the path of least resistance whenever a condition turns out to be
# inapplicable. Fixing the twelfth instance does not make the thirteenth
# less likely; stating the rule does.
#
# All four rules apply to Adapters/scripts/install.sh,
# Adapters/scripts/release.sh, Adapters/scripts/setup-project-bootstrap.sh,
# Adapters/ai-runtimes/generate-agents.sh, and the CI jobs in
# Adapters/github-actions/ — a caller that discards a check's exit status
# breaks rule 1 just as surely as a check that never ran.
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

# Byte ordering, not locale ordering, for every glob expansion, `sort`, and
# `comm` in this script.
#
# This is not a style preference. --regenerate-roster writes a COMMITTED file,
# and glob order decides the order of its entries. Under Git Bash on Windows
# the collation is locale-aware and puts ML_ENGINEER.md before
# MLOPS_ENGINEER.md, because it discounts the underscore; under C collation on
# a Linux runner MLOPS_ENGINEER.md comes first, because 'O' (0x4F) sorts before
# '_' (0x5F). The roster was therefore reproducible only on the platform that
# generated it, and CI's "regeneration must be a no-op" step failed on the
# runner while passing locally — which is exactly the check earning its place.
#
# Pinning the locale makes the generated artifact identical everywhere.
export LC_ALL=C

VERBOSE=0
REGENERATE=0

for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --regenerate-roster) REGENERATE=1 ;;
    --help|-h)
      sed -n '2,109p' "$0"
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

# Standards First is the root of the hierarchy CLAUDE.md draws and the one
# Standard that decides how every other is applied — official standard first,
# project convention second. Every Employee's Standards Applied section is
# expected to open with it; two did not, and nothing said so for eleven
# versions. The other Standards are deliberately NOT checked this way: the
# section is a per-role reading aid, not an exhaustive list (Git Standard
# appears in none of the 42), and Core/AGENT_CONDUCT.md is where the
# universally-binding ones are stated instead.
missing_sf=""
sf_checked=0
for f in Employees/*/*.md; do
  sf_checked=$((sf_checked + 1))
  # ANCHORED REGEX, NOT `grep -qxF '- Standards First'`. The list item begins
  # with a hyphen, so as a bare pattern grep reads it as an option bundle and
  # exits 2 with "unknown option" on every file — which this check reported as
  # all 42 Employees failing, the first time it ran, while the same grep in a
  # shell had just found all 42. A pattern that starts with `-` needs either
  # `--` before it or an anchor in front of the hyphen; the anchor is used
  # here because it also pins the item to the start of its line.
  # `\r?$` guards a CRLF checkout, as the roster readers do (Registry/README.md).
  grep -qE '^- Standards First\r?$' "$f" || missing_sf="$missing_sf$(basename "$f"); "
done
if [ "$sf_checked" -eq 0 ]; then
  fail "no Employee definitions found under Employees/*/*.md" "The glob matched nothing, so this check verified nothing. An empty input set is not a pass."
elif [ -n "$missing_sf" ]; then
  fail "Employees whose Standards Applied omits Standards First: $missing_sf" "Standards/STANDARDS_FIRST.md is the root of the hierarchy in CLAUDE.md; every Employee applies it. Add '- Standards First' to the Standards Applied section."
else
  pass "all $sf_checked Employees list Standards First"
fi

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
# Zero inspected documents is not "all documents passed".
#
# This and the three checks below all derived their verdict from a set that
# could be empty — a wrong working directory, a renamed directory, or a
# changed documentation convention yields no input, every per-item loop is
# skipped, and the summary line reports success. Same shape as the git-less
# index-mode pass and the blind marker scan, one consequence level down: none
# of these is currently the sole guard over a critical property, but the
# mechanism is identical and it is why this class kept recurring.
#
# Carrying the count also makes --verbose state what was actually verified
# rather than only that nothing objected.
if [ "$META_COUNT" -eq 0 ]; then
  fail "metadata check inspected 0 governed documents" "The globs (Core/*.md, Standards/*.md, Workflows/*.md, Templates/*.md, Governance/*.md, Employees/*/*.md) matched nothing. Either the run is in the wrong directory or a directory was renamed — an empty input set is not a passing check."
else
  pass "metadata fields checked across $META_COUNT governed documents"
fi

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
refs_checked=0
# shellcheck disable=SC2016
while IFS= read -r ref; do
  if has_line "$KNOWN_ABSENT" "$ref"; then continue; fi
  refs_checked=$((refs_checked + 1))
  [ -e "$ref" ] || broken="$broken$ref; "
#
# CHANGELOG.md is excluded, and the reason is categorical rather than
# convenient. A changelog describes the repository as it was at each version,
# so it necessarily names paths that no longer exist: renames, deletions, and
# superseded locations are the substance of the entries. Its v0.0.7.1 entry
# reads "`Core/GLOSSARY.MD` renamed to `Core/GLOSSARY.md` — fixes broken
# references on case-sensitive filesystems", and the pre-rename name is the
# whole point of that sentence — rewriting history to satisfy a link checker
# would destroy the record. Requiring a historical document's paths to resolve
# against the present tree is a category error.
#
# This was found by CI, not locally: Windows resolves Core/GLOSSARY.MD against
# Core/GLOSSARY.md on a case-insensitive filesystem, so the check passed on the
# authoring machine and failed only on the Linux runner.
done < <(grep -rhoE '`(Core|Standards|Employees|Workflows|Templates|Examples|Governance|Adapters|Registry|Prompts)/[A-Za-z0-9_/.-]*`' \
           --include='*.md' --exclude='CHANGELOG.md' . | tr -d '`' | sort -u)

if [ -n "$broken" ]; then
  fail "documents reference paths that do not exist: $broken" "Governance/DEPRECATION_POLICY.md's Cross-Reference Check requires every reference to be updated or removed when its target moves."
elif [ "$refs_checked" -eq 0 ]; then
  fail "the cross-reference scan resolved 0 paths" "The pattern matches backtick-quoted paths under a hand-maintained list of top-level directories. Zero matches means the documentation convention changed, or a new top-level directory was added to the repository but not to that list — either way nothing was checked, which is not the same as everything passing."
else
  pass "every framework path referenced in prose resolves ($refs_checked checked)"
fi

# Bare filenames in Depends On lists resolve against the referring document's
# own directory.
broken_local=""
deps_checked=0
while IFS= read -r f; do
  while IFS= read -r ref; do
    deps_checked=$((deps_checked + 1))
    if [ ! -e "$(dirname "$f")/$ref" ] && [ ! -e "$ref" ]; then
      broken_local="$broken_local$f -> $ref; "
    fi
  done < <(sed -n '/^Depends On:/,/^Referenced By:/p' "$f" \
            | grep -oE '^- [A-Za-z0-9_.-]+\.md$' | sed 's/^- //')
done < <(find Core Standards Workflows Templates Governance Employees -name '*.md')

if [ -n "$broken_local" ]; then
  fail "Depends On entries that resolve nowhere: $broken_local" "A bare filename in Depends On is read relative to the referring document's directory."
elif [ "$deps_checked" -eq 0 ]; then
  fail "the Depends On scan resolved 0 entries" "The extraction is a sed range between the literal headings 'Depends On:' and 'Referenced By:'. Renaming either heading collapses the range to nothing, and no entry is checked at all — reported here rather than passing silently."
else
  pass "every Depends On entry resolves ($deps_checked checked)"
fi

# README.md and CLAUDE.md both print the repository's top-level layout. Both
# were missing Registry/ after WU-IAENG-137 added it, and both had advertised
# Prompts/ since the first commit while it held only a placeholder — a
# directory a reader is told to expect is a directory that should exist.
# Compared in both directions: nothing listed that is absent, nothing present
# that goes unlisted.
# TRACKED content, not the filesystem.
#
# The first version listed directories with `find`, so any untracked
# top-level directory — a scratch folder, a build output, a local clone of
# something — produced two failures about a documentation listing it has no
# business appearing in. Reproduced: creating an empty `scratch_probe/`
# failed both README.md and CLAUDE.md.
#
# That is the kind of false positive rule 4's neighbours exist to prevent. It
# does not reduce coverage — a directory nobody committed is not part of the
# framework — but it erodes the check's credibility, and a check whose
# failures are routinely irrelevant is one people learn to skip.
#
# The git-less fallback keeps the old behaviour rather than skipping, because
# a copied reference has no index and the listing is still worth checking
# there; it is only in a working checkout that untracked noise exists.
# Dot-directories are excluded in both branches. `.github` is tracked, so the
# tracked listing surfaces it, but it holds this repository's installed copies
# of the Adapters rather than framework content — README.md and CLAUDE.md
# describe what the framework IS, and no reader expects `.github` in that list.
# Omitting the exclusion swapped one false positive for another: the first
# version of this fix flagged `.github` on every run, which is the same defect
# it was written to remove.
if git rev-parse --git-dir > /dev/null 2>&1; then
  TOP_DIRS="$(git ls-files | awk -F/ 'NF > 1 && $1 !~ /^\./ { print $1 }' | sort -u)"
else
  TOP_DIRS="$(find . -maxdepth 1 -type d \
    -not -name '.' -not -name '.git' -not -name '.github' -not -name '.omc' -not -name '.claude' \
    | sed 's|^\./||' | sort)"
fi

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

# Adapters deliberately NOT installed in this repository, named individually
# with the reason each is exempt.
#
# The previous version expressed this as a property of ABSENCE rather than of
# these two files: any missing installed copy reported
# "not installed in this repository (expected)" as a pass. So deleting
# .github/workflows/pr-validation.yml produced a green tick on a check called
# "Adapter / installed-copy parity" — verified before this change. The
# rationale in that comment was right about ci-build-test.yml and
# ghcr-publish.yml and wrong to generalise from them.
#
# Adding an Adapter that this repository should not install means adding it
# here, deliberately, with a reason. Anything else absent is a failure.
NOT_INSTALLED_HERE="ci-build-test.yml
ghcr-publish.yml"

check_parity() {
  local adapter="$1" installed="$2" base
  base="$(basename "$adapter")"

  if [ ! -f "$adapter" ]; then
    fail "$adapter is referenced as an Adapter but does not exist" ""
    return
  fi

  if [ ! -f "$installed" ]; then
    if has_line "$NOT_INSTALLED_HERE" "$base"; then
      # These two target a bootstrapped application project, and this
      # repository ships no application to build or containerize.
      pass "$base: not installed here, by design"
    else
      fail "$base is shipped as an Adapter but $installed is missing" "This repository installs its own Adapters, which is what makes it their first consumer. A missing installed copy means it has stopped testing what it distributes. If this Adapter genuinely should not be installed here, add it to NOT_INSTALLED_HERE with a reason rather than letting its absence read as a pass."
    fi
    return
  fi
  if diff -q "$adapter" "$installed" > /dev/null 2>&1; then
    pass "$base: installed copy is identical"
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
  # NOT a pass, and not counted as a check.
  #
  # A git-less tree is a supported import shape, not a corner case:
  # Workflows/ONBOARDING.md Step 1 and install.sh both name "submodule, copied
  # reference, or linked documentation directory", and a copied reference —
  # extracted from a release tarball or a zip — carries no index of its own.
  # That is precisely the shape in which the executable bit is most likely to
  # have been lost in transit, so reporting `pass` here announced success in
  # the one deployment where this check matters most. It was the only guard
  # standing over WU-IAENG-150, and it was blind exactly where the risk lives.
  #
  # "Cannot evaluate" is genuinely not a defect in the tree being checked, so
  # failing would be wrong too. It is reported as an unevaluated condition and
  # left out of the CHECKS tally, because a total that counts a check nobody
  # ran overstates what was verified.
  printf '   --    index modes not evaluated: no git repository here\n'
  printf '         A copied reference or extracted tarball has no index, and\n'
  printf '         this is the shape where the executable bit is most often\n'
  printf '         lost. Verify from a git checkout, or check the modes by\n'
  printf '         hand: ls -l Adapters/git-hooks Adapters/scripts\n'
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::warning::Index file modes were not evaluated — no git repository. Run this from a git checkout to verify the executable bit on shipped scripts."
  fi
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

# The scan roots are asserted to exist BEFORE scanning, and stderr is not
# discarded.
#
# An earlier version passed the roots straight to `grep -r ... 2>/dev/null ||
# true`. That swallowed "No such file or directory" for a renamed or mistyped
# path, and an empty result is indistinguishable from a clean one — so the
# check reported success while scanning nothing. Demonstrated: renaming
# Adapters/ai-runtimes to Adapters/runtimes and adding a genuine unfinished
# marker to a script inside it produced "no unresolved work markers in shipped
# Adapter code". The run only went red because a different check noticed the
# now-dangling documented path; a rename that also updated the references
# would have left this check permanently blind and permanently green.
#
# This section's own comment argues that a marker in shipped Adapter code is a
# step the adopting project silently does not get. A scan that silently
# inspects nothing is the same defect one level up.
MARKER_ROOTS=(
  Adapters/git-hooks
  Adapters/scripts
  Adapters/github-actions
  Adapters/ai-runtimes
  Registry
)

missing_roots=""
present_roots=()
for root in "${MARKER_ROOTS[@]}"; do
  if [ -d "$root" ]; then
    present_roots+=("$root")
  else
    missing_roots="$missing_roots$root; "
  fi
done

if [ -n "$missing_roots" ]; then
  fail "work-marker scan roots do not exist: $missing_roots" "The scan cannot report a clean result for a directory it never read. If these paths moved, update this list; if they were removed, remove them from it deliberately."
fi

# Scanning only the roots that exist, so the failure above is the single report
# of a missing path rather than that failure plus a raw grep error. Guarded
# against an empty array, which `set -u` would otherwise reject.
if [ "${#present_roots[@]}" -eq 0 ]; then
  markers=""
else
  markers="$(grep -rnE '(#[[:space:]]*(TODO|FIXME|XXX|HACK)\b|\b(TODO|FIXME|XXX|HACK)[(:])' \
    "${present_roots[@]}" \
    | grep -vF 'TODO(adopting project)' || true)"
fi
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
  actors_checked=0
  while IFS= read -r actor; do
    actors_checked=$((actors_checked + 1))
    case "$actor" in
      "Main Agent"|"Director"|"Engineer") continue ;;
    esac
    roster_names | grep -qxF "$actor" || bad_actors="$bad_actors$actor; "
  done < <(grep -E '^ +- employee: ' Registry/chains.yml | sed 's/^ *- employee: //' | tr -d '\015' | sort -u)
  if [ -n "$bad_actors" ]; then
    fail "Registry/chains.yml names non-Employees: $bad_actors" "A chain step dispatches to a real Employee, or to the framework roles Main Agent / Director / Engineer. Core/MAIN_AGENT_CONDUCT.md's Dispatch Discipline is the reason: a step with no named Employee has no accountable owner."
  elif [ "$actors_checked" -eq 0 ]; then
    fail "Registry/chains.yml yielded 0 chain actors" "The extraction is an indentation-sensitive grep for '      - employee: '. Zero matches means the file was reformatted and the consumer reads nothing — section 1 enforces a parsing contract for employees.yml only, so nothing else would have caught this."
  else
    pass "every chain step names a real Employee or framework role ($actors_checked checked)"
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
  # Multi-word chain names included. The earlier pattern was
  # `^# [A-Za-z]+ Chain$` — single word only — so a chain named e.g.
  # "Incident Response Chain" would never have been extracted, and its failure
  # branch was unreachable. That matters because Core/AGENT_CHAINS.md's
  # "Machine-Readable Form" section promises in those words that "a seventh
  # chain added here without a Registry entry fails the build". The checker
  # could not keep that guarantee for any multi-word name, which is a document
  # making a claim its mechanism does not support.
  #
  # `Chain$` is singular and anchored, so the document's own structural
  # headings do not collide today: "Agent Chains" and "Composing Custom
  # Chains" are plural, "Chain Selection" and "Chain Conventions" do not end
  # in the word. They are excluded by name anyway rather than by relying on
  # that, since a future heading like "# Custom Chain" would otherwise be read
  # as a chain.
  done < <(grep -oE '^# [A-Za-z][A-Za-z ]*Chain$' Core/AGENT_CHAINS.md \
             | sed 's/^# //' \
             | grep -vxE 'Chain Selection|Chain Conventions|Composing Custom Chain')
  pass "Registry/chains.yml covers every named chain"
else
  fail "Registry/chains.yml is missing" "It existed as of WU-IAENG-145 and Registry/README.md lists its consumers. Reporting a pass for an absent file is the same silent-skip shape as a gate that skips itself — if the Registry genuinely no longer carries chains, remove this check deliberately rather than letting a deletion look like a success."
fi

if [ -f Registry/workflows.yml ]; then
  missing_doc=""
  wf_entries=0
  while IFS= read -r wf; do
    wf_entries=$((wf_entries + 1))
    [ -f "$wf" ] || missing_doc="$missing_doc$wf; "
  done < <(grep -E '^    file: ' Registry/workflows.yml | sed 's/^    file: //' | tr -d '\015')
  if [ -n "$missing_doc" ]; then
    fail "Registry/workflows.yml references missing documents: $missing_doc" ""
  elif [ "$wf_entries" -eq 0 ]; then
    fail "Registry/workflows.yml yielded 0 workflow entries" "The extraction is an indentation-sensitive grep for '    file: '. Zero matches means the file was reformatted and every consumer reads nothing from it, including the gate lookups — reported here rather than passing."
  else
    pass "every workflow entry points at a real document ($wf_entries checked)"
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
  fail "Registry/workflows.yml is missing" "It existed as of WU-IAENG-145. The gate positions recorded there are what makes Core/MAIN_AGENT_CONDUCT.md's autonomy-between-gates rule mechanically answerable; an absent file cannot be reported as a pass."
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
  fail "Registry/work-units.yml is missing" "It existed as of WU-IAENG-146, and the Work Unit Exists CI job resolves every referenced ID against it. Without it that required check fails closed, so this cannot be a pass here."
fi

# ==========================================================================
section "14. VERSION.md inventory vs. the repository"
# ==========================================================================
# VERSION.md lists, by name, every Standard, Workflow, and Template the
# framework contains. Section 3 already checks the ONE number that was
# historically wrong (the roster size); these lists are the same fact in a
# longer form, and they drifted the same way — at the point this check was
# written VERSION.md claimed 8 Standards of 10, 9 Workflows of 10, and 7
# Templates of 11.
#
# Governance/TROUBLESHOOTING.md names the class (entry N): a literal count or
# list in prose is a second copy of a fact, and two copies drift. The remedy it
# prescribes is to derive rather than restate, so the comparison is made
# against the documents themselves.
#
# The name of a document is its H1, minus the category suffix the file itself
# carries ("Feature Development Workflow" -> "Feature Development"). That is a
# rule, not a lookup table: an exception list here would be the fall-through
# the Check Convention forbids, and would need an entry every time a document
# is added — which is the maintenance burden this check exists to remove.

check_inventory() {
  local dir="$1" heading="$2" suffix="$3"
  local real listed declared real_count listed_count missing extra title f
  local suffix_note=""

  # Built plainly rather than inline in the message. An inline
  # ${suffix:+... '$suffix'} expands correctly but reads to shellcheck as a
  # single-quoted expression (SC2016), and the fix for a finding is never a
  # directive — Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression.
  if [ -n "$suffix" ]; then
    suffix_note=", minus the trailing category word $suffix"
  fi

  if ! grep -qE "^### $heading( \([0-9]+\))?\$" VERSION.md; then
    fail "VERSION.md has no '### $heading' section" "It lists every $dir document by name; a missing section cannot be checked and is not a pass. Restore the section or update this check deliberately."
    return
  fi

  # TRACKED **AND** PRESENT-BUT-UNTRACKED. Enumerating only tracked files
  # meant a contributor who added Standards/NEW.md and ran the validator
  # before staging got a pass, and discovered the inventory gap in CI instead
  # — or, on this branch, discovered it because the author happened to stage
  # first. Untracked-and-ignored files stay out, via --exclude-standard.
  real=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    title="$(head -1 "$f" | sed 's/^# //' | tr -d '\015')"
    if [ -n "$suffix" ]; then title="${title% "$suffix"}"; fi
    real="$real$title
"
  done < <( { git ls-files "$dir/*.md"; git ls-files --others --exclude-standard "$dir/*.md"; } | sort -u)

  listed="$(awk -v want="$heading" '
    $0 ~ "^### " want "( \\([0-9]+\\))?$" { inside = 1; next }
    inside && /^#+ / { inside = 0 }
    inside && /^- \[x\] / { sub(/^- \[x\] /, ""); sub(/\015$/, ""); print }
  ' VERSION.md)"

  real_count="$(printf '%s' "$real" | grep -c .)"
  listed_count="$(printf '%s\n' "$listed" | grep -c .)"

  if [ "$real_count" -eq 0 ]; then
    fail "no documents found under $dir/" "The inventory check has nothing to compare against. Either the directory was renamed or the glob is wrong — an empty input set is not a passing check."
    return
  fi
  if [ "$listed_count" -eq 0 ]; then
    fail "VERSION.md's '### $heading' section lists no '- [x]' items" "$real_count documents exist under $dir/. A section that enumerates nothing cannot be compared, so it fails rather than passing silently."
    return
  fi

  missing=""; extra=""
  while IFS= read -r title; do
    [ -n "$title" ] || continue
    has_line "$listed" "$title" || missing="$missing$title; "
  done < <(printf '%s' "$real")
  while IFS= read -r title; do
    [ -n "$title" ] || continue
    has_line "$real" "$title" || extra="$extra$title; "
  done < <(printf '%s\n' "$listed")

  if [ -n "$missing" ]; then
    fail "VERSION.md's $heading list is missing: $missing" "Every document under $dir/ is listed there by its H1 title$suffix_note. Governance/CONTRIBUTING.md requires the inventory updated in the same Work Unit that adds the document."
  fi
  if [ -n "$extra" ]; then
    fail "VERSION.md's $heading list names documents that do not exist: $extra" "The list is compared against the H1 title of every tracked file under $dir/. Either the document was removed without updating VERSION.md, or its title changed."
  fi

  # A title listed TWICE produces neither a missing nor an extra — set
  # membership holds in both directions while the list is still wrong. The
  # counts are what catch it, which is why listed_count is compared rather
  # than merely printed.
  dupes="$(printf '%s\n' "$listed" | grep -v '^$' | sort | uniq -d | tr '\n' '|' | sed 's/|$//')"
  if [ -n "$dupes" ]; then
    fail "VERSION.md's $heading list names the same document more than once: $dupes" "Each document appears once. Duplicates keep the set comparison happy while the list stays wrong."
  elif [ "$listed_count" -ne "$real_count" ]; then
    fail "VERSION.md's $heading list has $listed_count entries but $real_count documents exist under $dir/" "The names all match, so this is a counting difference the membership comparison cannot see."
  fi

  # The parenthesised count is a third copy of the same fact. Checked only when
  # present: '### Standards' carries no count and is not required to grow one.
  declared="$(grep -oE "^### $heading \([0-9]+\)\$" VERSION.md | grep -oE '[0-9]+' | head -1)"
  if [ -n "$declared" ] && [ "$declared" -ne "$real_count" ]; then
    fail "VERSION.md says '$heading ($declared)' but $real_count exist under $dir/" "Update the heading in the same Work Unit as the document."
  fi

  if [ -z "$missing" ] && [ -z "$extra" ] && [ -z "$dupes" ] && [ "$listed_count" -eq "$real_count" ] \
     && { [ -z "$declared" ] || [ "$declared" -eq "$real_count" ]; }; then
    pass "VERSION.md lists all $real_count $heading, by name${declared:+, and the heading count agrees}"
  fi
}

# Standards are listed under their full title ("Git Standard"); Workflows and
# Templates under their title minus the category word the file's own H1 carries
# ("Feature Development Workflow" -> "Feature Development"). The suffix is a
# parameter rather than a guess, so a directory whose documents do not carry
# one passes "" and nothing is stripped.
check_inventory Standards Standards ""
check_inventory Workflows Workflows Workflow
check_inventory Templates Templates Template

# ==========================================================================
section "15. Glossary ordering"
# ==========================================================================
# Core/GLOSSARY.md states that its letter sections and the terms within them
# are in alphabetical order. A document that claims a property the tooling does
# not check is a claim nobody verifies — the shape this milestone spent its
# time removing — so the claim is checked here.
#
# Three questions, each answerable and each reported: are the letter headings
# ascending, is every term under the letter it starts with, and are the terms
# within each letter ascending. Byte order (LC_ALL=C, pinned at the top of this
# script) so the answer does not depend on the machine's locale.

GLOSSARY="Core/GLOSSARY.md"
if [ ! -f "$GLOSSARY" ]; then
  fail "$GLOSSARY is missing" "CLAUDE.md lists it as a Core document and every artifact is required to use its vocabulary. Its absence cannot be a pass."
else
  # \r? and tr -d '\015' throughout: the rest of this script guards a CRLF
  # checkout and section 15 did not. Git Bash's awk happens to strip the
  # carriage return, so the omission was latent here and would have reported
  # every term misfiled under a POSIX awk on a CRLF working tree.
  glossary_letters="$(grep -E '^# [A-Z]\r?$' "$GLOSSARY" | sed 's/^# //' | tr -d '\015')"
  letter_count="$(printf '%s\n' "$glossary_letters" | grep -c .)"
  term_count="$(grep -cE '^## ' "$GLOSSARY")"

  if [ "$letter_count" -eq 0 ] || [ "$term_count" -eq 0 ]; then
    fail "$GLOSSARY yielded $letter_count letter section(s) and $term_count term(s)" "The extraction reads '# X' letter headings and '## Term' entries. Zero of either means the document was restructured and this check now reads nothing — reported rather than passed."
  else
    if [ "$glossary_letters" != "$(printf '%s\n' "$glossary_letters" | sort)" ]; then
      fail "$GLOSSARY letter sections are not in alphabetical order: $(printf '%s' "$glossary_letters" | tr '\n' ' ')" "The document says they are. Reorder the sections, or change the claim."
    else
      pass "$GLOSSARY: $letter_count letter sections in alphabetical order"
    fi

    # Walk the document once, carrying the current letter, so a term can be
    # checked against the section it is actually in.
    misfiled="$(awk '
      /^# [A-Z]\r?$/ { letter = substr($0, 3, 1); next }
      /^## / {
        term = substr($0, 4)
        sub(/\015$/, "", term)
        initial = toupper(substr(term, 1, 1))
        if (letter == "") { print term " (before any letter section)"; next }
        if (initial != letter) { print term " (under " letter ")" }
      }
    ' "$GLOSSARY" | sed 's/$/;/' | tr '\n' ' ')"
    # sed then tr, not `tr '\n' '; '`: tr truncates the replacement set to the
    # length of the source set, so the intended separator silently lost its
    # space. Cosmetic, in a failure message — and exactly the kind of thing
    # that is only ever noticed when the message finally fires.
    if [ -n "$misfiled" ]; then
      fail "$GLOSSARY has terms filed under the wrong letter: $misfiled" "A term belongs under its own initial, or the glossary cannot be scanned."
    else
      pass "$GLOSSARY: all $term_count terms are under their own initial"
    fi

    unsorted=""
    while IFS= read -r letter; do
      [ -n "$letter" ] || continue
      terms="$(awk -v want="# $letter" '
        { line = $0; sub(/\015$/, "", line) }
        line == want { inside = 1; next }
        inside && /^# / { exit }
        inside && /^## / { t = substr(line, 4); print t }
      ' "$GLOSSARY")"
      if [ "$terms" != "$(printf '%s\n' "$terms" | sort)" ]; then
        unsorted="$unsorted$letter "
      fi
    done < <(printf '%s\n' "$glossary_letters")
    if [ -n "$unsorted" ]; then
      fail "$GLOSSARY terms are not alphabetical within section(s): $unsorted" "The document says they are."
    else
      pass "$GLOSSARY: terms are alphabetical within each of the $letter_count sections"
    fi
  fi
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
