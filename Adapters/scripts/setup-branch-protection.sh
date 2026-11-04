#!/usr/bin/env bash
# IA Engineering — setup-branch-protection.sh
#
# Configures GitHub branch protection on main, develop, and release/* via the
# GitHub API instead of relying on written policy alone, matching:
#   - Standards/BRANCH_STANDARD.md — no direct push to protected branches
#   - Workflows/CODE_REVIEW.md — a Pull Request must be reviewed before merge
#   - Adapters/github-actions/pr-validation.yml and
#     Adapters/github-actions/framework-validation.yml — their blocking jobs
#     (PR Compliance, Work Unit Exists, Employee Trailer, Shellcheck Adapters,
#     Validate Workflow YAML, Hook Tests, Script Tests, PR Size, Framework
#     Validation, Data Policy) become required status checks once this
#     script has run, on main, develop, AND release/*
#   - the Director's decision of 22 Oct 2026 (issue #299) — `strict` (a
#     branch must be up to date with its base before merging) is ON for main
#     and release/* and OFF for develop. See strict_for() below.
#   - Workflows/RELEASE.md — "The release branch `release/vX.X.X` is never
#     deleted. It serves as a permanent snapshot of the exact state released
#     to production." This script is what makes `allow_deletions: false`
#     mechanically true for release branches, not just written policy.
#
# Requires: GitHub CLI (`gh`), authenticated (`gh auth status`).
#
# This mutates shared repository settings. Review the payload below before
# running it against a real repository.
#
# IMPORTANT — single-identity constraint: GitHub does not allow a PR author to
# formally "Approve" their own PR. In an IA Engineering project where every
# Employee (and the Director) acts through the same authenticated `gh`
# identity, there is no second account available to provide that approval —
# requiring a formal approving review deadlocks every PR. The real review gate
# here is the Code Reviewer Employee's documented review comment
# (Workflows/CODE_REVIEW.md) plus the required PR Compliance/Shellcheck/YAML
# status checks, not a
# GitHub-native approval count. `required_approving_review_count` is therefore
# 0, and `enforce_admins` is false so the repository owner (Director) can
# still merge. If a project later has genuinely separate human/bot GitHub
# accounts reviewing each other, raise these back up.
#
# The same single-identity rationale applies to release/* below: its ruleset
# also uses `required_approving_review_count: 0` and grants the repository
# admin role an "always" bypass — the closest ruleset equivalent to classic
# protection's `enforce_admins: false` — for the identical reason: there is no
# second `gh` identity available to formally approve, and the Director must
# still be able to merge a PR-based defect fix into a release branch.
#
# Those values apply only where a repository requires nothing more. On a
# repository with protection of its own, a run keeps it: the required checks
# become the union of the project's and the framework's, and no count or
# setting is lowered (issue #447, WU-IAENG-433). See "Reading before writing"
# below.
#
# Usage:
#   ./setup-branch-protection.sh [owner/repo]
#
# If owner/repo is omitted, it is detected from the current directory's git
# remote via `gh repo view`.

set -euo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# THIS SCRIPT IS THE GITHUB IMPLEMENTATION, and now establishes that before it
# acts. The host is resolved here; what to do about a different one is decided
# after REQUIRED_CHECKS is defined, because the checklist enumerates it.
if [ -x "$SCRIPT_DIR/resolve-host.sh" ]; then
  HOST="$(bash "$SCRIPT_DIR/resolve-host.sh" . 2>/dev/null || echo unknown)"
else
  HOST=github
  echo "resolve-host.sh not found beside this script; assuming github." >&2
fi

REPO=""
if [ "$HOST" = "github" ]; then
  REPO="${1:-}"
  if [ -z "$REPO" ]; then
    REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  fi
fi


