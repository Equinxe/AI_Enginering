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
      sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}'
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
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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
# RESOLVED AGAINST TRACKED CONTENT, CASE-EXACTLY — not with `[ -e ]`.
#
# `-e` asks the filesystem, and Windows answers case-insensitively, so a
# reference to Core/GLOSSARY.MD resolved against Core/GLOSSARY.md on the
# authoring machine and failed only on the Linux runner. That is the incident
# in Governance/TROUBLESHOOTING.md entry F, whose remedy line used to claim
# this check already resolved against tracked content. It did not; the WU-151
# fix was the CHANGELOG exclusion below, and the case-sensitivity half was
# never done. It is done here, so a local run and CI answer the same question.
#
# A reference may name a directory, which `git ls-files` does not list, so a
# path also resolves when some tracked file lies beneath it.
TRACKED_PATHS="$(git ls-files)"
resolves() {
  local p="${1%/}"
  has_line "$TRACKED_PATHS" "$p" && return 0
  # Here-string, not a pipe: awk exits at its first hit, and the producer on the
  # other end of a pipe would take SIGPIPE and fail the pipeline under pipefail.
  awk -v pre="$p/" 'index($0, pre) == 1 { found = 1; exit } END { exit !found }' <<< "$TRACKED_PATHS"
}

# The backtick that delimits a quoted path is held in a variable so the grep
# pattern can be double-quoted. Written literally it needed single quotes,
# which made shellcheck read it as an unexpanded expression (SC2016) and
# required a suppression directive — and that directive then had to sit
# immediately before the compound command, which made it fragile: inserting
# the resolver above pushed it away from the loop and the finding came back.
# Restructuring so the rule is satisfied is what
# Standards/CODE_QUALITY_STANDARD.md asks for before a directive is
# considered, and here it costs one variable.
BT='`'
REF_PATTERN="${BT}(Core|Standards|Employees|Workflows|Templates|Examples|Governance|Adapters|Registry|Prompts)/[A-Za-z0-9_/.-]*${BT}"

refs_checked=0
while IFS= read -r ref; do
  if has_line "$KNOWN_ABSENT" "$ref"; then continue; fi
  refs_checked=$((refs_checked + 1))
  resolves "$ref" || broken="$broken$ref; "
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
#
# TROUBLESHOOTING.md is excluded for the same categorical reason as
# CHANGELOG.md, and the reason is visible in the failure that added it: entry
# F's symptom line quotes `Core/GLOSSARY.MD` because that broken path IS the
# incident. An incident catalog names paths that were wrong — that is what it
# is for — exactly as a changelog names paths that were renamed. Requiring
# either document's paths to resolve against the present tree is a category
# error, and rewriting them to satisfy a link checker would destroy the record.
#
# THE SCAN READS TRACKED FILES, not the working tree. `grep -r .` walked
# everything present, including gitignored local notes — the moment
# .ia-engineering/SESSION_STATE.md mentioned this very incident by name, the
# validator failed on the author's machine and could not have failed in CI,
# where that file does not exist. A check whose result depends on untracked
# scratch is a check that cannot be trusted either way.
#
# Section 14 deliberately does the opposite and includes untracked files,
# because there an unstaged NEW document is exactly the omission to report.
# The difference is the subject: that check asks "is the inventory complete",
# this one asks "does the committed corpus hang together".
#
# The changelog fragments, changelog.d/WU-*.md, are excluded for CHANGELOG.md's
# reason: each is a CHANGELOG.md entry waiting for the version bump, and an
# entry about a rename names the old path. Checking a fragment today would
# fail the same sentence that passes once release.sh assemble has moved it
# into CHANGELOG.md. changelog.d/README.md is not an entry, and stays checked.
done < <(git ls-files '*.md' \
           | grep -v -e '^CHANGELOG\.md$' -e '/TROUBLESHOOTING\.md$' -e '^changelog\.d/WU-' \
           | xargs -r grep -hoE "$REF_PATTERN" \
           | tr -d "$BT" | sort -u)

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
#
# changelog.d/ is excluded by name, for the same reason: it holds the pending
# entries of CHANGELOG.md (section 23), release bookkeeping beside a file the
# listing does not name either, not a part of the framework a reader adopts.
if git rev-parse --git-dir > /dev/null 2>&1; then
  TOP_DIRS="$(git ls-files | awk -F/ 'NF > 1 && $1 !~ /^\./ && $1 != "changelog.d" { print $1 }' | sort -u)"
else
  TOP_DIRS="$(find . -maxdepth 1 -type d \
    -not -name '.' -not -name '.git' -not -name '.github' -not -name '.omc' -not -name '.claude' -not -name 'changelog.d' \
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

  # AN INSTALLED COPY MUST BE MARKED DERIVED, or every change to the pair costs
  # double against the review limit.
  #
  # Standards/PULL_REQUEST_STANDARD.md puts that limit on "the lines a reviewer
  # must READ", and the two files above are byte-identical by the check that
  # just ran — nobody reads them twice. Measured on the change set that exposed
  # this: 1,274 of 2,618 lines were the same 637 counted once per copy, and
  # PR Size refused a change that was near the limit rather than well over it.
  # The effect is perverse: keeping the installed copy in sync, which is the
  # correct habit, was the thing being penalised.
  #
  # Checked rather than left to whoever adds the next Adapter, because the
  # failure is silent: a new pair simply starts costing double and nothing says
  # so. `git check-attr` is asked, so what is verified is the attribute git
  # actually resolves rather than the presence of a line in a file.
  local attr
  attr="$(git check-attr linguist-generated -- "$installed" 2>/dev/null | sed 's/.*: //')"
  if [ "$attr" = "set" ] || [ "$attr" = "true" ]; then
    pass "$base: installed copy is marked linguist-generated"
  else
    fail "$installed is not marked linguist-generated (git says: ${attr:-unreadable})" "It is byte-identical to $adapter, so a reviewer reads those lines once and PR Size counts them twice. Add '/$installed linguist-generated=true' to .gitattributes. Mark the INSTALLED copy, never the Adapter — the Adapter is the source and must stay reviewable."
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
# this script hard-failing on the files not yet written. Whether each chain's
# steps match its diagram in Core/AGENT_CHAINS.md is section 22.

if [ -f Registry/chains.yml ]; then
  bad_actors=""
  actors_checked=0
  roster_list="$(roster_names)"
  while IFS= read -r actor; do
    actors_checked=$((actors_checked + 1))
    case "$actor" in
      "Main Agent"|"Director"|"Engineer") continue ;;
    esac
    has_line "$roster_list" "$actor" || bad_actors="$bad_actors$actor; "
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
  #
  # Counted, and failed at zero (rule 3). The pass line used to print whatever
  # the loop saw, so an extraction that read no chain at all still claimed
  # coverage (issue #227). One measured way to read none: a CRLF checkout read
  # by a grep that keeps the carriage return, where "Chain$" never matches
  # "# Feature Chain\r". The CR is stripped before the match for that reason.
  chains_named=0
  chains_missing=0
  while IFS= read -r chain; do
    chains_named=$((chains_named + 1))
    if ! grep -qF "name: $chain" Registry/chains.yml; then
      chains_missing=$((chains_missing + 1))
      fail "Core/AGENT_CHAINS.md defines '$chain' but Registry/chains.yml has no entry" "A runtime reading the Registry would not know this chain exists."
    fi
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
  done < <(tr -d '\015' < Core/AGENT_CHAINS.md \
             | grep -oE '^# [A-Za-z][A-Za-z ]*Chain$' \
             | sed 's/^# //' \
             | grep -vxE 'Chain Selection|Chain Conventions|Composing Custom Chain')
  if [ "$chains_named" -eq 0 ]; then
    fail "Core/AGENT_CHAINS.md yielded 0 named chains" "The extraction reads '# <Name> Chain' headings. Zero means the document is missing, its headings changed form, or the read failed, so no chain was checked against Registry/chains.yml. That is reported, not passed."
  elif [ "$chains_missing" -eq 0 ]; then
    pass "Registry/chains.yml covers every named chain ($chains_named checked)"
  fi
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
  roster_list="$(roster_names)"
  while IFS= read -r owner; do
    has_line "$roster_list" "$owner" || bad_owner="$bad_owner$owner; "
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

