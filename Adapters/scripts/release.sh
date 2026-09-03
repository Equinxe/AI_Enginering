#!/usr/bin/env bash
# IA Engineering — release.sh
#
# The mechanical parts of Workflows/RELEASE.md, executed. Nothing else.
#
# WHAT THIS IS FOR
#
# Core/MAIN_AGENT_CONDUCT.md's Autonomous Release Execution rule exists because
# the Main Agent had been advancing a fully-specified process one prompt at a
# time, waiting to be told to begin each step. The rule says to run the whole
# sequence on its own. But the steps themselves were still entirely manual, and
# two of them are pure mechanism that a human or an AI gets wrong in the same
# way twice:
#
#   Step 1 readiness — a list of conditions to confirm by eye. "Confirm CI/CD
#   is green on develop" and "confirm no open critical defects remain" were
#   things to remember to look at.
#
#   Step 7 tagging — Workflows/RELEASE.md had to be amended (WU-IAENG-131)
#   because a bare annotated tag produces no description on the Releases page.
#   It now requires a full GitHub Release whose notes derive from that version's
#   CHANGELOG.md entry. That gap had to be fixed after the fact for BOTH v0.0.10
#   and v0.0.10.1 — the same mistake, twice, on consecutive releases. Extracting
#   a CHANGELOG section by hand and pasting it is exactly the kind of step that
#   gets shortened to a one-line summary under time pressure.
#
# WHAT THIS DELIBERATELY DOES NOT DO
#
# It does not approve, and it does not merge to main.
#
# Workflows/RELEASE.md Step 5 states: "No merge to `main` happens without
# explicit Director approval." Autonomous Release Execution is explicit that it
# governs pacing between steps and "never converts a mandatory approval gate
# into an optional one". A script that could merge to main would be a script
# that can pass the gate, and it would pass it every time it ran. So `check`
# stops at Step 5 and says so, and `release` refuses to run until the merge has
# already happened by other means.
#
# It also does not bump the version. Step 2 is a normal Work Unit merged into
# develop through the standard branch/commit/PR cycle, subject to the same CI
# and hooks as any other change — deliberately, so the release branch cut in
# Step 3 is a pure snapshot. Automating a commit-and-PR here would route around
# the review path the workflow chose on purpose.
#
# Usage:
#   ./Adapters/scripts/release.sh check [version] [--milestone <name>]
#       Step 1 readiness review. Reports every condition; exits 1 on any
#       failure. Read-only — touches nothing.
#
#   ./Adapters/scripts/release.sh notes <version>
#       Print that version's CHANGELOG.md section, exactly as Step 7 requires
#       the GitHub Release notes to read.
#
#   ./Adapters/scripts/release.sh publish <version> [--confirm]
#       Step 7 only: annotated tag plus a full GitHub Release built from the
#       CHANGELOG.md section. Requires the release to already be merged to main
#       (Steps 5 and 6 complete). Prints the plan and stops unless --confirm is
#       given.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT" || exit 2

FAILURES=0
MILESTONE_OVERRIDE=""

