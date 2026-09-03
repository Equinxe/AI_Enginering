#!/usr/bin/env bash
# IA Engineering — install.sh
#
# Installs every host-agnostic Adapter into a project, in one command.
#
# Adapters/README.md's Installation section previously listed six `cp` and
# `chmod` invocations to run by hand, with a parenthetical warning that "every
# clone must repeat this — hooks are not transmitted by git itself". A
# multi-step manual procedure that must be repeated per clone is a procedure
# that gets skipped, and a skipped hook installation is silent: commits land
# with no Employee attribution and nothing complains until a server-side check
# catches it later, or nobody does.
#
# WHY core.hooksPath INSTEAD OF COPYING INTO .git/hooks:
#
# Copying produces a second, forkable version of each hook. The copy is frozen
# at the framework version current when it was made, so a project that
# installed hooks at v0.0.9 keeps validating against a v0.0.9 roster forever
# while its submodule moves on — and nothing reports the mismatch.
# core.hooksPath points git directly at the framework's own hooks, so the hook
# in force is always the hook in the imported framework version. There is one
# copy of each hook, in one place, under version control.
#
# This does not make hooks travel with a clone. Nothing can: git deliberately
# never transmits hooks or local config, because a repository that could
# install executables on clone would be a remote-code-execution vector. Every
# clone still runs this script once. The difference is that it is one command
# that cannot be half-done, instead of six that can.
#
# WHAT THIS SCRIPT DOES NOT DO:
#
#   - Branch protection. Adapters/scripts/setup-branch-protection.sh mutates
#     shared repository settings through the GitHub API and needs an
#     authenticated `gh`. Mutating settings every collaborator sees does not
#     belong in a routine per-clone install; run it deliberately, once per
#     repository.
#   - Stack-specific CI and containers. ci-build-test.yml, ghcr-publish.yml,
#     and the Dockerfile depend on a stack this script has no way to know.
#     Adapters/scripts/setup-project-bootstrap.sh owns those and calls this
#     script for the host-agnostic part.
#
# Usage:
#   ./ia-engineering/Adapters/scripts/install.sh [options]
#
#   --dry-run     print every action without performing it
#   --no-hooks    skip hook configuration (CI/templates only)
#   --force       overwrite existing files that differ from the Adapter
#   --help
#
# Run from the root of the project being set up.

set -uo pipefail

DRY_RUN=0
NO_HOOKS=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-hooks) NO_HOOKS=1 ;;
    --force) FORCE=1 ;;
    --help|-h)
      sed -n '2,50p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! PROJECT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "install.sh: not inside a git repository." >&2
  echo "  Run this from the root of the project you are setting up. The Git" >&2
  echo "  Standard (Standards/GIT_STANDARD.md) makes git mandatory, and every" >&2
  echo "  Adapter installed here enforces a git-level rule." >&2
  exit 1
fi

cd "$PROJECT" || exit 1

# Re-derive the project root from the shell after cd. On Windows, `git
# rev-parse --show-toplevel` reports a native path ("C:/Developpement/x") while
# `pwd` reports the shell's own form ("/c/Developpement/x"). The two never
# compare equal as strings, so the framework-inside-project test below would
# reject a perfectly correct layout. Both paths now come from the same source.
PROJECT="$(pwd)"

# The hooks path recorded in git config must be relative to the project root,
# so the setting keeps working if the checkout is moved or is on another
# machine. An absolute path would be correct only for whoever ran the script.
HOOKS_REL="${FRAMEWORK#"$PROJECT"/}"
if [ "$HOOKS_REL" = "$FRAMEWORK" ]; then
  # The framework is not under the project root: it is the project (this
  # repository installing its own Adapters), or it lives somewhere unrelated.
  if [ "$FRAMEWORK" = "$PROJECT" ]; then
    HOOKS_REL="."
  else
    echo "install.sh: the framework at $FRAMEWORK is neither inside nor equal to" >&2
    echo "  the project at $PROJECT. Workflows/ONBOARDING.md Step 1 imports the" >&2
    echo "  framework as a submodule, copied reference, or linked directory" >&2
    echo "  inside the project, so its path can be recorded relative to the" >&2
    echo "  project root. Move it inside the project and re-run." >&2
    exit 1
  fi
fi

CHANGED=0
SKIPPED=0
PROBLEMS=0

