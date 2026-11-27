#!/usr/bin/env bash
# IA Engineering — hook tests: the installers do not write through a .claude
# that is a link, nor through a .gitattributes that is one (WU-IAENG-457)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/claude-link.sh [--verbose]
#
# THE BEHAVIOUR. When a project's .claude is a link (a symbolic link, or a
# Windows junction), mkdir -p, mktemp and mv all follow it, so install-hooks.sh
# wrote settings.json into the directory the link leads to, and --check said
# nothing (issue #282). install-skills.sh wrote .claude/skills/<name> the same
# way, and both appended their .gitattributes rule through a linked
# .gitattributes (issue #255). Now, before anything is written:
#
#   - a run refuses a linked .claude (exit 1, nothing written: no directory,
#     no temporary file, no .gitattributes line), naming where it leads and
#     the remedy; --follow-claude-link installs there, with a notice on
#     stderr;
#   - a link to Claude Code's user settings directory, by either of its
#     names, ${CLAUDE_CONFIG_DIR:-$HOME/.claude} and $HOME/.claude, is
#     refused with the flag too;
#   - --check reports the link as a fault (exit 1), never "0 fault(s)";
#   - install-skills.sh applies the same rule to .claude, .claude/skills and
#     each .claude/skills/<name>;
#   - a .gitattributes that is a link is not appended to: the run exits 1 and
#     prints the line to add, and --check reports a fault.
#
# What is proved, for each kind of directory link the platform can make: a
# symbolic link (ln -s, or an MSYS sys link where ln -s copies) and a junction
# (mklink /J, Windows only):
#
#   - install-hooks.sh, .claude a link to an empty directory: a run exits 1,
#     the directory stays empty, the project gets no .gitattributes, and the
#     message names the directory and --follow-claude-link; --check exits 1
#     with the fault record; --follow-claude-link exits 0, writes the template
#     there, says so on stderr, and writes the project's .gitattributes rule.
#   - install-hooks.sh, .claude a link to a directory that holds a project's
#     own settings.json and a settings.local.json: a run and a --force run
#     exit 1, that directory byte-identical; --check exits 1 with the fault
#     record, not "customized", and no "disabled" or "shadowed" record read
#     behind the link; --follow-claude-link merges there, the other keys kept.
#   - .claude a link to the user settings directory, named by a fake
#     CLAUDE_CONFIG_DIR, and by a fake HOME with CLAUDE_CONFIG_DIR unset or
#     naming another directory: a run exits 1 with and without the flag, the
#     directory byte-identical; --check names it in its fault record.
#   - install-skills.sh, .claude a link: a run exits 1, nothing written;
#     --check exits 1 with a fault record for .claude and no record for what
#     lies behind the link; the flag installs the skills there.
#     .claude/skills a link to the user skills directory: a run with the
#     flag exits 1, that directory byte-identical. One skill's directory a
#     link: a run and a --force run exit 1, nothing written; --check reports
#     it; a link to the user skills directory's same skill, or another one,
#     refused with the flag. The same refusals for $HOME/.claude/skills
#     while CLAUDE_CONFIG_DIR names another directory: .claude/skills a link
#     to it, and a skill's directory a link to a skill in it. A user skill
#     that is itself a link (a skill kept in dotfiles): a skill's directory
#     a link to it, by the same name or another, or to a directory inside
#     it, refused with the flag, the dotfiles byte-identical.
#   - .claude a symbolic link to no directory: each installer refuses it with
#     the flag, creating nothing, and --check says it leads nowhere.
#   - --check with --follow-claude-link: exit 2 from each installer.
#   - .gitattributes a symbolic link to a file (#255), for each installer: a
#     run exits 1, the file byte-identical, the rule printed; --check exits 1
#     with a gitattributes fault. The same when the file it leads to already
#     holds both rules, which git does not read through the link (checked
#     with git check-attr). A dangling one: no file appears where it points.
#   - Controls: a plain .claude, and a project reached through a linked
#     parent directory, install as before (exit 0).
#   - The dir_link block, written out in both installers, is byte-identical
#     in the two.
#
# ORACLES (Standards/TESTING_STANDARD.md, Independent Oracle). None is taken
# from the installers' output:
#   - "nothing written": a copy of the link's directory made before the run,
#     compared with diff -r after it;
#   - what --follow-claude-link writes: settings.example.json rendered here
#     with sed for the framework root "ia-engineering", and the skills' own
#     sources;
#   - the messages: the acceptance of the approved Usage plan, "a message
#     naming the target and the remedy"; the target is matched by its own
#     unique directory name, so neither spelling of a Windows path (/c/... or
#     the /tmp mount) decides a check;
#   - --check: install-hooks.sh's header, exit 1 a fault, and the record
#     format "<family> TAB <status> TAB <path> TAB <detail>".
#
# NO TEST REACHES THE REAL USER DIRECTORY. Every installer run gets a fake
# HOME and, but for the one case that tests the HOME fallback, a fake
# CLAUDE_CONFIG_DIR, both under this test's own temporary directory, and every
# link leads into that directory.
#
# A check that cannot make its link here is printed "n/a" with its reason and
# is not counted as a pass: a junction off Windows, or a symbolic link where
# neither form can be made. Each case runs in its own project, in the
# background, as tests/settings-shapes.sh does; a case that did not reach its
# end is a failure.
#
# Exit 0 when every check that ran passed, 1 when any failed, 2 when the
# environment is unusable. With IAENG_HOOK_TESTS_COUNTS set to a file,
# "<total> <failed>" is written there for run.sh.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "claude-link.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
CC="$(cd "$HOOKS/.." && pwd)"

command -v jq >/dev/null 2>&1 || {
  echo "claude-link.sh: jq is required and is not installed. Reported rather than skipped." >&2
  exit 2
}

