#!/usr/bin/env bash
# IA Engineering — setup-project-bootstrap.sh
#
# Installs the "v0.0.10 — Project Bootstrap" Adapters into a newly-bootstrapped
# project (see Workflows/PROJECT_BOOTSTRAP.md). It mirrors the Installation
# section of Adapters/README.md: copy the shipped artifacts into place so a
# fresh project gets real CI/CD and container publishing mechanically.
#
# What it installs:
#   - Adapters/github-actions/ci-build-test.yml -> .github/workflows/
#   - Adapters/github-actions/ghcr-publish.yml  -> .github/workflows/
#   - Adapters/dockerfiles/<stack>.Dockerfile   -> ./Dockerfile
#
# Run from the root of the target project.
#
# Usage:
#   ./setup-project-bootstrap.sh <stack>
#     where <stack> is one of: node | python | go | jvm | generic

set -euo pipefail

VALID_STACKS="node python go jvm generic"

STACK="${1:-}"
if [ -z "$STACK" ]; then
  echo "Usage: $0 <stack>   (one of: $VALID_STACKS)" >&2
  exit 1
fi

# Validate the requested stack against the known set.
case " $VALID_STACKS " in
  *" $STACK "*) ;;
  *)
    echo "Error: unknown stack '$STACK'. Expected one of: $VALID_STACKS" >&2
    exit 1
    ;;
esac

# Resolve the Adapters directory relative to this script, so the script works
# regardless of the caller's current directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Installing IA Engineering project-bootstrap adapters (stack: $STACK)"

# 1. CI + GHCR workflows -> .github/workflows/
mkdir -p .github/workflows
cp "$ADAPTERS_DIR/github-actions/ci-build-test.yml" .github/workflows/
cp "$ADAPTERS_DIR/github-actions/ghcr-publish.yml" .github/workflows/
echo "-> .github/workflows/ci-build-test.yml"
echo "-> .github/workflows/ghcr-publish.yml"

# 2. Stack-appropriate Dockerfile -> ./Dockerfile
DOCKERFILE_SRC="$ADAPTERS_DIR/dockerfiles/$STACK.Dockerfile"
if [ ! -f "$DOCKERFILE_SRC" ]; then
  echo "Error: no starter Dockerfile for stack '$STACK' at $DOCKERFILE_SRC" >&2
  exit 1
fi
cp "$DOCKERFILE_SRC" ./Dockerfile
echo "-> ./Dockerfile (from $STACK.Dockerfile)"

# 3. Issue templates -> .github/ISSUE_TEMPLATE/
# TODO(WU-IAENG-112): a sibling Work Unit (WU-IAENG-111) is concurrently
# authoring Adapters/github/ISSUE_TEMPLATE/. Once it has merged, WU-IAENG-112
# will add the copy step here, e.g.:
#     mkdir -p .github/ISSUE_TEMPLATE
#     cp -R "$ADAPTERS_DIR/github/ISSUE_TEMPLATE/." .github/ISSUE_TEMPLATE/
# Do NOT enable this until those source files exist in the repository.

echo "Done. Review the copied workflows and ./Dockerfile, then commit them."
