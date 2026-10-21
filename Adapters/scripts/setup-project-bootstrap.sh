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
#   .ia-engineering/stack, .ia-engineering/risk-map.yml  (starters)
#   Registry/work-units.yml                   (starter, empty: the project's own
#                                              Work Unit registry, read by the
#                                              required Work Unit Exists check)
#
# Still not installed here, deliberately: branch protection. It mutates shared
# repository settings through the GitHub API and needs an authenticated `gh`;
# run Adapters/scripts/setup-branch-protection.sh once per repository.
#
# Run from the root of the target project.
#
# Usage:
#   ./setup-project-bootstrap.sh <stack> [--dry-run] [--force]
#   ./setup-project-bootstrap.sh [<stack>] --check [--quiet]
#     where <stack> is one of: node | web | python | go | jvm | dotnet | php | generic
#
#     `web` is a static front end (React, Vue, Svelte, Astro, a site
#     generator): it builds with Node and ships files behind a web
#     server, with no Node in the runtime image. It is the one stack that
#     cannot be inferred, because a site and a server both have
#     package.json — which is why the chosen stack is recorded.
#
# --check (WU-IAENG-353) writes nothing. It runs `install.sh --check` (its
# records, its closing `#` line and its exit code, documented in install.sh's
# header), then adds one record per file this script owns:
#
#   project-file TAB present|absent TAB <path> TAB <detail>
#
# Those files are the project's own once written (an existing one is left
# untouched without --force), so presence is this script's whole decision and
# the whole check: `absent` is drift (re-run this script without --force),
# `present` is not compared with anything. A second `#` line counts them.
# The stack is optional under --check, since no project-owned file is
# compared with a stack template. --quiet prints nothing when nothing needs
# acting on. Exit: 0 nothing to act on, 3 drift, 1 a fault (the worse of the
# two halves wins: 1 over 3 over 0), 2 usage. It is a building block for the
# drift checks that run on their own in a session, not a flag to type.

set -euo pipefail

VALID_STACKS="node web python go jvm dotnet php generic"

STACK=""
PASSTHROUGH=()
CHECK=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --dry-run|--force) PASSTHROUGH+=("$arg") ;;
    --check) CHECK=1 ;;
    --quiet) QUIET=1 ;;
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

if [ "$CHECK" -eq 1 ] && [ "${#PASSTHROUGH[@]}" -gt 0 ]; then
  echo "Error: --check reports and writes nothing; it cannot be combined with --dry-run or --force." >&2
  exit 2
fi
if [ "$QUIET" -eq 1 ] && [ "$CHECK" -eq 0 ]; then
  echo "Error: --quiet only applies to --check." >&2
  exit 2
fi

if [ -z "$STACK" ] && [ "$CHECK" -eq 0 ]; then
  echo "Usage: $0 <stack> [--dry-run] [--force]   (stack: $VALID_STACKS)" >&2
  exit 1
fi

# Validate the requested stack against the known set. An empty stack reaches
# here only under --check (refused above otherwise), which needs none.
if [ -n "$STACK" ]; then
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
fi

