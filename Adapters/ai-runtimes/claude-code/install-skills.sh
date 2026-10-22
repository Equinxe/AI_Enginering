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
#   ./ia-engineering/Adapters/ai-runtimes/claude-code/install-skills.sh --check [--quiet]
#
#   --list   print what would be installed and where, and change nothing
#   --force  overwrite a skill that already exists in the project and differs
#   --check  report what a run would find, and write nothing (below)
#   --quiet  with --check: print nothing when there is nothing to act on
#
# --check (WU-IAENG-357): THE SAME DECISIONS, REPORTED INSTEAD OF APPLIED, in
# the record format of Adapters/scripts/install.sh --check:
#
#   <family> TAB <status> TAB <path> TAB <detail>
#
#   skill          current | absent | differs | not-applicable | fault
#                  (current: `diff -r` finds no difference from its source,
#                  the same comparison a run makes; not-applicable: a skill
#                  for projects, in the framework checkout itself)
#   gitattributes  present | missing          (detail: the LF rule)
#
# Actionable: absent, differs, missing, fault. A closing `#` line counts each
# family and gives the remedies. Exit codes: 0 nothing to act on, 3 drift,
# 1 a fault (no skill found to compare), 2 usage (--check with --list or
# --force; --quiet without --check). A run under --check writes nothing and
# runs no git command.
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
CHECK=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --list)  LIST=1 ;;
    --check) CHECK=1 ;;
    --quiet) QUIET=1 ;;
    --help|-h)
      sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "install-skills.sh: unknown option '$arg'" >&2; exit 2 ;;
  esac
done
if [ "$CHECK" -eq 1 ] && { [ "$LIST" -eq 1 ] || [ "$FORCE" -eq 1 ]; }; then
  echo "install-skills.sh: --check reports and writes nothing; it cannot be combined with --list or --force." >&2
  exit 2
fi
if [ "$QUIET" -eq 1 ] && [ "$CHECK" -eq 0 ]; then
  echo "install-skills.sh: --quiet only applies to --check." >&2
  exit 2
fi

# Under --check: no git command takes an optional lock. None runs today; the
# variable is set before any could (git's spelling of --no-optional-locks).
[ "$CHECK" -eq 1 ] && export GIT_OPTIONAL_LOCKS=0

# --check keeps the real stdout on fd 3 for the records and sends every
# human-readable line to /dev/null, as install.sh --check does.
REPORT=""
[ "$CHECK" -eq 1 ] && exec 3>&1 >/dev/null

# record <family> <status> <path> <detail> — one line: flat() flattens
# fields 2 to 4, so a directory name can neither split the record nor carry
# a terminal escape. Field 1 is a literal.
# >>> record sanitiser — byte-identical in install.sh, install-hooks.sh,
# install-skills.sh and check-framework-drift.sh: none of them sources
# another, and Adapters/scripts/tests/run.sh compares the four (WU-IAENG-366).
# flat <text> — every control character (TAB, LF, CR, ESC, ...) becomes a
# space: a record is one line and carries no terminal escape.
# The C1 controls (U+0080-U+009F, CSI among them) are UTF-8 pairs \xc2\x80 to
# \xc2\x9f: a pair becomes one space. A lone byte in that range is part of
# another character and is left alone (SEC-IAENG-358-01). The result is the
# same under the C locale and a UTF-8 one.
C1_LEAD=$'\xc2'
flat() {
  FLAT="${1//[[:cntrl:]]/ }"
  FLAT="${FLAT//"$C1_LEAD"[$'\x80'-$'\x9f']/ }"
}
# <<< record sanitiser
record() {
  local f2 f3 f4
  flat "$2"; f2="$FLAT"; flat "$3"; f3="$FLAT"; flat "$4"; f4="$FLAT"
  REPORT="$REPORT$1"$'\t'"$f2"$'\t'"$f3"$'\t'"$f4"$'\n'
}

