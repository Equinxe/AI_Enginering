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
# `assemble` is the one subcommand that writes, and it writes only the working
# tree of the bump branch: it folds the changelog.d/ fragments into
# CHANGELOG.md and deletes them, and the Release Manager commits that inside
# the Step 2 Work Unit. It commits nothing and opens nothing, for the reason
# above.
#
# Usage:
#   ./Adapters/scripts/release.sh check [version] [--milestone <name>]
#       Step 1 readiness review. Reports every condition; exits 1 on any
#       failure. Read-only — touches nothing.
#
#   ./Adapters/scripts/release.sh assemble
#       Step 2: fold every changelog.d/ fragment into the [Unreleased]
#       section of CHANGELOG.md, by category then Work Unit id, below the
#       bullets already there, and delete the fragments. Commits nothing.
#       Refuses, changing nothing, when a fragment is malformed.
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

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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
# Resolves the forge once and prints the directory holding its implementations
# of the four host-dependent operations. See Adapters/scripts/hosts/README.md.
#
# This script owns the RULES — what a green CI conclusion means for Step 1,
# whether an open defect blocks, what belongs in release notes. The host owns
# only how to ask its own API. Keeping the split here rather than at each call
# site means a second forge adds one directory and changes nothing in this file.
host_dir() {
  local root host
  root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  if [ ! -x "$root/resolve-host.sh" ]; then
    echo "resolve-host.sh is missing beside this script" >&2
    return 1
  fi
  host="$(bash "$root/resolve-host.sh" . 2>/dev/null)" || return 1
  [ -n "$host" ] || return 1
  printf '%s\n' "$root/hosts/$host"
}

changelog_section() {
  local version="${1#v}"
  awk -v want="$version" '
    $0 ~ "^## \\[" want "\\]" { inside = 1; print; next }
    inside && /^## \[/ { exit }
    inside { print }
  ' CHANGELOG.md
}

# True when CHANGELOG.md already has a section naming this milestone.
#
# The codename field of a heading is a LIST, not a single name:
#
#   ## [0.0.11] - Governance
#   ## [0.0.12] - Automation & Convergence
#
# The second form exists because two milestones can both finish before either
# ships. Governance/VERSIONING_POLICY.md allows one version to carry several
# rather than inventing a number for a release that never happened, so a
# milestone is released when it is named ANYWHERE in the list — not only when
# it is the whole field. The earlier version compared the whole field, which
# would have reported both halves of v0.0.12 as unreleased forever, on every
# subsequent release: a permanently-red condition 1, which is the failure mode
# the comment above this function's caller exists to describe.
#
# Splitting in awk rather than building a grep pattern from the name is
# deliberate. A milestone name is free text from the registry, and a name
# containing a regex metacharacter would otherwise decide its own match.
#
# The whole field is compared BEFORE it is split, and that order is load
# bearing: v0.0.10.1 shipped as "Consistency & Compliance Hardening", a single
# milestone whose own name contains " & ". Splitting alone turns it into two
# names that match nothing, so a released milestone reads as unreleased. The
# first draft of this function did exactly that, and the falsifier caught it —
# the separator is ambiguous, so the unsplit reading has to be tried first.
milestone_released() {
  awk -v want="$1" '
    /^## \[[0-9.]+\] - / {
      names = $0
      sub(/^## \[[0-9.]+\] - /, "", names)
      gsub(/\015/, "", names)
      if (names == want) { found = 1; exit }
      n = split(names, parts, / & /)
      for (i = 1; i <= n; i++) {
        if (parts[i] == want) { found = 1; exit }
      }
    }
    END { exit found ? 0 : 1 }
  ' CHANGELOG.md
}

# --------------------------------------------------- changelog fragments ----
#
# One fragment per Work Unit, changelog.d/<Work Unit id>.md, instead of an
# edit of CHANGELOG.md in every Work Unit's Pull Request. Two Pull Requests
# that each append a line to the same CHANGELOG.md category conflict; two
# that each add their own file do not. changelog.d/README.md is the format,
# changelog-fragment.awk beside this script is the format as code.

FRAGMENT_DIR="changelog.d"
FRAGMENT_PARSER="$SCRIPT_DIR/changelog-fragment.awk"

# The Work Unit ids registered against one milestone, sorted.
milestone_wu_ids() {
  awk -v m="$1" '
    /^  - id: / { id = $0; sub(/^  - id: /, "", id); gsub(/\015/, "", id) }
    /^    milestone: / { ms = $0; sub(/^    milestone: /, "", ms); gsub(/\015/, "", ms)
                         if (ms == m && id != "") print id }
  ' Registry/work-units.yml | sort -u
}