# The blocking checks every protected branch requires, kept in one place so
# main, develop, and the release/* ruleset cannot drift apart.
#
# "Employee Trailer" and "Framework Validation" were added in WU-IAENG-144.
# Employee Trailer shipped in v0.0.10.1 but was left out of the required set
# pending a decision, which meant the server-side backstop for Dispatch
# Discipline reported its result and blocked nothing — a commit with no
# Employee attribution could still merge past a red check.
#
# "Script Tests" was added in WU-IAENG-229, after the four PR checks moved out
# of pr-validation.yml and into Adapters/scripts/check-*.sh. Without it the
# move would have been a downgrade: the logic portable and covered by 80 cases,
# and none of them run by anything that blocks a merge. Requiring the suite is
# what makes the extraction an improvement rather than a relocation.
#
# It was added ONLY AFTER the job had reported on a real Pull Request. A
# required check that has never reported blocks every merge on a status that
# cannot appear, and GitHub offers no way to distinguish "not yet run" from
# "will never run" — this repository has already had to sequence a merge before
# a protection change once for exactly that reason.
#
# "Review Recorded (advisory)" is deliberately NOT here. It matches comment
# text, which is softer evidence than a native gate and can be satisfied by
# pasting the block; making it required would buy false confidence. Promoting
# it stays a Director decision, as its own job comment states.
REQUIRED_CHECKS=(
  "PR Compliance"
  "Work Unit Exists"
  "Employee Trailer"
  "Shellcheck Adapters"
  "Validate Workflow YAML"
  "Hook Tests"
  "Script Tests"
  "PR Size"
  "Framework Validation"
  "Data Policy"
)

# Branch protection is the FIFTH forge-dependent operation, alongside the four
# in Adapters/scripts/hosts/. It is not under hosts/ yet, and that is a
# deliberate stop rather than an oversight: moving two hundred lines of GitHub
# API calls into a directory shaped for a second forge, with no second forge to
# verify the shape against, is motion that cannot be checked. It gets its fifth
# operation when there is an instance to prove it on.
#
# What changes now is the FAILURE. Run on another forge, this used to call the
# GitHub API against it and fail with whatever that API said. It recognises the
# host first now and prints what a human must configure by hand — the same
# bargain the `none` implementations make, because an adopter off GitHub
# deserves a checklist rather than an authentication error.
if [ "$HOST" != "github" ]; then
  echo "host '$HOST': this script configures GitHub branch protection and cannot" >&2
  echo "configure yours. Nothing was changed." >&2
  echo >&2
  echo "Configure the equivalent by hand on main, develop and release/*:" >&2
  echo >&2
  echo "  - require these status checks to pass before merging:" >&2
  for c in "${REQUIRED_CHECKS[@]}"; do
    echo "      $c" >&2
  done
  echo "  - require the branch to be up to date with its base before merging, on main" >&2
  echo "    and release/* only: NOT on develop (Director, 22 Oct 2026)" >&2
  echo "  - refuse force-pushes" >&2
  echo "  - refuse branch deletion" >&2
  echo "  - require a pull request for every change" >&2
  echo "  - turn OFF automatic head-branch deletion on merge, if your forge has" >&2
  echo "    it. On GitHub that setting bypasses the deletion rule entirely, and" >&2
  echo "    Workflows/RELEASE.md Step 10 is unconditional: release branches are" >&2
  echo "    never deleted." >&2
  echo >&2
  echo "'Review Recorded (advisory)' is deliberately NOT in that list: it matches" >&2
  echo "comment text, which can be satisfied by pasting the block, so requiring it" >&2
  echo "would buy false confidence." >&2
  exit 1
fi

echo "Configuring branch protection on $REPO for: main, develop, release/*"

# The two GitHub APIs used below want the same list in different shapes:
# classic branch protection takes a bare array of context strings, while the
# Rulesets API takes objects. Both are derived from this one list, given to
# both merge programs below, so the release/* ruleset cannot end up requiring
# a different set than main/develop.

contexts_json() {
  local out="" c
  for c in "${REQUIRED_CHECKS[@]}"; do
    out="$out, \"$c\""
  done
  printf '%s' "${out#, }"
}

