#!/usr/bin/env bash
# IA Engineering — hook tests: install-hooks.sh merges into a settings.json
# that has no "hooks", names what it cannot read, and writes by rename
# (WU-IAENG-437, WU-IAENG-441)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/settings-shapes.sh [--verbose]
#
# THE DEFECT (DEF-465-01, QA on PR #465). A project's own .claude/settings.json
# often has no "hooks": it holds its permissions only, a $schema only, or
# nothing. install-hooks.sh refused to merge into it: "exists and differs, and
# the merge failed. Not changed.", exit 1, and --check reported a fault. The
# near-miss scan ran to_entries on the missing "hooks" (jq: "null (null) has
# no keys"). "hooks": null failed the same way. "hooks": {} merged.
#
# What is proved, per shape of the project's file:
#
#   - No "hooks" (permissions only, as QA found it; $schema only; {}), and
#     "hooks": null. --check, before the run: exit 3, the settings item
#     "customized", one "absent" hook record per template group and the
#     statusLine "absent". The run: exit 0, every template group added once
#     and nothing else under "hooks", the template statusLine, every other
#     key kept as it was and in its order, and its "added:" lines name the
#     same entries --check named absent. --check after the run: exit 0.
#   - "hooks": {}, the control: it merged before the fix too, and must still.
#   - Every other key at once: $schema, permissions, env and model kept as
#     they were, and the project's statusLine wrapped (padding kept, its
#     command single-quoted after --chain); a re-run changes nothing.
#   - Refused, the file left byte-identical, exit 1, and the same reason in
#     the run's "Not changed" line and in --check's fault record (exit 1):
#       a // comment: its line named, and the remedy;
#       a /* */ comment on the line after a $schema URL: the comment's line,
#         never the URL's, whose // is inside a string;
#       a trailing comma, with that URL too: jq's own reason, no comment named;
#       "hooks": false: not an object, absent or null.
#   - Stricter shape validation (WU-IAENG-441). Refused the same way, each
#     fixture holding every template entry so that only one thing is wrong:
#       an event written as an object; a group whose "hooks" is an object;
#       NaN, -Infinity and +1, each named with its line; a byte order mark.
#   - Every write goes beside the file and is renamed over it (WU-IAENG-441):
#       a symbolic link to no file: a run refuses, keeps the link and creates
#         nothing where it points; --check reports a fault, not an absent
#         file; once the link is removed a run writes the template;
#       --force on a link: refused, the file it points at byte-identical;
#       --force on a regular file: the template in place, and a hard link to
#         the old file keeps the old content (a rename, not a write into it).
#
# ORACLES (Standards/TESTING_STANDARD.md, Independent Oracle). None is taken
# from install-hooks.sh's output:
#   - what a merge adds: settings.example.json, rendered here with sed for the
#     framework root "ia-engineering" (the template is the specification of
#     the framework's entries: 8 hook groups and the statusLine);
#   - what is kept: the input fixture itself, per install-hooks.sh's header,
#     "nothing already in the file is changed, reordered or removed — the
#     project's own hooks, its env, its permissions";
#   - the statusLine wrap: install-hooks.sh's header (WU-IAENG-379) and
#     hooks/README.md, Context Status Line: "the framework's command, then
#     --chain and the project's command in single quotes. The statusLine's
#     other fields, such as padding, are kept";
#   - --check: its header, "THE SAME DECISIONS, REPORTED INSTEAD OF APPLIED",
#     exit 0 nothing to act on, 3 drift, 1 a fault;
#   - comments: RFC 8259 has no comment syntax, and jq 1.8.1 refuses a //
#     line ("Invalid numeric literal", measured for this Work Unit), so the
#     file cannot be merged and the remedy is to remove the comment;
#   - the settings shape: Claude Code's settings schema, which gives each
#     hook event a list of matcher groups and each group a "hooks" list (read
#     in the local Claude Code 2.1.327 for this Work Unit);
#   - tokens: RFC 8259's grammar has no NaN or Infinity, and a number has no
#     leading + (section 6); a JSON text is not written with a byte order
#     mark (section 8.1);
#   - links and renames: POSIX, a write through a path follows a symbolic
#     link, and rename() replaces the name, not the file it named.
#
# EACH CASE RUNS IN ITS OWN PROJECT, IN THE BACKGROUND. On Git for Windows
# one installer run takes tens of seconds, and the cases make about forty:
# run one after another they took over ten minutes. Each case writes its
# results to a file of its own; once every case has ended they are counted
# in the order the cases are listed. A case that did not reach its end is a
# failure, never a pass.
#
# Nothing is skipped. Exit 0 when every check passes, 1 when any fails, 2 when
# the environment is unusable. With IAENG_HOOK_TESTS_COUNTS set to a file,
# "<total> <failed>" is written there for run.sh.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "settings-shapes.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
CC="$(cd "$HOOKS/.." && pwd)"