section "16. Every shipped CHANGELOG version has a tag"

# ==========================================================================
# THIS SECTION EXISTS BECAUSE ITS ABSENCE COST TWO RELEASES.
#
# v0.0.11 — Governance merged to main on 24 July 2026 and was never tagged. It
# had a CHANGELOG section, VERSION.md announced it for six weeks, and no tag or
# GitHub Release existed. v0.0.9.1 has the same gap. The version that shipped
# untagged is the one whose own milestone delivered the rule requiring a full
# GitHub Release (WU-IAENG-131).
#
# Nothing checked it. This script passed 156 checks across 15 sections and
# never compared a CHANGELOG heading against a tag; release.sh only looks at
# the version being released. Governance/CONTRIBUTING.md Section 7: the second
# instance of a class names the class and writes the rule, and a rule that can
# be checked mechanically becomes a control. This is that control.
#
# THE VERSION BEING PREPARED IS EXEMPT, and it is a named allow-list of exactly
# one version rather than "skip the newest heading". Workflows/RELEASE.md Step 2
# writes the CHANGELOG section in the bump commit and Step 7 creates the tag
# afterwards, so between those two steps the current version legitimately has a
# section and no tag. Skipping "the newest" instead would also skip a genuinely
# forgotten tag the moment anything landed after it.

CHANGELOG_FILE="CHANGELOG.md"
if [ ! -f "$CHANGELOG_FILE" ]; then
  fail "$CHANGELOG_FILE is missing" "Every released version's notes are built from it (Workflows/RELEASE.md Step 7). Its absence cannot be a pass."
elif ! git rev-parse --git-dir >/dev/null 2>&1; then
  fail "not a git repository, so no tag could be read" "This section compares CHANGELOG versions against tags. Outside a repository it can establish nothing, which is a failure and not a pass."
else
  changelog_versions="$(grep -oE '^## \[[0-9][0-9.]*\]' "$CHANGELOG_FILE" | tr -d '#[] ' | tr -d '\015')"
  changelog_count="$(printf '%s\n' "$changelog_versions" | grep -c . || true)"
  tag_count="$(git tag | grep -c . || true)"

  if [ "$changelog_count" -eq 0 ]; then
    fail "$CHANGELOG_FILE yielded no version headings" "The extraction reads '## [x.y.z]'. Zero means the file was restructured and this check now reads nothing — reported rather than passed."
  elif [ "$tag_count" -eq 0 ]; then
    # Universal failure would be a fact about the checkout, not the repository
    # — TROUBLESHOOTING entry T. Named as such instead of reported per version.
    fail "no tags are present in this checkout, so $changelog_count CHANGELOG version(s) could not be compared" "A shallow clone carries no tags. Fetch them (actions/checkout with fetch-depth: 0, or 'git fetch --tags') and run again. Reporting every version untagged here would describe the clone and not the repository."
  else
    # VERSION.md's current version is the one exemption, resolved once.
    preparing=""
    if [ -f VERSION.md ]; then
      preparing="$(grep -oE '^\*\*v[0-9][0-9.]*\*\*' VERSION.md | head -1 | tr -d '*v' | tr -d '\015')"
    fi

    # THE TAG IS LOOKED FOR FIRST, and the exemption applies only when it is
    # genuinely absent. Exempting the current version outright would also
    # excuse a tag that once existed and was deleted, and would make the pass
    # message claim an exemption was needed when it was not.
    untagged=""
    exempted=""
    checked=0
    for v in $changelog_versions; do
      [ -n "$v" ] || continue
      checked=$((checked + 1))
      if git rev-parse -q --verify "refs/tags/v$v" >/dev/null 2>&1; then
        continue
      fi
      if [ -n "$preparing" ] && [ "$v" = "$preparing" ]; then
        exempted="$v"
        continue
      fi
      untagged="$untagged v$v"
    done

    if [ -n "$untagged" ]; then
      fail "CHANGELOG versions with no tag:$untagged" "Workflows/RELEASE.md Step 7 tags the release and builds its GitHub Release from this section. A version with notes and no tag shipped without completing Step 7 — which is how v0.0.11 and v0.0.9.1 went untagged. Tag it at the commit that merged it to main, or remove the section if it never shipped."
    else
      if [ -n "$exempted" ]; then
        pass "$checked CHANGELOG version(s): all tagged except v$exempted, which VERSION.md says is being prepared — Step 2 writes the section, Step 7 creates the tag"
      else
        pass "all $checked CHANGELOG version(s) have a tag"
      fi
    fi
  fi
fi

section "17. Every declared stack has a starter Dockerfile, and no orphan Dockerfile"
# ==========================================================================
# The framework's universality claim rests on ONE command adopting any stack.
# setup-project-bootstrap.sh accepts a closed list, VALID_STACKS, and for each
# copies Adapters/dockerfiles/<stack>.Dockerfile. If a stack is added to that
# list without shipping its Dockerfile, bootstrap does not fail at build time —
# it errors "no starter Dockerfile for stack '<x>'" only when an adopter picks
# that stack, i.e. on someone else's machine. This makes the coverage a fact
# the repository checks, not a promise. Both directions: a declared stack with
# no Dockerfile is a broken adoption; a Dockerfile matching no declared stack is
# a dead file or a typo an adopter can never reach.
BOOTSTRAP="Adapters/scripts/setup-project-bootstrap.sh"
DOCKERFILE_DIR="Adapters/dockerfiles"
if [ ! -f "$BOOTSTRAP" ]; then
  fail "$BOOTSTRAP is missing" "It declares VALID_STACKS, the closed list this section verifies against the shipped Dockerfiles."
elif [ ! -d "$DOCKERFILE_DIR" ]; then
  fail "$DOCKERFILE_DIR is missing" "The stack half of bootstrap copies its starter Dockerfile from here; without the directory no stack can be adopted."