ok()   { printf '   ok    %s\n' "$1"; }
bad()  { FAILURES=$((FAILURES + 1)); printf '   FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '         %s\n' "$2"; }
note() { printf '         %s\n' "$1"; }
head2() { printf '\n== %s\n' "$1"; }

current_version() {
  grep -m1 -oE '^\*\*v[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?\*\*$' VERSION.md \
    | tr -d '*' | tr -d '\015'
}

# Extracts one version's section from CHANGELOG.md: from its own "## [x.y.z]"
# heading up to (not including) the next "## [" heading.
changelog_section() {
  local version="${1#v}"
  awk -v want="$version" '
    $0 ~ "^## \\[" want "\\]" { inside = 1; print; next }
    inside && /^## \[/ { exit }
    inside { print }
  ' CHANGELOG.md
}

# ---------------------------------------------------------------- check ----

cmd_check() {
  local target="${1:-}"

  echo "IA Engineering — release readiness (Workflows/RELEASE.md Step 1)"
  echo "Repository: $ROOT"

  head2 "Branch and working tree"

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$branch" = "develop" ]; then
    ok "on develop"
  else
    bad "on '$branch', not develop" "Step 1 reviews develop's readiness, and Step 3 cuts the release branch from it. Checking any other branch answers a different question."
  fi

  if [ -z "$(git status --porcelain)" ]; then
    ok "working tree is clean"
  else
    bad "working tree has uncommitted changes" "A release is cut from committed state. Anything uncommitted is not in it."
  fi

  git fetch --quiet origin 2>/dev/null || note "could not fetch origin — the comparison below may be stale"

  local ahead behind
  ahead="$(git rev-list --count "origin/$branch..$branch" 2>/dev/null || echo "?")"
  behind="$(git rev-list --count "$branch..origin/$branch" 2>/dev/null || echo "?")"
  if [ "$ahead" = "0" ] && [ "$behind" = "0" ]; then
    ok "in sync with origin/$branch"
  else
    bad "$ahead ahead, $behind behind origin/$branch" "Cut the release from what the remote actually holds, not a local divergence."
  fi

  head2 "Version and changelog"

  local version
  version="$(current_version)"
  if [ -z "$version" ]; then
    bad "could not read the current version from VERSION.md" "Expected a line of the form **vX.X.X**."
  else
    ok "VERSION.md says $version"
    if [ -n "$target" ] && [ "$target" != "$version" ] && [ "v${target#v}" != "$version" ]; then
      bad "asked about $target but VERSION.md says $version" "Step 2 bumps the version on develop BEFORE the release branch is cut, so develop should already carry the version being released."
    fi
  fi

  local check_version="${target:-$version}"
  if [ -n "$check_version" ]; then
    local section
    section="$(changelog_section "$check_version")"
    if [ -z "$section" ]; then
      bad "CHANGELOG.md has no section for ${check_version}" "Step 7 builds the GitHub Release notes from it. Without the section there is nothing to publish, which is how v0.0.10 and v0.0.10.1 both shipped with a bare tag."
    else
      local lines
      lines="$(printf '%s\n' "$section" | grep -c . || true)"
      ok "CHANGELOG.md section for ${check_version} present ($lines non-empty lines)"
      if [ "$lines" -lt 4 ]; then
        bad "the CHANGELOG.md section for ${check_version} looks too thin ($lines lines)" "Step 1 requires reviewing that every significant change since the last release is accounted for."
      fi
    fi
  fi

  head2 "Work Unit completeness"

  # Workflows/RELEASE.md Step 1 item 1: "Confirm all planned Work Units are
  # merged into develop."
  #
  # This had no mechanical form until now, and Step 1's lead-in nonetheless
  # claimed the script reported every condition in its list — a document
  # claiming enforcement it did not have, which is the prose mirror of the
  # silent-skip this script had in its framework-consistency step
  # (WU-IAENG-153). Found in review.
  #
  # It became tractable through two mechanisms this milestone built:
  # WU-IAENG-155 made every commit's Work Unit readable from its `Work Unit:`
  # trailer, and Registry/work-units.yml records each Work Unit against a
  # `milestone:`. So the condition becomes checkable: for the milestone being
  # released, every registered Work Unit must have a trailer reachable from
  # this branch. It is the Step 1 condition whose failure is least visible by
  # eye — a Work Unit merged to a feature branch but never to develop looks
  # identical to one that landed.

  # WHICH MILESTONE IS BEING RELEASED — resolved, not read from VERSION.md.
  #
  # The first version took the codename from VERSION.md and could therefore
  # never pass where Step 1 is specified to run. Step 1 is the readiness
  # review; Step 2 is the version bump. So at Step 1 VERSION.md necessarily
  # still names the PREVIOUS milestone, condition 1 resolved the
  # already-released one, found zero Work Units, and failed — on every
  # release, with Step 1 then saying "block the release". The only way to clear
  # it was to do Step 2 first, which Step 1 gates. Found in review.
  #
  # That is the same shape as a check that cannot go green when run as
  # documented, and it carried the extra cost of training the reader to treat
  # condition 1's FAIL as routine — so the next genuinely unmerged Work Unit
  # would look identical at a glance.
  #
  # The milestone under release is derived instead: a milestone in
  # Registry/work-units.yml with no matching CHANGELOG.md section has not
  # shipped. That is checkable before the bump, unlike VERSION.md, because this
  # project writes the CHANGELOG section in the bump commit itself. Exactly one
  # unreleased milestone is the normal case; --milestone overrides, and
  # ambiguity is reported rather than guessed.
  local codename registry_ids merged_ids unreleased n_unreleased

  if [ -n "$MILESTONE_OVERRIDE" ]; then
    codename="$MILESTONE_OVERRIDE"
    ok "milestone '$codename' (from --milestone)"
  elif [ ! -f Registry/work-units.yml ] || [ ! -f CHANGELOG.md ]; then
    codename=""
  else
    unreleased="$(awk '/^    milestone: / { m = $0; sub(/^    milestone: /, "", m); gsub(/\015/, "", m); print m }' \
      Registry/work-units.yml | sort -u | while IFS= read -r m; do
        [ -n "$m" ] || continue
        grep -qE "^## \[[0-9.]+\] - $m\$" CHANGELOG.md || printf '%s\n' "$m"
      done)"
    n_unreleased="$(printf '%s\n' "$unreleased" | grep -c . || true)"

    if [ "$n_unreleased" -eq 1 ]; then
      codename="$(printf '%s\n' "$unreleased" | grep .)"
      ok "milestone '$codename' — the one registry milestone with no CHANGELOG.md section yet"
    elif [ "$n_unreleased" -eq 0 ]; then
      codename=""
      ok "every registry milestone already has a CHANGELOG.md section — no unreleased Work Units to confirm"
    else
      codename=""
      bad "cannot determine which milestone is being released" "$n_unreleased registry milestones have no CHANGELOG.md section: $(printf '%s' "$unreleased" | tr '\n' ' '). Pass --milestone <name> to say which one this release is. Guessing would evaluate condition 1 against the wrong set."
    fi
  fi

  if [ -z "$codename" ] && [ "$n_unreleased" != "0" ]; then
    : # the branches above already reported why
  elif [ -z "$codename" ]; then
    : # nothing pending; already reported as ok
  elif [ ! -f Registry/work-units.yml ]; then
    bad "Registry/work-units.yml is missing" "Step 1 item 1 needs it to know which Work Units this milestone planned."
  else
    registry_ids="$(awk -v m="$codename" '
      /^  - id: / { id = $0; sub(/^  - id: /, "", id); gsub(/\015/, "", id) }
      /^    milestone: / { ms = $0; sub(/^    milestone: /, "", ms); gsub(/\015/, "", ms)
                           if (ms == m && id != "") print id }
    ' Registry/work-units.yml | sort -u)"

    if [ -z "$registry_ids" ]; then
      # Not a pass: the milestone was named (by --milestone or by derivation)
      # but no Work Unit is registered against that label, so the condition was
      # not evaluated. An unevaluated condition is a failure.
      bad "no Work Units registered against milestone '$codename'" "The label was resolved but Registry/work-units.yml has no entry using it — check for a spelling difference between the CHANGELOG section, --milestone, and the registry's milestone field. Condition 1 cannot be confirmed either way, and an unevaluated condition is not a met one."
    else
      # PER COMMIT, taking each commit's own trailer — not a flat grep over
      # every body.
      #
      # The flat version counted any `Work Unit:` line at column 0 anywhere in
      # any message as evidence the Work Unit had landed. Reproduced in review:
      # with an unmerged Work Unit registered, the check correctly failed;
      # after one commit whose body merely QUOTED that id at column 0, it
      # reported the milestone complete. A false pass on a release gate, and
      # realistic here specifically, because quoting trailer lines in commit
      # bodies is a habit in this repository — it is how the original head -1
      # bug was found. A commit explaining why a Work Unit was deferred is the
      # natural shape of that false pass.
      #
      # Note the rule here differs from the other three readers on purpose, and
      # the difference is the question being asked. They VALIDATE — every claim
      # in a message must resolve, so all lines are checked. This ATTRIBUTES —
      # which Work Unit does this commit perform — and attribution needs one
      # answer per commit. Git's own trailer definition would give it, but
      # cannot: `Work Unit:` contains a space and so is never parsed as a
      # trailer (see Standards/COMMIT_STANDARD.md, Trailers). The last matching
      # line is the closest honest approximation, and it is correct for any
      # message conforming to that Standard, which requires the trailer block
      # last and any quoted example indented.
      merged_ids="$(for sha in $(git rev-list --no-merges "$branch" 2>/dev/null); do
          git log -1 --format=%B "$sha" \
            | grep -E '^Work Unit: ' | tail -1 | sed 's/^Work Unit: //' | tr -d '\r'
        done | grep . | sort -u)"

      local missing_wu="" total=0
      while IFS= read -r id; do
        [ -n "$id" ] || continue
        total=$((total + 1))
        printf '%s\n' "$merged_ids" | grep -qxF "$id" || missing_wu="$missing_wu$id "
      done < <(printf '%s\n' "$registry_ids")

      if [ -n "$missing_wu" ]; then
        bad "$(echo "$missing_wu" | wc -w | tr -d ' ') of $total Work Units for '$codename' are not on $branch: $missing_wu" "Each is registered against this milestone but no commit reachable from $branch carries its 'Work Unit:' trailer. Merge them, or move them to a later milestone in Registry/work-units.yml — releasing without them ships a milestone the registry says is incomplete."
      else
        ok "all $total registered Work Units for '$codename' are on $branch"
      fi
    fi
  fi

  head2 "Continuous integration on $branch"

  if ! command -v gh > /dev/null 2>&1; then
    bad "gh is not installed — cannot verify CI status" "Step 1 requires confirming CI is green on develop. Install the GitHub CLI, or verify it by hand and record that you did."
  else
    local conclusion
    conclusion="$(gh run list --branch "$branch" --limit 1 \
      --json conclusion,status,workflowName 2>/dev/null || true)"
    if [ -z "$conclusion" ] || [ "$conclusion" = "[]" ]; then
      bad "no CI runs found for $branch" "Cannot confirm CI is green. A release with no CI evidence is not ready."
    elif echo "$conclusion" | grep -q '"conclusion":"success"'; then
      ok "latest CI run on $branch succeeded"
    elif echo "$conclusion" | grep -q '"status":"in_progress"'; then
      bad "a CI run on $branch is still in progress" "Wait for it. Step 1 requires green, not pending."
    else
      bad "the latest CI run on $branch did not succeed" "$conclusion"
    fi
  fi

  head2 "Framework consistency"

  # Tested with -f and invoked through `bash`, not tested with -x and run
  # directly. The earlier version did the latter, and its else branch called
  # `note` rather than `bad` — so a validator that was missing, or merely
  # committed without its executable bit, was skipped while FAILURES stayed at
  # zero and the readiness review still printed "Ready for Step 2". A release
  # gate that skips itself and reports success is the exact failure shape this
  # milestone exists to remove, and it was sitting inside the milestone. Found
  # in review, not by me.
  #
  # Invoking via `bash` also means the executable bit is not load-bearing here:
  # WU-IAENG-150 fixed the committed modes, but a gate should not depend on
  # file metadata staying correct forever.
  if [ ! -f Adapters/scripts/validate-framework.sh ]; then
    bad "Adapters/scripts/validate-framework.sh is missing" "Release readiness cannot confirm framework consistency without it. Absent evidence is not the same as a passing check, so this blocks rather than being skipped."
  else
    VALIDATE_LOG="$(mktemp)"
    if bash Adapters/scripts/validate-framework.sh > "$VALIDATE_LOG" 2>&1; then
      ok "validate-framework.sh passes"
    else
      bad "validate-framework.sh reports failures" "$(grep FAIL "$VALIDATE_LOG" | head -3 | tr '\n' ' ')"
    fi
    rm -f "$VALIDATE_LOG"
  fi

  head2 "Open defects"

  if ! command -v gh > /dev/null 2>&1; then
    note "gh is not installed — open defects not listed. The CI condition above already failed for the same reason."
  else
    local blockers
    blockers="$(gh issue list --state open --label 'bug' --limit 100 --json number,title 2>/dev/null || true)"
    if [ -z "$blockers" ] || [ "$blockers" = "[]" ]; then
      ok "no open issues labelled bug"
    else
      local count
      count="$(echo "$blockers" | grep -o '"number"' | wc -l | tr -d ' ')"
      note "$count open issue(s) labelled bug — Step 1 requires confirming none is critical or high"
      note "This is a judgment call, not a mechanical one, so it is reported rather than failed."
      echo "$blockers" | head -5
    fi
  fi

  head2 "Result"

  if [ "$FAILURES" -eq 0 ]; then
    echo "   Ready for Step 2 (version bump on develop), then Step 3 (release branch)."
  else
    echo "   $FAILURES condition(s) not met."
    echo "   Workflows/RELEASE.md Step 1: \"If any condition is not met: block the"
    echo "   release. Do not proceed until develop is ready.\""
  fi

  cat <<'GATE'

   Not checked here, and not automatable:
     Step 4  QA Engineer executes the release acceptance test plan.
     Step 5  DIRECTOR APPROVAL — a hard gate. Workflows/RELEASE.md: "No merge
             to `main` happens without explicit Director approval." This script
             cannot and must not stand in for it.