# The CHANGELOG.md section whose heading names the milestone, heading
# included, carriage returns dropped. Before the bump that is
# "## [Unreleased] - <milestone>"; after it, "## [x.y.z] - <milestone>". The
# codename field is a list, read as milestone_released reads it: the whole
# field first, then split on " & ".
milestone_section() {
  awk -v want="$1" '
    { gsub(/\015/, "") }
    /^## \[/ {
      if (inside) exit
      names = substr($0, 5)
      names = substr(names, index(names, "]") + 1)
      if (substr(names, 1, 3) != " - ") next
      names = substr(names, 4)
      hit = (names == want)
      n = split(names, parts, / & /)
      for (i = 1; i <= n; i++) if (parts[i] == want) hit = 1
      if (hit) { inside = 1; print; next }
    }
    inside { print }
  ' CHANGELOG.md
}

# The Work Unit ids a CHANGELOG.md section accounts for, read from stdin.
#
# A Work Unit counts when it is named in the FINAL parenthesised group of a
# BULLET — the last line of a "- " item and its indented continuations —
# "... (#262, WU-IAENG-353)". That is the convention every CHANGELOG.md line
# of this repository follows, and the place the assembler puts the id: it
# appends it to the bullet's last line (changelog-fragment.awk, flush). A
# mention anywhere else does not count: the [Unreleased] bullet that
# documents the up-front reservation names WU-IAENG-376 to WU-IAENG-380 in its
# text, and none of those Work Units has an entry. Nor does the final group of
# a wrapped bullet's FIRST line, which is a mention like any other.
#
# Ceiling, stated rather than hidden: any id in that final group counts, so
# "(follow-up of WU-IAENG-9)" accounts for WU-IAENG-9. The parser reads the
# group the same way, and a group naming two Work Units is this changelog's
# convention for a shared entry.
#
# An exemption assembled from a "No changelog entry:" fragment is the comment
# line "<!-- No changelog entry (<id>): <reason> -->", and counts only in that
# exact shape: one id, a non-empty reason, and the closing "-->" on the same
# line. An unclosed one hides the rest of the section in the published notes,
# and one with no reason is the silent omission this condition exists to
# catch (SEC-IAENG-378-01, N1).
section_accounted_ids() {
  awk '
    function item_end(    line, i, open, grp) {
      line = last
      last = ""
      if (line == "") return
      sub(/[ \t]+$/, "", line)
      if (substr(line, length(line), 1) != ")") return
      open = 0
      for (i = length(line); i > 0; i--) if (substr(line, i, 1) == "(") { open = i; break }
      if (!open) return
      grp = substr(line, open + 1, length(line) - open - 1)
      while (match(grp, /WU-[A-Za-z0-9]+-[0-9]+/)) {
        print substr(grp, RSTART, RLENGTH)
        grp = substr(grp, RSTART + RLENGTH)
      }
    }
    { gsub(/\015/, "") }
    /^<!-- No changelog entry \(/ {
      item_end()
      rest = substr($0, length("<!-- No changelog entry (") + 1)
      close_at = index(rest, "): ")
      if (close_at == 0) next
      id = substr(rest, 1, close_at - 1)
      reason = substr(rest, close_at + 3)
      if (id !~ /^WU-[A-Za-z0-9]+-[0-9]+$/) next
      if (substr(reason, length(reason) - 3) != " -->") next
      reason = substr(reason, 1, length(reason) - 4)
      if (reason !~ /[^ \t]/ || index(reason, "--") > 0) next
      print id
      next
    }
    /^- / { item_end(); last = $0; next }
    /^[ \t]+[^ \t]/ { if (last != "") last = $0; next }
    { item_end() }
    END { item_end() }
  ' | sort -u
}

# ---------------------------------------------------------------- check ----

cmd_check() {
  local target="${1:-}"
  # Whether Step 2's output is already present. Set from the VERSION.md and
  # CHANGELOG.md checks below, read by the closing line.
  STEP2_DONE=0
  # Whether Step 7 already happened for this version — a tag exists for it.
  ALREADY_RELEASED=0
  RELEASED_VERSION=""

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
      STEP2_DONE=0
      bad "CHANGELOG.md has no section for ${check_version}" "Step 7 builds the GitHub Release notes from it. Without the section there is nothing to publish, which is how v0.0.10 and v0.0.10.1 both shipped with a bare tag."
    else
      local lines
      lines="$(printf '%s\n' "$section" | grep -c . || true)"
      ok "CHANGELOG.md section for ${check_version} present ($lines non-empty lines)"
      # Reported rather than failed: a tagged version on develop is the normal
      # state between one release and the next bump, not an error. It changes
      # what the closing line should say, and nothing else.
      if git rev-parse -q --verify "refs/tags/v${check_version#v}" >/dev/null 2>&1; then
        note "v${check_version#v} is already tagged — this version has shipped"
        ALREADY_RELEASED=1
        RELEASED_VERSION="$check_version"
      fi
      # STEP 2'S OUTPUT, OBSERVED. Workflows/RELEASE.md Step 2 states its
      # output as "develop carries the final VERSION.md and CHANGELOG.md for
      # this release", and those are exactly the two conditions just checked.
      # Recording it here is what lets the closing line say which step is
      # actually next instead of always naming Step 2 — a gate that reads the
      # output of a step and then tells the reader to perform it.
      STEP2_DONE=1
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
        milestone_released "$m" || printf '%s\n' "$m"
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
      # NO ORDINAL. A commit with more than one `Work Unit:` line is refused by
      # Adapters/git-hooks/commit-msg and by the work-unit-exists CI check, so
      # a conforming commit has exactly one and there is nothing to rank.
      #
      # The rule here still differs from those two readers, and the difference
      # is the question. They VALIDATE — every claim must resolve, so all lines
      # are checked. This ATTRIBUTES — which Work Unit does this commit perform
      # — which needs one answer. Applying all-lines here would count a quoted
      # id as merged, which is the defect this reader had before.
      #
      # An earlier version took the LAST matching line, on the reasoning that
      # the failure direction would be a false FAIL. That reasoning was wrong
      # and review reproduced the false PASS: a commit conforming to the
      # current Standard, with a deferral note quoting an id after the trailer
      # block, flipped a blocked release to green — the quoted line was last,
      # so it counted as merged, and nothing else caught it because the quoted
      # id was itself registered and validated fine. The rule that would have
      # protected this reader is "put nothing after the trailers", which the
      # Standard correctly labels unenforced guidance; depending on guidance as
      # though it were a gate is what the ordinal was doing.
      #
      # Uniqueness removes the choice instead of choosing a better end, and
      # moves the failure to commit time for the author rather than Step 1 for
      # the Release Manager. A non-conforming multi-claim commit cannot reach
      # this branch, but if one somehow does, it is reported rather than ranked.
      # ONE git log pass over the branch, not one subprocess per commit.
      #
      # The first version ran `git log -1` inside a loop over `git rev-list`.
      # On Windows, where process creation is expensive, that alone exceeded a
      # three-minute timeout on this repository's history — and it scales with
      # total history, not with the milestone. A single stream delimited per
      # commit, partitioned in awk, is one process.
      local scan
      scan="$(git log --no-merges --format='%x01%h%n%B' "$branch" 2>/dev/null | awk '
        BEGIN { RS = "\001" }
        NR == 1 { next }
        {
          split($0, lines, "\n")
          sha = lines[1]
          count = 0; id = ""
          for (i = 2; i in lines; i++) {
            if (lines[i] ~ /^Work Unit: /) {
              count++
              id = lines[i]; sub(/^Work Unit: /, "", id); gsub(/\015/, "", id)
            }
          }
          if (count > 1)       print "MULTI\t" sha
          else if (count == 1) print "ID\t" id
        }
      ')"

      local multi_claim
      multi_claim="$(printf '%s\n' "$scan" | awk -F'\t' '$1 == "MULTI" { printf "%s ", $2 }')"
      merged_ids="$(printf '%s\n' "$scan" | awk -F'\t' '$1 == "ID" { print $2 }' | sort -u)"

      if [ -n "$multi_claim" ]; then
        # No verdict at all. A commit with two claims has no determinable
        # attribution, so the completeness answer is not merely uncertain — it
        # is unevaluated, and an unevaluated condition is a failure rather than
        # something to report alongside a reassuring total. Emitting "all N are
        # on" beside this failure is what an earlier version did, and it stated
        # something false next to something true.
        bad "cannot evaluate Work Unit completeness: $(echo "$multi_claim" | wc -w | tr -d ' ') commit(s) carry more than one 'Work Unit:' line — $multi_claim" "One Work Unit is one commit, and both the commit-msg hook and the work-unit-exists CI check refuse a second claim, so these predate that rule or bypassed it. Attribution is undeterminable for them, so no completeness verdict is given. Fix the messages or explain them before releasing."
      else
        local missing_wu="" total=0
        while IFS= read -r id; do
          [ -n "$id" ] || continue
          total=$((total + 1))
          grep -qxF "$id" <<< "$merged_ids" || missing_wu="$missing_wu$id "
        done < <(printf '%s\n' "$registry_ids")

        if [ -n "$missing_wu" ]; then
          bad "$(echo "$missing_wu" | wc -w | tr -d ' ') of $total Work Units for '$codename' are not on $branch: $missing_wu" "Each is registered against this milestone but no commit reachable from $branch carries its 'Work Unit:' trailer. Merge them, or move them to a later milestone in Registry/work-units.yml — releasing without them ships a milestone the registry says is incomplete."
        else
          ok "all $total registered Work Units for '$codename' are on $branch"
        fi
      fi
    fi
  fi

  head2 "Changelog accounting"

  # Workflows/RELEASE.md Step 1 condition 5: "Pending changelog entries account
  # for every significant change."
  #
  # Until changelog fragments, this was only the section's presence and size
  # (above), and its content was a reading task. A fragment per Work Unit makes
  # the accounting mechanical: every Work Unit registered against the milestone
  # must have a fragment waiting in changelog.d/ (an entry or a "No changelog
  # entry:" exemption), or be accounted for in the milestone's CHANGELOG.md
  # section already — the bullets written there before fragments existed, and
  # everything the assembler wrote there at Step 2. Whether each entry SAYS the
  # right thing is still a reading task; whether one EXISTS no longer is.
  #
  # After Step 2 the section is versioned and the fragments are gone. A
  # fragment still in changelog.d/ for a Work Unit of a versioned section was
  # merged after the assembly and will not ship in these notes, so it fails.
  local cl_ids cl_section cl_heading cl_accounted cl_versioned=0
  local cl_missing="" cl_unassembled="" cl_frag=0 cl_cited=0 cl_total=0
  if [ -z "$codename" ]; then
    if [ "$n_unreleased" = "0" ]; then
      ok "no unreleased milestone — no Work Unit to account for"
    else
      bad "condition 5 not evaluated: the milestone under release is not known" "Work Unit completeness above says why. Without the milestone there is no set of Work Units to account for, and an unevaluated condition is not a met one."
    fi
  elif [ ! -f Registry/work-units.yml ] || [ ! -f CHANGELOG.md ]; then
    bad "condition 5 not evaluated: Registry/work-units.yml or CHANGELOG.md is missing" "Both are needed to say which Work Units the milestone has and which are accounted for."
  elif [ ! -d "$FRAGMENT_DIR" ]; then
    bad "$FRAGMENT_DIR/ is missing" "Each Work Unit's changelog entry waits there until Step 2 assembles it (changelog.d/README.md). Without the directory no pending entry can be seen, and an unevaluated condition is not a met one."
  else
    cl_ids="$(milestone_wu_ids "$codename")"
    cl_section="$(milestone_section "$codename")"
    [ -n "$cl_section" ] || cl_section="$(changelog_section Unreleased | tr -d '\015')"
    cl_heading="$(printf '%s\n' "$cl_section" | head -1)"
    case "$cl_heading" in
      "## [Unreleased]"*|"") cl_versioned=0 ;;
      *) cl_versioned=1 ;;
    esac
    cl_accounted="$(printf '%s\n' "$cl_section" | section_accounted_ids)"
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      cl_total=$((cl_total + 1))
      if [ -f "$FRAGMENT_DIR/$id.md" ]; then
        if [ "$cl_versioned" -eq 1 ]; then
          cl_unassembled="$cl_unassembled$id "
        else
          cl_frag=$((cl_frag + 1))
        fi
      elif grep -qxF "$id" <<< "$cl_accounted"; then
        cl_cited=$((cl_cited + 1))
      else
        cl_missing="$cl_missing$id "
      fi
    done <<< "$cl_ids"

    if [ "$cl_total" -eq 0 ]; then
      bad "condition 5 not evaluated: no Work Units registered against milestone '$codename'" "The same gap Work Unit completeness reports above. Nothing was accounted for either way."
    else
      if [ -n "$cl_missing" ]; then
        bad "$(echo "$cl_missing" | wc -w | tr -d ' ') of $cl_total Work Units for '$codename' have no changelog fragment, entry or exemption: $cl_missing" "Each is registered against this milestone, has no $FRAGMENT_DIR/<id>.md, and is not named in the final parenthesised group of any line of the '${cl_heading:-[Unreleased]}' section. Add the fragment — an entry, or 'No changelog entry: <reason>' — per changelog.d/README.md."
      fi
      if [ -n "$cl_unassembled" ]; then
        bad "fragments not assembled into '${cl_heading}': $cl_unassembled" "The section is already versioned, so Step 2 ran before these were merged and they are not in the release notes. Move each entry into that section by hand, ending each line with its Work Unit id in parentheses, and delete the fragment in the same commit."
      fi
      if [ -z "$cl_missing" ] && [ -z "$cl_unassembled" ]; then
        ok "all $cl_total Work Units for '$codename' accounted for: $cl_frag fragment(s) waiting in $FRAGMENT_DIR/, $cl_cited named in '${cl_heading:-[Unreleased]}'"
      fi
    fi
  fi

  head2 "Continuous integration on $branch"

  # The host reports the conclusion; the RULE that only "success" is green
  # stays here, so every forge is judged by the same standard.
  local hd conclusion ci_err
  if ! hd="$(host_dir)"; then
    bad "could not resolve the host" "Adapters/scripts/resolve-host.sh decides which implementation reads the CI conclusion. Without it, Step 1 condition 2 cannot be evaluated, and an unevaluated condition is not a met one."
  elif [ ! -x "$hd/ci-conclusion.sh" ]; then
    bad "$hd/ci-conclusion.sh is missing" "Every host implements the four operations listed in Adapters/scripts/hosts/README.md. A missing one cannot be a pass."
  else
    ci_err="$(mktemp)"
    if conclusion="$("$hd/ci-conclusion.sh" "$branch" 2>"$ci_err")"; then
      if [ "$conclusion" = "success" ]; then
        ok "latest CI run on $branch succeeded"
      else
        bad "the latest CI run on $branch concluded '$conclusion'" "Step 1 requires green. Only success is green; anything else means shipping on a run that did not pass."
      fi
    else
      bad "could not confirm CI is green on $branch" "$(tr '\n' ' ' < "$ci_err")"
    fi
    rm -f "$ci_err"
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

  # Reported, never failed — Step 1 condition 3 is a judgment and always was.
  local bugs bugs_err bug_count
  if ! hd="$(host_dir)" || [ ! -x "$hd/open-bugs.sh" ]; then
    note "no host implementation to list open defects — review your tracker by hand for critical or high defects."
  else
    bugs_err="$(mktemp)"
    if bugs="$("$hd/open-bugs.sh" 2>"$bugs_err")"; then
      bug_count="$(printf '%s\n' "$bugs" | grep -c . || true)"
      if [ "$bug_count" -eq 0 ]; then
        ok "no open issues labelled bug"
      else
        note "$bug_count open issue(s) labelled bug — Step 1 requires confirming none is critical or high"
        note "This is a judgment call, not a mechanical one, so it is reported rather than failed."
        printf '%s\n' "$bugs" | head -5 | sed 's/^/         /'
      fi
    else
      note "open defects could not be listed: $(tr '\n' ' ' < "$bugs_err")"
      note "Nothing was established either way — that is not the same as having no blockers."
    fi
    rm -f "$bugs_err"
  fi

  head2 "Result"

  if [ "$FAILURES" -eq 0 ]; then
    if [ "${ALREADY_RELEASED:-0}" -eq 1 ]; then
      # A TAG MEANS STEP 7 HAPPENED. Everything above is then a description of
      # a release that already shipped, and "ready for Step 3" would invite
      # cutting a second release branch for a version already on main. Found
      # immediately after fixing the sibling defect (#81), by reading the very
      # output that fix produced.
      echo "   v${RELEASED_VERSION#v} is ALREADY RELEASED: the tag exists, so Step 7 is done"
      echo "   and every condition above describes a release that has shipped."
      echo "   Nothing here is ready to cut. Start the next release by bumping"
      echo "   VERSION.md and adding its CHANGELOG.md section (Step 2)."
    elif [ "${STEP2_DONE:-0}" -eq 1 ]; then
      echo "   Step 2 is already on this branch: VERSION.md and CHANGELOG.md both"
      echo "   carry this version. Ready for Step 3 (cut the release branch)."
    else
      echo "   Ready for Step 2 (version bump on develop), then Step 3 (release branch)."
    fi
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

