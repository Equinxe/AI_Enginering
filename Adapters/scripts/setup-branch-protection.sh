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
# Usage:
#   ./setup-branch-protection.sh [owner/repo]
#
# If owner/repo is omitted, it is detected from the current directory's git
# remote via `gh repo view`.

set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

echo "Configuring branch protection on $REPO for: main, develop, release/*"

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

# The two GitHub APIs used below want the same list in different shapes:
# classic branch protection takes a bare array of context strings, while the
# Rulesets API takes objects. Both are derived from the one array above so the
# release/* ruleset cannot end up requiring a different set than main/develop.

contexts_json() {
  local out="" c
  for c in "${REQUIRED_CHECKS[@]}"; do
    out="$out, \"$c\""
  done
  printf '%s' "${out#, }"
}

ruleset_checks_json() {
  local out="" c
  for c in "${REQUIRED_CHECKS[@]}"; do
    out="$out, { \"context\": \"$c\" }"
  done
  printf '%s' "${out#, }"
}

protect_branch() {
  local branch="$1"
  echo "-> $branch"
  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "repos/$REPO/branches/$branch/protection" \
    --input - <<EOF > /dev/null
{
  "required_status_checks": {
    "strict": true,
    "contexts": [$(contexts_json)]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
  echo "   protected."
}

for branch in main develop; do
  if gh api "repos/$REPO/branches/$branch" > /dev/null 2>&1; then
    protect_branch "$branch"
  else
    echo "-> $branch: branch not found on remote, skipped."
  fi
done

# --- release/* -------------------------------------------------------------
#
# Why this needs a different API than main/develop above:
#
# The classic protection endpoint used by `protect_branch()`
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
# update by id), consistent with how `protect_branch()` above already talks
# to the GitHub API — no GraphQL needed.
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
RELEASE_RULESET_NAME="release-branch-protection"

release_ruleset_payload() {
  cat <<EOF
{
  "name": "$RELEASE_RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/release/*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [$(ruleset_checks_json)]
      }
    }
  ]
}
EOF
}

protect_release_branches() {
  echo "-> release/* (ruleset)"

  local existing_id
  existing_id="$(gh api "repos/$REPO/rulesets" -q \
    ".[] | select(.name == \"$RELEASE_RULESET_NAME\") | .id" 2>/dev/null || true)"

  if [ -n "$existing_id" ]; then
    release_ruleset_payload | gh api \
      --method PUT \
      -H "Accept: application/vnd.github+json" \
      "repos/$REPO/rulesets/$existing_id" \
      --input - > /dev/null
  else
    release_ruleset_payload | gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      "repos/$REPO/rulesets" \
      --input - > /dev/null
  fi

  echo "   protected."
}

protect_release_branches

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