FAILED=0
TOTAL=0
NA=0
# RES: inside a background case, the file its results go to, one line each:
# "ok<TAB>label", "bad<TAB>label<TAB>detail" or "na<TAB>label<TAB>why".
RES=""
ok() {
  if [ -n "$RES" ]; then printf 'ok\t%s\n' "$1" >> "$RES"; return 0; fi
  TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0
}
bad() {
  if [ -n "$RES" ]; then printf 'bad\t%s\t%s\n' "$1" "$(printf '%s' "${2:-}" | tr '\t\n\r' '   ')" >> "$RES"; return 0; fi
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '         %s\n' "$2"; return 0
}
na() {
  if [ -n "$RES" ]; then printf 'na\t%s\t%s\n' "$1" "$(printf '%s' "${2:-}" | tr '\t\n\r' '   ')" >> "$RES"; return 0; fi
  NA=$((NA + 1)); printf '   n/a   %s (%s)\n' "$1" "${2:-}"; return 0
}
# v <label> <status> — ok when <status> (the $? of the condition just
# evaluated) is 0, else bad with the last run's exit and streams.
v() {
  if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1" "rc=$RC out: $(head -c 300 "$C/out" 2>/dev/null) err: $(head -c 400 "$C/err" 2>/dev/null)"; fi
}
strip_eol_cr() { sed $'s/\r$//'; }

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-claudelink457.XXXXXX")" || { echo "claude-link.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
# Every link made here leads into $T, and rm -rf removes a link, never what
# it leads to, so this removes nothing outside $T.
trap 'cd / && rm -rf "$T"' EXIT

# The oracle: the template rendered for this project, independently of the
# script (its own rendering is a sed of the same placeholder).
TPL="$T/template.json"
sed 's#__IAENG_ROOT__#ia-engineering#g' "$CC/settings.example.json" > "$TPL"
TPL_GROUPS="$(jq '[.hooks[][]] | length' "$TPL" | strip_eol_cr)"
if [ "$TPL_GROUPS" -gt 0 ] 2>/dev/null; then
  ok "fixture: the template has hook groups ($TPL_GROUPS)"
else
  bad "fixture: the template has hook groups" "groups=[$TPL_GROUPS]"
fi
HOOK_RULE="/.claude/settings.json text eol=lf"
SKILL_RULE="/.claude/skills/** text eol=lf"
# What install-skills.sh says of a link into the user skills directory (an
# ERE, the apostrophe matched by "."), after where the link leads.
USER_SKILLS_PLACE="which is, or lies in, Claude Code.s user skills directory or one of its skills"

# The dir_link block is written out in both installers, neither sourcing the
# other: the two copies must stay byte-identical.
sed -n '/^# >>> dir_link/,/^# <<< dir_link/p' "$CC/install-hooks.sh" > "$T/dir_link.hooks"
sed -n '/^# >>> dir_link/,/^# <<< dir_link/p' "$CC/install-skills.sh" > "$T/dir_link.skills"
if [ -s "$T/dir_link.hooks" ] && cmp -s "$T/dir_link.hooks" "$T/dir_link.skills"; then
  ok "the dir_link block is byte-identical in install-hooks.sh and install-skills.sh"
else
  bad "the dir_link block is byte-identical in install-hooks.sh and install-skills.sh" \
    "$(diff "$T/dir_link.hooks" "$T/dir_link.skills" 2>&1 | head -c 400)"
fi

# project <name> [<parent>] — an adopting project of its own for one case,
# the framework under ia-engineering/; no .claude yet. Sets C (the case's
# scratch), IP (the project, as the installers are run from it) and IFW.
project() {
  C="$T/case-$1"
  IP="${2:-$C}/project"
  mkdir -p "$C/home" "$C/userdir" "${2:-$C}"
  IFW="$IP/ia-engineering/Adapters/ai-runtimes/claude-code"
  mkdir -p "$IFW/hooks"
  cp -p "$CC/install-hooks.sh" "$CC/install-skills.sh" "$CC/settings.example.json" "$IFW/"
  cp -p "$HOOKS"/*.sh "$IFW/hooks/"
  cp -R "$CC/skills" "$IFW/"
  chmod +x "$IFW"/hooks/*.sh "$IFW/install-hooks.sh" "$IFW/install-skills.sh"
}
# run <script> [args] — the installer from the project root, with a fake HOME
# and a fake CLAUDE_CONFIG_DIR; ENV_CFG overrides the latter (for the HOME
# fallback, "-u CLAUDE_CONFIG_DIR").
ENV_CFG=""
run() {
  local script="$1"; shift
  local -a envs=("HOME=$C/home")
  if [ "$ENV_CFG" = unset ]; then envs=(-u CLAUDE_CONFIG_DIR "${envs[@]}"); else envs+=("CLAUDE_CONFIG_DIR=$C/userdir"); fi
  ( cd "$IP" && env "${envs[@]}" bash "$IFW/$script" "$@" ) > "$C/out" 2> "$C/err"; RC=$?
}

# dirlink <kind> <target> <link> — a link to a directory. symlink: ln -s, or,
# where ln -s copies (Git for Windows without the right to make native
# links), an MSYS sys link, which bash and every MSYS tool follow as POSIX
# does a symbolic link. junction: mklink /J, where cmd and cygpath exist.
# True only when <link> is then a link that leads to <target>; otherwise
# WHY_NA says why, and nothing is left at <link>.
WHY_NA=""
dirlink() {
  case "$1" in
    symlink)
      ln -s "$2" "$3" 2>/dev/null && [ -L "$3" ] && [ "$3" -ef "$2" ] && return 0
      rm -rf "$3"
      MSYS="${MSYS:+$MSYS }winsymlinks:sys" ln -s "$2" "$3" 2>/dev/null && [ -L "$3" ] && [ "$3" -ef "$2" ] && return 0
      rm -rf "$3"
      WHY_NA="no symbolic link to a directory can be made here (ln -s, native or MSYS sys)"
      return 1 ;;
    junction)
      if command -v cmd >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
        MSYS2_ARG_CONV_EXCL='*' cmd /c mklink /J "$(cygpath -w "$3")" "$(cygpath -w "$2")" >/dev/null 2>&1
        [ "$3" -ef "$2" ] && [ "$(CDPATH='' cd -P -- "$3" && pwd -P)" != "$(CDPATH='' cd -P -- "$(dirname -- "$3")" && pwd -P)/$(basename -- "$3")" ] && return 0
      fi
      WHY_NA="no junction can be made here (mklink /J is Windows only)"
      return 1 ;;
  esac
  WHY_NA="unknown link kind $1"; return 1
}
# filelink <target> <link> — a symbolic link to a file, which may not exist.
filelink() {
  ln -s "$1" "$2" 2>/dev/null && [ -L "$2" ] && return 0
  rm -f "$2"
  MSYS="${MSYS:+$MSYS }winsymlinks:sys" ln -s "$1" "$2" 2>/dev/null && [ -L "$2" ] && return 0
  rm -f "$2"
  WHY_NA="no symbolic link to a file can be made here (ln -s, native or MSYS sys)"
  return 1
}
# snap <dir> — a copy of <dir> beside it, <dir>.orig, for same_as.
snap() { rm -rf "$1.orig"; cp -Rp "$1" "$1.orig"; }
same_as() { diff -r "$1" "$1.orig" >/dev/null 2>&1; }
empty_dir() { [ -d "$1" ] && [ -z "$(find "$1" -mindepth 1 2>/dev/null)" ]; }
# said <text> — the last run printed <text> on stderr (fixed string).
said() { grep -qF -- "$1" "$C/err"; }
# said_re <regex> — the last run printed a line matching <regex> on stderr.
said_re() { grep -qE -- "$1" "$C/err"; }
# record_is <family> <status> <path> <detail ERE> — the last --check printed
# exactly one record with those three fields whose detail matches the ERE.
record_is() {
  [ "$(awk -F '\t' -v f="$1" -v s="$2" -v p="$3" -v re="$4" \
        '$1 == f && $2 == s && $3 == p && $4 ~ re { n++ } END { print n + 0 }' "$C/out")" = 1 ]
}
closing_faults() { tail -n 1 "$C/out" | grep -qF -- "; $1 fault(s)."; }
settings_is_template() { [ -f "$1/settings.json" ] && [ "$(strip_eol_cr < "$1/settings.json")" = "$(cat "$TPL")" ]; }
no_project_attr() { [ ! -e "$IP/.gitattributes" ] && [ ! -L "$IP/.gitattributes" ]; }
# git_here <dir> <git args> — git in <dir>, reading no system, user or XDG
# configuration or attributes file; stdout only.
git_here() {
  ( cd "$1" && shift && HOME="$C/home" XDG_CONFIG_HOME="$C/home/.config" GIT_CONFIG_NOSYSTEM=1 GIT_ATTR_NOSYSTEM=1 git "$@" ) 2>/dev/null
}
has_rule() { [ -f "$IP/.gitattributes" ] && strip_eol_cr < "$IP/.gitattributes" | grep -qxF -- "$1"; }

# =============================================================================
# The cases. Each is a function run in its own project, in the background.

# .claude a link to an empty directory: refused, reported, then followed.
case_hooks_new() {
  local k="$1" tgt L="install-hooks.sh, .claude a $1 to an empty directory"
  project "hooks-new-$k"
  tgt="$C/outside-hooks-new-$k"; mkdir -p "$tgt"
  if ! dirlink "$k" "$tgt" "$IP/.claude"; then na "$L" "$WHY_NA"; return 0; fi
  run install-hooks.sh
  [ "$RC" -eq 1 ] && empty_dir "$tgt"
  v "$L: a run exits 1 and writes nothing there" $?
  no_project_attr
  v "$L: no .gitattributes is written in the project" $?
  said_re "^! [.]claude is a link to .*/outside-hooks-new-$k, " && said "re-run with --follow-claude-link" \
    && said "replace the link with a directory"
  v "$L: the message names where the link leads and both remedies" $?
  run install-hooks.sh --check
  [ "$RC" -eq 1 ] && closing_faults 1 \
    && record_is settings fault .claude "^it is a link to .*/outside-hooks-new-$k; a run refuses to write through it [(]--follow-claude-link installs there[)]\$"
  v "$L: --check exits 1 with the link's fault record, and counts it" $?
  empty_dir "$tgt"
  v "$L: --check writes nothing there" $?
  run install-hooks.sh --follow-claude-link
  [ "$RC" -eq 0 ] && settings_is_template "$tgt"
  v "$L: --follow-claude-link exits 0 and writes the template there" $?
  said_re "^! [.]claude is a link: installing into .*/outside-hooks-new-$k\$"
  v "$L: --follow-claude-link says on stderr where it installs" $?
  has_rule "$HOOK_RULE"
  v "$L: --follow-claude-link writes the project's .gitattributes rule" $?
  [ -z "$(find "$tgt" -name '*.iaeng-*')" ]
  v "$L: --follow-claude-link leaves no temporary file" $?
}

# .claude a link to a directory holding a project's own settings.json: the
# merge path and --force refused, --check a fault, the flag merges.
case_hooks_merge() {
  local k="$1" tgt L="install-hooks.sh, .claude a $1 to a directory with its own settings.json"
  project "hooks-merge-$k"
  tgt="$C/outside-hooks-merge-$k"; mkdir -p "$tgt"
  printf '{\n  "model": "opus",\n  "permissions": {"allow": ["Bash(ls)"]}\n}\n' > "$tgt/settings.json"
  printf '{\n  "disableAllHooks": true,\n  "statusLine": {"type": "command", "command": "own-status-line.sh"}\n}\n' > "$tgt/settings.local.json"
  if ! dirlink "$k" "$tgt" "$IP/.claude"; then na "$L" "$WHY_NA"; return 0; fi
  snap "$tgt"
  run install-hooks.sh
  [ "$RC" -eq 1 ] && same_as "$tgt"
  v "$L: a run exits 1, the directory byte-identical" $?
  no_project_attr
  v "$L: no .gitattributes is written in the project" $?
  run install-hooks.sh --force
  [ "$RC" -eq 1 ] && same_as "$tgt" && said "is a link to "
  v "$L: --force exits 1, the directory byte-identical" $?
  run install-hooks.sh --check
  [ "$RC" -eq 1 ] && closing_faults 1 && ! grep -q $'\tcustomized\t' "$C/out" \
    && record_is settings fault .claude "^it is a link to .*/outside-hooks-merge-$k; "
  v "$L: --check exits 1 with the link's fault record, never customized" $?
  ! grep -qE $'^(settings\tdisabled|statusline\tshadowed)\t' "$C/out"
  v "$L: --check reads nothing behind the link: no disabled or shadowed record from its settings.local.json" $?
  run install-hooks.sh --follow-claude-link
  [ "$RC" -eq 0 ] && [ "$(jq '[.hooks[][]] | length' "$tgt/settings.json" | strip_eol_cr)" = "$TPL_GROUPS" ] \
    && [ "$(jq -c '{model, permissions}' "$tgt/settings.json" | strip_eol_cr)" = '{"model":"opus","permissions":{"allow":["Bash(ls)"]}}' ]
  v "$L: --follow-claude-link merges there (exit 0), every group added, the other keys kept" $?
}

# .claude a link to Claude Code's user settings directory, named by a fake
# CLAUDE_CONFIG_DIR: refused with and without the flag.
case_hooks_user() {
  local k="$1" tgt L="install-hooks.sh, .claude a $1 to CLAUDE_CONFIG_DIR"
  project "hooks-user-$k"
  tgt="$C/userdir"
  printf '{\n  "model": "opus"\n}\n' > "$tgt/settings.json"
  if ! dirlink "$k" "$tgt" "$IP/.claude"; then na "$L" "$WHY_NA"; return 0; fi
  snap "$tgt"
  run install-hooks.sh
  [ "$RC" -eq 1 ] && same_as "$tgt" \
    && said_re "^! [.]claude is a link to .*/userdir, Claude Code.s user settings directory[.] Not changed, with or without --follow-claude-link[.]\$"
  v "$L: a run exits 1, the directory byte-identical, Claude Code's user settings directory named" $?
  run install-hooks.sh --follow-claude-link
  [ "$RC" -eq 1 ] && same_as "$tgt" && said "with or without --follow-claude-link" && ! said "installing into"
  v "$L: --follow-claude-link exits 1 too, the directory byte-identical" $?
  no_project_attr
  v "$L: no .gitattributes is written in the project" $?
  run install-hooks.sh --check
  [ "$RC" -eq 1 ] \
    && record_is settings fault .claude "^it is a link to .*/userdir, Claude Code.s user settings directory; a run refuses to write through it, with or without --follow-claude-link\$"
  v "$L: --check exits 1 and names the user settings directory in its fault record" $?
}

# The same for $HOME/.claude, with a fake HOME: the fallback when
# CLAUDE_CONFIG_DIR is unset, and still the user directory when that variable
# names another one (a Claude Code started without it reads $HOME/.claude).
case_hooks_home() {
  local k="$1" tgt L="install-hooks.sh, .claude a $1 to \$HOME/.claude"
  project "hooks-home-$k"
  tgt="$C/home/.claude"; mkdir -p "$tgt"
  printf '{}\n' > "$tgt/settings.json"
  if ! dirlink "$k" "$tgt" "$IP/.claude"; then na "$L" "$WHY_NA"; return 0; fi
  snap "$tgt"
  ENV_CFG='unset'
  run install-hooks.sh --follow-claude-link
  ENV_CFG=""
  [ "$RC" -eq 1 ] && same_as "$tgt" && said "Claude Code's user settings directory"
  v "$L: CLAUDE_CONFIG_DIR unset, --follow-claude-link exits 1, the directory byte-identical" $?
  run install-hooks.sh --follow-claude-link
  [ "$RC" -eq 1 ] && same_as "$tgt" && said "Claude Code's user settings directory" && ! said "installing into"
  v "$L: CLAUDE_CONFIG_DIR naming another directory, --follow-claude-link exits 1 too, the directory byte-identical" $?
}

# install-skills.sh: .claude a link to an empty directory.
case_skills_new() {
  local k="$1" tgt d s=0 L="install-skills.sh, .claude a $1 to an empty directory"
  project "skills-new-$k"
  tgt="$C/outside-skills-new-$k"; mkdir -p "$tgt"
  if ! dirlink "$k" "$tgt" "$IP/.claude"; then na "$L" "$WHY_NA"; return 0; fi
  run install-skills.sh
  [ "$RC" -eq 1 ] && empty_dir "$tgt"
  v "$L: a run exits 1 and writes nothing there" $?
  no_project_attr
  v "$L: no .gitattributes is written in the project" $?
  said_re "^! [.]claude is a link to .*/outside-skills-new-$k, " && said "re-run with --follow-claude-link" \
    && said "replace the link with a directory"
  v "$L: the message names where the link leads and both remedies" $?
  run install-skills.sh --check
  [ "$RC" -eq 1 ] && closing_faults 1 \
    && record_is skill fault .claude "^it is a link to .*/outside-skills-new-$k; a run refuses to write through it [(]--follow-claude-link installs there[)]\$"
  v "$L: --check exits 1 with a fault record for .claude" $?
  # Behind the link: a skill that differs from its source, and a skill's
  # directory that is itself a link. --check reads neither.
  mkdir -p "$tgt/skills/dashboard" "$C/elsewhere-skill"
  printf 'edited\n' > "$tgt/skills/dashboard/SKILL.md"
  if dirlink "$k" "$C/elsewhere-skill" "$tgt/skills/create-project"; then
    run install-skills.sh --check
    [ "$RC" -eq 1 ] && closing_faults 1 && [ "$(awk -F '\t' '$1 == "skill"' "$C/out" | wc -l | tr -d ' ')" = 1 ]
    v "$L: --check reads nothing behind the link: no record for a skill there, nor for a link there" $?
  else
    na "$L: --check reads nothing behind the link" "$WHY_NA"
  fi
  rm -rf "$tgt/skills"
  run install-skills.sh --follow-claude-link
  for d in "$CC"/skills/*/; do
    diff -r "$d" "$tgt/skills/$(basename "$d")" >/dev/null 2>&1 || s=1
  done
  [ "$RC" -eq 0 ] && [ "$s" -eq 0 ]
  v "$L: --follow-claude-link exits 0 and installs every skill there, as its source" $?
  said_re "^! [.]claude is a link: installing into .*/outside-skills-new-$k\$"
  v "$L: --follow-claude-link says on stderr where it installs" $?
  has_rule "$SKILL_RULE"
  v "$L: --follow-claude-link writes the project's .gitattributes rule" $?
}

# install-skills.sh: .claude/skills a link to the user skills directory, and
# .claude a link to the user settings directory: refused with the flag.
case_skills_user() {
  local k="$1" L="install-skills.sh, a $1 into CLAUDE_CONFIG_DIR"
  project "skills-user-$k"
  mkdir -p "$C/userdir/skills/own" "$IP/.claude"
  printf 'the user own skill\n' > "$C/userdir/skills/own/SKILL.md"
  if ! dirlink "$k" "$C/userdir/skills" "$IP/.claude/skills"; then na "$L" "$WHY_NA"; return 0; fi
  snap "$C/userdir"
  run install-skills.sh --follow-claude-link
  [ "$RC" -eq 1 ] && same_as "$C/userdir" && said_re "^! [.]claude/skills is a link to .*/userdir/skills, " \
    && said "with or without --follow-claude-link"
  v "$L: .claude/skills a link to its user counterpart — --follow-claude-link exits 1, nothing written" $?
  run install-skills.sh --check
  [ "$RC" -eq 1 ] \
    && record_is skill fault .claude/skills "^it is a link to .*/userdir/skills, .*with or without --follow-claude-link\$"
  v "$L: .claude/skills a link to its user counterpart — --check exits 1 with its fault record" $?
  rm -rf "$IP/.claude"
  if ! dirlink "$k" "$C/userdir" "$IP/.claude"; then na "$L: .claude a link to the user settings directory" "$WHY_NA"; return 0; fi
  run install-skills.sh --follow-claude-link
  [ "$RC" -eq 1 ] && same_as "$C/userdir" \
    && said_re "^! [.]claude is a link to .*/userdir, Claude Code.s user settings directory[.]"
  v "$L: .claude a link to the user settings directory — --follow-claude-link exits 1, nothing written" $?
}

# install-skills.sh: one skill's directory a link (the per-skill rule). To an
# outside directory: refused with and without --force, a fault under --check.
# Into the user skills directory, as the same skill or as another one:
# refused with the flag too.
case_skills_one() {
  local k="$1" tgt u L="install-skills.sh, .claude/skills/dashboard a $1"
  project "skills-one-$k"
  mkdir -p "$IP/.claude/skills"
  tgt="$C/outside-skills-one-$k"; mkdir -p "$tgt"
  if ! dirlink "$k" "$tgt" "$IP/.claude/skills/dashboard"; then na "$L" "$WHY_NA"; return 0; fi
  run install-skills.sh
  [ "$RC" -eq 1 ] && empty_dir "$tgt" && [ ! -e "$IP/.claude/skills/create-project" ] \
    && said_re "^! [.]claude/skills/dashboard is a link to .*/outside-skills-one-$k, not a directory of this project.s own[.] Not changed[.]\$"
  v "$L to an empty directory: a run exits 1 and writes nothing, the link named" $?
  run install-skills.sh --force
  [ "$RC" -eq 1 ] && empty_dir "$tgt" && [ ! -e "$IP/.claude/skills/create-project" ]
  v "$L to an empty directory: --force exits 1 too and writes nothing" $?
  run install-skills.sh --check
  [ "$RC" -eq 1 ] && closing_faults 1 \
    && record_is skill fault .claude/skills/dashboard "^it is a link to .*/outside-skills-one-$k; a run refuses to write through it [(]--follow-claude-link installs there[)]\$"
  v "$L to an empty directory: --check exits 1 with a fault record for it" $?
  for u in dashboard other; do
    rm -rf "$IP/.claude/skills/dashboard"
    mkdir -p "$C/userdir/skills/$u"
    printf 'the user own skill\n' > "$C/userdir/skills/$u/SKILL.md"
    if ! dirlink "$k" "$C/userdir/skills/$u" "$IP/.claude/skills/dashboard"; then na "$L to the user skills/$u" "$WHY_NA"; continue; fi
    snap "$C/userdir"
    run install-skills.sh --follow-claude-link --force
    [ "$RC" -eq 1 ] && same_as "$C/userdir" \
      && said_re "^! [.]claude/skills/dashboard is a link to .*/userdir/skills/$u, ${USER_SKILLS_PLACE}[.] Not changed, with or without --follow-claude-link[.]\$"
    v "$L to the user skills/$u: --follow-claude-link --force exits 1, the user directory byte-identical" $?
  done
}

# install-skills.sh: links into $HOME/.claude/skills while CLAUDE_CONFIG_DIR
# names another directory (the fake one every run gets): $HOME/.claude is
# still the user directory, the one a Claude Code started without that
# variable reads. .claude/skills a link to its skills/, then one skill's
# directory a link to a skill there: refused with the flag.
case_skills_home() {
  local k="$1" L="install-skills.sh, a $1 into \$HOME/.claude/skills, CLAUDE_CONFIG_DIR naming another directory"
  project "skills-home-$k"
  mkdir -p "$C/home/.claude/skills/other" "$IP/.claude"
  printf 'the user own skill\n' > "$C/home/.claude/skills/other/SKILL.md"
  if ! dirlink "$k" "$C/home/.claude/skills" "$IP/.claude/skills"; then na "$L" "$WHY_NA"; return 0; fi
  snap "$C/home/.claude"
  run install-skills.sh --follow-claude-link --force
  [ "$RC" -eq 1 ] && same_as "$C/home/.claude" \
    && said_re "^! [.]claude/skills is a link to .*/home/[.]claude/skills, ${USER_SKILLS_PLACE}[.] Not changed, with or without --follow-claude-link[.]\$"
  v "$L: .claude/skills a link to it — --follow-claude-link --force exits 1, the user directory byte-identical" $?
  run install-skills.sh --check
  [ "$RC" -eq 1 ] \
    && record_is skill fault .claude/skills "^it is a link to .*/home/[.]claude/skills, $USER_SKILLS_PLACE; a run refuses to write through it, with or without --follow-claude-link\$"
  v "$L: .claude/skills a link to it — --check exits 1 with its fault record" $?
  rm -rf "$IP/.claude/skills"
  mkdir -p "$IP/.claude/skills"
  if ! dirlink "$k" "$C/home/.claude/skills/other" "$IP/.claude/skills/dashboard"; then na "$L: .claude/skills/dashboard a link to its skill other" "$WHY_NA"; return 0; fi
  run install-skills.sh --follow-claude-link --force
  [ "$RC" -eq 1 ] && same_as "$C/home/.claude" && [ ! -e "$IP/.claude/skills/create-project" ] \
    && said_re "^! [.]claude/skills/dashboard is a link to .*/home/[.]claude/skills/other, ${USER_SKILLS_PLACE}[.] Not changed, with or without --follow-claude-link[.]\$"
  v "$L: .claude/skills/dashboard a link to its skill other — --follow-claude-link --force exits 1, nothing written" $?
}

# install-skills.sh: a skill in the user skills directory that is itself a
# link, as a skill kept in a dotfiles checkout is. .claude/skills/dashboard a
# link to that skill, by the same name or another, or to a directory inside
# it: refused with the flag, the dotfiles byte-identical. The link's physical
# path lies outside the user directory; only the user's own link to it makes
# it a user skill.
case_skills_kept() {
  local k="$1" u L="install-skills.sh, .claude/skills/dashboard a $1 to a user skill that is itself a link"
  project "skills-kept-$k"
  mkdir -p "$IP/.claude/skills" "$C/userdir/skills" "$C/dotfiles/dashboard" "$C/dotfiles/other/sub"
  printf 'the user own skill\n' > "$C/dotfiles/dashboard/SKILL.md"
  printf 'the user own skill\n' > "$C/dotfiles/other/SKILL.md"
  if ! dirlink "$k" "$C/dotfiles/dashboard" "$C/userdir/skills/dashboard" \
    || ! dirlink "$k" "$C/dotfiles/other" "$C/userdir/skills/other"; then
    na "$L" "$WHY_NA"; return 0
  fi
  snap "$C/dotfiles"
  for u in dashboard other other/sub; do
    rm -rf "$IP/.claude/skills/dashboard"
    if ! dirlink "$k" "$C/userdir/skills/$u" "$IP/.claude/skills/dashboard"; then na "$L: to the user skills/$u" "$WHY_NA"; continue; fi
    run install-skills.sh --follow-claude-link --force
    [ "$RC" -eq 1 ] && same_as "$C/dotfiles" && [ ! -e "$IP/.claude/skills/create-project" ] \
      && said_re "^! [.]claude/skills/dashboard is a link to .*/dotfiles/$u, ${USER_SKILLS_PLACE}[.] Not changed, with or without --follow-claude-link[.]\$"
    v "$L: to the user skills/$u — --follow-claude-link --force exits 1, the dotfiles byte-identical" $?
    [ "$u" = other/sub ] || continue
    run install-skills.sh --check
    [ "$RC" -eq 1 ] \
      && record_is skill fault .claude/skills/dashboard "^it is a link to .*/dotfiles/other/sub, $USER_SKILLS_PLACE; a run refuses to write through it, with or without --follow-claude-link\$"
    v "$L: to the user skills/$u — --check exits 1 with its fault record" $?
  done
}

# .claude a symbolic link that leads to no directory: each installer refuses
# it with the flag and creates nothing; --check says it leads nowhere.
case_dangling() {
  local s fam L=".claude a symbolic link to no directory"
  project dangling
  if ! filelink "$C/nowhere" "$IP/.claude"; then na "$L" "$WHY_NA"; return 0; fi
  for s in install-hooks.sh install-skills.sh; do
    fam=settings; [ "$s" = install-skills.sh ] && fam=skill
    run "$s" --follow-claude-link
    [ "$RC" -eq 1 ] && [ ! -e "$C/nowhere" ] && no_project_attr && ! said "installing into" \
      && said_re "^! [.]claude is a link to .*/nowhere, which leads to no directory[.] Not changed: "
    v "$L: $s --follow-claude-link exits 1, creates nothing, and says the link leads to no directory" $?
    run "$s" --check
    [ "$RC" -eq 1 ] \
      && record_is "$fam" fault .claude "^it is a link to .*/nowhere, which leads to no directory; a run refuses to write through it, with or without --follow-claude-link\$"
    v "$L: $s --check exits 1 and says the link leads to no directory" $?
  done
}

# --check with --follow-claude-link: a usage error in each installer.
case_usage() {
  local s L="usage: --check with --follow-claude-link"
  project usage
  for s in install-hooks.sh install-skills.sh; do
    run "$s" --check --follow-claude-link
    [ "$RC" -eq 2 ] && said "$s: --follow-claude-link applies to a run; --check reports" && [ ! -s "$C/out" ]
    v "$L: $s exits 2 and says why" $?
  done
}

# .gitattributes a symbolic link to a file outside the project (#255).
case_attr() {
  local L=".gitattributes a symbolic link"
  project attr
  mkdir -p "$IP/.claude" "$C/elsewhere"
  printf '* text=auto\n' > "$C/elsewhere/attributes"
  cp "$C/elsewhere/attributes" "$C/attributes.orig"
  if ! filelink "$C/elsewhere/attributes" "$IP/.gitattributes"; then na "$L" "$WHY_NA"; return 0; fi
  run install-hooks.sh
  [ "$RC" -eq 1 ] && settings_is_template "$IP/.claude" && cmp -s "$C/elsewhere/attributes" "$C/attributes.orig" \
    && [ -L "$IP/.gitattributes" ]
  v "$L: install-hooks.sh installs settings.json, then exits 1 with the file byte-identical" $?
  said "! .gitattributes is a link to " && said "$HOOK_RULE"
  v "$L: install-hooks.sh prints the line to add" $?
  run install-hooks.sh --check
  [ "$RC" -eq 1 ] \
    && record_is gitattributes fault .gitattributes "^it is a link to .*/elsewhere/attributes, and git does not read a [.]gitattributes that is a symbolic link; a run refuses to append to it"
  v "$L: install-hooks.sh --check exits 1 with a gitattributes fault" $?
  run install-skills.sh
  [ "$RC" -eq 1 ] && cmp -s "$C/elsewhere/attributes" "$C/attributes.orig" && [ -L "$IP/.gitattributes" ]
  v "$L: install-skills.sh exits 1 with the file byte-identical" $?
  said "! .gitattributes is a link to " && said "$SKILL_RULE"
  v "$L: install-skills.sh prints the line to add" $?
  run install-skills.sh --check
  [ "$RC" -eq 1 ] \
    && record_is gitattributes fault .gitattributes "^it is a link to .*/elsewhere/attributes, and git does not read a [.]gitattributes that is a symbolic link; a run refuses to append to it"
  v "$L: install-skills.sh --check exits 1 with a gitattributes fault" $?
}

# .gitattributes a symbolic link to a file that already holds both rules
# (#255 item 1): git reads no .gitattributes that is a link, so for git the
# rule is not there, and neither installer may count it present.
case_attr_holding() {
  local L=".gitattributes a symbolic link to a file holding both rules"
  project attr-holding
  mkdir -p "$IP/.claude" "$C/elsewhere"
  printf '* text=auto\n%s\n%s\n' "$HOOK_RULE" "$SKILL_RULE" > "$C/elsewhere/attributes"
  cp "$C/elsewhere/attributes" "$C/attributes.orig"
  if ! filelink "$C/elsewhere/attributes" "$IP/.gitattributes"; then na "$L" "$WHY_NA"; return 0; fi
  # The premise, from git itself: no eol for the installed file through the
  # link, and eol=lf from a plain copy of the same file, the control that
  # shows the rule would apply if git read it. No system, user or XDG
  # attributes file is read, so only the project's own decides. Git for
  # Windows reads an MSYS sys link as a plain file whose text starts
  # "!<symlink>", and warns of a negative pattern: no rule either way, and
  # the warning is not this check's output.
  local ctl="$C/attr-control"
  mkdir -p "$ctl"; cp "$C/elsewhere/attributes" "$ctl/.gitattributes"
  if command -v git >/dev/null 2>&1 && git_here "$IP" init -q . && git_here "$ctl" init -q .; then
    [ "$(git_here "$IP" check-attr eol -- .claude/settings.json | strip_eol_cr)" = ".claude/settings.json: eol: unspecified" ] \
      && [ "$(git_here "$ctl" check-attr eol -- .claude/settings.json | strip_eol_cr)" = ".claude/settings.json: eol: lf" ]
    v "$L: fixture: git check-attr finds no eol through the link, and eol lf in a plain copy of the file" $?
  else
    na "$L: fixture: git check-attr finds no eol through the link" "no git, or git init failed here"
  fi
  run install-hooks.sh
  [ "$RC" -eq 1 ] && settings_is_template "$IP/.claude" && cmp -s "$C/elsewhere/attributes" "$C/attributes.orig" \
    && said "! .gitattributes is a link to " && said "$HOOK_RULE"
  v "$L: install-hooks.sh installs settings.json, then exits 1, the file byte-identical, the line to add printed" $?
  run install-hooks.sh --check
  [ "$RC" -eq 1 ] && ! grep -q $'^gitattributes\tpresent\t' "$C/out" \
    && record_is gitattributes fault .gitattributes "^it is a link to .*/elsewhere/attributes, and git does not read "
  v "$L: install-hooks.sh --check exits 1 with a gitattributes fault, never present" $?
  run install-skills.sh
  [ "$RC" -eq 1 ] && cmp -s "$C/elsewhere/attributes" "$C/attributes.orig" \
    && said "! .gitattributes is a link to " && said "$SKILL_RULE"
  v "$L: install-skills.sh exits 1, the file byte-identical, the line to add printed" $?
  run install-skills.sh --check
  [ "$RC" -eq 1 ] && ! grep -q $'^gitattributes\tpresent\t' "$C/out" \
    && record_is gitattributes fault .gitattributes "^it is a link to .*/elsewhere/attributes, and git does not read "
  v "$L: install-skills.sh --check exits 1 with a gitattributes fault, never present" $?
}

# A dangling .gitattributes link: no file appears where it points.
case_attr_dangling() {
  local L=".gitattributes a symbolic link to no file"
  project attr-dangling
  mkdir -p "$IP/.claude" "$C/elsewhere"
  if ! filelink "$C/elsewhere/none" "$IP/.gitattributes"; then na "$L" "$WHY_NA"; return 0; fi
  run install-hooks.sh
  [ "$RC" -eq 1 ] && [ ! -e "$C/elsewhere/none" ]
  v "$L: install-hooks.sh exits 1 and creates nothing where it points" $?
  run install-skills.sh
  [ "$RC" -eq 1 ] && [ ! -e "$C/elsewhere/none" ]
  v "$L: install-skills.sh exits 1 and creates nothing where it points" $?
}

# Controls: a plain .claude installs as before; so does a project reached
# through a linked parent directory, whose .claude is its own.
case_plain() {
  local L="control: a plain .claude"
  project plain
  mkdir -p "$IP/.claude"
  run install-hooks.sh
  [ "$RC" -eq 0 ] && settings_is_template "$IP/.claude" && ! said "is a link"
  v "$L: install-hooks.sh exits 0 and writes the template" $?
  run install-skills.sh
  [ "$RC" -eq 0 ] && [ -f "$IP/.claude/skills/dashboard/SKILL.md" ] && ! said "is a link"
  v "$L: install-skills.sh exits 0" $?
  run install-hooks.sh --check
  [ "$RC" -eq 0 ] && closing_faults 0
  v "$L: install-hooks.sh --check exits 0" $?
}
case_via_link() {
  local k="$1" L="control: a project reached through a $1 to its parent"
  C="$T/case-via-$k"
  mkdir -p "$C/real"
  if ! dirlink "$k" "$C/real" "$C/via"; then na "$L" "$WHY_NA"; return 0; fi
  project "via-$k" "$C/via"
  mkdir -p "$IP/.claude"
  run install-hooks.sh
  [ "$RC" -eq 0 ] && settings_is_template "$C/real/project/.claude" && ! said "is a link"
  v "$L: install-hooks.sh exits 0 and writes the template" $?
  run install-skills.sh
  [ "$RC" -eq 0 ] && ! said "is a link"
  v "$L: install-skills.sh exits 0" $?
}

# enter <name> — in a case's background subshell: its results file.
# leave — the mark that the case reached its end.
enter() { RES="$T/res-$1"; : > "$RES"; }
leave() { printf 'end\n' >> "$RES"; }
CASES=""
for k in symlink junction; do
  CASES="$CASES hooks_new_$k";   ( enter "hooks_new_$k";   case_hooks_new "$k";   leave ) &
  CASES="$CASES hooks_merge_$k"; ( enter "hooks_merge_$k"; case_hooks_merge "$k"; leave ) &
  CASES="$CASES hooks_user_$k";  ( enter "hooks_user_$k";  case_hooks_user "$k";  leave ) &
  CASES="$CASES hooks_home_$k";  ( enter "hooks_home_$k";  case_hooks_home "$k";  leave ) &
  CASES="$CASES skills_new_$k";  ( enter "skills_new_$k";  case_skills_new "$k";  leave ) &
  CASES="$CASES skills_user_$k"; ( enter "skills_user_$k"; case_skills_user "$k"; leave ) &
  CASES="$CASES skills_one_$k";  ( enter "skills_one_$k";  case_skills_one "$k";  leave ) &
  CASES="$CASES skills_home_$k"; ( enter "skills_home_$k"; case_skills_home "$k"; leave ) &
  CASES="$CASES skills_kept_$k"; ( enter "skills_kept_$k"; case_skills_kept "$k"; leave ) &
  CASES="$CASES via_$k";         ( enter "via_$k";         case_via_link "$k";    leave ) &
done
CASES="$CASES dangling";      ( enter dangling;      case_dangling;      leave ) &
CASES="$CASES usage";         ( enter usage;         case_usage;         leave ) &
CASES="$CASES attr";          ( enter attr;          case_attr;          leave ) &
CASES="$CASES attr_holding";  ( enter attr_holding;  case_attr_holding;  leave ) &
CASES="$CASES attr_dangling"; ( enter attr_dangling; case_attr_dangling; leave ) &
CASES="$CASES plain";         ( enter plain;         case_plain;         leave ) &
wait

# The results, in the order the cases are listed.
echo "== install-hooks.sh and install-skills.sh — a .claude or a .gitattributes that is a link"
for name in $CASES; do
  ended=0
  while IFS=$'\t' read -r st label detail; do
    case "$st" in
      ok) ok "$label" ;;
      bad) bad "$label" "$detail" ;;
      na) na "$label" "$detail" ;;
      end) ended=1 ;;
    esac
  done < "$T/res-$name"
  [ "$ended" -eq 1 ] || bad "case $name: it did not reach its end"
done

# =============================================================================
echo
[ -z "${IAENG_HOOK_TESTS_COUNTS:-}" ] || printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
if [ "$FAILED" -eq 0 ]; then
  printf 'Claude link result: %s checks passed, %s not applicable here.\n' "$TOTAL" "$NA"
  exit 0
fi
printf 'Claude link result: %s of %s checks failed, %s not applicable here.\n' "$FAILED" "$TOTAL" "$NA"
exit 1