say()  { printf '  %s\n' "$1"; }
did()  { CHANGED=$((CHANGED + 1)); printf '  + %s\n' "$1"; }
same() { SKIPPED=$((SKIPPED + 1)); printf '  = %s\n' "$1"; }
warn() { PROBLEMS=$((PROBLEMS + 1)); printf '  ! %s\n' "$1" >&2; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

# Copies a shipped Adapter into place, but never silently overwrites a file the
# project has diverged from — a project may have deliberately extended a
# workflow, and destroying that without a word is worse than not installing.
#
# Third argument: pass "customized" for an Adapter the project is *expected* to
# edit after installing. ISSUE_TEMPLATE/config.yml is the case that exists
# today — it ships OWNER/REPO placeholders and instructs the adopter to replace
# them, so a divergent installed copy is the correct end state, not drift.
# Reporting it as a problem on every run would train the reader to ignore the
# script's warnings, which is how a real warning gets missed.
install_file() {
  local src="$1" dest="$2" kind="${3:-strict}"

  if [ ! -f "$src" ]; then
    warn "$src is missing from the framework — nothing to install at $dest"
    return
  fi

  if [ -f "$dest" ]; then
    if diff -q "$src" "$dest" > /dev/null 2>&1; then
      same "$dest (already current)"
      return
    fi
    if [ "$kind" = "customized" ] && [ "$FORCE" -eq 0 ]; then
      same "$dest (customized for this project, left alone)"
      return
    fi
    if [ "$FORCE" -eq 0 ]; then
      warn "$dest exists and differs from the Adapter — left untouched. Review 'diff $src $dest', then re-run with --force to overwrite."
      return
    fi
  fi

  run mkdir -p "$(dirname "$dest")"
  if run cp "$src" "$dest"; then
    did "$dest"
  else
    warn "failed to write $dest"
  fi
}

echo "IA Engineering — installing Adapters"
echo "  framework: $FRAMEWORK"
echo "  project:   $PROJECT"
[ "$DRY_RUN" -eq 1 ] && echo "  mode:      dry run (nothing will be written)"
echo

# --- Git hooks -------------------------------------------------------------

echo "Git hooks"
if [ "$NO_HOOKS" -eq 1 ]; then
  say "skipped (--no-hooks)"
else
  HOOKS_DIR="$HOOKS_REL/Adapters/git-hooks"

  if [ ! -d "$PROJECT/$HOOKS_DIR" ]; then
    warn "$HOOKS_DIR does not exist — cannot point core.hooksPath at it"
  else
    CURRENT="$(git config --local core.hooksPath || true)"

    # Setting core.hooksPath makes git ignore .git/hooks entirely. If the
    # project has its own hooks there, they would stop running with no error
    # and no output — exactly the silent-degradation failure this framework
    # keeps repairing. Detect it and say so rather than breaking them quietly.
    #
    # The directory must be derived from --absolute-git-dir, NOT from
    # "git rev-parse --git-path hooks": once core.hooksPath is set, --git-path
    # resolves to that configured value, so a second run would inspect the
    # framework's own hooks directory and report its two hooks as pre-existing
    # project hooks about to be shadowed. Checked only when the setting is not
    # already correct, since the question is only meaningful before switching.
    if [ "$CURRENT" != "$HOOKS_DIR" ]; then
      REAL_HOOKS="$(git rev-parse --absolute-git-dir)/hooks"
      EXISTING="$(find "$REAL_HOOKS" -maxdepth 1 -type f ! -name '*.sample' 2>/dev/null \
                    | wc -l | tr -d ' ')"
      if [ "$EXISTING" -gt 0 ]; then
        warn "$EXISTING hook(s) already in $REAL_HOOKS. Setting core.hooksPath makes git ignore that directory entirely, so those hooks would stop running silently. Move them into $HOOKS_DIR (or into a directory of your own that also contains the framework's hooks) before continuing."
      fi
    fi
    if [ "$CURRENT" = "$HOOKS_DIR" ]; then
      same "core.hooksPath = $HOOKS_DIR"
    else
      if run git config --local core.hooksPath "$HOOKS_DIR"; then
        did "core.hooksPath = $HOOKS_DIR${CURRENT:+ (was: $CURRENT)}"
      else
        warn "could not set core.hooksPath"
      fi
    fi

    # A hook that is not executable is a hook git skips without complaint.
    for h in "$PROJECT/$HOOKS_DIR"/*; do
      [ -f "$h" ] || continue
      if [ ! -x "$h" ]; then
        run chmod +x "$h" && did "chmod +x $(basename "$h")"
      fi
    done
  fi
fi
echo

# --- CI workflows ----------------------------------------------------------

echo "CI workflows"
install_file "$FRAMEWORK/Adapters/github-actions/pr-validation.yml" \
             ".github/workflows/pr-validation.yml"
install_file "$FRAMEWORK/Adapters/github-actions/framework-validation.yml" \
             ".github/workflows/framework-validation.yml"
echo

# --- GitHub templates ------------------------------------------------------

echo "GitHub templates"
install_file "$FRAMEWORK/Adapters/github/PULL_REQUEST_TEMPLATE.md" \
             ".github/PULL_REQUEST_TEMPLATE.md"

if [ -d "$FRAMEWORK/Adapters/github/ISSUE_TEMPLATE" ]; then
  for t in "$FRAMEWORK/Adapters/github/ISSUE_TEMPLATE"/*; do
    [ -f "$t" ] || continue
    base="$(basename "$t")"
    if [ "$base" = "config.yml" ]; then
      install_file "$t" ".github/ISSUE_TEMPLATE/$base" customized
      if [ -f ".github/ISSUE_TEMPLATE/$base" ] \
         && grep -q 'OWNER/REPO' ".github/ISSUE_TEMPLATE/$base"; then
        warn ".github/ISSUE_TEMPLATE/config.yml still has the OWNER/REPO placeholder. Its contact links point at a repository that does not exist — replace OWNER/REPO with this project's own owner and name."
      fi
    else
      install_file "$t" ".github/ISSUE_TEMPLATE/$base"
    fi
  done
else
  warn "Adapters/github/ISSUE_TEMPLATE/ is missing from the framework"
fi
echo

# --- Line endings ----------------------------------------------------------
# The Adapters are shell scripts and CI configs. A CRLF checkout breaks a
# shebang on a Linux runner, and it breaks the Registry parsing contract that
# the commit-msg hook depends on (see Registry/README.md). Appended rather than
# written, so a project's own .gitattributes rules survive.

echo "Line endings"
ATTR_RULES="/Adapters/** text eol=lf
/Registry/** text eol=lf
/.github/** text eol=lf"

if [ "$FRAMEWORK" = "$PROJECT" ]; then
  same ".gitattributes (framework repository governs its own paths)"
else
  MISSING_RULES=""
  while IFS= read -r rule; do
    if [ ! -f .gitattributes ] || ! grep -qF "$rule" .gitattributes; then
      MISSING_RULES="$MISSING_RULES$rule
"
    fi
  done < <(printf '%s\n' "$ATTR_RULES")

  if [ -z "$MISSING_RULES" ]; then
    same ".gitattributes (LF rules already present)"
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] append to .gitattributes:\n'
    printf '%s' "$MISSING_RULES" | sed 's/^/    /'
  else
    {
      echo ""
      echo "# IA Engineering Adapters — installed by Adapters/scripts/install.sh."
      echo "# The Adapters are shell scripts and CI configs: a CRLF checkout breaks a"
      echo "# shebang on a Linux runner, and breaks the Registry parsing contract the"
      echo "# commit-msg hook depends on (Registry/README.md)."
      printf '%s' "$MISSING_RULES"
    } >> .gitattributes
    did ".gitattributes (appended $(printf '%s' "$MISSING_RULES" | grep -c .) LF rule(s))"
  fi
fi
echo

# --- Verify ----------------------------------------------------------------
# Core/MAIN_AGENT_CONDUCT.md's Verification Over Waiting requires confirming
# real state rather than trusting a report. An installer that prints "done"
# without checking anything is the same defect. This proves the hook is live by
# running it, rather than asserting that copying a file made it work.

echo "Verification"
if [ "$DRY_RUN" -eq 1 ]; then
  say "skipped (dry run)"
elif [ "$NO_HOOKS" -eq 1 ]; then
  say "hooks not installed — nothing to verify"
else
  HOOK="$PROJECT/$(git config --local core.hooksPath || echo '.git/hooks')/commit-msg"
  if [ ! -x "$HOOK" ]; then
    warn "commit-msg hook is not executable at $HOOK"
  else
    PROBE="$(mktemp)"
    printf 'chore(install): probe\n\nEmployee: DevOps Engineer\n' > "$PROBE"
    if "$HOOK" "$PROBE" > /dev/null 2>&1; then
      say "commit-msg hook accepts a valid Employee trailer"
    else
      warn "the commit-msg hook rejected a well-formed probe commit. It usually means it cannot resolve Registry/employees.yml. Run: $HOOK $PROBE"
    fi

    printf 'chore(install): probe\n\nEmployee: executor\n' > "$PROBE"
    if "$HOOK" "$PROBE" > /dev/null 2>&1; then
      warn "the commit-msg hook ACCEPTED 'Employee: executor', which is a tool label and not an Employee. The hook is installed but not enforcing — check that it resolves the roster."
    else
      say "commit-msg hook rejects a generic tool label"
    fi
    rm -f "$PROBE"
  fi
fi
echo

# --- Result ----------------------------------------------------------------

echo "Result"
printf '  %s installed/updated, %s already current' "$CHANGED" "$SKIPPED"
if [ "$PROBLEMS" -gt 0 ]; then
  printf ', %s needing attention\n' "$PROBLEMS"
else
  printf '\n'
fi

if [ "$FRAMEWORK" != "$PROJECT" ]; then
  echo
  echo "Not installed by this script, by design:"
  echo "  Branch protection   ./$HOOKS_REL/Adapters/scripts/setup-branch-protection.sh"
  echo "                      (mutates shared repository settings; run once per repo)"
  echo "  Stack CI/container  ./$HOOKS_REL/Adapters/scripts/setup-project-bootstrap.sh <stack>"
  echo "                      (needs the stack decided in Workflows/PROJECT_BOOTSTRAP.md Phase B)"
fi

[ "$PROBLEMS" -gt 0 ] && exit 1
exit 0
