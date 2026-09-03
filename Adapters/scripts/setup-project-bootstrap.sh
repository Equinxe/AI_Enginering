#!/usr/bin/env bash
# IA Engineering — setup-project-bootstrap.sh
#
# Scaffolds a newly-bootstrapped project so that running this script, plus
# setup-branch-protection.sh, actually satisfies Workflows/PROJECT_BOOTSTRAP.md's
# Coverage Checklist — rather than leaving items on it that no script performs.
#
# WHAT CHANGED IN WU-IAENG-142, and why it mattered:
#
# This script previously installed only the two CI workflows and a Dockerfile,
# and carried a TODO deferring its issue-template step to a follow-up Work Unit
# pending files that were being written concurrently. Those files shipped in
# v0.0.10 and the TODO was never removed, so the script stayed permanently one
# step short of the workflow that points at it. PROJECT_BOOTSTRAP.md Step 6
# requires issue templates and its Coverage Checklist lists them, but the
# script named as the mechanism silently skipped them. A project bootstrapped
# by following the workflow exactly ended up without them, with nothing
# reporting the omission.
#
# It also left Step 4's pr-validation.yml and PR template to be copied by hand,
# so the checklist could only ever be completed with manual steps the workflow
# did not spell out.
#
# The host-agnostic half is now delegated to install.sh rather than duplicated:
# git hooks, pr-validation.yml, framework-validation.yml, the PR template, the
# issue templates, and the .gitattributes LF rules. This script owns only what
# genuinely depends on the stack chosen in PROJECT_BOOTSTRAP.md Phase B, which
# is the one thing install.sh cannot know.
#
# What it installs:
#   everything install.sh installs (hooks, CI, templates, line endings)
#   Adapters/github-actions/ci-build-test.yml -> .github/workflows/
#   Adapters/github-actions/ghcr-publish.yml  -> .github/workflows/
#   Adapters/dockerfiles/<stack>.Dockerfile   -> ./Dockerfile
#
# Still not installed here, deliberately: branch protection. It mutates shared
# repository settings through the GitHub API and needs an authenticated `gh`;
# run Adapters/scripts/setup-branch-protection.sh once per repository.
#
# Run from the root of the target project.
#
# Usage:
#   ./setup-project-bootstrap.sh <stack> [--dry-run] [--force]
#     where <stack> is one of: node | python | go | jvm | generic

set -euo pipefail

VALID_STACKS="node python go jvm generic"

STACK=""
PASSTHROUGH=()

for arg in "$@"; do
  case "$arg" in
    --dry-run|--force) PASSTHROUGH+=("$arg") ;;
    --help|-h)
      sed -n '2,46p' "$0"
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
    *)
      if [ -n "$STACK" ]; then
        echo "Error: more than one stack given ('$STACK' and '$arg')." >&2
        exit 2
      fi
      STACK="$arg"
      ;;
  esac
done

if [ -z "$STACK" ]; then
  echo "Usage: $0 <stack> [--dry-run] [--force]   (stack: $VALID_STACKS)" >&2
  exit 1
fi

# Validate the requested stack against the known set.
case " $VALID_STACKS " in
  *" $STACK "*) ;;
  *)
    echo "Error: unknown stack '$STACK'. Expected one of: $VALID_STACKS" >&2
    echo "  Workflows/PROJECT_BOOTSTRAP.md's Escalation table covers this case:" >&2
    echo "  a stack outside Node, Python, Go, and JVM uses the Generic fallback" >&2
    echo "  template as a starting point, with any gaps documented." >&2
    exit 1
    ;;
esac

# Resolve the Adapters directory relative to this script, so the script works
# regardless of the caller's current directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=0
for arg in "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}"; do
  [ "$arg" = "--dry-run" ] && DRY_RUN=1
done

echo "IA Engineering — project bootstrap (stack: $STACK)"
echo

# 1. Everything host-agnostic, via the single installer.
echo "--- Host-agnostic Adapters (install.sh) ---"
"$SCRIPT_DIR/install.sh" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"} || true
echo

# 2. Stack-dependent CI and container publishing.
echo "--- Stack Adapters ---"

copy_into() {
  local src="$1" dest="$2"
  if [ ! -f "$src" ]; then
    echo "Error: $src is missing from the framework." >&2
    exit 1
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] cp $src $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "  + $dest"
}

copy_into "$ADAPTERS_DIR/github-actions/ci-build-test.yml" ".github/workflows/ci-build-test.yml"
copy_into "$ADAPTERS_DIR/github-actions/ghcr-publish.yml" ".github/workflows/ghcr-publish.yml"

DOCKERFILE_SRC="$ADAPTERS_DIR/dockerfiles/$STACK.Dockerfile"
if [ ! -f "$DOCKERFILE_SRC" ]; then
  echo "Error: no starter Dockerfile for stack '$STACK' at $DOCKERFILE_SRC" >&2
  exit 1
fi
if [ -f Dockerfile ] && ! printf '%s\n' "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}" | grep -qx -- '--force'; then
  echo "  ! ./Dockerfile already exists — left untouched. A bootstrapped project" >&2
  echo "    gets a starter Dockerfile; an existing one is the project's own and" >&2
  echo "    overwriting it silently would discard real work. Re-run with --force" >&2
  echo "    to replace it with the $STACK starter." >&2
else
  copy_into "$DOCKERFILE_SRC" "./Dockerfile"
fi
echo

# 3. Report the Coverage Checklist items this script cannot complete, so they
#    are visible rather than assumed done. PROJECT_BOOTSTRAP.md's Exit Criteria
#    requires every checklist item, and the items below need a decision, a
#    Director, or an authenticated API call — not a file copy.
echo "--- Remaining Coverage Checklist items (Workflows/PROJECT_BOOTSTRAP.md) ---"
echo "  Branch protection      ./$(realpath --relative-to=. "$SCRIPT_DIR" 2>/dev/null || echo "$SCRIPT_DIR")/setup-branch-protection.sh"
echo "  main + develop created git branch develop && git push -u origin develop"
echo "  README.md              from the Phase A answers (project identity)"
echo "  .gitignore             stack-appropriate for $STACK"
echo "  Project Charter        Templates/PROJECT_CHARTER.md, from Phase A"
echo "  Stack Decision ADR     Templates/ADR.md, Accepted before this step per"
echo "                         Workflows/ARCHITECTURE_DECISION.md"
echo "  CLAUDE.md + roster     Workflows/ONBOARDING.md Step 4"
echo "  First Work Unit        Workflows/ONBOARDING.md Step 6, Director-approved"
echo
echo "Review the copied workflows and ./Dockerfile, then commit them."
