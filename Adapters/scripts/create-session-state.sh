#!/usr/bin/env bash
# IA Engineering — create a project's .ia-engineering/SESSION_STATE.md
#
# WHAT THIS EXISTS FOR
#
# An adopting project creates its dated operational state file once, right
# after its first commit (Workflows/PROJECT_BOOTSTRAP.md Step 4 item 5,
# Workflows/ONBOARDING.md Step 1 item 3). Done by hand, that is a manual
# extraction with two mistakes nothing reports until the first session
# (issue #218):
#
#   - copying the whole of Templates/SESSION_STATE.md instead of the fenced
#     block under "Template" (issue #213): session-start.sh then reads the
#     placeholder `_Last updated:` line and warns "no parsable date";
#   - a localized month name ("août"), which lib.sh's iaeng_month_num does
#     not recognise, so the header-freshness check can never fire.
#
# This script writes exactly the fenced block, with the project name and
# `_Last updated: <D Month YYYY> by <who>` filled in, the month name taken
# under LC_ALL=C (English, the form session-start.sh parses).
#
# WHAT IT REFUSES (exit 1, nothing written)
#
#   - a directory that is not a git work tree, or the inside of the
#     framework's own submodule (run it from the project root);
#   - a project with no commit yet: a state file older than HEAD is reported
#     "N commit(s) behind" on the first session, and the adoption commit is
#     what makes HEAD exist (Workflows/PROJECT_BOOTSTRAP.md Step 4 item 5);
#   - an existing .ia-engineering/SESSION_STATE.md, or a link in its place:
#     it holds the project's state, and overwriting it discards real work;
#   - a .ia-engineering that is a symbolic link: the file would land outside
#     the project;
#   - a path git does not ignore: the file records what is currently weak
#     and is never committed (Standards/DATA_PROTECTION_STANDARD.md).
#     Adapters/scripts/install.sh adds the ignore rule.
#
# It FAILS CLOSED (exit 2, nothing written) when it cannot do the job it
# claims: the template is missing, the fenced block or one of the two lines
# it fills is not where it should be, `date` does not give a parsable date,
# or git cannot answer whether the path is ignored. A helper that wrote a
# half-filled file and exited 0 would recreate the defect it exists to stop.
#
# USAGE
#
#   ./ia-engineering/Adapters/scripts/create-session-state.sh [--name NAME] [--by WHO]
#
#   --name NAME   the project name in the "# SESSION STATE — " heading
#                 (default: the name of the project's root directory)
#   --by WHO      who the header says made this update
#                 (default: git config user.name; the template's placeholder
#                 when that is unset)
#
# Run from the project root (or anywhere inside the project's work tree).
# Exit 0 created, 1 refused, 2 failed closed.

set -uo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE="$FRAMEWORK_ROOT/Templates/SESSION_STATE.md"
REL=".ia-engineering/SESSION_STATE.md"

refuse() { printf 'create-session-state: refused — %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '  %s\n' "$2" >&2; exit 1; }
fail()   { printf 'create-session-state: cannot proceed — %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '  %s\n' "$2" >&2; exit 2; }

usage() { sed -n '/^# USAGE/,/^# Exit 0/p' "$0" | sed 's/^# \{0,1\}//'; }

NAME=""
BY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || fail "--name needs a value"; NAME="$2"; shift 2 ;;
    --by)   [ $# -ge 2 ] || fail "--by needs a value";   BY="$2";   shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" "Usage: create-session-state.sh [--name NAME] [--by WHO]" ;;
  esac
done

# --- where the project is ---------------------------------------------------
TOP="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || refuse "not inside a git work tree" "Run it from the adopting project's root, after its first commit."
SUPER="$(git rev-parse --show-superproject-working-tree 2>/dev/null)"
if [ -n "$SUPER" ]; then
  refuse "this directory is inside a submodule ($TOP), not the project" \
    "Run it from the project root ($SUPER): ./ia-engineering/Adapters/scripts/create-session-state.sh"
fi

# --- 1. after the first commit, never before ---------------------------------
git -C "$TOP" rev-parse --verify -q HEAD >/dev/null 2>&1 \
  || refuse "the project has no commit yet" \
       "Make the adoption commit first (Workflows/PROJECT_BOOTSTRAP.md Step 4 item 5): a state file older than HEAD is reported \"N commit(s) behind\" on the first session."

# --- 2. never overwrite --------------------------------------------------------
STATE="$TOP/$REL"
[ -L "$TOP/.ia-engineering" ] && refuse "$TOP/.ia-engineering is a symbolic link" "The state file would be written outside the project. Make it a real directory."
if [ -e "$STATE" ] || [ -L "$STATE" ]; then
  refuse "$REL already exists" "It holds this project's state; edit it instead. To start over, move it aside yourself first."
fi

# --- 4 (checked before writing). gitignored ------------------------------------
git -C "$TOP" check-ignore -q "$REL" 2>/dev/null
case $? in
  0) ;;
  1) refuse "$REL is not ignored by git" \
       "It must never be committed. Run ./ia-engineering/Adapters/scripts/install.sh, which adds the rule, or add '$REL' to .gitignore." ;;
  *) fail "git check-ignore could not tell whether $REL is ignored" ;;