# Resolve the Adapters directory relative to this script, so the script works
# regardless of the caller's current directory.
#
# `cd ... && pwd` here — without `-P` — resolves through `.`/`..` but NOT
# through a symlink: bash's own logical `$PWD` keeps a symlinked path
# component (e.g. a project's `ia-engineering -> ../elsewhere/ia-engineering`
# checkout) intact as the name it was invoked through, rather than rewriting
# it to the link's physical target. SCRIPT_DIR relies on that: it is used
# below to print a path the reader can act on, and a project sees its own
# framework checkout by the link name, not by wherever that link happens to
# point on this machine.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Computes a relative path from directory $1 to path $2 by comparing path
# segments as strings — no realpath, and no symlink resolution. GNU
# `realpath --relative-to` CANONICALIZES both sides first, so a caller
# reached through a symlinked directory gets back a path through the link's
# physical target instead of the link name (e.g. `../actual-target/...`
# instead of `./ia-engineering/...`); `realpath` is also not present on every
# platform this script targets (Git Bash, Linux, macOS — the earlier
# `--relative-to` call fell back to an absolute path when it failed). Both
# inputs must already be absolute (SCRIPT_DIR and the caller's `pwd` both are,
# from plain non -P `cd`/`pwd`).
relpath() {
  local from="$1" to="$2" i=0 up="" rest="" j
  local -a from_parts to_parts
  IFS='/' read -r -a from_parts <<<"$from"
  IFS='/' read -r -a to_parts <<<"$to"
  while [ "$i" -lt "${#from_parts[@]}" ] && [ "$i" -lt "${#to_parts[@]}" ] \
        && [ "${from_parts[$i]}" = "${to_parts[$i]}" ]; do
    i=$((i + 1))
  done
  j="$i"
  while [ "$j" -lt "${#from_parts[@]}" ]; do
    up="../$up"
    j=$((j + 1))
  done
  j="$i"
  while [ "$j" -lt "${#to_parts[@]}" ]; do
    rest="$rest${to_parts[$j]}/"
    j=$((j + 1))
  done
  rest="${rest%/}"
  if [ -z "$up$rest" ]; then
    printf '.'
  else
    printf '%s%s' "$up" "$rest"
  fi
}

DRY_RUN=0
for arg in "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}"; do
  [ "$arg" = "--dry-run" ] && DRY_RUN=1
done

# The files this script owns, named once: the write steps below and --check
# both read these names, so the check cannot drift from what is written.
CI_BUILD_TEST_FILE=".github/workflows/ci-build-test.yml"
GHCR_PUBLISH_FILE=".github/workflows/ghcr-publish.yml"
STACK_FILE=".ia-engineering/stack"
RISK_MAP_FILE=".ia-engineering/risk-map.yml"
WU_REGISTRY_FILE="Registry/work-units.yml"
DOCKERFILE_FILE="Dockerfile"
PROJECT_OWNED_FILES="$CI_BUILD_TEST_FILE $GHCR_PUBLISH_FILE $STACK_FILE $RISK_MAP_FILE $WU_REGISTRY_FILE $DOCKERFILE_FILE"

# --- --check: report, write nothing (WU-IAENG-353) --------------------------
# The decision for each project-owned file is presence alone (each write step
# below leaves an existing file untouched without --force), so presence is
# what is reported. The host-agnostic half is install.sh's own --check: the
# same records, the same exit codes, nothing re-implemented here.
if [ "$CHECK" -eq 1 ]; then
  INSTALL_ARGS=(--check)
  [ "$QUIET" -eq 1 ] && INSTALL_ARGS+=(--quiet)
  INSTALL_RC=0
  "$SCRIPT_DIR/install.sh" "${INSTALL_ARGS[@]}" || INSTALL_RC=$?

  # Built in the shell, without a subshell per file: this runs inside session
  # hooks with a time budget, and every fork is slow on Git for Windows.
  OWN_PRESENT=""
  OWN_ABSENT_ROWS=""
  OWN_ABSENT=0
  OWN_TOTAL=0
  for f in $PROJECT_OWNED_FILES; do
    OWN_TOTAL=$((OWN_TOTAL + 1))
    if [ -f "$f" ]; then
      OWN_PRESENT="${OWN_PRESENT}project-file"$'\t'"present"$'\t'"$f"$'\t'"project-owned once written; presence only"$'\n'
    else
      OWN_ABSENT=$((OWN_ABSENT + 1))
      OWN_ABSENT_ROWS="${OWN_ABSENT_ROWS}project-file"$'\t'"absent"$'\t'"$f"$'\t'"written by setup-project-bootstrap.sh; re-run it without --force"$'\n'
    fi
  done
  if [ "$QUIET" -eq 0 ] || [ "$OWN_ABSENT" -gt 0 ]; then
    if [ "$QUIET" -eq 1 ]; then
      printf '%s' "$OWN_ABSENT_ROWS"
    else
      printf '%s%s' "$OWN_PRESENT" "$OWN_ABSENT_ROWS"
    fi
    LINE="# setup-project-bootstrap.sh --check: $OWN_ABSENT to act on. $OWN_TOTAL project-owned file(s): $((OWN_TOTAL - OWN_ABSENT)) present, $OWN_ABSENT absent."
    if [ "$OWN_ABSENT" -gt 0 ]; then
      LINE="$LINE absent: re-run $(relpath "$(pwd)" "$SCRIPT_DIR")/setup-project-bootstrap.sh <stack> without --force; it writes what is absent and overwrites nothing."
    fi
    printf '%s\n' "$LINE"
  fi

  # The worse half wins: a fault (1) over drift (3) over nothing to act on (0).
  if [ "$INSTALL_RC" -ne 0 ] && [ "$INSTALL_RC" -ne 3 ]; then
    exit "$INSTALL_RC"
  fi
  if [ "$INSTALL_RC" -eq 3 ] || [ "$OWN_ABSENT" -gt 0 ]; then
    exit 3
  fi
  exit 0
