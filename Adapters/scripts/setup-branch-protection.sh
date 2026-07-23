#!/usr/bin/env bash
# IA Engineering — setup-branch-protection.sh
#
# Configures GitHub branch protection on main, develop, and release/* via the
# GitHub API instead of relying on written policy alone, matching:
#   - Standards/BRANCH_STANDARD.md — no direct push to protected branches
#   - Workflows/CODE_REVIEW.md — a Pull Request must be reviewed before merge
#   - Adapters/github-actions/pr-validation.yml — its three jobs (PR
#     Compliance, Shellcheck Adapters, Validate Workflow YAML) become
#     required status checks once this script has run (main/develop only —
#     see the release/* section below for why they are NOT required there)
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
    "contexts": ["PR Compliance", "Shellcheck Adapters", "Validate Workflow YAML"]
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
# Deliberately NOT included: a "required_status_checks" rule for the PR
# Compliance / Shellcheck Adapters / Validate Workflow YAML contexts used on
# main/develop. Adapters/github-actions/pr-validation.yml is scoped with
# `on.pull_request.branches: [main, develop]` — it does not trigger for PRs
# targeting a release/* branch at all. Requiring status checks that can never
# be reported would permanently deadlock every release/* PR (GitHub blocks
# merge on "Expected — waiting for status to be reported" forever). Making
# these checks meaningful for release/* would require widening that
# workflow's `branches:` trigger, which is out of scope for this Work Unit
# (only this script is touched here) — flagged in this Work Unit's report as
# a candidate follow-up.
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

echo "Done. Verify at: https://github.com/$REPO/settings/branches"