else
  declared_stacks="$(grep -E '^VALID_STACKS=' "$BOOTSTRAP" | head -1 | sed 's/^VALID_STACKS=//' | tr -d '"' | tr -d "'" | tr -d '\015')"
  if [ -z "$declared_stacks" ]; then
    fail "could not read VALID_STACKS from $BOOTSTRAP" "The extraction reads a line 'VALID_STACKS=\"...\"'. Empty means the declaration moved and this section now verifies nothing — reported rather than passed."
  else
    # forward: every declared stack ships a non-empty Dockerfile.
    for s in $declared_stacks; do
      [ -n "$s" ] || continue
      if [ -s "$DOCKERFILE_DIR/$s.Dockerfile" ]; then
        pass "stack '$s' has a starter Dockerfile"
      else
        fail "stack '$s' is in VALID_STACKS but $DOCKERFILE_DIR/$s.Dockerfile is missing or empty" "An adopter who picks '$s' gets 'no starter Dockerfile for stack $s' and a half-installed project. Ship the Dockerfile, or remove '$s' from VALID_STACKS."
      fi
    done
    # reverse: every shipped Dockerfile corresponds to a declared stack.
    for f in "$DOCKERFILE_DIR"/*.Dockerfile; do
      [ -e "$f" ] || continue
      base="$(basename "$f" .Dockerfile)"
      case " $declared_stacks " in
        *" $base "*) pass "Dockerfile '$base.Dockerfile' matches a declared stack" ;;
        *) fail "$f matches no stack in VALID_STACKS" "A Dockerfile no declared stack names is unreachable — an adopter can never select it. Add '$base' to VALID_STACKS if it is a real stack, or delete the file." ;;
      esac
    done
  fi
fi

section "18. Front doors name the current version"
# ==========================================================================
# Two files restate the version and codename that live authoritatively in
# VERSION.md: README.md (the page a visitor reads first) and CLAUDE.md (the
# contract every agent reads first). Nothing checked they agreed, so the README
# block sat at "v0.0.12 - Automation & Convergence" for ten days after v0.0.13
# shipped, and CLAUDE.md still announced "the next milestone takes 0.0.13" after
# 0.0.13 was the current one — the exact silent drift this repository keeps
# repairing, on its two most-read pages. This pins both: the version and
# codename VERSION.md declares must appear in each. VERSION.md is the source;
# the two files are restatements, so a mismatch names the restatement to fix.
VER_FILE="VERSION.md"
if [ ! -f "$VER_FILE" ]; then
  fail "cannot check the front doors: $VER_FILE is missing" "It is the authoritative source the README and CLAUDE.md are checked against."
else
  # VERSION.md: the '**vX.Y.Z**' after 'Current Version', the '**Codename**'
  # after 'Codename'. tr -d '\r' so a CRLF checkout does not defeat the match.
  ver_version="$(grep -A2 '^Current Version' "$VER_FILE" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9.]+' | head -1 | tr -d '\r')"
  ver_codename="$(grep -A2 '^Codename' "$VER_FILE" | grep -oE '\*\*[^*]+\*\*' | head -1 | tr -d '*\r')"
  if [ -z "$ver_version" ] || [ -z "$ver_codename" ]; then
    fail "could not read the current version and codename from $VER_FILE" "The extraction reads '**vX.Y.Z**' under 'Current Version' and '**Codename**' under 'Codename'. Empty means that header moved and this section now verifies nothing — reported rather than passed."
  else
    # README: the exact 'vX.Y.Z - Codename' line in the Current Status block.
    if [ ! -f README.md ]; then
      fail "README.md is missing" "The front door must exist and restate the current version."
    else
      readme_line="$(sed -n '/^## Current Status/,/^Completed/p' README.md | grep -oE 'v[0-9]+\.[0-9]+\.[0-9.]+ - .+' | head -1 | tr -d '\r')"
      expected="$ver_version - $ver_codename"
      if [ -z "$readme_line" ]; then
        fail "README.md has no 'vX.Y.Z - Codename' line in its Current Status block" "Add it under '## Current Status' as '$expected', or this check reads nothing."
      elif [ "$readme_line" = "$expected" ]; then
        pass "README Current Status names '$expected', matching $VER_FILE"
      else
        fail "README Current Status says '$readme_line' but $VER_FILE declares '$expected'" "The front door has drifted. Fix README.md's '## Current Status' block to '$expected'."
      fi
    fi
    # CLAUDE.md: the '# Current Version' section must name BOTH the version and
    # the codename. It uses an em-dash rather than the README's hyphen, so the
    # two tokens are checked for presence rather than an exact 'X - Y' line.
    if [ ! -f CLAUDE.md ]; then
      fail "CLAUDE.md is missing" "It is the contract every agent reads first and must restate the current version."
    else
      claude_block="$(sed -n '/^# Current Version/,/^# /p' CLAUDE.md | tr -d '\r')"
      if grep -qF "$ver_version" <<< "$claude_block" && grep -qF "$ver_codename" <<< "$claude_block"; then
        pass "CLAUDE.md Current Version names '$ver_version' and '$ver_codename', matching $VER_FILE"
      else
        fail "CLAUDE.md's Current Version section does not name '$ver_version — $ver_codename'" "The contract every agent reads first has drifted. Fix CLAUDE.md's '# Current Version' section to name the version and codename $VER_FILE declares."
      fi
    fi
  fi
fi

section "19. README front-page counts match the framework"
# ==========================================================================
# Workflows/CODE_REVIEW.md rule 5 — "count the things prose counts" — is a
# manual review step: every literal count drifts each time the set it counts
# grows. The README front page states three such counts (engineering workflows,
# required status checks, first-class stacks), each derivable from the tree or a
# script. This mechanises the rule for those three, the same way section 3 does
# for the roster: the claimed number, in digits or as a written-out word, must
# equal what the framework actually has. Reported against the README — the
# directory and the scripts are the source, the front page the restatement.

# Written-out cardinals, one..twenty, so "seven first-class stacks" is checked
# as strictly as "7". Returns the input unchanged when it is already digits.
word2num() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    one) echo 1 ;; two) echo 2 ;; three) echo 3 ;; four) echo 4 ;;
    five) echo 5 ;; six) echo 6 ;; seven) echo 7 ;; eight) echo 8 ;;
    nine) echo 9 ;; ten) echo 10 ;; eleven) echo 11 ;; twelve) echo 12 ;;
    thirteen) echo 13 ;; fourteen) echo 14 ;; fifteen) echo 15 ;;
    sixteen) echo 16 ;; seventeen) echo 17 ;; eighteen) echo 18 ;;
    nineteen) echo 19 ;; twenty) echo 20 ;;
    *) printf '%s' "$1" ;;
  esac
}

# check_front_page_count <label> <actual> <regex-with-count-token-first>
# The regex must match a README phrase whose FIRST token is the count (digit or
# cardinal word); grep -oE extracts the phrase, and the leading token is read.
check_front_page_count() {
  local label="$1" actual="$2" regex="$3" phrase tok claimed
  phrase="$(grep -ohE "$regex" README.md | head -1 | tr -d '\r')"
  if [ -z "$phrase" ]; then
    fail "README: could not find the $label count" "Expected a phrase matching /$regex/. If the front page reworded it, update this check — a count no check reads drifts silently (Workflows/CODE_REVIEW.md rule 5)."
    return
  fi
  tok="$(printf '%s' "$phrase" | grep -oiE '^[A-Za-z0-9]+')"
  claimed="$(word2num "$tok")"
  if [[ ! "$claimed" =~ ^[0-9]+$ ]]; then
    fail "README: could not read a number from '$phrase' for the $label count" "The leading token '$tok' is neither digits nor a cardinal one..twenty."
  elif [ "$claimed" -ne "$actual" ]; then
    fail "README says '$phrase' but the framework has $actual $label" "Front-page count drift. Fix README.md to state $actual, or the set changed and the front page did not (Workflows/CODE_REVIEW.md rule 5)."
  else
    pass "README $label count is $actual"
  fi
}

gt_workflows="$(find Workflows -maxdepth 1 -name '*.md' 2>/dev/null | grep -c . || true)"
gt_checks="$(sed -n '/^REQUIRED_CHECKS=(/,/^)/p' Adapters/scripts/setup-branch-protection.sh 2>/dev/null | grep -cE '^[[:space:]]*"' || true)"
# First-class stacks = the declared stacks minus the generic fallback.
gt_stacks_all="$(grep -m1 '^VALID_STACKS=' Adapters/scripts/setup-project-bootstrap.sh 2>/dev/null | grep -oE '"[^"]*"' | tr -d '"' | wc -w | tr -d ' ')"
gt_stacks_fc="$(( gt_stacks_all > 0 ? gt_stacks_all - 1 : 0 ))"
# Named Agent Chains = the top-level chain entries in the Registry, the same
# source Core/AGENT_CHAINS.md and Examples/ are built from.
gt_chains="$(grep -cE '^  - name:' Registry/chains.yml 2>/dev/null || true)"
# Example walkthroughs = Examples/*.md minus the directory's own index file.
# Examples/README.md is the index (see its "Category: Example — Index"
# metadata), not a seventh walkthrough; excluding it by name is excluding a
# known non-walkthrough file, not hard-coding the walkthrough count.
gt_examples="$(find Examples -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | grep -c . || true)"

if [ ! -f README.md ]; then
  fail "README.md is missing" "The front page must exist for its counts to be checked."
else
  if [ "$gt_workflows" -gt 0 ]; then
    check_front_page_count "engineering workflows" "$gt_workflows" '[0-9]+ engineering workflows'
  else
    fail "could not count Workflows/*.md" "The workflow count is derived from the directory; an empty count means the directory moved."
  fi
  if [ "$gt_checks" -gt 0 ]; then
    check_front_page_count "required status checks" "$gt_checks" '[A-Za-z0-9]+ required status checks'
  else
    fail "could not count REQUIRED_CHECKS in setup-branch-protection.sh" "The required-checks count is derived from that array; an empty count means it moved."
  fi
  if [ "$gt_stacks_fc" -gt 0 ]; then
    check_front_page_count "first-class stacks" "$gt_stacks_fc" '[A-Za-z0-9]+ first-class stacks'
  else
    fail "could not count VALID_STACKS in setup-project-bootstrap.sh" "The stack count is derived from that array; an empty count means it moved."
  fi
  if [ "$gt_chains" -gt 0 ]; then
    check_front_page_count "named Agent Chains" "$gt_chains" '[0-9]+ named Agent Chains'
  else
    fail "could not count '  - name:' entries in Registry/chains.yml" "The named-Agent-Chains count is derived from that Registry; an empty count means it moved or was renamed."
  fi
  if [ "$gt_examples" -gt 0 ]; then
    check_front_page_count "end-to-end chain walkthroughs" "$gt_examples" '[0-9]+ end-to-end chain walkthroughs'
  else
    fail "could not count Examples/*.md walkthroughs (excluding README.md)" "The walkthrough count is derived from the directory minus its index file; an empty count means the directory moved or the index was renamed."
  fi
fi

# ==========================================================================
section "20. README enumeration completeness (Core, Templates, Standards)"
# ==========================================================================
# Section 19 checks that the README's front-page COUNTS match the framework;
# it does not check that the counted items are the right ones. A precision
# audit (WU-IAENG-264) found the "Completed" section's Core and Templates
# enumeration bullets each silently dropped one file from their list while
# every number elsewhere on the page stayed correct — nothing above would
# have caught it, because nothing above reads the list itself, only digits
# near it. WU-IAENG-266 extends the same coverage to the Standards bullet,
# a full name-list of the same shape as Core and Templates, closing it
# before the same drift repeats there unguarded.
#
# APPROACH CHOSEN: count-based, not title-derivation, on evidence rather than
# a shortcut. Title-derivation was tried first, against the file each
# enumeration names. For Templates, 12 of 13 README entries are exactly the
# file's `# ` heading with a trailing " Template" stripped — but ADR.md's
# heading is "Architecture Decision Record Template" and the README calls it
# "ADR", an abbreviation, not a suffix strip. Core has the same shape in the
# other direction: AI_MANIFEST.md, DECISION_TREE.md, GLOSSARY.md, and
# ORCHESTRATION.md all drop words their heading has that the README does not
# ("AI Engineering Manifest" -> "AI Manifest", "IA Engineering Decision Tree"
# -> "Decision Tree", "IA Engineering Glossary" -> "Glossary",
# "Orchestration Protocol" -> "Orchestration"). A strict match needs a
# hand-maintained exception table for 5 of the 23 entries before it can run
# at all — which is a second place for the same drift to happen unnoticed,
# exactly what this section exists to remove.
#
# A count check needs no such table: the number of comma-separated entries in
# the enumeration must equal the number of *.md files in the directory. It
# catches exactly the failure this section was written for — a file silently
# dropped from (or a phantom one added to) the list, which changes the count
# either way. It does NOT catch a file swapped for a same-count rename (e.g.
# one entry's name changed to duplicate another, or to the wrong file's
# title), which title-matching would have caught. That gap is accepted: the
# defect on record is a drop, not a swap, and this check is unconditionally
# reliable where title-matching is reliable only after exceptions are
# hand-maintained — the second copy of the bug the title approach would add.

check_enum_completeness() {
  local label="$1" dir="$2" line items n_items n_files
  if [ ! -d "$dir" ]; then
    fail "cannot check the $label enumeration: $dir/ is missing" "README.md's 'Completed' section enumerates $dir/*.md; without the directory this check verifies nothing."
    return
  fi
  n_files="$(find "$dir" -maxdepth 1 -name '*.md' 2>/dev/null | grep -c . || true)"
  if [ "$n_files" -eq 0 ]; then
    fail "cannot check the $label enumeration: $dir/*.md matched nothing" "An empty input set is not a passing check."
    return
  fi
  line="$(grep -oE "$label \\([^)]*\\)" README.md | head -1 | tr -d '\r')"
  if [ -z "$line" ]; then
    fail "README: could not find the $label enumeration bullet" "Expected a line matching /$label \\([^)]*\\)/ in the 'Completed' section. If the wording changed, update this check — an unread enumeration drifts silently."
    return
  fi
  items="$(sed -E 's/^[A-Za-z]+ \(//; s/\)$//' <<< "$line")"
  n_items="$(awk -F',' '{print NF}' <<< "$items")"
  if [ "$n_items" -ne "$n_files" ]; then
    fail "README's $label enumeration lists $n_items entries but $dir/ holds $n_files files" "A file was added to or dropped from $dir/ without the README enumeration following it. Compare '$line' against $dir/*.md."
  else
    pass "README's $label enumeration lists $n_items entries, matching $dir/ ($n_files files)"
  fi
}

if [ ! -f README.md ]; then
  fail "README.md is missing" "The Core, Templates, and Standards enumeration bullets checked here live in its 'Completed' section."
else
  check_enum_completeness "Core" "Core"
  check_enum_completeness "Templates" "Templates"
  check_enum_completeness "Standards" "Standards"
fi

section "21. In-progress milestone named consistently across the front doors"
# ==========================================================================
# Section 18 pins the CURRENT version and codename across VERSION.md,
# README.md and CLAUDE.md. It does not pin the IN-PROGRESS milestone that
# VERSION.md separately declares under '## Next Milestone' — the exact gap
# that let VERSION.md declare Precision (v0.0.14) while CLAUDE.md's 'Next:'
# line and README's 'Planned' section still read TBD for two more Work
# Units (fixed by WU-IAENG-283). VERSION.md is the source; CLAUDE.md's
# 'Next:' line and README's 'Planned' bullet are restatements, so a mismatch
# names the restatement to fix.
#
# DESIGN CHOICE, recorded rather than assumed: when VERSION.md's Next
# Milestone is TBD/unscoped (no milestone name declared), this check does
# NOT require the front doors to also read TBD. A between-milestones state
# is legitimate, and asserting the negative ("the front doors name nothing")
# is brittle against wording that has already varied across releases (see
# VERSION.md history). The failure this section exists to catch is a SCOPED
# milestone in VERSION.md that the front doors have not caught up to, not
# the shape of the unscoped state's prose.
if [ ! -f "$VER_FILE" ]; then
  fail "cannot check the in-progress milestone: $VER_FILE is missing" "It is the authoritative source the README and CLAUDE.md are checked against."
elif ! grep -q '^## Next Milestone' "$VER_FILE"; then
  fail "cannot find '## Next Milestone' in $VER_FILE" "The extraction reads the first bold token in the two lines following that heading. A missing heading means it moved and this section verifies nothing."
else
  # The milestone name is the first '**...**' token within the heading plus
  # the two lines that follow it (heading, blank line, content line) — the
  # same '-A2' plus bold-token idiom section 18 uses for Codename. A TBD
  # line carries no bold token, so this is empty for the unscoped state, by
  # design (see above).
  next_ms="$(grep -A2 '^## Next Milestone' "$VER_FILE" | grep -oE '\*\*[^*]+\*\*' | head -1 | tr -d '*\r')"
  if [ -z "$next_ms" ]; then
    pass "$VER_FILE's Next Milestone is unscoped (TBD); the front doors are not required to name one"
  else
    if [ ! -f CLAUDE.md ]; then
      fail "CLAUDE.md is missing" "It must restate the in-progress milestone $VER_FILE declares."
    else
      claude_next="$(grep -E '^Next:' CLAUDE.md | tr -d '\r')"
      if [ -z "$claude_next" ]; then
        fail "CLAUDE.md has no 'Next:' line" "Expected a line starting 'Next:' naming '$next_ms', the in-progress milestone $VER_FILE declares."
      elif grep -qF "$next_ms" <<< "$claude_next"; then
        pass "CLAUDE.md's 'Next:' line names '$next_ms', matching $VER_FILE's Next Milestone"
      else
        fail "CLAUDE.md's 'Next:' line does not name '$next_ms'" "$VER_FILE's Next Milestone declares '$next_ms'; CLAUDE.md's 'Next:' line has drifted ('$claude_next'). Fix CLAUDE.md's 'Next:' line to name '$next_ms'."
      fi
    fi

    if [ ! -f README.md ]; then
      fail "README.md is missing" "It must restate the in-progress milestone $VER_FILE declares."
    else
      readme_planned="$(sed -n '/^Planned/,/^---/p' README.md | tr -d '\r')"
      if [ -z "$readme_planned" ]; then
        fail "README.md has no 'Planned' section" "Expected a 'Planned' section naming '$next_ms', the in-progress milestone $VER_FILE declares."
      elif grep -qF "$next_ms" <<< "$readme_planned"; then
        pass "README's 'Planned' section names '$next_ms', matching $VER_FILE's Next Milestone"
      else
        fail "README's 'Planned' section does not name '$next_ms'" "$VER_FILE's Next Milestone declares '$next_ms'; README's 'Planned' section has drifted. Fix it to name '$next_ms'."
      fi
    fi
  fi
fi

# ==========================================================================
section "22. Chain diagrams match Registry/chains.yml step for step"
# ==========================================================================
# Section 13 checks that Registry/chains.yml names real Employees, real
# workflow documents, and every chain Core/AGENT_CHAINS.md defines. It never
# compared the STEPS. The Review Chain diagram therefore lost its Security
# Engineer and Compliance Engineer steps, the Architecture Chain diagram its
# Security Engineer step, and the Feature Chain diagram its ADR gate, while
# chains.yml kept all four and every check here passed. A manual check-up found
# them (WU-IAENG-334, PR #201). This section compares each diagram with its
# Registry entry position by position, in both directions, so that drift fails
# the build instead of waiting for the next audit.
#
# HOW A DIAGRAM IS READ. The grammar below is the one the six diagrams already
# use, derived from them rather than imposed on them. A chain's diagram is the
# first fenced block after its "# <Name> Chain" heading (section 13's heading
# rule). Each line, trimmed, is one of:
#
#   ↓                              connector                not a step
#   [ ... ]                        output                   not a step
#   Main Agent → Director          Director gate            gate: Director
#   Main Agent                     Main Agent's own work    employee: Main Agent
#   Engineer, Engineer(s)          the Engineer step        employee: Engineer
#   <Employee>                     dispatch                 employee: <Employee>
#   ┌── <cond>? → <Employee> ──┐  conditional branch       employee: <Employee>, when:
#   └── <cond> → <Employee> → resubmit ──┘
#                                  review loop              loops_to: <Employee>, on
#                                                           the step before the box
#   ┌── Approved ──┐, │   │, └───┘  branch label, box rules  not a step
#
# A step line may end in "(...)", a condition, and in "← parallel ...", which
# the Registry records as parallel: true. Anything else is refused as
# unrecognised rather than skipped (rule 1). That includes a box line with no
# "→" whose text is anything but empty (box rules only) or the one branch label
# the diagrams use, "Approved" - a named allow-list (rule 2), because a step
# drawn in a box, or a branch typed with "->" or "⟶", would otherwise go
# unchecked. It includes an output line that opens "[" and never closes "]",
# and one that holds more than one bracket pair: "[a] Step [b]" would hide a
# step between two outputs, so an output line is "[" first, "]" last and no
# bracket in between.
#
# WHAT IS COMPARED at each position: the kind (gate or employee), the name,
# whether the step is conditional, whether it is parallel, and its loop
# target. A condition is compared by PRESENCE, never by wording: the diagram's
# "(if ...)" and the Registry's when: say one thing in two styles. The Registry
# writes "when: Always" on an unconditional gate, so that value counts as no
# condition.
#
# ONE NAMED EXCEPTION (rule 2). The parenthesised clause "Engineering Manager
# if multi-pole work", exactly, names who does the step under a Director's
# multi-pole mandate (Core/AGENT_CHAINS.md, Work Unit Decomposition). It names
# another actor; it does not make the step conditional, and the Registry
# records it in a note:, not a when:. Clauses are split on ";", so in the
# Architecture Chain's "(if Accepted; Engineering Manager if multi-pole work)"
# the "if Accepted" clause is still a condition. The exception is that name and
# nothing else: "(Only if multi-pole work)" is a condition, and so is any clause
# that merely ends the same way. Every other parenthesised clause is a
# condition, including "(P1/P2 mandatory notification)", which the Registry
# records as "when: Severity is P1 or P2".
#
# WHAT IS READ FROM chains.yml, at the fixed indentation its header's parsing
# contract requires: "  - name:" opens a chain; "      - employee:" or
# "      - gate:" opens a step; the step keys read are "        when:",
# "        parallel:" and "        loops_to:". Refused rather than skipped: any
# other "      - " line, and a "- employee:" or "- gate:" line at any other
# indentation. The content of a block scalar (a key ending in ">-", ">", "|"
# and the like) is text, whatever it looks like: it is skipped while its lines
# are blank or deeper than the key that opened it, exactly as YAML reads it.
#
# CRLF is stripped explicitly. Git for Windows' awk drops the carriage return
# on read, but an awk elsewhere keeps it, which would end every heading, name
# and value with \r.
#
# One awk process reads both files, because process creation dominates this
# script's runtime on Windows (see flatten_roster). Only the first differing
# position of a chain is reported: after one missing step every later position
# differs too. The detail line carries both full sequences instead, which is
# what the fix needs.

# chain_diagram_drift <diagram-document> <chain-registry>
# Prints tab-separated records: "ok<TAB><message>" for each agreeing chain,
# "fail<TAB><message><TAB><detail>" for each difference or unreadable line,
# and last "total<TAB><chains compared><TAB><steps compared>". Exits 0 only
# when at least one chain was compared and nothing differed. Self-contained,
# because Adapters/scripts/tests/run.sh extracts and runs it on fixtures.
chain_diagram_drift() {
  local doc="$1" reg="$2"
  if [ ! -f "$doc" ] || [ ! -f "$reg" ]; then
    printf 'fail\tcannot compare chain diagrams: %s or %s is missing\tBoth files are required. Nothing was compared, which is not a pass.\n' "$doc" "$reg"
    printf 'total\t0\t0\n'
    return 1
  fi
  LC_ALL=C awk '
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    function unreadable(file, what) {
      printf "fail\t%s:%d: %s\tThis line is outside the grammar section 22 of validate-framework.sh reads, so it was not compared. Rewrite it in that grammar, or extend the grammar and its tests.\n", file, FNR, what
      errors++
    }
    function add_step(side, chain, kind, name, cond, par,   i) {
      i = ++count[side, chain]
      skind[side, chain, i] = kind
      sname[side, chain, i] = name
      scond[side, chain, i] = cond
      spar[side, chain, i] = par
      sloop[side, chain, i] = ""
      sline[side, chain, i] = FNR
      return i
    }
    function render(side, chain, i,   q) {
      q = ""
      if (scond[side, chain, i]) q = q ", conditional"
      if (spar[side, chain, i]) q = q ", parallel"
      if (sloop[side, chain, i] != "") q = q ", loops to " sloop[side, chain, i]
      if (q != "") q = " (" substr(q, 3) ")"
      return skind[side, chain, i] ": " sname[side, chain, i] q
    }
    function sequence(side, chain,   i, s) {
      s = ""
      for (i = 1; i <= count[side, chain] + 0; i++)
        s = s ((i > 1) ? "; " : "") i " " render(side, chain, i)
      return s
    }
    function diagram_line(raw,   t, x, inner, n, seg, i, p, ann, par, cond, paren, ncl, cl, c, kind, name, last) {
      t = trim(raw)
      if (t == "") return
      x = t
      gsub(/↓/, "", x)
      gsub(/[ \t]/, "", x)
      if (x == "") return
      if (substr(t, 1, 1) == "[") {
        # Exactly one bracket pair: "[" first, "]" last, and neither bracket
        # in between. Reading only the two ends skipped
        # "[Containment] Compliance Engineer [Assessment]" as one output, so
        # the step drawn between the two outputs went unchecked (issue #233).
        inner = substr(t, 2, length(t) - 2)
        if (length(t) >= 2 && substr(t, length(t)) == "]" &&
            index(inner, "[") == 0 && index(inner, "]") == 0) return
        unreadable(ARGV[2], dchain ": unrecognised output line \"" t "\"")
        return
      }
      if (index(t, "┌") == 1 || index(t, "│") == 1 || index(t, "└") == 1) {
        inner = t
        gsub(/┌|┐|└|┘|│|─/, "", inner)
        inner = trim(inner)
        if (index(inner, "→") == 0) {
          # Named allow-list (rule 2): box rules only, or the one branch label
          # the diagrams use. Anything else in a box is a line this grammar
          # does not read: a step drawn in a box, or a branch typed with "->".
          if (inner == "" || inner == "Approved") return
          unreadable(ARGV[2], dchain ": unrecognised box line \"" t "\"")
          return
        }
        n = split(inner, seg, "→")
        for (i = 1; i <= n; i++) seg[i] = trim(seg[i])
        if (n == 2 && seg[1] != "" && seg[2] != "") {
          add_step("d", dchain, "employee", seg[2], 1, 0)
          return
        }
        last = count["d", dchain] + 0
        if (n == 3 && seg[1] != "" && seg[2] != "" && last > 0) {
          sloop["d", dchain, last] = seg[2]
          return
        }
        unreadable(ARGV[2], dchain ": unrecognised box line \"" t "\"")
        return
      }
      par = 0
      p = index(t, "←")
      if (p > 0) {
        ann = trim(substr(t, p + length("←")))
        t = trim(substr(t, 1, p - 1))
        if (ann !~ /^parallel/) {
          unreadable(ARGV[2], dchain ": unrecognised annotation \"" ann "\"")
          return
        }
        par = 1
      }
      cond = 0
      p = index(t, " (")
      if (p > 0) {
        if (substr(t, length(t)) != ")") {
          unreadable(ARGV[2], dchain ": unrecognised step line \"" trim(raw) "\"")
          return
        }
        paren = substr(t, p + 2, length(t) - p - 2)
        t = trim(substr(t, 1, p - 1))
        ncl = split(paren, cl, ";")
        for (i = 1; i <= ncl; i++) {
          c = trim(cl[i])
          # The one named exception, compared for equality: a pattern would
          # also exempt "Only if multi-pole work", a real condition.
          if (c != "" && c != "Engineering Manager if multi-pole work") cond = 1
        }
      }
      n = split(t, seg, "→")
      if (n == 1) {
        kind = "employee"
        name = t
        sub(/\(s\)$/, "", name)
      } else if (n == 2 && trim(seg[1]) == "Main Agent") {
        kind = "gate"
        name = trim(seg[2])
      } else {
        unreadable(ARGV[2], dchain ": unrecognised step line \"" trim(raw) "\"")
        return
      }
      if (name == "") {
        unreadable(ARGV[2], dchain ": a step line with no name \"" trim(raw) "\"")
        return
      }
      add_step("d", dchain, kind, name, cond, par)
    }

    BEGIN { block = -1 }

    # Registry/chains.yml, the first operand.
    FILENAME == ARGV[1] {
      gsub(/\015/, "")
      # The content of a block scalar is text, whatever it looks like. It runs
      # while lines are blank or deeper than the key that opened it.
      if (block >= 0) {
        if ($0 ~ /^[ \t]*$/) next
        match($0, /^ */)
        if (RLENGTH > block) next
        block = -1
      }
      if ($0 ~ /^ *[A-Za-z_]+:[ \t]*[>|][-+0-9]*[ \t]*$/) {
        match($0, /^ */)
        block = RLENGTH
      }
      v = $0
      if (sub(/^  - name: /, "", v)) {
        rchain = trim(v)
        rcur = 0
        if (rchain in rseen) {
          unreadable(ARGV[1], "chain \"" rchain "\" is recorded twice")
          rchain = ""
        } else {
          rseen[rchain] = 1
          rorder[++nr] = rchain
        }
        next
      }
      if ($0 ~ /^      - (employee|gate): /) {
        if (rchain == "") {
          unreadable(ARGV[1], "a step outside any chain \"" trim($0) "\"")
          next
        }
        sub(/^      - /, "", v)
        p = index(v, ":")
        rcur = add_step("r", rchain, substr(v, 1, p - 1), trim(substr(v, p + 1)), 0, 0)
        next
      }
      if ($0 ~ /^      - /) {
        unreadable(ARGV[1], "a step that opens with neither employee: nor gate: \"" trim($0) "\"")
        next
      }
      if ($0 ~ /^[ \t]*-[ \t]*(employee|gate):/) {
        unreadable(ARGV[1], "a step at the wrong indentation (the parsing contract puts it at six spaces) \"" trim($0) "\"")
        next
      }
      if (!rcur) next
      if (sub(/^        when: /, "", v)) scond["r", rchain, rcur] = (trim(v) != "Always")
      else if (sub(/^        parallel: /, "", v)) spar["r", rchain, rcur] = (trim(v) == "true")
      else if (sub(/^        loops_to: /, "", v)) sloop["r", rchain, rcur] = trim(v)
      next
    }

    # Core/AGENT_CHAINS.md, the second operand.
    FILENAME == ARGV[2] {
      gsub(/\015/, "")
      if ($0 ~ /^[ \t]*```/) {
        if (fence) {
          fence = 0
          drawing = 0
        } else {
          fence = 1
          if (dchain != "" && !(dchain in dhas)) {
            dhas[dchain] = 1
            drawing = 1
          }
        }
        next
      }
      if (fence) {
        if (drawing) diagram_line($0)
        next
      }
      if ($0 ~ /^# /) {
        h = trim(substr($0, 3))
        dchain = ""
        if (h ~ /^[A-Za-z][A-Za-z ]*Chain$/ && h !~ /^(Chain Selection|Chain Conventions|Composing Custom Chain)$/) {
          if (h in dseen) {
            unreadable(ARGV[2], "chain \"" h "\" has two sections")
          } else {
            dseen[h] = 1
            dorder[++nd] = h
            dchain = h
          }
        }
      }
      next
    }

    END {
      for (k = 1; k <= nd; k++) {
        c = dorder[k]
        if (!(c in dhas)) {
          printf "fail\t%s: %s draws no diagram for it\tA chain diagram is the first fenced block after its heading, and this section has none, so nothing was compared.\n", c, ARGV[2]
          bad++
          continue
        }
        if (!(c in rseen)) {
          printf "fail\t%s: %s draws it, but %s has no entry for it\tA runtime reading the Registry would not know this chain exists. Add it to %s.\n", c, ARGV[2], ARGV[1], ARGV[1]
          bad++
          continue
        }
        dn = count["d", c] + 0
        rn = count["r", c] + 0
        if (dn == 0) {
          printf "fail\t%s: the diagram in %s yields no step\tAn empty diagram cannot be compared, which is not a pass.\n", c, ARGV[2]
          bad++
          continue
        }
        differs = 0
        for (i = 1; i <= dn || i <= rn; i++) {
          a = (i <= dn) ? render("d", c, i) : ""
          b = (i <= rn) ? render("r", c, i) : ""
          if (a != b) {
            differs = i
            break
          }
        }
        compared++
        steps += dn
        if (!differs) {
          printf "ok\t%s: diagram and Registry agree step for step (%d steps)\n", c, dn
          continue
        }
        bad++
        a = (differs <= dn) ? sprintf("%s:%d draws \"%s\"", ARGV[2], sline["d", c, differs], render("d", c, differs)) : sprintf("%s draws nothing (the diagram ends at step %d)", ARGV[2], dn)
        b = (differs <= rn) ? sprintf("%s:%d records \"%s\"", ARGV[1], sline["r", c, differs], render("r", c, differs)) : sprintf("%s records nothing (the Registry ends at step %d)", ARGV[1], rn)
        printf "fail\t%s, step %d: %s, %s\tDiagram, %d steps: %s. Registry, %d steps: %s. The diagram is authoritative: bring %s into line with it, unless the diagram is what changed by mistake (Registry/README.md, Authority - the Registry Never Wins).\n", c, differs, a, b, dn, sequence("d", c), rn, sequence("r", c), ARGV[1]
      }
      for (k = 1; k <= nr; k++) {
        c = rorder[k]
        if (!(c in dseen)) {
          printf "fail\t%s: %s records it, but %s has no \"# %s\" section\tA Registry chain with no diagram is stale or misnamed: the document is authoritative, so remove or rename the entry.\n", c, ARGV[1], ARGV[2], c
          bad++
        }
      }
      if (compared == 0) {
        printf "fail\tno chain diagram was compared\t%s yielded no \"# <Name> Chain\" section with a diagram that %s also records. A comparison over an empty set is not a pass.\n", ARGV[2], ARGV[1]
        bad++
      }
      printf "total\t%d\t%d\n", compared, steps
      if (bad || errors) exit 1
      exit 0
    }
  ' "$reg" "$doc"
}

chain_out="$(chain_diagram_drift Core/AGENT_CHAINS.md Registry/chains.yml)"
chain_status=$?
chain_total=""
chain_steps=""
chain_fails=0
while IFS=$'\t' read -r verdict message detail; do
  case "$verdict" in
    "") ;;
    ok) pass "$message" ;;
    fail) chain_fails=$((chain_fails + 1)); fail "$message" "$detail" ;;
    total) chain_total="$message"; chain_steps="$detail" ;;
    *) chain_fails=$((chain_fails + 1)); fail "chain_diagram_drift printed a record this section cannot read" "$verdict $message" ;;
  esac
done <<< "$chain_out"
if [ -z "$chain_total" ]; then
  fail "the chain diagram comparison produced no verdict" "chain_diagram_drift exited $chain_status without its closing 'total' record: awk did not run, or stopped early. Nothing was compared, which is not a pass."
elif [ "$chain_status" -eq 0 ] && [ "$chain_fails" -eq 0 ]; then
  pass "all $chain_total chain diagrams match Registry/chains.yml step for step ($chain_steps steps compared)"
elif [ "$chain_fails" -eq 0 ]; then
  fail "the chain diagram comparison failed without naming a difference" "chain_diagram_drift exited $chain_status after comparing $chain_total chains. Reported rather than passed."
fi

# ==========================================================================
section "23. Changelog fragments (changelog.d/)"
# ==========================================================================
# Each Work Unit's changelog entry is a fragment, changelog.d/<Work Unit
# id>.md, which Adapters/scripts/release.sh assemble folds into CHANGELOG.md
# at the version bump (Workflows/RELEASE.md Step 2). Two Pull Requests that
# each append to the same CHANGELOG.md category conflict; two that each add
# their own fragment do not (Release Manager study of 23 Oct 2026, option 1).
#
# A malformed fragment found at the bump is found by the wrong person, weeks
# after its author moved on. This section finds it on the Pull Request that
# adds it, with the parser assemble uses, Adapters/scripts/
# changelog-fragment.awk, so the two cannot disagree on what a fragment is:
#
#   - every entry of changelog.d/ other than README.md is a file named
#     <Work Unit id>.md — assemble refuses to run while anything else is there;
#   - that id is registered in Registry/work-units.yml;
#   - the content is an entry under Keep a Changelog's six headings, plus
#     "### Notes" for an upgrade note, each with a bullet and no HTML that
#     could hide text, or the single line "No changelog entry: <reason>";
#   - the parser ran and printed a record (a silent parser is no pass).
#
# THE DENOMINATOR MAY BE ZERO. Rule 3 asks a set-iterating check to fail at
# zero, because an empty set usually means the input moved. Here the set is a
# queue: assemble empties it at every release, and right after Step 2 zero
# fragments is the correct state. What would mean "the input moved" — the
# directory, its README.md, the parser or the registry missing — is a failure
# of its own below, so a zero count is reported with its number, not passed
# blind.
#
# The function prints the section 22 records: "fail<TAB>message<TAB>detail"
# per problem and a closing "total<TAB>n".
changelog_fragment_check() {
  local dir="$1" registry="$2" parser="$3"
  local f base id n=0 registered parsed status
  if [ ! -d "$dir" ]; then
    printf 'fail\t%s/ is missing\tWorkflows/RELEASE.md Step 2 assembles the changelog from it. Without it no fragment can be checked, and an unevaluated condition is not a pass.\n' "$dir"
    return 1
  fi
  if [ ! -f "$parser" ]; then
    printf 'fail\t%s is missing\tIt is the one definition of a fragment, shared with release.sh assemble. Nothing was checked.\n' "$parser"
    return 1
  fi
  if [ ! -f "$registry" ]; then
    printf 'fail\t%s is missing\tA fragment is named after a registered Work Unit. Nothing was checked.\n' "$registry"
    return 1
  fi
  if [ ! -f "$dir/README.md" ]; then
    printf 'fail\t%s/README.md is missing\tIt is where an author learns the fragment format.\n' "$dir"
  fi
  registered="$(grep -E '^  - id: ' "$registry" | sed 's/^  - id: //' | tr -d '\015')"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="${f##*/}"
    [ "$base" = "README.md" ] && continue
    # A symbolic link is refused even when it points at a valid fragment:
    # assemble reads through it and deletes only the link, so the content
    # would come from outside changelog.d/ (SEC-IAENG-378-01, N2).
    if [ -L "$f" ] || [ ! -f "$f" ] || ! [[ "$base" =~ ^WU-[A-Za-z0-9]+-[0-9]+\.md$ ]]; then
      printf 'fail\t%s is not a fragment\t%s/ holds README.md and regular files named <Work Unit id>.md, nothing else, no symbolic link; release.sh assemble refuses to run while anything else is there.\n' "$f" "$dir"
      continue
    fi
    n=$((n + 1))
    id="${base%.md}"
    if ! grep -qxF -- "$id" <<< "$registered"; then
      printf 'fail\t%s names %s, which %s does not register\tA fragment is the changelog entry of one registered Work Unit: register it, or rename the fragment to the Work Unit it belongs to.\n' "$f" "$id" "$registry"
    fi
    # A parse that succeeds always prints at least one ENTRY, EXEMPT or ERROR
    # record: an empty fragment is itself an ERROR. A parser that exits
    # non-zero, or prints no record, did not evaluate the fragment, and an
    # unevaluated fragment is a failure, never a clean one.
    parsed="$(awk -v id="$id" -f "$parser" "$f" 2>/dev/null)"
    status=$?
    if [ "$status" -ne 0 ] || ! grep -qE '^(ENTRY|EXEMPT|ERROR)'$'\t' <<< "$parsed"; then
      printf 'fail\t%s: the fragment parser did not run (exit %s) or printed no record\t%s is the one definition of a fragment. Nothing was evaluated, which is not a pass.\n' "$f" "$status" "$parser"
      continue
    fi
    awk -F'\t' -v f="$f" '$1 == "ERROR" { printf "fail\t%s line %s: %s\tThe format is in changelog.d/README.md. release.sh assemble refuses a malformed fragment at the version bump.\n", f, $2, $3 }' <<< "$parsed"
  done < <(find "$dir" -mindepth 1 -maxdepth 1 | LC_ALL=C sort)
  printf 'total\t%d\n' "$n"
}

frag_out="$(changelog_fragment_check changelog.d Registry/work-units.yml Adapters/scripts/changelog-fragment.awk)"
frag_total=""
frag_fails=0
while IFS=$'\t' read -r verdict message detail; do
  case "$verdict" in
    "") ;;
    fail) frag_fails=$((frag_fails + 1)); fail "$message" "$detail" ;;
    total) frag_total="$message" ;;
    *) frag_fails=$((frag_fails + 1)); fail "changelog_fragment_check printed a record this section cannot read" "$verdict $message" ;;
  esac
done <<< "$frag_out"
if [ "$frag_fails" -eq 0 ] && [ -z "$frag_total" ]; then
  fail "the changelog fragment check produced no verdict" "changelog_fragment_check stopped without its closing 'total' record. Nothing was checked, which is not a pass."
elif [ "$frag_fails" -eq 0 ]; then
  pass "changelog.d/: $frag_total fragment(s), each named after a registered Work Unit, with Keep a Changelog headings or an upgrade note only"
fi

# EARLY WARNING, on a Pull Request only, and never a failure.
#
# Condition 5 of release.sh check fails a release whose Work Unit has no
# fragment, but the release is weeks after the Pull Request, and the author is
# the one who knows what the entry should say. So the Pull Request that
# carries a Work Unit's trailer and adds no changelog.d/<id>.md, and does not
# edit CHANGELOG.md either (the way entries were written before fragments), is
# told so here, as a warning annotation.
#
# A warning and not a failure: a Work Unit spread over several Pull Requests
# has its fragment in one of them, and a back-merge carries trailers whose
# fragments were assembled long ago. Neither is wrong, and a check that fails
# on correct Pull Requests teaches people to ignore it. The gate is condition 5.
#
# Only where this repository IS the one under review — the framework's own CI.
# In an adopting project this script validates the framework inside the
# project's ia-engineering/ directory, and the Pull Request's trailers name
# the project's Work Units, whose changelog is the project's business.
changelog_fragment_advisory() {
  local dir="$1" base="$2" head="$3" id
  git rev-parse -q --verify "$base^{commit}" > /dev/null 2>&1 || return 2
  git rev-parse -q --verify "$head^{commit}" > /dev/null 2>&1 || return 2
  [ -z "$(git diff --name-only "$base...$head" -- CHANGELOG.md 2>/dev/null)" ] || return 0
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    [ -f "$dir/$id.md" ] || printf '%s\n' "$id"
  done < <(git log --no-merges --format=%B "$base..$head" 2>/dev/null \
             | awk '/^Work Unit: / { id = $0; sub(/^Work Unit: /, "", id); gsub(/\015/, "", id); print id }' \
             | LC_ALL=C sort -u)
}

if [ -n "${GITHUB_BASE_REF:-}" ] && [ -n "${GITHUB_WORKSPACE:-}" ] && [ "$GITHUB_WORKSPACE" -ef "$ROOT" ]; then
  frag_adv="$(changelog_fragment_advisory changelog.d "origin/$GITHUB_BASE_REF" HEAD)"
  frag_adv_status=$?
  if [ "$frag_adv_status" -eq 2 ]; then
    printf '   --    changelog fragment early warning not evaluated: origin/%s or HEAD is not a commit here\n' "$GITHUB_BASE_REF"
    echo "::warning::Changelog fragment early warning not evaluated: origin/$GITHUB_BASE_REF or HEAD could not be read. release.sh check condition 5 still applies at the release."
  else
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      printf '   note  %s has no changelog.d/%s.md in this Pull Request\n' "$id" "$id"
      echo "::warning::$id has no changelog.d/$id.md and this Pull Request does not edit CHANGELOG.md. Add the fragment (changelog.d/README.md), or 'No changelog entry: <reason>'; release.sh check condition 5 blocks the release without one."
    done <<< "$frag_adv"
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