command -v jq >/dev/null 2>&1 || {
  echo "settings-shapes.sh: jq is required and is not installed. Reported rather than skipped." >&2
  exit 2
}

FAILED=0
TOTAL=0
# RES: inside a background case, the file its results go to, one line each:
# "ok<TAB>label" or "bad<TAB>label<TAB>detail", the detail on one line.
RES=""
ok() {
  if [ -n "$RES" ]; then printf 'ok\t%s\n' "$1" >> "$RES"; return 0; fi
  TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0
}
bad() {
  if [ -n "$RES" ]; then printf 'bad\t%s\t%s\n' "$1" "$(printf '%s' "${2:-}" | tr '\t\n\r' '   ')" >> "$RES"; return 0; fi
  TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '         %s\n' "$2"; return 0
}
# Only the carriage return that ends a line is removed: jq for Windows ends
# each line in CRLF (Check Convention, Shell Scripts rule 3).
strip_eol_cr() { sed $'s/\r$//'; }

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-shapes437.XXXXXX")" || { echo "settings-shapes.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
trap 'cd / && rm -rf "$T"' EXIT

# The oracle: the template rendered for this project, independently of the
# script (its own rendering is a sed of the same placeholder).
TPL="$T/template.json"
sed 's#__IAENG_ROOT__#ia-engineering#g' "$CC/settings.example.json" > "$TPL"
TPL_GROUPS="$(jq '[.hooks[][]] | length' "$TPL" | strip_eol_cr)"
TPL_SL_CMD="$(jq -r '.statusLine.command' "$TPL" | strip_eol_cr)"
if [ "$TPL_GROUPS" = 8 ] && [ -n "$TPL_SL_CMD" ]; then
  ok "fixture: the template has 8 hook groups and a statusLine command"
else
  bad "fixture: the template has 8 hook groups and a statusLine command" "groups=$TPL_GROUPS statusLine=[$TPL_SL_CMD]"
fi

# project <name> — an adopting project of its own for one case, the framework
# under ia-engineering/ as a submodule; sets C (the case's scratch), IP, IFW
# and SET.
project() {
  C="$T/case-$1"
  IP="$C/project"
  IFW="$IP/ia-engineering/Adapters/ai-runtimes/claude-code"
  mkdir -p "$IFW/hooks" "$IP/.claude"
  cp -p "$CC/install-hooks.sh" "$CC/settings.example.json" "$IFW/"
  cp -p "$HOOKS"/*.sh "$IFW/hooks/"
  chmod +x "$IFW"/hooks/*.sh "$IFW/install-hooks.sh"
  SET="$IP/.claude/settings.json"
}
inst() { ( cd "$IP" && bash "$IFW/install-hooks.sh" "$@" ) > "$C/inst.out" 2> "$C/inst.err"; INST_RC=$?; }

# groups_once — every template group is in $SET exactly once under its event,
# and $SET has no other group (the input had none).
groups_once() {
  [ "$(jq -n --slurpfile t "$TPL" --slurpfile m "$SET" '
        ([$t[0].hooks | to_entries[] | .key as $ev | .value[] | . as $g
          | [$m[0].hooks[$ev][]? | select(. == $g)] | length] | all(. == 1))
        and ([$m[0].hooks[][]] | length) == ([$t[0].hooks[][]] | length)' | strip_eol_cr)" = true ]
}
# others_kept <input> — every key but hooks and statusLine, as compact JSON
# in its order, is the input's.
others_kept() {
  [ "$(jq -c 'del(.hooks, .statusLine)' "$1" | strip_eol_cr)" = "$(jq -c 'del(.hooks, .statusLine)' "$SET" | strip_eol_cr)" ]
}
# check_absent — the hook "absent" details of the last --check, sorted.
check_absent() { awk -F '\t' '$1 == "hook" && $2 == "absent" { print $4 }' "$C/inst.out" | sort; }
# run_added — the hook lines a run reported as added, sorted.
run_added() { sed -n 's/^    added:   //p' "$C/inst.out" | grep -v '^statusLine: ' | sort; }

# merges <label> <fixture> — the whole contract for a file that gets the
# framework's entries and holds no statusLine of its own.
merges() {
  local label="$1" fixture="$2" absent
  cp "$fixture" "$SET"
  inst --check
  absent="$(check_absent)"
  if [ "$INST_RC" -eq 3 ] && grep -qF "settings	customized	.claude/settings.json	" "$C/inst.out" \
      && [ "$(printf '%s\n' "$absent" | grep -c .)" -eq "$TPL_GROUPS" ] \
      && grep -qF "statusline	absent	.claude/settings.json	context-statusline.sh" "$C/inst.out"; then
    ok "$label: --check before the run — drift (exit 3), customized, $TPL_GROUPS hook entries and the statusLine absent"
  else
    bad "$label: --check before the run — drift (exit 3), customized, $TPL_GROUPS hook entries and the statusLine absent" "rc=$INST_RC $(head -c 600 "$C/inst.out") $(head -c 300 "$C/inst.err")"
  fi
  inst
  if [ "$INST_RC" -eq 0 ] && groups_once && [ "$(jq -c '.statusLine' "$SET" | strip_eol_cr)" = "$(jq -c '.statusLine' "$TPL" | strip_eol_cr)" ]; then
    ok "$label: a run exits 0 and adds every template hook group once, and the template statusLine"
  else
    bad "$label: a run exits 0 and adds every template hook group once, and the template statusLine" "rc=$INST_RC $(head -c 300 "$C/inst.err")"
  fi
  if others_kept "$fixture"; then ok "$label: every other key is kept as it was, in its order"; else bad "$label: every other key is kept as it was, in its order" "$(jq -c 'del(.hooks, .statusLine)' "$SET" 2>&1 | head -c 300)"; fi
  if [ -n "$absent" ] && [ "$absent" = "$(run_added)" ]; then
    ok "$label: the run adds exactly the entries --check named absent"
  else
    bad "$label: the run adds exactly the entries --check named absent" "check: $(printf '%s' "$absent" | tr '\n' '|') run: $(run_added | tr '\n' '|')"
  fi
  inst --check
  if [ "$INST_RC" -eq 0 ] && grep -qF "$TPL_GROUPS hook entries: $TPL_GROUPS present" "$C/inst.out"; then
    ok "$label: --check after the run — nothing to act on (exit 0), every entry present"
  else
    bad "$label: --check after the run — nothing to act on (exit 0), every entry present" "rc=$INST_RC $(tail -n 1 "$C/inst.out")"
  fi
}

# refused <label> <fixture> <expected reason text> [text that must not appear]
# — exit 1, the file byte-identical, the reason in the run's "Not changed"
# line, and the same reason in --check's fault record (exit 1).
refused() {
  local label="$1" fixture="$2" want="$3" never="${4:-}" rec
  cp "$fixture" "$SET"
  inst
  cp "$C/inst.err" "$C/run.err"
  if [ "$INST_RC" -eq 1 ] && cmp -s "$SET" "$fixture" && grep -qF "exists and differs, and $want" "$C/run.err" \
      && grep -qF ". Not changed." "$C/run.err" && { [ -z "$never" ] || ! grep -qF "$never" "$C/run.err"; }; then
    ok "$label: a run refuses (exit 1), the file byte-identical, the reason named"
  else
    bad "$label: a run refuses (exit 1), the file byte-identical, the reason named" "rc=$INST_RC want [$want] got: $(head -c 400 "$C/run.err")"
  fi
  inst --check
  rec="$(awk -F '\t' '$1 == "settings" && $2 == "fault" { print $4 }' "$C/inst.out")"
  if [ "$INST_RC" -eq 1 ] && [ -n "$rec" ] && [[ "$rec" == *"$want"* ]] && grep -qF "exists and differs, and $rec. Not changed." "$C/run.err"; then
    ok "$label: --check reports the same reason as a fault (exit 1)"
  else
    bad "$label: --check reports the same reason as a fault (exit 1)" "rc=$INST_RC record: [$rec]"
  fi
  if [ -z "$(find "$IP/.claude" -name '*.iaeng-merge.*' 2>/dev/null)" ]; then ok "$label: no temporary file is left behind"; else bad "$label: no temporary file is left behind"; fi
}

# =============================================================================
# The cases. Each is a function run in its own project, in the background.

# QA's input on PR #465, byte for byte: the commonest shape.
case_permissions() {
  printf '{"permissions":{"allow":["Bash(npm test)","Bash(npm run lint)"]}}\n' > "$C/in.json"
  merges "permissions only" "$C/in.json"
  cp "$SET" "$C/merged.json"
  inst
  if [ "$INST_RC" -eq 0 ] && grep -q "present exactly" "$C/inst.out" && cmp -s "$SET" "$C/merged.json"; then
    ok "permissions only: a re-run adds nothing, the file byte-identical"
  else
    bad "permissions only: a re-run adds nothing, the file byte-identical" "rc=$INST_RC $(head -c 300 "$C/inst.out")"
  fi
}
case_schema() {
  cat > "$C/in.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
EOF
  merges "\$schema only" "$C/in.json"
}
case_empty() {
  printf '{}\n' > "$C/in.json"
  merges "an empty object {}" "$C/in.json"
}
case_null() {
  printf '{\n  "model": "opus",\n  "hooks": null,\n  "env": {"NODE_ENV": "test"}\n}\n' > "$C/in.json"
  merges "\"hooks\": null" "$C/in.json"
}
# The control: an empty "hooks" object merged before the fix too.
case_control() {
  printf '{\n  "permissions": {"allow": ["Bash(ls)"]},\n  "hooks": {}\n}\n' > "$C/in.json"
  cp "$C/in.json" "$SET"
  inst
  if [ "$INST_RC" -eq 0 ] && groups_once && others_kept "$C/in.json"; then
    ok "control: \"hooks\": {} — merged, every template group once, the other keys kept"
  else
    bad "control: \"hooks\": {} — merged, every template group once, the other keys kept" "rc=$INST_RC $(head -c 300 "$C/inst.err")"
  fi
}
# Every other key at once, and a statusLine of the project's own.
case_every_key() {
  cat > "$C/in.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": ["Bash(npm test)", "Bash(npm run lint)"],
    "deny": ["Read(./.env)"]
  },
  "env": {"NODE_ENV": "test", "LEDGER_DB": "postgres://localhost:5432/ledger"},
  "model": "opus",
  "statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 0}
}
EOF
  cp "$C/in.json" "$SET"
  inst
  if [ "$INST_RC" -eq 0 ] && groups_once && others_kept "$C/in.json"; then
    ok "every other key: merged, every template group once; \$schema, permissions, env and model kept, in their order"
  else
    bad "every other key: merged, every template group once; \$schema, permissions, env and model kept, in their order" "rc=$INST_RC $(head -c 300 "$C/inst.err")"
  fi
  local want_sl
  want_sl="$(jq -cn --arg c "$TPL_SL_CMD --chain '~/.claude/statusline.sh'" '{type: "command", command: $c, padding: 0}' | strip_eol_cr)"
  if [ "$(jq -c '.statusLine' "$SET" | strip_eol_cr)" = "$want_sl" ]; then
    ok "every other key: the project's statusLine is wrapped — its command single-quoted after --chain, its padding kept"
  else
    bad "every other key: the project's statusLine is wrapped — its command single-quoted after --chain, its padding kept" "got: $(jq -c '.statusLine' "$SET" | strip_eol_cr)"
  fi
  cp "$SET" "$C/merged.json"
  inst
  if [ "$INST_RC" -eq 0 ] && grep -q "present exactly" "$C/inst.out" && cmp -s "$SET" "$C/merged.json"; then
    ok "every other key: a re-run adds nothing, the file byte-identical"
  else
    bad "every other key: a re-run adds nothing, the file byte-identical" "rc=$INST_RC $(head -c 300 "$C/inst.out")"
  fi
}
case_line_comment() {
  printf '{\n  // the project note\n  "permissions": {"allow": ["Bash(ls)"]}\n}\n' > "$C/in.json"
  refused "a // comment" "$C/in.json" \
    "line 2 holds a comment (// or /* */), which JSON does not allow and jq cannot read: remove it (a note can go in a \"\$comment\" key) and re-run"
}
case_block_comment() {
  cat > "$C/in.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {"allow": ["Bash(ls)"]} /* the project note */
}
EOF
  refused "a /* */ comment after a \$schema URL" "$C/in.json" \
    "line 3 holds a comment (// or /* */)" "line 2 holds a comment"
}
case_trailing_comma() {
  cat > "$C/in.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {"allow": ["Bash(ls)"]},
}
EOF
  refused "a trailing comma, a \$schema URL above it" "$C/in.json" \
    "jq cannot read it as JSON (" "holds a comment"
}
case_hooks_false() {
  printf '{"permissions": {"allow": ["Bash(ls)"]}, "hooks": false}\n' > "$C/in.json"
  refused "\"hooks\": false" "$C/in.json" \
    "it is not one JSON object whose 'hooks' is an object, absent or null"
}

