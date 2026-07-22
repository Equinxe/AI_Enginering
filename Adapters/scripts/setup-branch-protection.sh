#!/usr/bin/env bash
# IA Engineering — setup-branch-protection.sh
#
# Configures GitHub branch protection on main and develop via the GitHub API
# instead of relying on written policy alone, matching:
#   - Standards/BRANCH_STANDARD.md — no direct push to protected branches
#   - Workflows/CODE_REVIEW.md — a Pull Request must be reviewed before merge
#   - Adapters/github-actions/pr-validation.yml — its "validate" job becomes
#     a required status check once this script has run
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
# (Workflows/CODE_REVIEW.md) plus the required "validate" status check, not a
# GitHub-native approval count. `required_approving_review_count` is therefore
# 0, and `enforce_admins` is false so the repository owner (Director) can
# still merge. If a project later has genuinely separate human/bot GitHub
# accounts reviewing each other, raise these back up.
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

echo "Configuring branch protection on $REPO for: main, develop"

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
    "contexts": ["validate"]
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

echo "Done. Verify at: https://github.com/$REPO/settings/branches"