GATE

  [ "$FAILURES" -eq 0 ] || return 1
  return 0
}

# ---------------------------------------------------------------- notes ----

cmd_notes() {
  local version="${1:-}"
  if [ -z "$version" ]; then
    echo "Usage: $0 notes <version>" >&2
    return 2
  fi

  local section
  section="$(changelog_section "$version")"
  if [ -z "$section" ]; then
    echo "No CHANGELOG.md section found for $version." >&2
    echo "Expected a heading of the form: ## [${version#v}] - <Codename>" >&2
    return 1
  fi
  printf '%s\n' "$section"
}

# -------------------------------------------------------------- publish ----

cmd_publish() {
  local version="${1:-}" confirm="${2:-}"

  if [ -z "$version" ]; then
    echo "Usage: $0 publish <version> [--confirm]" >&2
    return 2
  fi
  version="v${version#v}"

  echo "IA Engineering — publish release $version (Workflows/RELEASE.md Step 7)"

  # Step 7 follows Steps 5 and 6. Tagging a commit that never went through the
  # Director gate and the merge PR would produce a release of something nobody
  # approved.
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$branch" != "main" ]; then
    echo "release.sh: refusing — on '$branch', not main." >&2
    echo "  Step 7 tags the release on main, after Step 5 (Director approval)" >&2
    echo "  and Step 6 (merge via Pull Request). Being on another branch means" >&2
    echo "  at least one of those has not happened, and this script does not" >&2
    echo "  perform either: the gate is the Director's, and the merge is the" >&2
    echo "  Release Manager's through a reviewed Pull Request." >&2
    return 1
  fi

  if [ -n "$(git status --porcelain)" ]; then
    echo "release.sh: refusing — working tree is not clean." >&2
    return 1
  fi

  git fetch --quiet origin 2>/dev/null || true
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main 2>/dev/null || echo none)" ]; then
    echo "release.sh: refusing — local main does not match origin/main." >&2
    echo "  Tag what was actually merged and published, not a local state." >&2
    return 1
  fi

  if git rev-parse "$version" > /dev/null 2>&1; then
    echo "release.sh: refusing — tag $version already exists." >&2
    echo "  Re-tagging a published release rewrites what a version means." >&2
    return 1
  fi

  local codename section
  codename="$(grep -m1 -A2 "^## \[${version#v}\]" CHANGELOG.md | head -1 \
    | sed 's/.*] - //' | tr -d '\015')"
  section="$(changelog_section "$version")"

  if [ -z "$section" ]; then
    echo "release.sh: refusing — CHANGELOG.md has no section for $version." >&2
    echo "  Step 7 requires the Release notes to reproduce that version's" >&2
    echo "  CHANGELOG.md entry. A bare tag with a one-line message is what" >&2
    echo "  WU-IAENG-131 changed the workflow to forbid, after it had to be" >&2
    echo "  corrected after the fact for both v0.0.10 and v0.0.10.1." >&2
    return 1
  fi

  echo
  echo "  Version:  $version"
  echo "  Codename: ${codename:-<none found>}"
  echo "  Commit:   $(git rev-parse --short HEAD) on main"
  echo "  Notes:    $(printf '%s\n' "$section" | grep -c . || true) non-empty lines from CHANGELOG.md"
  echo
  echo "  Would run:"
  echo "    git tag -a $version -m \"$version — ${codename:-}\""
  echo "    git push origin $version"
  echo "    gh release create $version --title \"$version — ${codename:-}\" --notes-file <changelog section>"
  echo

  if [ "$confirm" != "--confirm" ]; then
    echo "  Nothing done. Re-run with --confirm to publish."
    echo "  Publishing a release is externally visible and effectively"
    echo "  irreversible, so it is never the default."
    return 0
  fi

  local notes_file
  notes_file="$(mktemp)"
  printf '%s\n' "$section" > "$notes_file"

  git tag -a "$version" -m "$version — ${codename:-}" || return 1
  echo "   tagged $version"

  git push origin "$version" || return 1
  echo "   pushed $version"

  if command -v gh > /dev/null 2>&1; then
    gh release create "$version" \
      --title "$version — ${codename:-}" \
      --notes-file "$notes_file" || return 1
    echo "   GitHub Release created with notes from CHANGELOG.md"
  else
    echo "   gh not installed — the tag is pushed but NO GitHub Release exists." >&2
    echo "   Step 7 is incomplete until one is created from the notes in" >&2
    echo "   $notes_file. A tag without release notes is an incomplete release" >&2
    echo "   (Governance/VERSIONING_POLICY.md, Versioning and Release Completeness)." >&2
    return 1
  fi

  rm -f "$notes_file"

  cat <<'REMAINING'

   Remaining, per Workflows/RELEASE.md:
     Step 8   Back-merge to develop via Pull Request, IF a defect fix landed
              directly on the release branch during Step 4. Not needed when the
              release branch never diverged.
     Step 9   Post-release verification — QA Engineer and Observability
              Engineer confirm production health.
     Step 10  Preserve the release branch. It is never deleted.