fi

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
#
# install.sh also appends one record per decision to INSTALL_REPORT (the
# --check record format, documented in its header). The closing message reads
# it to name the files that differ and to keep the hook wording for real hook
# faults (issue #262): before, any non-zero exit was blamed on the hooks,
# including a run whose only problem was two Adapter files that differed and
# whose own hook verification had passed. Kept outside the project.
echo "--- Host-agnostic Adapters (install.sh) ---"
INSTALL_REPORT="$(mktemp)"
trap 'rm -f "$INSTALL_REPORT"' EXIT
INSTALL_RC=0
IAENG_FROM_BOOTSTRAP=1 IAENG_INSTALL_REPORT="$INSTALL_REPORT" \
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

copy_into "$ADAPTERS_DIR/github-actions/ci-build-test.yml" "$CI_BUILD_TEST_FILE"
copy_into "$ADAPTERS_DIR/github-actions/ghcr-publish.yml" "$GHCR_PUBLISH_FILE"

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
# (STACK_FILE is named with the other project-owned files near the top.)
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
# (RISK_MAP_FILE is named with the other project-owned files near the top.)
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

# A STARTER WORK UNIT REGISTRY, BECAUSE THE REQUIRED `Work Unit Exists` CHECK
# READS THE PROJECT'S AND NEVER THE FRAMEWORK'S.
#
# check-work-units.sh used to fall back to ia-engineering/Registry/work-units.yml
# when the project had none, which failed the adopter's first Pull Request and
# let a commit claiming a framework Work Unit pass (DEF-1, issue #181). It now
# fails with the file to create instead, so this script creates it.
#
# The location is Registry/work-units.yml at the project root: it is the path
# Workflows/FEATURE_DEVELOPMENT.md Step 4 already tells every project to
# register Work Units in, and the path the check reads, so no new convention is
# introduced. The list is EMPTY, not seeded with an example: an example ID would
# be a registered Work Unit that nobody performed, which is the false pass this
# file exists to prevent. A bare `work_units:` key (not `[]`) so entries can be
# appended beneath it as valid YAML.
# (WU_REGISTRY_FILE is named with the other project-owned files near the top.)
if [ -f "$WU_REGISTRY_FILE" ] && ! printf '%s\n' "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}" | grep -qx -- '--force'; then
  echo "  ! $WU_REGISTRY_FILE already exists — left untouched (the project's own)." >&2
  WU_REGISTRY_NOTE="already present, left untouched (the project's own)"
  echo "    Re-run with --force to replace it with the empty starter." >&2
elif [ "$DRY_RUN" -eq 1 ]; then
  WU_REGISTRY_NOTE="would be written (dry run)"
  echo "  [dry-run] write $WU_REGISTRY_FILE (starter: empty Work Unit list)"
else
  WU_REGISTRY_NOTE="starter written above"
  mkdir -p "$(dirname "$WU_REGISTRY_FILE")"
  cat > "$WU_REGISTRY_FILE" <<'WUREGISTRY'
