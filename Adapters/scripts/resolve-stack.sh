#!/usr/bin/env bash
# IA Engineering — resolve-stack.sh
#
# Prints the project's stack on stdout, one word, and nothing else there.
# Everything explanatory goes to stderr so the caller can use the result
# directly: `stack="$(resolve-stack.sh)"`.
#
# A DECLARATION BEATS A GUESS
#
# setup-project-bootstrap.sh writes `.ia-engineering/stack` with the stack it
# was told to install, so the answer is recorded rather than inferred.
#
# Inference works only while one manifest file means one stack, and it stops
# working the moment two stacks share one. A React site and a Node server both
# have package.json, and no rule over file names tells them apart without
# guessing — which is why a `web` stack could not exist while detection was the
# only mechanism. Recording the answer is what makes more stacks possible at
# all, not merely tidier.
#
# AN UNRECOGNISED DECLARATION FAILS
#
# It does not fall back to sniffing. Falling back would turn a typo in that
# file into a silent switch to a different build, which then reports success
# for a stack nobody chose — the same shape as the IAENG_PROJECT_ROSTER defect,
# where a wrong path degraded quietly into validating against a narrower set.
#
# WHY THIS IS A SCRIPT
#
# It was written inline in ci-build-test.yml first, and that was the same
# mistake this milestone exists to undo: logic in a workflow file can only be
# tested by deploying it. Its cases live in Adapters/scripts/tests/run.sh.
#
# USAGE
#
#   resolve-stack.sh [project-root]      (default: the current directory)
#
# Exit 0 with the stack on stdout; 1 when a declaration exists and names
# something unknown.

set -uo pipefail

KNOWN_STACKS="node python go jvm generic"

ROOT="${1:-.}"
if [ ! -d "$ROOT" ]; then
  echo "resolve-stack: no such directory: $ROOT" >&2
  exit 1
fi

DECLARATION="$ROOT/.ia-engineering/stack"

if [ -f "$DECLARATION" ]; then
  # [:space:] rather than an escape list: it covers CR from a Windows checkout
  # as well as stray spaces and the trailing newline, and it needs no backslash
  # to survive whatever writes this file.
  stack="$(tr -d '[:space:]' < "$DECLARATION")"

  if [ -z "$stack" ]; then
    echo "::error::$DECLARATION exists but is empty. Write the stack into it (one of: $KNOWN_STACKS), or delete the file to fall back to manifest detection. An empty declaration is not a declaration, and treating it as one would pick a stack nobody wrote down." >&2
    exit 1
  fi

  case " $KNOWN_STACKS " in
    *" $stack "*)
      echo "Stack declared in $DECLARATION: $stack" >&2
      printf '%s\n' "$stack"
      exit 0
      ;;
    *)
      echo "::error::$DECLARATION declares '$stack', which is not one of: $KNOWN_STACKS. Fix the declaration, or delete the file to fall back to manifest detection. Guessing instead would build a stack nobody chose and report success." >&2
      exit 1
      ;;
  esac
fi

# No declaration: infer. First match wins, and the order is the precedence.
# This keeps a project that predates the declaration building exactly as before.
if   [ -f "$ROOT/package.json" ];                                            then stack=node
elif [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ];       then stack=python
elif [ -f "$ROOT/go.mod" ];                                                  then stack=go
elif [ -f "$ROOT/pom.xml" ] || [ -f "$ROOT/build.gradle" ] || [ -f "$ROOT/build.gradle.kts" ]; then stack=jvm
else stack=generic
fi

echo "No $DECLARATION; inferred from manifests: $stack" >&2
echo "::notice::This project's stack was inferred, not declared. Run setup-project-bootstrap.sh, or write the stack into .ia-engineering/stack, so the build does not depend on which manifest happens to exist." >&2
printf '%s\n' "$stack"