# strict_for <branch> — whether <branch> requires a Pull Request's head to be
# up to date with it before merging (`required_status_checks.strict`).
#
# ON FOR main, OFF FOR develop. The Director set develop to strict=false on
# 22 Oct 2026 and kept main and release/* strict (issue #299). Until
# WU-IAENG-384 this script sent `"strict": true` for both, so re-running it
# quietly undid that decision. The value now lives here, per branch, and
# Adapters/scripts/tests/run.sh asserts the body sent for each.
#
# What the setting changes: with strict on, a Pull Request cannot merge until
# its branch contains the base's tip, so every merge into the base sends every
# other open Pull Request back for an update and a fresh run of its checks.
# With it off, a Pull Request on develop merges once its required checks have
# passed on its own head. main and release/* keep strict: what merges there is
# what ships.
#
# This is the framework's value, and it never turns strict off. Where a
# branch's own protection already has strict on, it stays on, develop
# included (WU-IAENG-433): the merge below takes the repository's value OR
# this one. So a run never makes develop strict, and never undoes a project
# that made it so.
#
# release/* is not set here: its ruleset sets
# `strict_required_status_checks_policy: true` in RULESET_JQ below.
# A branch with no decided value fails rather than getting a guessed one.
#
# No run of this script reaches that refusal: the loop below names main and
# develop only. Adapters/scripts/tests/run.sh therefore extracts this function,
# from its `strict_for() {` line to the first `}` at the start of a line, and
# calls it alone with a release branch (issue #329). Keep that shape, or the
# test stops finding the function and fails.
strict_for() {
  case "$1" in
    main) echo true ;;
    develop) echo false ;;
    *)
      echo "strict_for: no strict value decided for branch '$1'" >&2
      return 1
      ;;
  esac
}

# --- Reading before writing --------------------------------------------------
#
# AN EXISTING REPOSITORY KEEPS WHAT IT ALREADY ENFORCES (issue #447). Until
# WU-IAENG-433 this script sent GitHub's PUT a body built from constants, and
# that PUT replaces a branch's protection whole. A project's own required
# checks were dropped, its approvals set to 0 and enforce_admins turned off,
# and every setting the body left out went back to its default. On a real
# repository that is a destructive change to a security boundary.
#
# Each branch's protection is now read first, then merged by PROTECTION_JQ.
# The required checks are the union of the project's and REQUIRED_CHECKS.
# Every setting the project turned on stays on, every count stays at least
# what it was, and the framework's rules are added: no force-push, no
# deletion, stale reviews dismissed, strict per strict_for. Nothing is
# lowered. The release/* ruleset is merged the same way, by RULESET_JQ.
#
# EVERY READ COMES BEFORE THE FIRST WRITE, and every read fails closed. A
# read that fails stops the run with nothing changed. It is never taken for
# "no protection" or "no such branch", which `2>/dev/null || true` and an
# unconditional "skipped" used to make of it.
#
# THE MERGE RUNS IN gh's OWN jq (`gh api -q`), so the script needs nothing but
# gh. A branch with no protection has no answer to filter, so its body comes
# from the same program run on `{}`, carried by a read of the repository that
# has already succeeded. One program builds both bodies, and they cannot
# drift apart. The program is passed on one line: a line break inside an
# argument is the part of a command line least sure to reach gh.exe intact
# on Windows.
#
# ONE KNOWN LIMIT. A required check pinned to a GitHub App (`checks[].app_id`)
# is sent back by name, in `contexts`, which is what this script has always
# sent. GitHub then pins it to the app that last reported it (REST docs,
# Update branch protection, `contexts`), the same app in every ordinary case.

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
APPLIED=""