# check_report — prints the records (under --quiet the actionable ones) and
# the closing line on fd 3, then exits 1 (a fault), 3 (drift) or 0.
check_report() {
  local actionable="" faults=0 _fam _st _rest _me
  while IFS=$'\t' read -r _fam _st _rest; do
    case "$_st" in
      fault) faults=$((faults + 1)); actionable="$actionable$_fam"$'\t'"$_st"$'\t'"$_rest"$'\n' ;;
      absent|differs|missing) actionable="$actionable$_fam"$'\t'"$_st"$'\t'"$_rest"$'\n' ;;
    esac
  done <<< "$REPORT"
  [ "$QUIET" -eq 1 ] && [ -z "$actionable" ] && exit 0
  flat "$0"; _me="$FLAT"
  {
    if [ "$QUIET" -eq 1 ]; then printf '%s' "$actionable"; else printf '%s' "$REPORT"; fi
    # The script's path reaches awk through the environment, not -v, which
    # would decode its backslashes.
    IAENG_ME="$_me" awk -F '\t' '
      NF == 0 { next }
      { n[$1]++; s[$1 FS $2]++; if ($2 ~ /^(absent|differs|missing|fault)$/) act++; if ($2 == "fault") f++ }
      function part(fam, label, statuses,   k, i, out, sep, st) {
        out = n[fam] + 0 " " label
        k = split(statuses, st, " ")
        sep = ": "
        for (i = 1; i <= k; i++) if (s[fam FS st[i]]) { out = out sep s[fam FS st[i]] " " st[i]; sep = ", " }
        return out
      }
      END {
        line = "# install-skills.sh --check: " (act + 0) " to act on. " part("skill", "skill(s)", "current absent differs not-applicable fault")
        line = line "; " part("gitattributes", ".gitattributes rule(s)", "present missing")
        line = line "; " (f + 0) " fault(s)."
        if (s["skill" FS "absent"] || s["gitattributes" FS "missing"])
          line = line " absent/missing: re-run " ENVIRON["IAENG_ME"] " without --force; it adds them and overwrites nothing."
        if (s["skill" FS "differs"])
          line = line " differs: diff -r <source> <path>; --force only for a skill the project never edited."
        if (f) line = line " fault: read the fault record(s); nothing is current until they are fixed."
        print line
      }' <<< "$REPORT"
  } >&3
  [ "$faults" -gt 0 ] && exit 1
  [ -n "$actionable" ] && exit 3
  exit 0
}

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(pwd)"
SRC="$HERE/skills"

# The skills that also belong in the framework repository's own .claude/.
FRAMEWORK_SKILLS="dashboard"

if [ ! -d "$SRC" ]; then
  echo "install-skills.sh: $SRC is missing" >&2
  [ "$CHECK" -eq 1 ] && { record skill fault "(none)" "$SRC is missing"; check_report; }
  exit 1
fi

# skill_state <source dir> <destination> — absent, current or differs, in
# SKILL_STATE (no subshell). One comparison, for a run and for --check.
skill_state() {
  if [ ! -e "$2" ]; then
    SKILL_STATE=absent
  elif diff -r "$1" "$2" >/dev/null 2>&1; then
    SKILL_STATE=current
  else
    SKILL_STATE=differs
  fi
}

# The installed skills' LF rule (issue #242), matched as install-hooks.sh
# matches its own: only a CR that ends a line is dropped, never one inside a
# line (SEC-IAENG-353-01), and the file is read into the shell and matched
# there as a whole line, so no pipe can fail the match with SIGPIPE and no
# grep that drops a CR on its own (Git for Windows') decides it.
LF_RULE="/.claude/skills/** text eol=lf"
ATTR="$PROJECT/.gitattributes"
lf_rule_present() {
  local content
  [ -f "$ATTR" ] || return 1
  content="$(sed $'s/\r$//' "$ATTR")"
  [[ $'\n'"$content"$'\n' == *$'\n'"$LF_RULE"$'\n'* ]]
}

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
    [ "$CHECK" -eq 1 ] && record skill not-applicable ".claude/skills/$name" "not for the framework checkout"
    continue
  fi
  FOUND=$((FOUND + 1))
  dest="$PROJECT/.claude/skills/$name"

  if [ "$LIST" -eq 1 ]; then
    echo "  $name -> .claude/skills/$name"
    continue
  fi

  skill_state "$skill_dir" "$dest"
  if [ "$CHECK" -eq 1 ]; then
    src_rel="${skill_dir%/}"
    case "$src_rel" in "$PROJECT"/*) src_rel="${src_rel#"$PROJECT"/}" ;; esac
    record skill "$SKILL_STATE" ".claude/skills/$name" "$src_rel"
    continue
  fi

  if [ "$SKILL_STATE" = current ]; then
    echo "  = .claude/skills/$name already current"
    CURRENT=$((CURRENT + 1))
    continue
  fi

  if [ "$SKILL_STATE" = differs ] && [ "$FORCE" -eq 0 ]; then
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
  [ "$CHECK" -eq 1 ] && { record skill fault "(none)" "no skills found under $SRC"; check_report; }
  exit 1
fi

if [ "$CHECK" -eq 1 ]; then
  if lf_rule_present; then
    record gitattributes present .gitattributes "$LF_RULE"
  else
    record gitattributes missing .gitattributes "$LF_RULE"
  fi
  check_report
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
# path, and a file it sourced would have to be one too. LF_RULE, ATTR and
# lf_rule_present are defined above, with skill_state.
# Read before the append starts: a last line without its newline gets one.
SEP=""
if [ -s "$ATTR" ] && [ -n "$(tail -c 1 "$ATTR")" ]; then SEP=$'\n'; fi
if lf_rule_present; then
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
