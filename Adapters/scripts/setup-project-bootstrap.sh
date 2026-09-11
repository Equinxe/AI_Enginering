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
#     where <stack> is one of: node | web | python | go | jvm | dotnet | php | generic
#
#     `web` is a static front end (React, Vue, Svelte, Astro, a site
#     generator): it builds with Node and ships files behind a web
#     server, with no Node in the runtime image. It is the one stack that
#     cannot be inferred, because a site and a server both have
#     package.json — which is why the chosen stack is recorded.

set -euo pipefail

VALID_STACKS="node web python go jvm dotnet php generic"

STACK=""
PASSTHROUGH=()

for arg in "$@"; do
  case "$arg" in
    --dry-run|--force) PASSTHROUGH+=("$arg") ;;
    --help|-h)
      sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}'
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
    echo "  a stack outside the list above uses the Generic fallback" >&2
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
#
# The exit status is CAPTURED, not discarded. It previously ended in
# `|| true`, which threw away the two conditions install.sh works hardest to
# detect: pre-existing hooks in .git/hooks that core.hooksPath will make git
# ignore entirely and silently, and — worse — its own negative probe result,
# "the commit-msg hook ACCEPTED 'Employee: executor' ... installed but not
# enforcing". That probe is the strongest single piece of evidence either
# script produces, and its verdict was being deleted one line after it was
# computed.
#
# Because this script then ended on an echo, its exit status was that echo's:
# zero. So a project could follow Workflows/PROJECT_BOOTSTRAP.md Step 4
# exactly, receive exit 0, and have a commit-msg hook installed and not
# enforcing. Step 4 was rewritten in this same milestone to say this script
# "verifies the installed commit-msg hook actually rejects an invalid Employee
# trailer" — true of install.sh, false of the script the workflow told you to
# run. Found in review.
#
# `|| true` was load-bearing only because of `set -euo pipefail`: the goal is
# to survive the failure and finish the stack-specific half, not to forget it.
# A hook problem should not stop the Dockerfile being installed.
echo "--- Host-agnostic Adapters (install.sh) ---"
INSTALL_RC=0
"$SCRIPT_DIR/install.sh" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"} || INSTALL_RC=$?
echo

# 2. Stack-dependent CI and container publishing.
echo "--- Stack Adapters ---"

