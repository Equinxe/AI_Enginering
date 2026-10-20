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
#   - AI-runtime hooks and agents. Adapters/ai-runtimes/<runtime>/ depends on
#     which runtime the project uses, which this script has no way to know,
#     and the Claude Code hooks are installed into a COMMITTED
#     .claude/settings.json — a file that decides what the model may do and
#     that a project reviews like code, not something a per-clone installer
#     should write unasked. Run
#     ./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh and
#     ./ia-engineering/Adapters/ai-runtimes/generate-agents.sh once, per
#     project. Listing only the two exclusions above let a reader conclude the
#     hooks were covered here.
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
      sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}'
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
#
# THE RELATION IS ESTABLISHED BY WALKING, NOT BY COMPARING SPELLINGS.
#
# A string prefix test asks whether one path is written like another, which is
# a different question from whether one directory contains another. It was
# wrong here twice, in two different ways:
#
#   `git rev-parse --show-toplevel` reports "C:/Developpement/x" on Windows
#   while `pwd` reports "/c/Developpement/x". Fixed earlier by deriving both
#   from `pwd` — see the comment above.
#
#   The two can still differ in CASE. PROJECT begins as git's recorded
#   spelling and FRAMEWORK is resolved from this script's own path, so a
#   Windows checkout reachable as both "C--Foo" and "c--Foo" produced
#   "/tmp/.../C--Foo/proj/ia-engineering" and "/tmp/.../c--Foo/proj". Neither
#   is wrong; they are the same directory. install.sh refused a correct
#   installation and told the adopter to move their framework.
#
# So the containment test walks up from the framework and asks `-ef` at each
# step: are these the same file, by device and inode. That is immune to case,
# to /c/ against C:/, to a trailing slash, and to a symlinked checkout — none
# of which a prefix test survives. The relative path is accumulated on the way
# up, so it is built from the real components rather than from a substring.
HOOKS_REL=""
_probe="$FRAMEWORK"
_rel=""
while :; do
  if [ "$_probe" -ef "$PROJECT" ]; then
    HOOKS_REL="${_rel:-.}"
    break
  fi
  _parent="$(dirname "$_probe")"
  # dirname of the root is the root: stop rather than loop forever.
  [ "$_parent" = "$_probe" ] && break
  _rel="$(basename "$_probe")${_rel:+/$_rel}"
  _probe="$_parent"
done
unset _probe _rel _parent

if [ -z "$HOOKS_REL" ]; then
  echo "install.sh: the framework at $FRAMEWORK is not inside, and is not," >&2
  echo "  the project at $PROJECT. Workflows/ONBOARDING.md Step 1 imports the" >&2
  echo "  framework as a submodule, copied reference, or linked directory" >&2
  echo "  inside the project, so its path can be recorded relative to the" >&2
  echo "  project root. Move it inside the project and re-run." >&2
  echo "  (Checked by walking parents and comparing device and inode, so a" >&2
  echo "  difference in spelling or letter case is not what caused this.)" >&2
  exit 1
fi

CHANGED=0
SKIPPED=0
PROBLEMS=0
ACTIONS=0

say()  { printf '  %s\n' "$1"; }
did()  { CHANGED=$((CHANGED + 1)); printf '  + %s\n' "$1"; }
same() { SKIPPED=$((SKIPPED + 1)); printf '  = %s\n' "$1"; }

# A real installation fault. Counted, and it makes this script exit non-zero,
# which setup-project-bootstrap.sh now propagates (WU-IAENG-159).
warn() { PROBLEMS=$((PROBLEMS + 1)); printf '  ! %s\n' "$1" >&2; }

