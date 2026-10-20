#!/usr/bin/env bash
# IA Engineering — install the Claude Code skills into a project
#
# Copies Adapters/ai-runtimes/claude-code/skills/* into the project's
# .claude/skills/, so a slash command like /create-project or /dashboard
# exists in this runtime without the framework's own content ever mentioning
# one.
#
# WHY THIS IS A SEPARATE SCRIPT FROM install-hooks.sh
#
# It could have been three lines added there. A file called install-hooks.sh
# that also installs skills is the quiet kind of mismatch this repository
# refuses elsewhere: the name stops describing the job, and the next person
# reading the installer list has to open it to find out what it does.
#
# WHY THE SKILL IS NOT PART OF THE FRAMEWORK
#
# Core/AI_MANIFEST.md Principle X requires the framework to stay AI-agnostic.
# Slash commands are a Claude Code feature, so the wrapper lives here in the
# runtime Adapter and the Workflow it invokes never mentions it. A different
# runtime writes its own wrapper beside this one and the Workflow is untouched.
#
# IN THE FRAMEWORK CHECKOUT ITSELF
#
# Only the skills named in FRAMEWORK_SKILLS below are installed there, and the
# others are skipped with a note. /create-project bootstraps a project that
# imports the framework; installing it in the framework's own .claude/ would
# offer the framework a command for somebody else's repository. /dashboard
# measures whichever project it runs in, the framework repository included
# (WU-IAENG-342). Its installed copy is committed beside .claude/settings.json,
# the same kind of runtime configuration, and the hook tests check that the
# copy matches its source here.
#
# Usage, from the project root:
#   ./ia-engineering/Adapters/ai-runtimes/claude-code/install-skills.sh [--force] [--list]
#
#   --list   print what would be installed and where, and change nothing
#   --force  overwrite a skill that already exists in the project and differs
#
# An existing skill of the same name is NEVER overwritten without --force. A
# project may have edited it, and silently replacing edited content is the
# failure mode install-hooks.sh already refuses for settings.json. One that is
# identical to its source is reported as current, so a re-run is quiet.
#
# The project's .gitattributes gets the line "/.claude/skills/** text eol=lf"
# when it does not have it yet (issue #242): the launchers are bash scripts,
# and a clone with core.autocrlf=true would otherwise check them out CRLF,
# unlike the framework's own copies. Nothing else in .gitattributes is
# touched; --list writes nothing.

set -uo pipefail
export LC_ALL=C

FORCE=0
LIST=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --list)  LIST=1 ;;
    --help|-h)
      sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "install-skills.sh: unknown option '$arg'" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(pwd)"
SRC="$HERE/skills"

# The skills that also belong in the framework repository's own .claude/.
FRAMEWORK_SKILLS="dashboard"

if [ ! -d "$SRC" ]; then
  echo "install-skills.sh: $SRC is missing" >&2
  exit 1
fi

IN_FRAMEWORK=0
if [ -f "$PROJECT/Core/AI_MANIFEST.md" ] && [ -d "$PROJECT/Adapters/ai-runtimes" ]; then
  IN_FRAMEWORK=1
  echo "  This is the IA Engineering checkout itself: only the skills it uses for its own"
  echo "  work are installed here ($FRAMEWORK_SKILLS); the others are Adapters for projects."
fi

wanted() {
  [ "$IN_FRAMEWORK" -eq 0 ] && return 0
  case " $FRAMEWORK_SKILLS " in *" $1 "*) return 0 ;; esac
  return 1
}

INSTALLED=0
SKIPPED=0
CURRENT=0
FOUND=0

for skill_dir in "$SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  if ! wanted "$name"; then
    echo "  - $name: not for the framework checkout — skipped."
    continue
  fi
  FOUND=$((FOUND + 1))
  dest="$PROJECT/.claude/skills/$name"

  if [ "$LIST" -eq 1 ]; then
    echo "  $name -> .claude/skills/$name"
    continue
  fi

  if [ -e "$dest" ] && diff -r "$skill_dir" "$dest" >/dev/null 2>&1; then
    echo "  = .claude/skills/$name already current"
    CURRENT=$((CURRENT + 1))
    continue
  fi

  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    echo "  ! $name already exists at .claude/skills/$name and differs — left untouched." >&2
    echo "    A project may have edited it. Re-run with --force to replace it." >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if ! mkdir -p "$dest"; then
    echo "install-skills.sh: could not create $dest" >&2
    exit 1
  fi
  if ! cp -R "$skill_dir." "$dest/"; then
    echo "install-skills.sh: could not copy $name into $dest" >&2
    exit 1
  fi
  echo "  + .claude/skills/$name"
  INSTALLED=$((INSTALLED + 1))
done

# The denominator, always: "0 installed" and "nothing to install" are different
# states, and only one of them is a problem (Adapters/README.md, The Check
# Convention, rule 3).
if [ "$FOUND" -eq 0 ]; then
  echo "install-skills.sh: no skills found under $SRC — nothing to install." >&2
  exit 1
fi

if [ "$LIST" -eq 1 ]; then
  echo "  ($FOUND skill(s) available; nothing written)"
  exit 0
fi

echo "  $INSTALLED installed, $CURRENT already current, $SKIPPED left untouched, of $FOUND available."

# THE INSTALLED SKILLS ARE PINNED TO LF IN THE PROJECT (issue #242). Exact
# line (a CRLF .gitattributes read as LF); appended on its own line, so a file
# without a final newline is not joined to it. The same few lines as
# install-hooks.sh's, written out rather than shared: that script is a control
# path, and a file it sourced would have to be one too.
LF_RULE="/.claude/skills/** text eol=lf"
ATTR="$PROJECT/.gitattributes"
# Read before the append starts: a last line without its newline gets one.
SEP=""
if [ -s "$ATTR" ] && [ -n "$(tail -c 1 "$ATTR")" ]; then SEP=$'\n'; fi
if [ -f "$ATTR" ] && tr -d '\r' < "$ATTR" | grep -qxF "$LF_RULE"; then
  :
elif {
  printf '%s' "$SEP"
  echo "# IA Engineering — .claude/skills/ is written by install-skills.sh and holds"
  echo "# bash launchers; LF on every checkout, as in the framework (issue #242)."
  echo "$LF_RULE"
} >> "$ATTR"; then
  echo "  + .gitattributes: $LF_RULE (commit it with the skills)"
else
  echo "install-skills.sh: could not append to $ATTR; add this line to it by hand: $LF_RULE" >&2
  exit 1
fi

# VERIFIED, NOT ASSUMED: a skill Claude Code cannot read is not installed,
# whatever the copy reported. The one property that decides that is the
# presence of SKILL.md at the top of the directory.
MISSING=""
for skill_dir in "$SRC"/*/; do
  name="$(basename "$skill_dir")"
  wanted "$name" || continue
  [ -f "$PROJECT/.claude/skills/$name/SKILL.md" ] || MISSING="$MISSING $name"
done
if [ -n "$MISSING" ]; then
  echo "install-skills.sh: installed but unreadable —$MISSING has no SKILL.md at .claude/skills/<name>/SKILL.md." >&2
  exit 1
fi

echo "  verified: every installed skill has its SKILL.md where the runtime reads it."
