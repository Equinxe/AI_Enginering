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

KNOWN_STACKS="node web python go jvm dotnet php generic"

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

# No declaration: infer from manifests.
#
# AMBIGUITY IS REPORTED, NOT RANKED. The first version took the first match in
# a fixed order, which quietly answered a question it could not settle: a
# Laravel application has composer.json AND package.json, and a Python service
# with a JavaScript front end has both of those too. First-match-wins picks one
# and builds it, and the project is never told the other was equally true.
#
# So every match is collected. Exactly one is an answer. More than one is a
# question only the project can answer, and it is asked rather than guessed —
# the same rule release.sh applies when two milestones have no CHANGELOG
# section. The remedy is one line in one file, and the message gives it.
#
# `web` is deliberately absent here and cannot be inferred at all. A React site
# and a Node server both have package.json, and nothing in the file names
# separates a bundle of static files from a running server. It exists only as
# a declaration, which is what made the stack possible to add.
# A count and a first-match, rather than a list that has to be split back into
# words later. Splitting would need `set -- $MATCHES` unquoted, which is
# correct here but reads as a bug and would need a shellcheck directive to say
# otherwise — Standards/CODE_QUALITY_STANDARD.md asks for the restructure
# instead, and the restructure is also simpler.
MATCH_COUNT=0
MATCH_LIST=""
FIRST_MATCH=""
add_match() {
  MATCH_COUNT=$((MATCH_COUNT + 1))
  [ -n "$FIRST_MATCH" ] || FIRST_MATCH="$1"
  MATCH_LIST="${MATCH_LIST:+$MATCH_LIST, }$1"
}

[ -f "$ROOT/package.json" ]  && add_match node
[ -f "$ROOT/composer.json" ] && add_match php
[ -f "$ROOT/go.mod" ]        && add_match go
{ [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ]; } && add_match python
{ [ -f "$ROOT/pom.xml" ] || [ -f "$ROOT/build.gradle" ] || [ -f "$ROOT/build.gradle.kts" ]; } && add_match jvm
# A .NET project is named after itself, so these are globs and not fixed names.
#
# Tested one expansion at a time rather than with `ls glob glob glob`, which
# exits non-zero as soon as ANY operand is missing — so a project with a
# .csproj and no .sln reported no match at all, and .NET was undetectable. The
# suite caught it; the failure was silent and would not have shown up until a
# real .NET project built as `generic`.
#
# An unmatched glob stays literal in POSIX shells, so `[ -e ]` on it is false,
# which is exactly the test wanted here.
any_exists() {
  local candidate
  for candidate in "$@"; do
    [ -e "$candidate" ] && return 0
  done
  return 1
}
if any_exists "$ROOT"/*.csproj "$ROOT"/*.fsproj "$ROOT"/*.sln; then add_match dotnet; fi

case "$MATCH_COUNT" in
  0)
    stack=generic
    echo "No $DECLARATION and no recognised manifest; using: generic" >&2
    ;;
  1)
    stack="$FIRST_MATCH"
    echo "No $DECLARATION; inferred from manifests: $stack" >&2
    ;;
  *)
    echo "::error::No $DECLARATION, and this project matches $MATCH_COUNT stacks: $MATCH_LIST. Inference cannot settle that — a Laravel application has composer.json and package.json and both are true. Declare it instead: write one of ($KNOWN_STACKS) into .ia-engineering/stack. Picking one here would build it and report success without ever saying the other was equally likely." >&2
    exit 1
    ;;
esac

echo "::notice::This project's stack was inferred, not declared. Run setup-project-bootstrap.sh, or write the stack into .ia-engineering/stack, so the build does not depend on which manifest happens to exist." >&2
printf '%s\n' "$stack"