# Something the ADOPTING PROJECT must do next — reported, never fatal.
#
# This distinction exists because the first version of the exit-status fix did
# not have it. The only warning a clean, correct install emits is the
# OWNER/REPO placeholder in ISSUE_TEMPLATE/config.yml, which the Adapter ships
# deliberately and instructs the adopter to replace afterwards. Counting it as
# a problem made every correct first bootstrap exit 1 — a false failure on the
# happy path, introduced by the fix for a false success. Caught in testing
# before it shipped, but it is the same inversion the review warned about for
# the MERGE_HEAD probe: tightening an exit status turns every benign warning
# into a blocker unless benign is defined first.
todo() { ACTIONS=$((ACTIONS + 1)); printf '  > %s\n' "$1"; }

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
install_file "$FRAMEWORK/Adapters/github-actions/data-policy.yml" \
             ".github/workflows/data-policy.yml"
install_file "$FRAMEWORK/Adapters/github-actions/control-path-guard.yml" \
             ".github/workflows/control-path-guard.yml"
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
        todo "Replace the OWNER/REPO placeholders in .github/ISSUE_TEMPLATE/config.yml with this project's own owner and name. The Adapter ships them deliberately; until they are replaced, the Questions and Security Vulnerability contact links point at a repository that does not exist."
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
# /Adapters/** and /Registry/** are the FRAMEWORK repository's own top-level
# paths — install.sh copies individual files out of Adapters/ into a project,
# it does not create an Adapters/ or Registry/ directory in the project being
# set up, so an adopting project has nothing at either path for a
# .gitattributes rule to match. Only /.github/** is meaningful there. The two
# framework-only rules are appended only when FRAMEWORK = PROJECT below, i.e.
# only when this script installs into the framework repository itself, which
# is where /Adapters/** and /Registry/** actually exist.
#
# Beyond /.github/**, an adopting project gets an LF rule for each file the
# bootstrap (setup-project-bootstrap.sh, install-hooks.sh) writes, and
# .gitmodules, and that a hook or a CI job parses: under core.autocrlf=true git would
# otherwise check them out as CRLF (DEF-13, issue #181). They are EXACT paths,
# not `* text=auto` or a wildcard over the project: this script has no claim
# on the rest of the project's files and their line endings are its own.
# /.claude/skills/** is the one directory: install-skills.sh writes it whole,
# and its launchers are bash scripts (issue #242). install-hooks.sh and
# install-skills.sh append their own line too when it is missing, for a
# project that runs them without this script; each finds the other's.
ATTR_RULES="/.github/** text eol=lf
/.claude/settings.json text eol=lf
/.claude/skills/** text eol=lf
/.ia-engineering/stack text eol=lf
/.ia-engineering/risk-map.yml text eol=lf
/Registry/work-units.yml text eol=lf
/Dockerfile text eol=lf
/.gitmodules text eol=lf"
FRAMEWORK_ONLY_ATTR_RULES="/Adapters/** text eol=lf
/Registry/** text eol=lf
/.github/** text eol=lf"

# Appends whichever lines of $1 (newline-separated) are missing from
# .gitattributes, reporting $2 as the "nothing to do" message. Shared by both
# branches below so the append/dry-run/report logic exists once.
append_gitattributes_rules() {
  local rules="$1" same_msg="$2" missing=""
  while IFS= read -r rule; do
    if [ ! -f .gitattributes ] || ! grep -qF "$rule" .gitattributes; then
      missing="$missing$rule
"
    fi
  done < <(printf '%s\n' "$rules")

  if [ -z "$missing" ]; then
    same "$same_msg"
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] append to .gitattributes:\n'
    printf '%s' "$missing" | sed 's/^/    /'
  else
    {
      echo ""
      echo "# IA Engineering Adapters — installed by Adapters/scripts/install.sh."
      echo "# The Adapters are shell scripts and CI configs: a CRLF checkout breaks a"
      echo "# shebang on a Linux runner, and breaks the Registry parsing contract the"
      echo "# commit-msg hook depends on (Registry/README.md)."
      printf '%s' "$missing"
    } >> .gitattributes
    did ".gitattributes (appended $(printf '%s' "$missing" | grep -c .) LF rule(s))"
  fi
}

if [ "$FRAMEWORK" = "$PROJECT" ]; then
  append_gitattributes_rules "$FRAMEWORK_ONLY_ATTR_RULES" \
    ".gitattributes (framework repository governs its own paths)"
else
  append_gitattributes_rules "$ATTR_RULES" ".gitattributes (LF rules already present)"
fi
echo

# --- Data protection ---------------------------------------------------------
# Standards/DATA_PROTECTION_STANDARD.md: the local data directory, the
# environment file, and the operational state file are ignored from the first
# commit, before any of them exists. .gitignore is the advisory layer — the
# pre-commit hook and data-policy.yml refuse the same paths if it is ever
# bypassed — but it is the layer that stops `git add -A` from staging them in
# the first place. Appended, so a project's own rules survive. The framework
# repository carries these rules in its own .gitignore and is reported as-is.

echo "Data protection"
LOCAL_DATA_DIR="${IAENG_LOCAL_DATA_DIR:-local_test_data}"
IGNORE_RULES="$LOCAL_DATA_DIR/
.env
.ia-engineering/SESSION_STATE.md"

MISSING_IGNORES=""
while IFS= read -r rule; do
  if [ ! -f .gitignore ] || ! grep -qxF "$rule" .gitignore; then
    MISSING_IGNORES="$MISSING_IGNORES$rule
"
  fi
done < <(printf '%s\n' "$IGNORE_RULES")

if [ -z "$MISSING_IGNORES" ]; then
  same ".gitignore (data-protection rules already present)"
elif [ "$DRY_RUN" -eq 1 ]; then
  printf '  [dry-run] append to .gitignore:\n'
  printf '%s' "$MISSING_IGNORES" | sed 's/^/    /'
else
  {
    echo ""
    echo "# IA Engineering — Standards/DATA_PROTECTION_STANDARD.md (installed by"
    echo "# Adapters/scripts/install.sh). Real data lives only in the local data"
    echo "# directory; secrets only in the environment; operational state is never"
    echo "# committed. The pre-commit hook and data-policy.yml refuse the same paths."
    printf '%s' "$MISSING_IGNORES"
  } >> .gitignore
  did ".gitignore (appended $(printf '%s' "$MISSING_IGNORES" | grep -c .) data-protection rule(s))"
fi

# The pre-commit hook refuses the local data directory but cannot create it;
# a developer who has nowhere sanctioned to put a real file will put it
# somewhere unsanctioned.
if [ -d "$LOCAL_DATA_DIR" ]; then
  same "$LOCAL_DATA_DIR/ exists"
else
  run mkdir -p "$LOCAL_DATA_DIR" && did "$LOCAL_DATA_DIR/ created (gitignored; the only place for real data on this machine)"
fi
echo

# --- Generated and runtime artifacts ----------------------------------------
# .claude/agents/ is Adapters/ai-runtimes/generate-agents.sh's output —
# Employees/ and Registry/employees.yml rendered into one file per Employee,
# roughly 9,000 lines of derived content. It is a build artifact, not a
# source, the same way a compiled binary is not a source: every Employee edit
# would otherwise carry a large mechanical diff beside the real one, and
# `generate-agents.sh --check` in CI catches drift without the files being
# tracked. This repository ignores it for exactly that reason (.gitignore,
# Adapters/ai-runtimes/README.md, "Generated Output Is a Build Artifact") —
# an adopting project gets the same default unless it opts back in.
#
# .claude/worktrees/ is where this runtime creates isolated git worktrees for
# subagents (the Agent tool's `isolation: "worktree"`). It is per-session
# scratch state, not specific to this framework — any Claude Code project
# that uses isolated subagents gets the same untracked directory.
#
# .ia-engineering/usage/ is where usage-dashboard.sh writes its page by
# default. The page is regenerable from git and the local runtime
# transcripts, and it describes how ONE machine's sessions used the
# project — local, derived, and no business of the repository.
#
# Appended rather than written, so a project's own .gitignore rules survive,
# and skipped for the framework repository itself: its own .gitignore already
# carries these rules and is reported as-is, the same pattern as Data
# protection above.

echo "Generated and runtime artifacts"
ARTIFACT_IGNORE_RULES=".claude/agents/
.claude/worktrees/
.ia-engineering/usage/"

MISSING_ARTIFACT_IGNORES=""
while IFS= read -r rule; do
  if [ ! -f .gitignore ] || ! grep -qxF "$rule" .gitignore; then
    MISSING_ARTIFACT_IGNORES="$MISSING_ARTIFACT_IGNORES$rule
"
  fi
done < <(printf '%s\n' "$ARTIFACT_IGNORE_RULES")

if [ -z "$MISSING_ARTIFACT_IGNORES" ]; then
  same ".gitignore (generated/runtime-artifact rules already present)"
elif [ "$DRY_RUN" -eq 1 ]; then
  printf '  [dry-run] append to .gitignore:\n'
  printf '%s' "$MISSING_ARTIFACT_IGNORES" | sed 's/^/    /'
else
  {
    echo ""
    echo "# IA Engineering — generated and runtime artifacts (installed by"
    echo "# Adapters/scripts/install.sh). .claude/agents/ is generate-agents.sh's"
    echo "# derived output, regenerable with --check (Adapters/ai-runtimes/README.md)."
    echo "# .claude/worktrees/ is this runtime's own per-session scratch state for"
    echo "# isolated subagents. .ia-engineering/usage/ is usage-dashboard.sh's"
    echo "# locally generated page."
    printf '%s' "$MISSING_ARTIFACT_IGNORES"
  } >> .gitignore
  did ".gitignore (appended $(printf '%s' "$MISSING_ARTIFACT_IGNORES" | grep -c .) generated/runtime-artifact rule(s))"
fi
echo

# --- Verify ----------------------------------------------------------------
# Core/MAIN_AGENT_CONDUCT.md's Verification Over Waiting requires confirming
# real state rather than trusting a report. An installer that prints "done"
# without checking anything is the same defect. This proves the hook is live by
# running it, rather than asserting that copying a file made it work.

echo "Verification"

# The probes invoke the commit-msg hook directly, and that hook exits 0
# unconditionally while a merge is in progress — its MERGE_HEAD exception,
# which exists because an auto-generated merge subject can never carry an
# Employee trailer. So during a merge the negative probe passes straight
# through the exception, the hook "accepts" `Employee: executor`, and this
# script would report a correctly-installed hook as "installed but not
# enforcing".
#
# That false warning was harmless while setup-project-bootstrap.sh discarded
# this script's exit status. WU-IAENG-159 stops discarding it, which would have
# converted a false warning into a false FAILURE on a correct bootstrap run
# during a merge. The probes are skipped instead — and the skip is announced,
# because an unannounced skip is the defect this milestone has spent eleven
# fixes removing.
MERGE_IN_PROGRESS=0
if [ -f "$(git rev-parse --git-path MERGE_HEAD 2>/dev/null || echo /nonexistent)" ]; then
  MERGE_IN_PROGRESS=1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  say "skipped (dry run)"
elif [ "$NO_HOOKS" -eq 1 ]; then
  say "hooks not installed — nothing to verify"
elif [ "$MERGE_IN_PROGRESS" -eq 1 ]; then
  say "hook probes skipped: a merge is in progress."
  say "  The commit-msg hook exits 0 unconditionally under MERGE_HEAD, by"
  say "  design, so both probes would pass regardless of whether the hook"
  say "  actually enforces anything. Re-run install.sh after the merge"
  say "  completes to verify enforcement."
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

  # The pre-commit hook reads the index, so it is probed against a THROWAWAY
  # index (GIT_INDEX_FILE) seeded from HEAD plus one staged document — the
  # real index and working tree are untouched. Proves the hook resolves the
  # scanner and that the scanner refuses, rather than that a file was copied.
  PRE_COMMIT="$PROJECT/$(git config --local core.hooksPath || echo '.git/hooks')/pre-commit"
  if [ ! -x "$PRE_COMMIT" ]; then
    warn "pre-commit hook is not executable at $PRE_COMMIT"
  else
    PROBE_INDEX="$(mktemp)"
    rm -f "$PROBE_INDEX"
    if git rev-parse --verify --quiet HEAD >/dev/null; then
      GIT_INDEX_FILE="$PROBE_INDEX" git read-tree HEAD
    fi
    PROBE_BLOB="$(printf 'probe\n' | git hash-object -w --stdin)"
    GIT_INDEX_FILE="$PROBE_INDEX" git update-index --add \
      --cacheinfo "100644,$PROBE_BLOB,iaeng-install-probe.xlsx"
    if GIT_INDEX_FILE="$PROBE_INDEX" "$PRE_COMMIT" > /dev/null 2>&1; then
      warn "the pre-commit hook ACCEPTED a staged .xlsx document. The hook is installed but not enforcing — check that it resolves Adapters/scripts/data-policy-scan.sh."
    else
      say "pre-commit hook refuses a staged document (Standards/DATA_PROTECTION_STANDARD.md)"
    fi
    rm -f "$PROBE_INDEX"
  fi
fi
echo

# --- Result ----------------------------------------------------------------

echo "Result"
printf '  %s installed/updated, %s already current' "$CHANGED" "$SKIPPED"
if [ "$PROBLEMS" -gt 0 ]; then
  printf ', %s problem(s)' "$PROBLEMS"
fi
if [ "$ACTIONS" -gt 0 ]; then
  printf ', %s action(s) for this project' "$ACTIONS"
fi
printf '\n'

# Stated explicitly so the two lines are never conflated by a reader or by a
# caller: `>` items are next steps for the adopting project and do not affect
# the exit status; `!` items are faults and do.
if [ "$ACTIONS" -gt 0 ] && [ "$PROBLEMS" -eq 0 ]; then
  echo "  The '>' items above are next steps for this project, not installation"
  echo "  faults — this run succeeded and exits 0."
fi

if [ "$FRAMEWORK" != "$PROJECT" ]; then
  echo
  echo "Not installed by this script, by design:"
  echo "  Branch protection   ./$HOOKS_REL/Adapters/scripts/setup-branch-protection.sh"
  echo "                      (mutates shared repository settings; run once per repo)"
  # Suppressed when setup-project-bootstrap.sh is the caller: it is the script
  # that installs the stack half, and naming it as the thing to run next, while
  # it is running, sent the reader in a circle (DEF-12, issue #181).
  if [ -z "${IAENG_FROM_BOOTSTRAP:-}" ]; then
    echo "  Stack CI/container  ./$HOOKS_REL/Adapters/scripts/setup-project-bootstrap.sh <stack>"
    echo "                      (needs the stack decided in Workflows/PROJECT_BOOTSTRAP.md Phase B)"
  fi
  echo "  Runtime hooks       ./$HOOKS_REL/Adapters/ai-runtimes/claude-code/install-hooks.sh"
  echo "  Runtime skills      ./$HOOKS_REL/Adapters/ai-runtimes/claude-code/install-skills.sh"
  echo "                      (writes the COMMITTED .claude/settings.json, which decides what"
  echo "                       the model may do — a project reviews that like code)"
  echo "  Runtime agents      ./$HOOKS_REL/Adapters/ai-runtimes/generate-agents.sh"
  echo "                      (depends on which AI runtime the project uses)"
fi

[ "$PROBLEMS" -gt 0 ] && exit 1
exit 0