# -----------------------------------------------------------------------------
# Strict JSON in the settings schema's shape (WU-IAENG-441). Each fixture holds
# every template entry, so only the shape or the token is wrong.

# as_object <jq path> — the template, the list at <jq path> written as an
# object keyed "0", "1", ...
as_object() { jq "$1 |= (to_entries | map(.key |= tostring) | from_entries)" "$TPL" | strip_eol_cr; }
# with_line2 <text> — the template with <text> as its second line.
with_line2() { printf '{\n  %s\n' "$1"; tail -n +2 "$TPL"; }

case_event_object() {
  as_object '.hooks.PreToolUse' > "$C/in.json"
  refused "an event written as an object" "$C/in.json" \
    "\"hooks\" > \"PreToolUse\" is a JSON object, not a list (JSON array) of matcher groups"
}
case_group_object() {
  as_object '.hooks.PreToolUse[0].hooks' > "$C/in.json"
  refused "a group whose \"hooks\" is an object" "$C/in.json" \
    "group 1 of \"hooks\" > \"PreToolUse\" is not an object whose \"hooks\" is a list (JSON array)"
}
case_nan() {
  with_line2 '"x": NaN,' > "$C/in.json"
  refused "NaN beside every template entry" "$C/in.json" "line 2 holds NaN, which is not a JSON value"
}
case_infinity() {
  with_line2 '"x": [1, -Infinity],' > "$C/in.json"
  refused "-Infinity" "$C/in.json" "line 2 holds -Infinity, which is not a JSON value"
}
case_plus() {
  with_line2 '"x": +1,' > "$C/in.json"
  refused "a number with a leading +" "$C/in.json" "line 2 holds +1, which is not a JSON value"
}
case_bom() {
  { printf '\357\273\277'; cat "$TPL"; } > "$C/in.json"
  refused "a byte order mark before the template" "$C/in.json" "it begins with a byte order mark (BOM)"
}