# Work Unit Registry — STARTER, written by setup-project-bootstrap.sh
#
# The Work Units executed in THIS project. The required `Work Unit Exists` check
# resolves each commit's `Work Unit:` trailer against this file, and never
# against the framework's own Registry/work-units.yml.
#
# Register a Work Unit in the SAME commit that performs it, one entry per Work
# Unit, appended below the `work_units:` line:
#
#   - id: WU-<PROJECT>-001
#     employee: <an Employee name from the roster>
#     title: <what the Work Unit does>
#     milestone: <milestone or release label>
#     delivers: <paths this Work Unit changes>
#
# PARSING CONTRACT — read this before reformatting. Consumers read these lines
# with grep and sed: keep `  - id: <WU-ID>` as each entry's first line, two
# leading spaces, unquoted. IDs follow Templates/WORK_UNIT.md.

work_units:
WUREGISTRY
  echo "  + $WU_REGISTRY_FILE (starter — empty; register each Work Unit in the commit that performs it)"
fi

DOCKERFILE_SRC="$ADAPTERS_DIR/dockerfiles/$STACK.Dockerfile"
if [ ! -f "$DOCKERFILE_SRC" ]; then
  echo "Error: no starter Dockerfile for stack '$STACK' at $DOCKERFILE_SRC" >&2
  exit 1
fi
if [ -f "$DOCKERFILE_FILE" ] && ! printf '%s\n' "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}" | grep -qx -- '--force'; then
  echo "  ! ./Dockerfile already exists — left untouched. A bootstrapped project" >&2
  echo "    gets a starter Dockerfile; an existing one is the project's own and" >&2
  echo "    overwriting it silently would discard real work. Re-run with --force" >&2
  echo "    to replace it with the $STACK starter." >&2
else
  copy_into "$DOCKERFILE_SRC" "./$DOCKERFILE_FILE"
fi
echo

# 3. Report the Coverage Checklist items this script cannot complete, so they
#    are visible rather than assumed done. PROJECT_BOOTSTRAP.md's Exit Criteria
#    requires every checklist item, and the items below need a decision, a
#    Director, or an authenticated API call — not a file copy.
echo "--- Remaining Coverage Checklist items (Workflows/PROJECT_BOOTSTRAP.md) ---"
echo "  Branch protection      ./$(relpath "$(pwd)" "$SCRIPT_DIR")/setup-branch-protection.sh"
echo "  main + develop created make the first commit first (git branch fails with none), then"
echo "                         git push -u origin main && git branch develop && git push -u origin develop"
echo "                         (pre-push allows creating them; every later change goes by PR)"
echo "  README.md              from the Phase A answers (project identity)"
echo "  .gitignore             stack-appropriate for $STACK"
echo "  Project Charter        Templates/PROJECT_CHARTER.md, from Phase A"
echo "  Stack Decision ADR     Templates/ADR.md, Accepted before this step per"
echo "                         Workflows/ARCHITECTURE_DECISION.md"
echo "  Risk Map               .ia-engineering/risk-map.yml — the starter covers the installed"
echo "                         files only; map your own zones and account for all eight"
echo "                         categories (Templates/RISK_MAP.md), then run check-risk-map.sh"
echo "  CLAUDE.md              from Templates/PROJECT_CLAUDE.md, before Onboarding Step 4"
echo "                         (Workflows/ONBOARDING.md Step 1 item 2)"
echo "  SESSION_STATE.md       after the adoption commit: ./$(relpath "$(pwd)" "$SCRIPT_DIR")/create-session-state.sh"
echo "                         writes the Template block of Templates/SESSION_STATE.md, dated"
echo "                         (Workflows/ONBOARDING.md Step 1 item 3; gitignored)"
echo "  Adoption commit        signed Employee: DevOps Engineer; registers an adoption Work Unit"
echo "                         (milestone: Bootstrap; Workflows/PROJECT_BOOTSTRAP.md Step 4 item 5)"
echo "  Roster                 Workflows/ONBOARDING.md Step 4"
echo "  Work Unit registry     Registry/work-units.yml — $WU_REGISTRY_NOTE; register each"
echo "                         Work Unit in the commit that performs it"
echo "  First Work Unit        Workflows/ONBOARDING.md Step 6, Director-approved"
echo