copy_into() {
  local src="$1" dest="$2"
  if [ ! -f "$src" ]; then
    echo "Error: $src is missing from the framework." >&2
    exit 1
  fi
  # AN EXISTING FILE IS THE PROJECT'S OWN WORK, and is left untouched without
  # --force. This matters most when adopting into an ALREADY-STARTED project:
  # if it happens to have a file at one of these paths, overwriting it silently
  # would discard real work — the same reason the Dockerfile below is guarded.
  # Greenfield projects have none of these, so nothing changes for them.
  if [ -f "$dest" ] && ! printf '%s\n' "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}" | grep -qx -- '--force'; then
    echo "  ! $dest already exists — left untouched (the project's own). Re-run with --force to replace it with the framework's." >&2
    return
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

# THE STACK IS RECORDED, NOT LEFT TO BE GUESSED LATER.
#
# ci-build-test.yml used to infer the stack from whichever manifest file it
# found first. That works only while one manifest means one stack, and it
# stops working the moment two stacks share one: a React site and a Node
# server both have package.json, and no rule over file names can tell them
# apart without guessing. Guessing in a build gate is the defect class this
# framework catalogues everywhere else.
#
# This script already knows the answer — it was given it as an argument — so
# it writes it down. CI reads the declaration and only falls back to sniffing
# manifests when there is none, which keeps an existing project that never ran
# this script working exactly as before.
#
# .ia-engineering/ is where a project keeps what is true of it, and part of
# that directory is already committed and read by CI: the project roster at
# .ia-engineering/Registry/employees.yml, which the Employee Trailer check
# unions in. Only SESSION_STATE.md is gitignored. So this file belongs there
# and must be COMMITTED — a declaration CI cannot read declares nothing.
STACK_FILE=".ia-engineering/stack"
if [ -f "$STACK_FILE" ] && ! printf '%s\n' "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}" | grep -qx -- '--force'; then
  echo "  ! $STACK_FILE already exists (declares '$(tr -d '[:space:]' < "$STACK_FILE")') — left untouched." >&2
  echo "    Re-run with --force to change the declared stack." >&2
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "  [dry-run] write $STACK_FILE containing '$STACK'"
else
  mkdir -p "$(dirname "$STACK_FILE")"
  printf '%s\n' "$STACK" > "$STACK_FILE"
  echo "  + $STACK_FILE ($STACK)  — commit this; CI reads it"
fi

# A STARTER RISK MAP, FOR THE FILES THIS SCRIPT JUST INSTALLED — AND ONLY THOSE.
#
# Standards/RISK_STANDARD.md: a project without a Risk Map is unclassified, not
# safe, and the Risk Map CI check says so on the first Pull Request. That is the
# right behaviour and it is also the first thing an adopter meets, so the
# mechanical part is done here: the workflows, the Dockerfile and the
# .gitattributes this script wrote are infrastructure, and the map itself is the
# one file whose errors are invisible by construction.
#
# WHAT THIS DELIBERATELY DOES NOT DO is declare any category absent. Only the
# project knows whether it authenticates anyone or stores personal data, and a
# false declaration of absence switches the category off — the Standard calls
# that worse than an omission. So the `absent:` block is left empty on purpose,
# and check-risk-map.sh will list the unaccounted categories by name until the
# project searches for each one. An honest incomplete map that says what is
# missing beats a complete-looking one that guesses.
RISK_MAP_FILE=".ia-engineering/risk-map.yml"
if [ -f "$RISK_MAP_FILE" ] && ! printf '%s\n' "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}" | grep -qx -- '--force'; then
  echo "  ! $RISK_MAP_FILE already exists — left untouched. It is the project's own" >&2
  echo "    classification; re-run with --force to replace it with the starter." >&2
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "  [dry-run] write $RISK_MAP_FILE (starter: installed files only, no category declared absent)"
else
  mkdir -p "$(dirname "$RISK_MAP_FILE")"
  cat > "$RISK_MAP_FILE" <<'RISKMAP'
# Risk Map — STARTER, written by setup-project-bootstrap.sh
#
# Change-zone levels per Standards/RISK_STANDARD.md: routine | standard | sensitive.
# Patterns are matched in order and the FIRST match wins. `*` crosses `/`.
# How to finish this, and the five ways a map goes wrong: Templates/RISK_MAP.md.
#
# This starter classifies ONLY the files the bootstrap installed. It declares no
# category absent, because only this project knows what it authenticates, stores
# or spends — and a false declaration of absence switches a category off.
# `check-risk-map.sh` will name the unaccounted categories until each is either
# mapped to paths below or declared absent with a reason someone else can check.
#
# Verify after committing (the check reads tracked files):
#   ./ia-engineering/Adapters/scripts/check-risk-map.sh
#   ./ia-engineering/Adapters/scripts/check-risk-map.sh --explain

version: 1

zones:
  - pattern: ".ia-engineering/risk-map.yml"
    level: sensitive
    category: core_architecture
    reason: >
      This file. A wrong map does not fail: it classifies something important
      as ordinary, and every control that reads it then behaves correctly on
      a false input.

  - pattern: ".github/workflows/*"
    level: sensitive
    category: infrastructure_and_ci
    reason: >
      The CI gates. Loosening a trigger or a check is invisible in the diff of
      the thing it stops guarding.

  - pattern: "Dockerfile"
    level: sensitive
    category: infrastructure_and_ci
    reason: >
      What ships. A change here changes the runtime image for every deploy,
      and the build passing says nothing about what the image contains.

  # install.sh installs more infrastructure that belongs here ONCE YOU CONFIRM
  # IT EXISTS — .gitattributes (LF enforcement the hooks depend on), the git
  # hooks themselves, the PR and issue templates. They are NOT mapped by the
  # starter because install.sh is a separate step that can fail, and a zone for
  # a file that is not there is a dead entry (Templates/RISK_MAP.md, trap 4).
  # When you have committed them, add:
  #
  #   - pattern: ".gitattributes"
  #     level: sensitive
  #     category: infrastructure_and_ci
  #     reason: LF enforcement the hooks depend on; a CRLF hook is skipped silently.

  # ---- YOUR PROJECT'S OWN ZONES GO ABOVE THIS LINE -------------------------
  # Authentication, authorisation, payments, personal data, migrations,
  # secrets, the modules the deliverable depends on: search for each of the
  # eight categories in Standards/RISK_STANDARD.md and map what you find.

  - pattern: "*"
    level: standard
    reason: >
      The documented default for everything not classified above. A new path
      lands here rather than nowhere.

# Each of the eight categories is either mapped above, with its paths, or
# declared here with a reason someone else can verify. NOTHING is declared
# absent by the bootstrap: that is a judgement about your project, and a false
# declaration of absence is worse than an omission. The check names what is
# still unaccounted for.
absent: []
RISKMAP
  echo "  + $RISK_MAP_FILE (starter — installed files only; the check will name what remains)"
fi

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
echo "  Risk Map               .ia-engineering/risk-map.yml — the starter covers the installed"
echo "                         files only; map your own zones and account for all eight"
echo "                         categories (Templates/RISK_MAP.md), then run check-risk-map.sh"
echo "  CLAUDE.md + roster     Workflows/ONBOARDING.md Step 4"
echo "  First Work Unit        Workflows/ONBOARDING.md Step 6, Director-approved"
echo

# The closing report is what PROJECT_BOOTSTRAP.md Step 4 item 3 tells the
# reader to confirm, so a failure in either half is named here rather than left
# for them to notice — and the exit status carries it, so a wrapper or CI job
# sees it too.
if [ "$INSTALL_RC" -ne 0 ]; then
  echo "--- Problems reported ---" >&2
  echo "  install.sh exited $INSTALL_RC: the host-agnostic half needs attention." >&2
  echo "  Scroll up to its warnings. The two that matter most are pre-existing" >&2
  echo "  hooks in .git/hooks that core.hooksPath now shadows, and a commit-msg" >&2
  echo "  hook that is installed but not enforcing. The stack Adapters above" >&2
  echo "  were installed regardless — a hook problem is not a reason to skip" >&2
  echo "  the Dockerfile." >&2
  echo >&2
  echo "Review the copied workflows and ./Dockerfile, then commit them." >&2
  exit "$INSTALL_RC"
fi

echo "Review the copied workflows and ./Dockerfile, then commit them."