# gh_read <api path> [jq filter] — GET, its stdout in $TMP_DIR/out and its
# stderr in $TMP_DIR/err; returns gh's exit status. On an HTTP error gh writes
# the response body to stdout and "gh: <message> (HTTP <status>)" to stderr,
# so answered() looks in both.
gh_read() {
  if [ $# -gt 1 ]; then
    gh api "$1" -q "$2" > "$TMP_DIR/out" 2> "$TMP_DIR/err"
  else
    gh api "$1" > "$TMP_DIR/out" 2> "$TMP_DIR/err"
  fi
}
answered() { grep -qF -- "$1" "$TMP_DIR/out" "$TMP_DIR/err"; }

# GitHub's answer when the repository's plan has no branch protection: HTTP
# 403, "Upgrade to GitHub Pro or make this repository public to enable this
# feature." (issue #448).
refused_for_plan() { answered "Upgrade to GitHub" || answered "make this repository public"; }

say_applied() {
  if [ -z "$APPLIED" ]; then
    echo "Nothing was changed."
  else
    echo "Already applied before the refusal: $APPLIED."
  fi
}

# A private repository on GitHub Free (issue #448). The REST docs: "Protected
# branches are available in public repositories with GitHub Free and GitHub
# Free for organizations, and in public and private repositories with GitHub
# Pro, GitHub Team, GitHub Enterprise Cloud, and GitHub Enterprise Server."
refuse_plan() {
  {
    echo "GitHub refuses branch protection and rulesets on $REPO. It answered:"
    sed 's/^/  /' "$TMP_DIR/err"
    echo
    echo "GitHub offers them on a private repository only with a paid plan (GitHub Pro,"
    echo "Team or Enterprise): on GitHub Free they exist on public repositories only."
    say_applied
    echo
    echo "Until the repository is public or on such a plan, nothing on GitHub enforces"
    echo "the framework's rules. What still does is not a boundary:"
    echo "  - the local git hooks, on each clone where install.sh installed them. A clone"
    echo "    without them, or --no-verify, goes around them;"
    echo "  - the CI checks. They still run on every Pull Request, but they cannot be required:"
    echo "    a red check does not block a merge."
    echo "On a private repository the checks also spend the plan's Actions minutes."
    echo "See Governance/TROUBLESHOOTING.md, entry AD, for the cost and the options."
  } >&2
  exit 1
}

# refuse_read <what> — a read failed: say what, and what GitHub answered.
refuse_read() {
  refused_for_plan && refuse_plan
  {
    echo "setup-branch-protection.sh: cannot read $1. GitHub answered:"
    if [ -s "$TMP_DIR/err" ]; then sed 's/^/  /' "$TMP_DIR/err"; else echo "  (nothing)"; fi
    echo "Every read comes before the first write, so this stops the run."
    say_applied
  } >&2
  exit 1
}

# apply <what> <gh api arguments...> — one write; a refusal stops the run and
# says what was already applied.
apply() {
  local what="$1"
  shift
  if ! gh api "$@" > /dev/null 2> "$TMP_DIR/err"; then
    : > "$TMP_DIR/out"
    refused_for_plan && refuse_plan
    {
      echo "   FAILED: GitHub refused the change to $what. It answered:"
      sed 's/^/     /' "$TMP_DIR/err"
      say_applied
    } >&2
    exit 1
  fi
  APPLIED="${APPLIED:+$APPLIED, }$what"
}

# PROTECTION_JQ — merge_protection($strict; $ours; $branch) reads a branch's
# protection as GitHub's GET returns it, or {} for none, and prints three
# lines: the PUT body, what it kept that the framework does not require ("-"
# for nothing), and the strict value the body sends. Field names: REST docs,
# Get and Update branch protection. The GET answers with objects
# ({"enabled": true}, users with a login, teams and apps with a slug); the PUT
# takes booleans and lists of names. A setting that is off in the GET is left
# out of the body, which GitHub reads as its default, off. A branch with no
# protection therefore gets the same body this script has always sent. No `#`
# comment in here: the program is joined onto one line.
PROTECTION_JQ="$(cat <<'JQ'
def logins: [(. // [])[] | .login];
def slugs: [(. // [])[] | .slug];
def actors: {users: (.users | logins), teams: (.teams | slugs), apps: (.apps | slugs)};
def merge_protection($strict; $ours; $branch):
  . as $cur
  | ($cur.required_pull_request_reviews // {}) as $rpr
  | ($cur.required_status_checks // {}) as $rsc
  | ($rsc.contexts // [($rsc.checks // [])[] | .context]) as $have
  | {
      required_status_checks: {
        strict: (($rsc.strict // false) or $strict),
        contexts: ($have + ($ours - $have))
      },
      enforce_admins: ($cur.enforce_admins.enabled // false),
      required_pull_request_reviews: (
        {
          required_approving_review_count: ($rpr.required_approving_review_count // 0),
          dismiss_stale_reviews: true
        }
        + ({
            require_code_owner_reviews: ($rpr.require_code_owner_reviews // false),
            require_last_push_approval: ($rpr.require_last_push_approval // false)
          } | with_entries(select(.value == true)))
        + (if $rpr.dismissal_restrictions then {dismissal_restrictions: ($rpr.dismissal_restrictions | actors)} else {} end)
        + (if $rpr.bypass_pull_request_allowances then {bypass_pull_request_allowances: ($rpr.bypass_pull_request_allowances | actors)} else {} end)
      ),
      restrictions: (if $cur.restrictions then ($cur.restrictions | actors) else null end),
      allow_force_pushes: false,
      allow_deletions: false
    }
    + ({
        required_linear_history: ($cur.required_linear_history.enabled // false),
        block_creations: ($cur.block_creations.enabled // false),
        required_conversation_resolution: ($cur.required_conversation_resolution.enabled // false),
        lock_branch: ($cur.lock_branch.enabled // false),
        allow_fork_syncing: ($cur.allow_fork_syncing.enabled // false)
      } | with_entries(select(.value == true)))
    as $body
  | [ (($have - $ours) | select(length > 0) | "required checks of its own: " + join(", ")),
      (($rpr.required_approving_review_count // 0) | select(. > 0) | "required approvals: " + tostring),
      (select($cur.enforce_admins.enabled == true) | "enforce_admins"),
      (select(($rsc.strict // false) and ($strict | not)) | "strict, up to date before merging"),
      (select($rpr.require_code_owner_reviews == true) | "code-owner review"),
      (select($rpr.require_last_push_approval == true) | "last-push approval"),
      (select($rpr.dismissal_restrictions) | "who may dismiss reviews"),
      (select($rpr.bypass_pull_request_allowances) | "who may bypass reviews"),
      (select($cur.restrictions) | "push restrictions"),
      (select($cur.required_linear_history.enabled == true) | "linear history"),
      (select($cur.required_conversation_resolution.enabled == true) | "conversation resolution"),
      (select($cur.block_creations.enabled == true) | "block_creations"),
      (select($cur.lock_branch.enabled == true) | "lock_branch"),
      (select($cur.allow_fork_syncing.enabled == true) | "allow_fork_syncing")
    ] as $kept
  | ($body | tojson),
    (if ($kept | length) > 0 then "kept on " + $branch + ": " + ($kept | join("; ")) else "-" end),
    ($body.required_status_checks.strict | tostring);
JQ
)"
PROTECTION_JQ="$(printf '%s' "$PROTECTION_JQ" | tr '\n' ' ')"

# save_merged <name> <what> — $TMP_DIR/out holds the lines a merge prints:
# the body goes to $TMP_DIR/<name>.json, the kept line to <name>.kept and the
# strict value, where there is one, to <name>.strict. An answer that is not a
# JSON object is a failed read of <what>, never an empty body.
save_merged() {
  sed -n 1p "$TMP_DIR/out" > "$TMP_DIR/$1.json"
  sed -n 2p "$TMP_DIR/out" > "$TMP_DIR/$1.kept"
  sed -n 3p "$TMP_DIR/out" > "$TMP_DIR/$1.strict"
  case "$(cat "$TMP_DIR/$1.json")" in
    "{"*"}") ;;
    *)
      : > "$TMP_DIR/err"
      refuse_read "$2: the answer is not a JSON object"
      ;;
  esac
}

# The repository: its default branch and its visibility.
gh_read "repos/$REPO" '.default_branch + " " + .visibility' || refuse_read "the repository $REPO"
DEFAULT_BRANCH="" VISIBILITY=""
read -r DEFAULT_BRANCH VISIBILITY < "$TMP_DIR/out" || true
[ -n "$DEFAULT_BRANCH" ] || refuse_read "the default branch of $REPO"

# THE DEFAULT BRANCH IS PROTECTED, OR THE RUN REFUSES (issue #447). The script
# protects main, develop and release/* (Standards/BRANCH_STANDARD.md). A
# default branch with another name, master for example, would stay
# unprotected while the run reported done. Protecting it with main's rules
# would be a guess at what it is, the same guess strict_for() refuses.
case "$DEFAULT_BRANCH" in
  main | develop) ;;
  *)
    {
      echo "The default branch of $REPO is '$DEFAULT_BRANCH'. This script protects main, develop"
      echo "and release/* (Standards/BRANCH_STANDARD.md), so '$DEFAULT_BRANCH' would stay unprotected."
      echo "Nothing was changed."
      echo
      echo "Either make main the default branch, a decision for the project (GitHub Docs,"
      echo "\"Renaming a branch\"), then run this script again; or protect '$DEFAULT_BRANCH' by hand"
      echo "in Settings > Branches with the rules main gets here."
    } >&2
    exit 1
    ;;
esac

BRANCHES=()
for branch in main develop; do
  strict="$(strict_for "$branch")" || exit 1
  if ! gh_read "repos/$REPO/branches/$branch"; then
    if answered "Branch not found"; then
      echo "-> $branch: branch not found on remote, skipped."
      continue
    fi
    refuse_read "branch '$branch' of $REPO"
  fi
  filter="$PROTECTION_JQ merge_protection($strict; [$(contexts_json)]; \"$branch\")"
  if gh_read "repos/$REPO/branches/$branch/protection" "$filter"; then
    :
  elif answered "Branch not protected"; then
    gh_read "repos/$REPO" "$PROTECTION_JQ {} | merge_protection($strict; [$(contexts_json)]; \"$branch\")" \
      || refuse_read "the repository $REPO"
  else
    refuse_read "the protection of branch '$branch' of $REPO"
  fi
  save_merged "$branch" "the protection of branch '$branch' of $REPO"
  BRANCHES+=("$branch")
done

# --- release/* -------------------------------------------------------------
#
# Why this needs a different API than main/develop above:
#
# The classic protection endpoint used for main and develop
# (`PUT /repos/{owner}/{repo}/branches/{branch}/protection`) takes an exact,
# already-existing branch name in its path — it has no concept of a wildcard
# pattern, so it can only ever protect one already-created branch at a time.
# Release branches (`release/vX.X.X`, see Workflows/RELEASE.md) are cut fresh
# for every release and never deleted, so the set of branches matching
# `release/*` keeps growing — calling the classic endpoint per existing
# branch would miss every future release branch not yet created.
#
# GitHub's newer Repository Rulesets API
# (`/repos/{owner}/{repo}/rulesets`) solves this: a ruleset's
# `conditions.ref_name.include` accepts a glob pattern (`refs/heads/release/*`)
# and is evaluated against every ref, present or future, matching that
# pattern — exactly the "release/*" wildcard this Work Unit's audit finding
# calls for. This is still a plain `gh api` REST call (POST to create, PUT to
# update by id), consistent with how main and develop are protected above —
# no GraphQL needed.
#
# Rule choices, mapped to the Definition of Done:
#   - "deletion"          -> blocks branch deletion (the literal audit fix:
#                            `allow_deletions: false` for release/*, matching
#                            Workflows/RELEASE.md's "never deleted" policy).
#   - "non_fast_forward"  -> blocks force-pushes, same as main/develop.
#   - "pull_request"      -> blocks direct pushes; changes must land via a
#                            Pull Request, which is exactly the "minor defect
#                            fix" workflow this Work Unit exists to enable
#                            (PR-based fix targeting the release branch
#                            itself, reviewed like everywhere else, instead of
#                            the unreviewed direct push that happened during
#                            the v0.0.10 release).
#
#   - "required_status_checks" -> the same REQUIRED_CHECKS as main and develop.
#
# That last rule was previously absent, and the reason was sound at the time:
# pr-validation.yml was scoped to `[main, develop]`, so it never triggered for
# a PR targeting a release branch, and requiring a check that can never be
# reported deadlocks the PR forever on "Expected — waiting for status to be
# reported". The note here flagged widening that trigger as a candidate
# follow-up.
#
# WU-IAENG-144 did the widening. pr-validation.yml and
# framework-validation.yml now include `release/**`, so the checks do report on
# release-branch PRs and can safely be required. This closes a real hole rather
# than a theoretical one: Workflows/RELEASE.md Step 4 routes every
# release-branch defect fix through a PR, so those were the only PRs in the
# entire process running with no validation at all — on the branch that
# becomes the production release.
#
# AN EXISTING release-branch-protection RULESET IS MERGED, NOT REPLACED
# (issue #447), as main and develop are. Its own required checks stay, each
# with the app it must come from (`integration_id`). Its approval count stays
# at least what it was, and a rule the project added stays. Its bypass list is
# kept as it is: the admin bypass below goes only into a ruleset this script
# creates, never back into one whose bypass a project removed. Only the
# repository's own ruleset of that name is updated: the list also returns an
# organization's rulesets (`includes_parents` is true by default, REST docs,
# Get all repository rulesets).
RELEASE_RULESET_NAME="release-branch-protection"

# RULESET_JQ — merge_ruleset($name; $ours) reads a ruleset as GitHub's GET
# returns it, or {} for a new one, and prints the body and the kept line, as
# merge_protection does. Field names: REST docs, Rules (Get and Update a
# repository ruleset, and the pull_request and required_status_checks rule
# parameters).
RULESET_JQ="$(cat <<'JQ'
def merge_ruleset($name; $ours):
  . as $cur
  | ($cur.rules // []) as $rules
  | ([$rules[] | select(.type == "pull_request")][0].parameters // {}) as $pr
  | ([$rules[] | select(.type == "required_status_checks")][0].parameters // {}) as $sc
  | ($sc.required_status_checks // []) as $have
  | [$have[] | .context] as $have_names
  | ($cur.conditions.ref_name.include // []) as $include
  | [$rules[] | select(.type | IN("deletion", "non_fast_forward", "pull_request", "required_status_checks") | not)
      | {type} + (if has("parameters") then {parameters} else {} end)] as $others
  | {
      name: $name,
      target: "branch",
      enforcement: "active",
      bypass_actors: (if ($cur | has("id")) then ($cur.bypass_actors // [])
                      else [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always"}] end),
      conditions: {ref_name: {
        include: ($include + (["refs/heads/release/*"] - $include)),
        exclude: ($cur.conditions.ref_name.exclude // [])
      }},
      rules: (
        [ {type: "deletion"},
          {type: "non_fast_forward"},
          {type: "pull_request", parameters: ($pr + {
            required_approving_review_count: ($pr.required_approving_review_count // 0),
            dismiss_stale_reviews_on_push: true,
            require_code_owner_review: ($pr.require_code_owner_review // false),
            require_last_push_approval: ($pr.require_last_push_approval // false),
            required_review_thread_resolution: ($pr.required_review_thread_resolution // false)
          })},
          {type: "required_status_checks", parameters: ($sc + {
            strict_required_status_checks_policy: true,
            required_status_checks: ($have + [($ours - $have_names)[] | {context: .}])
          })}
        ] + $others
      )
    } as $body
  | [ (($have_names - $ours) | select(length > 0) | "required checks of its own: " + join(", ")),
      (($pr.required_approving_review_count // 0) | select(. > 0) | "required approvals: " + tostring),
      (select(($cur | has("id")) and (($cur.bypass_actors // []) | length) == 0) | "no bypass"),
      ([$others[] | .type] | select(length > 0) | "rules of its own: " + join(", "))
    ] as $kept
  | ($body | tojson),
    (if ($kept | length) > 0 then "kept on release/*: " + ($kept | join("; ")) else "-" end);
JQ
)"
RULESET_JQ="$(printf '%s' "$RULESET_JQ" | tr '\n' ' ')"
RULESET_CALL="merge_ruleset(\"$RELEASE_RULESET_NAME\"; [$(contexts_json)])"

gh_read "repos/$REPO/rulesets" \
  ".[] | select(.name == \"$RELEASE_RULESET_NAME\" and .source_type == \"Repository\") | .id" \
  || refuse_read "the rulesets of $REPO"
RULESET_ID="$(head -n 1 "$TMP_DIR/out")"
case "$RULESET_ID" in
  "")
    gh_read "repos/$REPO" "$RULESET_JQ {} | $RULESET_CALL" || refuse_read "the repository $REPO"
    ;;
  *[!0-9]*)
    : > "$TMP_DIR/err"
    refuse_read "the rulesets of $REPO: the id of $RELEASE_RULESET_NAME is not a number"
    ;;
  *)
    gh_read "repos/$REPO/rulesets/$RULESET_ID" "$RULESET_JQ $RULESET_CALL" \
      || refuse_read "the ruleset $RELEASE_RULESET_NAME of $REPO"
    ;;
esac
save_merged release "the ruleset $RELEASE_RULESET_NAME of $REPO"

# A PRIVATE REPOSITORY WITH NEITHER main NOR develop ON GITHUB YET (issue
# #448). The plan refusal above shows on a protection read, and with no
# branch to read there was none. A ruleset created on a private repository
# whose plan lacks rulesets may be accepted and still not enforced, which
# would read as protection and be none. A public repository has protection on
# every plan (REST docs, Branch protection), so only a non-public one stops.
if [ "${#BRANCHES[@]}" -eq 0 ] && [ "$VISIBILITY" != public ]; then
  {
    echo "setup-branch-protection.sh: cannot tell whether GitHub enforces branch protection on $REPO."
    echo "It is $VISIBILITY, and neither main nor develop exists on GitHub yet, so no protection"
    echo "could be read. Push main first, then run this script again."
    say_applied
  } >&2
  exit 1
fi

# --- Writing ------------------------------------------------------------------
#
# Every read above succeeded. A write that fails now stops the run, and the
# message names what was already applied.
show_kept() {
  local kept
  kept="$(cat "$TMP_DIR/$1.kept")"
  [ "$kept" = "-" ] || echo "   $kept"
}

# ${BRANCHES[@]+...}: an empty array under `set -u` is an error in bash
# before 4.4, macOS's /bin/bash 3.2 among them.
for branch in ${BRANCHES[@]+"${BRANCHES[@]}"}; do
  echo "-> $branch (strict: $(cat "$TMP_DIR/$branch.strict"))"
  show_kept "$branch"
  apply "$branch" --method PUT -H "Accept: application/vnd.github+json" \
    "repos/$REPO/branches/$branch/protection" --input - < "$TMP_DIR/$branch.json"
  echo "   protected."
done

echo "-> release/* (ruleset)"
show_kept release
if [ -n "$RULESET_ID" ]; then
  apply "release/*" --method PUT -H "Accept: application/vnd.github+json" \
    "repos/$REPO/rulesets/$RULESET_ID" --input - < "$TMP_DIR/release.json"
else
  apply "release/*" --method POST -H "Accept: application/vnd.github+json" \
    "repos/$REPO/rulesets" --input - < "$TMP_DIR/release.json"
fi
echo "   protected."

# --- Automatic head-branch deletion -----------------------------------------
#
# THE RULESET'S `deletion` RULE DOES NOT STOP THE ONE DELETION THAT HAPPENS.
#
# `release/*` carries a deletion rule, and on 8 September 2026 merging a
# release Pull Request deleted `release/v0.0.12` anyway. GitHub's automatic
# head-branch deletion is performed by the platform itself and is not evaluated
# against rulesets. So the rule stops a human or a token running
# `git push --delete`, and does nothing about the only realistic way a release
# branch disappears.
#
# CLAUDE.md and Workflows/RELEASE.md Step 10 both say release branches are
# never deleted. A protection that reads as enforcement and is not one is worse
# than no protection, because it is trusted.
#
# THE SETTING IS REPOSITORY-WIDE, and that cost is real: feature branches stop
# being tidied up on merge too. It is applied rather than offered because the
# framework's rule is unconditional — a project that prefers the tidy-up can
# turn it back on, having read this, and accept that release branches then
# depend on nobody clicking the button.
echo "-> repository: automatic head-branch deletion"

current="$(gh api "repos/$REPO" --jq '.delete_branch_on_merge' 2>/dev/null || echo "unknown")"
if [ "$current" = "false" ]; then
  echo "   already off."
else
  gh api --method PATCH "repos/$REPO" -F delete_branch_on_merge=false > /dev/null

  # VERIFIED, NOT ASSUMED. install.sh proves the hook it installed rejects an
  # invalid trailer rather than asserting that copying a file worked; the same
  # standard applies to an API call whose failure mode is silence.
  after="$(gh api "repos/$REPO" --jq '.delete_branch_on_merge' 2>/dev/null || echo "unknown")"
  if [ "$after" = "false" ]; then
    echo "   turned off (was: $current)."
  else
    echo "   FAILED: delete_branch_on_merge is still '$after' after the update." >&2
    echo "   Release branches will be deleted on merge despite the release/* deletion rule," >&2
    echo "   which does not apply to GitHub's own automatic deletion. Fix this in" >&2
    echo "   Settings > General > Pull Requests before running a release." >&2
    exit 1
  fi
fi

echo "Done. Verify at: https://github.com/$REPO/settings/branches"