# The closing report is what PROJECT_BOOTSTRAP.md Step 4 item 3 tells the
# reader to confirm, so a failure in either half is named here rather than left
# for them to notice — and the exit status carries it, so a wrapper or CI job
# sees it too.
#
# Each cause is named from install.sh's records, and only the causes that
# occurred are described (issue #262). A non-zero exit with no recorded cause
# is said as such, never explained away (the Check Convention, rule 1).
if [ "$INSTALL_RC" -ne 0 ]; then
  FORCED=0
  printf '%s\n' "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}" | grep -qx -- '--force' && FORCED=1
  # Under --force a differing file was overwritten, not left behind.
  DIFFERS_ROWS=""
  if [ "$FORCED" -eq 0 ]; then
    DIFFERS_ROWS="$(awk -F '\t' '$1 == "file" && $2 == "differs" { print $3 "\t" $4 }' "$INSTALL_REPORT")"
  fi
  HOOK_FAULTS="$(awk -F '\t' '$1 == "git-hooks" && $2 == "fault"' "$INSTALL_REPORT" | grep -c . || true)"
  OTHER_FAULTS="$(awk -F '\t' '$1 != "git-hooks" && $2 == "fault" { print $3 ": " $4 }' "$INSTALL_REPORT")"
  CHECK_CMD="./$(relpath "$(pwd)" "$SCRIPT_DIR")/setup-project-bootstrap.sh --check"

  echo "--- Problems reported ---" >&2
  echo "  install.sh exited $INSTALL_RC. The stack Adapters above were installed regardless." >&2
  if [ -n "$DIFFERS_ROWS" ]; then
    echo "  $(printf '%s\n' "$DIFFERS_ROWS" | grep -c .) installed file(s) differ from the framework's Adapter and were left untouched:" >&2
    while IFS=$'\t' read -r dest src; do
      echo "    $dest" >&2
      echo "      review: diff $src $dest" >&2
    done <<< "$DIFFERS_ROWS"
    echo "  For each one: if this project never edited it, copy the Adapter over it" >&2
    echo "  (cp <source> <path>); if it did, keep it and carry the upstream change in" >&2
    echo "  by hand. --force is the wrong tool for one file: it replaces every managed" >&2
    echo "  file at once, this project's own Dockerfile, Risk Map, stack declaration" >&2
    echo "  and Work Unit registry included. To list them again without writing" >&2
    echo "  anything: $CHECK_CMD" >&2
  fi
  if [ "$HOOK_FAULTS" -gt 0 ]; then
    echo "  $HOOK_FAULTS git hook problem(s): see the '!' lines under Git hooks and" >&2
    echo "  Verification above. The two that matter most are pre-existing hooks in" >&2
    echo "  .git/hooks that core.hooksPath now shadows, and a commit-msg hook that is" >&2
    echo "  installed but not enforcing." >&2
  fi
  if [ -n "$OTHER_FAULTS" ]; then
    echo "  Other problem(s):" >&2
    printf '%s\n' "$OTHER_FAULTS" | sed 's/^/    /' >&2
  fi
  if [ -z "$DIFFERS_ROWS" ] && [ "$HOOK_FAULTS" -eq 0 ] && [ -z "$OTHER_FAULTS" ]; then
    echo "  install.sh recorded no cause for this exit status: scroll up to its" >&2
    echo "  '!' lines. Nothing here is known to be current." >&2
  fi
  echo >&2
  echo "Review the copied workflows and ./Dockerfile, then commit them." >&2
  exit "$INSTALL_RC"
fi

echo "Review the copied workflows and ./Dockerfile, then commit them."