esac

# --- 3. the fenced block, filled -----------------------------------------------
[ -r "$TEMPLATE" ] || fail "template not found or unreadable: $TEMPLATE"

# The block is the first ```markdown fence after the "# Template" heading, up
# to its closing fence. Carriage returns are dropped: Templates/ is not forced
# to LF, and a CRLF checkout would otherwise put a \r on every line written.
BLOCK="$(awk '
  { sub(/\r$/, "") }
  /^# Template$/            { t = 1; next }
  t && !f && /^```markdown$/ { f = 1; next }
  f && /^```$/              { done = 1; exit }
  f                          { print }
  END { if (!done) exit 3 }
' "$TEMPLATE")" || fail "no complete \`\`\`markdown block under \"# Template\" in $TEMPLATE"

NAME_LINE='# SESSION STATE — [project name]'
DATE_LINE='_Last updated: [DD Month YYYY, morning/evening] by [Employee or person]_'
[ "$(grep -cxF -- "$NAME_LINE" <<< "$BLOCK")" = 1 ] || fail "the template block has no single line '$NAME_LINE' to fill" "Templates/SESSION_STATE.md changed shape; update this script with it."
[ "$(grep -cxF -- "$DATE_LINE" <<< "$BLOCK")" = 1 ] || fail "the template block has no single line '$DATE_LINE' to fill" "Templates/SESSION_STATE.md changed shape; update this script with it."

# %d, not %-d: the "-" flag is a GNU/BSD extension; stripping the zero here is
# portable. LC_ALL=C is the point: an English month name is what
# iaeng_month_num in hooks/lib.sh recognises.
TODAY="$(LC_ALL=C date '+%d %B %Y' 2>/dev/null)"
TODAY="${TODAY#0}"
printf '%s' "$TODAY" | grep -qxE '[1-9][0-9]? (January|February|March|April|May|June|July|August|September|October|November|December) [0-9]{4}' \
  || fail "date did not give a 'D Month YYYY' date under LC_ALL=C (got '$TODAY')"

[ -n "$NAME" ] || NAME="$(basename "$TOP")"
[ -n "$BY" ] || BY="$(git -C "$TOP" config user.name 2>/dev/null)"
[ -n "$BY" ] || BY="[Employee or person]"
case "$NAME$BY" in
  *$'\n'*|*$'\r'*) fail "--name and --by must be one line each" ;;
esac

NEW_NAME_LINE="# SESSION STATE — $NAME"
NEW_DATE_LINE="_Last updated: $TODAY by ${BY}_"

# Replaced as whole lines through ENVIRON, so a name holding &, \ or / is
# written as typed: no sed replacement syntax and no awk -v escape processing.
CONTENT="$(OLD1="$NAME_LINE" NEW1="$NEW_NAME_LINE" OLD2="$DATE_LINE" NEW2="$NEW_DATE_LINE" awk '
  $0 == ENVIRON["OLD1"] { print ENVIRON["NEW1"]; next }
  $0 == ENVIRON["OLD2"] { print ENVIRON["NEW2"]; next }
  { print }
' <<< "$BLOCK")" || fail "could not fill the template block"

mkdir -p "$TOP/.ia-engineering" || fail "could not create $TOP/.ia-engineering"
# noclobber: if the file appeared since the check above, this fails rather
# than overwriting it.
( set -C; printf '%s\n' "$CONTENT" > "$STATE" ) 2>/dev/null \
  || refuse "could not create $REL without overwriting (it exists now, or the directory is not writable)"

printf 'Created %s from the Template block of %s.\n' "$REL" "$TEMPLATE"
printf 'Gitignored: yes — never committed.\n'
printf 'Header, as session-start.sh reads it:\n'
printf '  %s\n' "$NEW_NAME_LINE"
printf '  %s\n' "$(grep -m1 -E '^_Last updated:' "$STATE" | sed 's/^_//; s/_$//')"
printf 'Fill in the remaining [placeholders] before the first session works from it, and\n'
printf 'refresh the _Last updated: line on every edit (Templates/SESSION_STATE.md, Snapshot Discipline).\n'
exit 0