# ------------------------------------------------------------- assemble ----
#
# Workflows/RELEASE.md Step 2: fold every fragment into the [Unreleased]
# section and delete it, in the working tree, for the bump commit.
#
# The section is rebuilt category by category in Keep a Changelog's order
# (Added, Changed, Deprecated, Removed, Fixed, Security). Under each, the
# bullets already there come first — the entries written into CHANGELOG.md
# before fragments existed, kept as they are — then the fragments' bullets,
# by Work Unit id. A heading that is not one of the six (### Notes) keeps its
# text and follows the six, in its original order. An exemption becomes the
# comment line "<!-- No changelog entry (<id>): <reason> -->" at the end of the
# section: invisible in the rendered release notes, and what lets condition 5
# of `check` see the Work Unit accounted for once its fragment is gone.
#
# All or nothing. Every fragment is parsed before CHANGELOG.md is touched, and
# one malformed fragment, or one file in changelog.d/ that is not a fragment,
# refuses the whole run with nothing changed: half an assembly would leave
# entries in two places, and a stray file would be left behind silently.
#
# Line endings: CHANGELOG.md is checked out CRLF on a Windows working tree with
# core.autocrlf, LF elsewhere. Every line is read with its carriage return
# dropped and written back with the ending the file had, so the rewrite does
# not turn into a whole-file line-ending change.
cmd_assemble() {
  if [ "$#" -gt 0 ]; then
    echo "Usage: $0 assemble" >&2
    return 2
  fi

  echo "IA Engineering — assemble changelog fragments (Workflows/RELEASE.md Step 2)"

  if [ ! -f "$FRAGMENT_PARSER" ]; then
    echo "release.sh: refusing — $FRAGMENT_PARSER is missing." >&2
    echo "  It is the one definition of a fragment, shared with validate-framework.sh." >&2
    return 1
  fi
  if [ ! -f CHANGELOG.md ]; then
    echo "release.sh: refusing — CHANGELOG.md is missing." >&2
    return 1
  fi
  if [ ! -d "$FRAGMENT_DIR" ]; then
    echo "release.sh: refusing — $FRAGMENT_DIR/ is missing." >&2
    echo "  Fragments wait there until this step. See changelog.d/README.md." >&2
    return 1
  fi
  if ! grep -qE '^## \[Unreleased\]' CHANGELOG.md; then
    echo "release.sh: refusing — CHANGELOG.md has no '## [Unreleased]' section." >&2
    echo "  Fragments are assembled into it, below the entries already there." >&2
    echo "  Add '## [Unreleased] - <Codename>' above the latest version, then" >&2
    echo "  run this again; rename it to the version after." >&2
    return 1
  fi

  local f base ids="" strays=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="${f##*/}"
    [ "$base" = "README.md" ] && continue
    # Regular files only: a symbolic link would be read from outside
    # changelog.d/ and only the link deleted (SEC-IAENG-378-01, N2).
    if [ ! -L "$f" ] && [ -f "$f" ] && [[ "$base" =~ ^WU-[A-Za-z0-9]+-[0-9]+\.md$ ]]; then
      ids="$ids${base%.md}"$'\n'
    else
      strays="$strays$f "
    fi
  done < <(find "$FRAGMENT_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)

  if [ -n "$strays" ]; then
    echo "release.sh: refusing — $FRAGMENT_DIR/ holds entries that are not fragments: $strays" >&2
    echo "  A fragment is a file named <Work Unit id>.md, for example" >&2
    echo "  WU-IAENG-378.md. Rename or remove these; nothing was changed." >&2
    return 1
  fi

  if [ -z "$ids" ]; then
    echo "   No fragment in $FRAGMENT_DIR/. CHANGELOG.md is unchanged."
    return 0
  fi

  # By the number of the id, then the id: WU-IAENG-1000 after WU-IAENG-999.
  ids="$(printf '%s' "$ids" | awk -F- '{ print $NF "\t" $0 }' | LC_ALL=C sort -t "$(printf '\t')" -k1,1n -k2,2 | cut -f2)"

  local records parsed parse_status errors="" id n_frag=0 n_exempt=0
  records="$(mktemp)"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    n_frag=$((n_frag + 1))
    # A parse that succeeds always prints at least one ENTRY, EXEMPT or ERROR
    # record. A parser that exits non-zero or prints none did not read the
    # fragment, and assembling it would delete the fragment with nothing
    # added — so it refuses the run like a malformed fragment.
    parsed="$(awk -v id="$id" -f "$FRAGMENT_PARSER" "$FRAGMENT_DIR/$id.md" 2>/dev/null)"
    parse_status=$?
    if [ "$parse_status" -ne 0 ] || ! grep -qE '^(ENTRY|EXEMPT|ERROR)'$'\t' <<< "$parsed"; then
      errors="$errors  $FRAGMENT_DIR/$id.md: the fragment parser did not run (exit $parse_status) or printed no record ($FRAGMENT_PARSER)"$'\n'
      continue
    fi
    if grep -q '^ERROR' <<< "$parsed"; then
      errors="$errors$(awk -F'\t' -v f="$FRAGMENT_DIR/$id.md" '$1 == "ERROR" { printf "  %s line %s: %s\n", f, $2, $3 }' <<< "$parsed")"$'\n'
      continue
    fi
    if grep -q '^EXEMPT' <<< "$parsed"; then
      n_exempt=$((n_exempt + 1))
      awk -F'\t' -v id="$id" '$1 == "EXEMPT" { print "EXEMPT\t" id "\t" $2 }' <<< "$parsed" >> "$records"
    else
      # "ENTRY<TAB>" dropped: the record is <Category><TAB><line>.
      awk '/^ENTRY\t/ { print substr($0, 7) }' <<< "$parsed" >> "$records"
    fi
  done <<< "$ids"

  if [ -n "$errors" ]; then
    rm -f "$records"
    echo "release.sh: refusing — malformed fragments; nothing was changed:" >&2
    printf '%s' "$errors" >&2
    echo "  The format is changelog.d/README.md's." >&2
    return 1
  fi

  local eol="" order out
  if [ "$(head -n 1 CHANGELOG.md | tr -cd '\r' | wc -c | tr -d ' ')" -gt 0 ]; then
    eol=$'\r'
  fi
  order="$(awk -v list=1 -f "$FRAGMENT_PARSER" < /dev/null 2>/dev/null | tr '\n' ' ')"
  if [ "$(printf '%s' "$order" | wc -w | tr -d ' ')" -ne 6 ]; then
    rm -f "$records"
    echo "release.sh: refusing — $FRAGMENT_PARSER did not list the six categories; nothing was changed." >&2
    return 1
  fi
  out="$(mktemp)"

  if ! awk -v recs="$records" -v order="$order" -v eol="$eol" '
    function emit(s) { printf "%s%s\n", s, eol }
    # One subsection: its heading, the lines already there (blank lines at
    # either end trimmed), then the lines the fragments add to it. When the text
    # already there ends in prose rather than a bullet — the upgrade-note
    # paragraph under ### Notes — a blank line separates the two, so the
    # first new bullet does not read as the paragraph continuing.
    function subsection(c,    a, b, j) {
      emit("### " c)
      emit("")
      a = 1; b = bn[c]
      while (a <= b && body[c, a] ~ /^[ \t]*$/) a++
      while (b >= a && body[c, b] ~ /^[ \t]*$/) b--
      for (j = a; j <= b; j++) emit(body[c, j])
      if (addn[c] > 0 && a <= b && body[c, b] !~ /^(- |[ \t])/) emit("")
      for (j = 1; j <= addn[c]; j++) emit(addl[c, j])
      emit("")
    }
    function rebuild(    i, j, c, a, b) {
      emit(heading)
      a = 1; b = npre
      while (a <= b && pre[a] ~ /^[ \t]*$/) a++
      while (b >= a && pre[b] ~ /^[ \t]*$/) b--
      emit("")
      if (a <= b) { for (j = a; j <= b; j++) emit(pre[j]); emit("") }
      for (i = 1; i <= ncat; i++) {
        c = CAT[i]
        if ((c in has) || addn[c] > 0) subsection(c)
      }
      # The other headings already in the section, in their order. ### Notes
      # is one of them when the section has upgrade notes, and receives the
      # Notes bullets of the fragments; when it has none, a ### Notes is added
      # after everything else.
      for (i = 1; i <= nsub; i++) {
        c = SUB[i]
        if (!(c in canon)) subsection(c)
      }
      if (!("Notes" in has) && addn["Notes"] > 0) subsection("Notes")
      for (i = 1; i <= nex; i++) emit(ex[i])
      if (nex > 0) emit("")
    }
    BEGIN {
      ncat = split(order, CAT, " ")
      for (i = 1; i <= ncat; i++) canon[CAT[i]] = 1
      while ((getline r < recs) > 0) {
        t = index(r, "\t"); kind = substr(r, 1, t - 1); rest = substr(r, t + 1)
        if (kind == "EXEMPT") {
          t = index(rest, "\t")
          ex[++nex] = "<!-- No changelog entry (" substr(rest, 1, t - 1) "): " substr(rest, t + 1) " -->"
        } else {
          addl[kind, ++addn[kind]] = rest
        }
      }
      state = 0
    }
    { line = $0; gsub(/\015/, "", line) }
    state == 0 && line ~ /^## \[Unreleased\]/ { state = 1; heading = line; next }
    state == 1 && line ~ /^## \[/ { rebuild(); state = 2; emit(line); next }
    state == 1 && line ~ /^### / {
      cur = substr(line, 5); sub(/[ \t]+$/, "", cur)
      if (!(cur in has)) { has[cur] = 1; SUB[++nsub] = cur }
      next
    }
    state == 1 {
      if (nsub == 0) pre[++npre] = line
      else body[cur, ++bn[cur]] = line
      next
    }
    { emit(line) }
    END { if (state == 1) rebuild() }
  ' CHANGELOG.md > "$out"; then
    rm -f "$records" "$out"
    echo "release.sh: refusing — the CHANGELOG.md rewrite failed; nothing was changed." >&2
    return 1
  fi

  # cat over the file rather than mv, so the file keeps its own mode and is
  # never absent for an instant.
  #
  # CHECKED, and before any fragment is deleted. This script runs without
  # `set -e`, so an unchecked write that failed — a read-only file, a file
  # an editor holds open on Windows, a full disk — went on to delete every
  # fragment and exit 0, and the fragments were the only copy of those
  # entries outside git history. Found in review of PR #313. A write that
  # failed part-way is undone from the copy taken before it, and the read-back
  # comparison catches a write that reported success and is not what was meant.
  local backup
  backup="$(mktemp)"
  if ! cp CHANGELOG.md "$backup"; then
    rm -f "$records" "$out" "$backup"
    echo "release.sh: refusing — CHANGELOG.md could not be copied before the write; nothing was changed." >&2
    return 1
  fi
  if ! cat "$out" > CHANGELOG.md 2>/dev/null || ! cmp -s "$out" CHANGELOG.md; then
    cat "$backup" > CHANGELOG.md 2>/dev/null
    rm -f "$records" "$out" "$backup"
    echo "release.sh: refusing — CHANGELOG.md could not be written. No fragment was deleted." >&2
    echo "  Make it writable (read-only, or held open by another program?) and run this again." >&2
    return 1
  fi
  rm -f "$out" "$backup"

  local summary
  summary="$(awk -F'\t' -v order="$order" '
    $1 != "EXEMPT" { n[$1]++ }
    END { k = split(order, c, " "); for (i = 1; i <= k; i++) if (n[c[i]]) printf "%s %s line(s), ", c[i], n[c[i]] }
  ' "$records")"
  rm -f "$records"

  local not_deleted=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    rm -f -- "$FRAGMENT_DIR/$id.md" 2>/dev/null
    [ -e "$FRAGMENT_DIR/$id.md" ] && not_deleted="$not_deleted$FRAGMENT_DIR/$id.md "
  done <<< "$ids"
  if [ -n "$not_deleted" ]; then
    echo "release.sh: CHANGELOG.md is assembled, but these fragments could not be deleted: $not_deleted" >&2
    echo "  Delete them by hand before committing, or they will be assembled a second time." >&2
    return 1
  fi

  echo "   Assembled $n_frag fragment(s) into [Unreleased]: ${summary:-no entry lines, }$n_exempt exemption(s)."
  echo "   Deleted: $(printf '%s' "$ids" | tr '\n' ' ')"
  echo
  echo "   Next, in the same Step 2 Work Unit: rename '## [Unreleased]' to the"
  echo "   version, then commit CHANGELOG.md and the deletions together"
  echo "   (git add CHANGELOG.md $FRAGMENT_DIR)."
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
  # Name the implementation that will actually run, not a GitHub command the
  # host may not have. A plan that describes a different action than the one
  # --confirm performs is worse than no plan.
  local plan_hd
  if plan_hd="$(host_dir)"; then
    echo "    $plan_hd/create-release.sh $version \"$version — ${codename:-}\" <changelog section>"
  else
    echo "    <host unresolved> create-release.sh $version \"$version — ${codename:-}\" <changelog section>"
  fi
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

  # The tag is pushed by now, so a failure below leaves a real and incomplete
  # state. The notes file is therefore NOT deleted on failure: it is what a
  # human needs to finish Step 7 by hand, and re-deriving it means extracting
  # the CHANGELOG section correctly under pressure.
  local hd
  if ! hd="$(host_dir)" || [ ! -x "$hd/create-release.sh" ]; then
    echo "   No host implementation to create a Release — the tag is pushed and" >&2
    echo "   Step 7 is INCOMPLETE. A tag without release notes is an incomplete" >&2
    echo "   release (Governance/VERSIONING_POLICY.md, Versioning and Release" >&2
    echo "   Completeness). Publish by hand from: $notes_file" >&2
    return 1
  fi

  if ! "$hd/create-release.sh" "$version" "$version — ${codename:-}" "$notes_file"; then
    echo "   Step 7 is INCOMPLETE: the tag is pushed and no Release exists." >&2
    echo "   The notes are kept at $notes_file — publish from that file rather" >&2
    echo "   than re-deriving them." >&2
    return 1
  fi
  echo "   Release created with notes from CHANGELOG.md"

  rm -f "$notes_file"

  cat <<'REMAINING'

   Remaining, per Workflows/RELEASE.md:
     Step 8   Back-merge to develop via Pull Request. ALWAYS required, on every
              release: Step 6 left a merge commit on main that develop never
              otherwise sees, and skipping it blocks the next release's Pull
              Request to main. Additionally, any defect fix that landed directly
              on the release branch during Step 4 is carried back by it.
     Step 9   Post-release verification — QA Engineer and Observability
              Engineer confirm production health.
     Step 10  Preserve the release branch. It is never deleted.
     Step 11  Release retrospective — Scrum Master, dispatched by the Main
              Agent once the release is tagged. One Issue, "Release
              retrospective vX.X.X", that the Director decides in one pass,
              recorded before the next milestone's first Work Unit is planned.
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
  assemble) shift; cmd_assemble "$@" ;;
  notes)   shift; cmd_notes "${1:-}" ;;
  publish) shift; cmd_publish "${1:-}" "${2:-}" ;;
  --help|-h|help)
    sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}'
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Usage: $0 {check [version] [--milestone <name>] | assemble | notes <version> | publish <version> [--confirm]}" >&2
    exit 2
    ;;
esac