REMAINING
}

# ----------------------------------------------------------------- main ----

case "${1:-check}" in
  # `shift` with fd 2 silenced, NOT `shift 2` — the two read almost
  # identically and the difference matters, as WU-IAENG-158 showed in
  # generate-agents.sh. Written out rather than left as a one-liner so the
  # next reader does not have to decide which one this is.
  check)
    shift
    CHECK_VERSION=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --milestone)
          # Arity guarded before the shift, for the reason WU-IAENG-158
          # documents in generate-agents.sh: `shift 2` on a trailing flag fails
          # out of range, and a failed shift does not shift, so the loop spins
          # forever.
          if [ "$#" -lt 2 ]; then
            echo "Argument error: --milestone requires a value." >&2
            echo "  It names the milestone being released, for condition 1." >&2
            exit 2
          fi
          MILESTONE_OVERRIDE="$2"
          shift 2
          ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *)
          if [ -n "$CHECK_VERSION" ]; then
            echo "Error: more than one version given." >&2
            exit 2
          fi
          CHECK_VERSION="$1"
          shift
          ;;
      esac
    done
    cmd_check "$CHECK_VERSION"
    ;;
  notes)   shift; cmd_notes "${1:-}" ;;
  publish) shift; cmd_publish "${1:-}" "${2:-}" ;;
  --help|-h|help)
    sed -n '2,72p' "$0"
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Usage: $0 {check [version] [--milestone <name>] | notes <version> | publish <version> [--confirm]}" >&2
    exit 2
    ;;
esac