# mklink <target> <link> — a symbolic link. Git for Windows without the right
# to create native links copies the target instead, or fails on a missing
# one; then a Cygwin-style link (MSYS=winsymlinks:sys), which bash and every
# MSYS tool follow as POSIX does a link. Returns non-zero when no link is made.
mklink() {
  ln -s "$1" "$2" 2>/dev/null && [ -L "$2" ] && return 0
  rm -f "$2"
  MSYS="${MSYS:+$MSYS }winsymlinks:sys" ln -s "$1" "$2" 2>/dev/null && [ -L "$2" ]
}
no_tmp_left() { [ -z "$(find "$IP/.claude" -name '*.iaeng-*' 2>/dev/null)" ]; }

# A link at settings.json that points at no file: a run refuses and creates
# nothing where it points; --check reports the same as a fault.
case_dangling() {
  mkdir -p "$C/elsewhere"
  local target="$C/elsewhere/settings.json" rec
  if ! mklink "$target" "$SET"; then
    bad "a dangling link: a symbolic link could be made for the case" "ln -s failed, native and MSYS sys links alike"
    return 0
  fi
  inst
  if [ "$INST_RC" -eq 1 ] && [ -L "$SET" ] && [ "$(readlink "$SET")" = "$target" ] && [ ! -e "$target" ] \
      && grep -qF "is a symbolic link. Not changed." "$C/inst.err" && no_tmp_left; then
    ok "a dangling link: a run refuses (exit 1), the link kept, nothing created where it points"
  else
    bad "a dangling link: a run refuses (exit 1), the link kept, nothing created where it points" "rc=$INST_RC target exists: $(if [ -e "$target" ]; then echo yes; else echo no; fi) $(head -c 300 "$C/inst.err")"
  fi
  inst --check
  rec="$(awk -F '\t' '$1 == "settings" && $2 == "fault" { print $4 }' "$C/inst.out")"
  if [ "$INST_RC" -eq 1 ] && [ "$rec" = "it is a symbolic link; a run refuses to write through it" ]; then
    ok "a dangling link: --check reports a fault (exit 1), not an absent file"
  else
    bad "a dangling link: --check reports a fault (exit 1), not an absent file" "rc=$INST_RC $(head -c 300 "$C/inst.out")"
  fi
  # The control: once the link is gone, a run installs the template.
  rm -f "$SET"
  inst
  if [ "$INST_RC" -eq 0 ] && [ ! -L "$SET" ] && [ "$(strip_eol_cr < "$SET")" = "$(cat "$TPL")" ] && no_tmp_left; then
    ok "a dangling link removed: a run writes the template (exit 0), no temporary file left"
  else
    bad "a dangling link removed: a run writes the template (exit 0), no temporary file left" "rc=$INST_RC $(head -c 300 "$C/inst.err")"
  fi
}
# --force on a link to the project's own file: refused, that file untouched.
case_force_link() {
  mkdir -p "$C/elsewhere"
  local target="$C/elsewhere/own.json"
  printf '{"permissions": {"allow": ["Bash(ls)"]}}\n' > "$target"
  cp "$target" "$C/own.orig"
  if ! mklink "$target" "$SET"; then
    bad "--force on a link: a symbolic link could be made for the case" "ln -s failed, native and MSYS sys links alike"
    return 0
  fi
  inst --force
  if [ "$INST_RC" -eq 1 ] && [ -L "$SET" ] && cmp -s "$target" "$C/own.orig" \
      && grep -qF "is a symbolic link. Not changed." "$C/inst.err" && no_tmp_left; then
    ok "--force on a link: refused (exit 1), the file it points at byte-identical, the link kept"
  else
    bad "--force on a link: refused (exit 1), the file it points at byte-identical, the link kept" "rc=$INST_RC $(head -c 300 "$C/inst.err")"
  fi
}
# --force on a regular file: the template is written beside it and renamed
# over it, so a second name (a hard link) of the old file keeps the old
# content; a write into the file would have changed both names.
case_force_rename() {
  printf '{"permissions": {"allow": ["Bash(ls)"]}}\n' > "$SET"
  cp "$SET" "$C/own.orig"
  if ! ln "$SET" "$C/second-name.json" 2>/dev/null || ! [ "$SET" -ef "$C/second-name.json" ]; then
    bad "--force: a hard link could be made for the case" "ln failed"
    return 0
  fi
  inst --force
  if [ "$INST_RC" -eq 0 ] && [ "$(strip_eol_cr < "$SET")" = "$(cat "$TPL")" ] \
      && cmp -s "$C/second-name.json" "$C/own.orig" && no_tmp_left; then
    ok "--force: the template replaces the file by rename (exit 0), the old file's other name unchanged, no temporary file left"
  else
    bad "--force: the template replaces the file by rename (exit 0), the old file's other name unchanged, no temporary file left" "rc=$INST_RC second name: $(head -c 120 "$C/second-name.json") $(head -c 300 "$C/inst.err")"
  fi
}

