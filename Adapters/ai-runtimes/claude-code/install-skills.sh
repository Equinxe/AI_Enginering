#!/usr/bin/env bash
# IA Engineering — install the Claude Code skills into a project
#
# Copies Adapters/ai-runtimes/claude-code/skills/* into the project's
# .claude/skills/, so a slash command like /create-project exists in this
# runtime without the framework's own content ever mentioning one.
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
# Usage, from the project root:
#   ./ia-engineering/Adapters/ai-runtimes/claude-code/install-skills.sh [--force] [--list]
#
#   --list   print what would be installed and where, and change nothing
#   --force  overwrite a skill that already exists in the project
#
# An existing skill of the same name is NEVER overwritten without --force. A
# project may have edited it, and silently replacing edited content is the
# failure mode install-hooks.sh already refuses for settings.json.

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

if [ ! -d "$SRC" ]; then
  echo "install-skills.sh: $SRC is missing" >&2
  exit 1
fi

# Refuse to install into the framework's own checkout. Running this from the
# framework root rather than from a project would put the skill in the
# framework's .claude/, where it is not wanted and where it would then be
# committed as framework content — the exact thing Principle X rules out.
if [ -f "$PROJECT/Core/AI_MANIFEST.md" ] && [ -d "$PROJECT/Adapters/ai-runtimes" ]; then
  echo "install-skills.sh: this looks like the IA Engineering checkout itself, not a project." >&2
  echo "  Run it from the root of the project that imported the framework." >&2
  echo "  The skill is an Adapter for other projects; installing it here would" >&2
  echo "  make a Claude-Code-specific file part of the framework's own content." >&2
  exit 1
fi

INSTALLED=0
SKIPPED=0
FOUND=0

for skill_dir in "$SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  FOUND=$((FOUND + 1))
  dest="$PROJECT/.claude/skills/$name"

  if [ "$LIST" -eq 1 ]; then
    echo "  $name -> .claude/skills/$name"
    continue
  fi

  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    echo "  ! $name already exists at .claude/skills/$name — left untouched." >&2
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

echo "  $INSTALLED installed, $SKIPPED left untouched, of $FOUND available."

# VERIFIED, NOT ASSUMED: a skill Claude Code cannot read is not installed,
# whatever the copy reported. The one property that decides that is the
# presence of SKILL.md at the top of the directory.
MISSING=""
for skill_dir in "$SRC"/*/; do
  name="$(basename "$skill_dir")"
  [ -f "$PROJECT/.claude/skills/$name/SKILL.md" ] || MISSING="$MISSING $name"
done
if [ -n "$MISSING" ]; then
  echo "install-skills.sh: installed but unreadable —$MISSING has no SKILL.md at .claude/skills/<name>/SKILL.md." >&2
  exit 1
fi

echo "  verified: every installed skill has its SKILL.md where the runtime reads it."