# enter <name> — in a case's background subshell: its results file and its
# project. leave — the mark that the case reached its end.
enter() { RES="$T/res-$1"; : > "$RES"; project "$1"; }
leave() { printf 'end\n' >> "$RES"; }
# One line per case: its name in CASES, which orders the count below, and its
# function called by name, so a name and its function cannot drift apart
# unseen (a name with no results file is a failure below).
CASES=""
CASES="$CASES permissions";    ( enter permissions;    case_permissions;    leave ) &
CASES="$CASES schema";         ( enter schema;         case_schema;         leave ) &
CASES="$CASES empty";          ( enter empty;          case_empty;          leave ) &
CASES="$CASES null";           ( enter null;           case_null;           leave ) &
CASES="$CASES control";        ( enter control;        case_control;        leave ) &
CASES="$CASES every_key";      ( enter every_key;      case_every_key;      leave ) &
CASES="$CASES line_comment";   ( enter line_comment;   case_line_comment;   leave ) &
CASES="$CASES block_comment";  ( enter block_comment;  case_block_comment;  leave ) &
CASES="$CASES trailing_comma"; ( enter trailing_comma; case_trailing_comma; leave ) &
CASES="$CASES hooks_false";    ( enter hooks_false;    case_hooks_false;    leave ) &
CASES="$CASES event_object";   ( enter event_object;   case_event_object;   leave ) &
CASES="$CASES group_object";   ( enter group_object;   case_group_object;   leave ) &
CASES="$CASES nan";            ( enter nan;            case_nan;            leave ) &
CASES="$CASES infinity";       ( enter infinity;       case_infinity;       leave ) &
CASES="$CASES plus";           ( enter plus;           case_plus;           leave ) &
CASES="$CASES bom";            ( enter bom;            case_bom;            leave ) &
CASES="$CASES dangling";       ( enter dangling;       case_dangling;       leave ) &
CASES="$CASES force_link";     ( enter force_link;     case_force_link;     leave ) &
CASES="$CASES force_rename";   ( enter force_rename;   case_force_rename;   leave ) &
wait

# The results, in the order the cases are listed.
echo "== install-hooks.sh — a settings.json without \"hooks\" (DEF-465-01), what it cannot merge, and how it writes"
for name in $CASES; do
  ended=0
  while IFS=$'\t' read -r st label detail; do
    case "$st" in
      ok) ok "$label" ;;
      bad) bad "$label" "$detail" ;;
      end) ended=1 ;;
    esac
  done < "$T/res-$name"
  [ "$ended" -eq 1 ] || bad "case $name: it did not reach its end"
done

# =============================================================================
echo
[ -z "${IAENG_HOOK_TESTS_COUNTS:-}" ] || printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
if [ "$FAILED" -eq 0 ]; then
  printf 'Settings shapes result: %s checks passed.\n' "$TOTAL"
  exit 0
fi
printf 'Settings shapes result: %s of %s checks failed.\n' "$FAILED" "$TOTAL"
exit 1
