#!/usr/bin/env bash
# IA Engineering — hook tests: the settings template denies Claude Code's
# PowerShell tool, and install-hooks.sh carries the rule into an existing
# settings.json (WU-IAENG-458)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/powershell-deny.sh [--verbose]
#
# WHY. The framework's guards read Bash commands. Claude Code on Windows also
# offers a PowerShell tool. Director decision of 26 November 2026: the
# settings template denies that tool, so that every shell command goes
# through the Bash tool, where the guards apply (hooks/README.md, Shell
# Commands Go Through Bash).
#
# What is proved:
#   - settings.example.json and the framework's own .claude/settings.json
#     hold the rule in permissions.deny, once.
#   - A fresh install writes it, and --check reports it present (exit 0).
#   - An install of an earlier framework (every hook entry, the statusLine,
#     the project's own allow, deny and ask rules, env and model): --check
#     reports the rule absent (exit 3) and --quiet keeps it; a run adds it
#     after the project's own deny rules, reports it as added, and changes
#     nothing else; --check after the run: present (exit 0); a re-run:
#     present exactly, the file byte-identical.
#   - No "permissions" at all, and "deny": null: the rule is added, every
#     other key kept.
#   - An allow or ask rule for the tool is kept and reported: --check lists
#     each as a near miss, information that never needs acting on alone; a
#     run names each on stderr and still adds the deny. A rule for another
#     tool, or a tool whose name only starts with PowerShell, is not one.
#   - A "permissions" that is not an object, and a "deny" that is not a list,
#     are refused: exit 1, the file byte-identical, the reason named in the
#     run's "Not changed" line and in --check's fault record (exit 1).
#
# ORACLES (Standards/TESTING_STANDARD.md, Independent Oracle). None is taken
# from install-hooks.sh's output, and the rule is never read from the
# template:
#   - the rule: Claude Code's permissions page, https://code.claude.com/docs/
#     en/permissions.md (read 26 November 2026): "Permission rules follow the
#     format Tool or Tool(specifier)"; "To match all uses of a tool, use only
#     the tool name without parentheses"; "a bare PowerShell or
#     PowerShell(*) matches every command"; "A bare tool name like Bash
#     removes the tool from Claude's context entirely". The canonical name is
#     the tools reference's, https://code.claude.com/docs/en/
#     tools-reference.md: "PowerShell". So the rule is the string PowerShell
#     in permissions.deny, spelled here;
#   - an allow or ask rule for the tool: the same page's format, the tool
#     name alone or followed by "(";
#   - what is kept: install-hooks.sh's header, "nothing already in the file
#     is changed, reordered or removed — the project's own hooks, its env,
#     its permissions";
#   - --check: its header, exit 0 nothing to act on, 3 drift, 1 a fault;
#     a near miss is information;
#   - the shape: Claude Code's settings schema gives "permissions" an object
#     and its "deny" a list of rule strings.
#
# EACH CASE RUNS IN ITS OWN PROJECT, IN THE BACKGROUND, as in
# tests/settings-shapes.sh: on Git for Windows one installer run takes tens of
# seconds under load. A case that did not reach its end is a failure.
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
    *) echo "powershell-deny.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
CC="$(cd "$HOOKS/.." && pwd)"
FRAMEWORK="$(cd "$CC/../../.." && pwd)"

command -v jq >/dev/null 2>&1 || {
  echo "powershell-deny.sh: jq is required and is not installed. Reported rather than skipped." >&2
  exit 2
}

# The rule, as the documentation spells it (ORACLES above).
RULE='PowerShell'

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

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-psdeny458.XXXXXX")" || { echo "powershell-deny.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
trap 'cd / && rm -rf "$T"' EXIT

# The template rendered for this project, independently of the script. The
# fixtures of an earlier install take it without its "permissions", which
# the template before this Work Unit did not have.
TPL="$T/template.json"
sed 's#__IAENG_ROOT__#ia-engineering#g' "$CC/settings.example.json" > "$TPL"
EARLIER="$T/earlier.json"
jq 'del(.permissions)' "$TPL" | strip_eol_cr > "$EARLIER"

# deny_count <file> — how many times the rule is in its permissions.deny.
deny_count() { jq --arg r "$RULE" '[.permissions.deny[]? | select(. == $r)] | length' "$1" 2>/dev/null | strip_eol_cr; }

# --- The template and the framework's own settings (no install) --------------
echo "== the template and the framework's own settings deny the PowerShell tool (WU-IAENG-458)"
if [ "$(deny_count "$CC/settings.example.json")" = 1 ]; then
  ok "settings.example.json: permissions.deny holds $RULE once"
else
  bad "settings.example.json: permissions.deny holds $RULE once" "got: $(jq -c '.permissions' "$CC/settings.example.json" 2>&1 | strip_eol_cr)"
fi
if [ "$(deny_count "$FRAMEWORK/.claude/settings.json")" = 1 ]; then
  ok "the framework's own .claude/settings.json: permissions.deny holds $RULE once"
else
  bad "the framework's own .claude/settings.json: permissions.deny holds $RULE once" "got: $(jq -c '.permissions' "$FRAMEWORK/.claude/settings.json" 2>&1 | strip_eol_cr)"
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
# perm_records <status> — the details of the last --check's permission
# records with that status, one per line.
perm_records() { awk -F '\t' -v st="$1" '$1 == "permission" && $2 == st { print $4 }' "$C/inst.out"; }
# but_deny <file> — the file without permissions.deny, as compact JSON in its
# key order: every other key, the project's other permissions included.
but_deny() { jq -c 'del(.permissions.deny)' "$1" | strip_eol_cr; }

# =============================================================================
# The cases. Each is a function run in its own project, in the background.

# A fresh project: the rule is written with the template.
case_fresh() {
  inst
  if [ "$INST_RC" -eq 0 ] && [ "$(deny_count "$SET")" = 1 ]; then
    ok "a fresh install: exit 0, permissions.deny holds $RULE once"
  else
    bad "a fresh install: exit 0, permissions.deny holds $RULE once" "rc=$INST_RC $(head -c 300 "$C/inst.err")"
  fi
  inst --check
  if [ "$INST_RC" -eq 0 ] && [ "$(perm_records present)" = "permissions.deny: $RULE" ] && [ -z "$(perm_records absent)" ]; then
    ok "a fresh install: --check reports the rule present (exit 0)"
  else
    bad "a fresh install: --check reports the rule present (exit 0)" "rc=$INST_RC $(head -c 600 "$C/inst.out")"
  fi
}

# An install of an earlier framework, with the project's own permissions:
# every hook entry is there, the rule is not.
case_earlier() {
  jq '.permissions = {"allow": ["Bash(npm test)"], "deny": ["Read(./.env)"], "ask": ["Bash(git push *)"]}
      | .env = {"NODE_ENV": "test"} | .model = "opus"' "$EARLIER" | strip_eol_cr > "$C/in.json"
  cp "$C/in.json" "$SET"
  inst --check
  if [ "$INST_RC" -eq 3 ] && [ "$(perm_records absent)" = "permissions.deny: $RULE" ] \
      && ! awk -F '\t' '$1 == "hook" && $2 == "absent"' "$C/inst.out" | grep -q . \
      && grep -qF "1 permission rule(s): 1 absent" "$C/inst.out"; then
    ok "an earlier install: --check reports the rule absent (exit 3), every hook entry present"
  else
    bad "an earlier install: --check reports the rule absent (exit 3), every hook entry present" "rc=$INST_RC $(head -c 800 "$C/inst.out")"
  fi
  inst --check --quiet
  if [ "$INST_RC" -eq 3 ] && grep -qF "permission	absent	.claude/settings.json	permissions.deny: $RULE" "$C/inst.out"; then
    ok "an earlier install: --check --quiet keeps the absent rule (exit 3)"
  else
    bad "an earlier install: --check --quiet keeps the absent rule (exit 3)" "rc=$INST_RC $(head -c 400 "$C/inst.out")"
  fi
  inst
  if [ "$INST_RC" -eq 0 ] && [ "$(jq -c '.permissions.deny' "$SET" | strip_eol_cr)" = "[\"Read(./.env)\",\"$RULE\"]" ]; then
    ok "an earlier install: a run adds the rule after the project's own deny rules (exit 0)"
  else
    bad "an earlier install: a run adds the rule after the project's own deny rules (exit 0)" "rc=$INST_RC deny: $(jq -c '.permissions.deny' "$SET" 2>&1 | strip_eol_cr) $(head -c 300 "$C/inst.err")"
  fi
  if [ "$(but_deny "$SET")" = "$(but_deny "$C/in.json")" ]; then
    ok "an earlier install: everything else is kept as it was, in its order (hooks, statusLine, allow, ask, env, model)"
  else
    bad "an earlier install: everything else is kept as it was, in its order (hooks, statusLine, allow, ask, env, model)" "$(but_deny "$SET" | head -c 300)"
  fi
  if grep -qxF "    added:   permissions.deny: $RULE" "$C/inst.out"; then
    ok "an earlier install: the run reports the rule as added"
  else
    bad "an earlier install: the run reports the rule as added" "$(head -c 600 "$C/inst.out")"
  fi
  inst --check
  if [ "$INST_RC" -eq 0 ] && [ "$(perm_records present)" = "permissions.deny: $RULE" ]; then
    ok "an earlier install: --check after the run reports the rule present (exit 0)"
  else
    bad "an earlier install: --check after the run reports the rule present (exit 0)" "rc=$INST_RC $(tail -n 1 "$C/inst.out")"
  fi
  cp "$SET" "$C/merged.json"
  inst
  if [ "$INST_RC" -eq 0 ] && grep -q "present exactly" "$C/inst.out" && cmp -s "$SET" "$C/merged.json" \
      && grep -qxF "    present: permissions.deny: $RULE" "$C/inst.out"; then
    ok "an earlier install: a re-run adds nothing, reports the rule present, the file byte-identical"
  else
    bad "an earlier install: a re-run adds nothing, reports the rule present, the file byte-identical" "rc=$INST_RC $(head -c 600 "$C/inst.out")"
  fi
}

# The shapes a rule can be missing from: no "permissions", and "deny": null.
case_no_permissions() {
  cp "$EARLIER" "$SET"
  inst
  if [ "$INST_RC" -eq 0 ] && [ "$(jq -c '.permissions' "$SET" | strip_eol_cr)" = "{\"deny\":[\"$RULE\"]}" ] \
      && [ "$(jq -c 'del(.permissions)' "$SET" | strip_eol_cr)" = "$(jq -c . "$EARLIER" | strip_eol_cr)" ]; then
    ok "no \"permissions\": a run adds {\"deny\": [\"$RULE\"]}, every other key kept (exit 0)"
  else
    bad "no \"permissions\": a run adds {\"deny\": [\"$RULE\"]}, every other key kept (exit 0)" "rc=$INST_RC $(jq -c '.permissions' "$SET" 2>&1 | strip_eol_cr) $(head -c 300 "$C/inst.err")"
  fi
}
case_deny_null() {
  jq '.permissions = {"allow": ["Bash(ls)"], "deny": null}' "$EARLIER" | strip_eol_cr > "$C/in.json"
  cp "$C/in.json" "$SET"
  inst
  if [ "$INST_RC" -eq 0 ] && [ "$(jq -c '.permissions' "$SET" | strip_eol_cr)" = "{\"allow\":[\"Bash(ls)\"],\"deny\":[\"$RULE\"]}" ] \
      && [ "$(but_deny "$SET")" = "$(but_deny "$C/in.json")" ]; then
    ok "\"deny\": null: a run makes it [\"$RULE\"], the allow rule and every other key kept (exit 0)"
  else
    bad "\"deny\": null: a run makes it [\"$RULE\"], the allow rule and every other key kept (exit 0)" "rc=$INST_RC $(jq -c '.permissions' "$SET" 2>&1 | strip_eol_cr) $(head -c 300 "$C/inst.err")"
  fi
}

# An allow and an ask rule for the tool: kept, reported, and the deny added.
# Bash(ls) is another tool's rule, and PowerShellISE a name that only starts
# with the tool's: neither is reported.
case_allow() {
  jq --arg r "$RULE" '.permissions = {"allow": [($r + "(Get-ChildItem *)"), "Bash(ls)", ($r + "ISE")], "ask": [$r]}' "$EARLIER" \
    | strip_eol_cr > "$C/in.json"
  cp "$C/in.json" "$SET"
  local want_near
  want_near="$(printf '%s\n' "permissions.allow: $RULE(Get-ChildItem *)" "permissions.ask: $RULE" | sort)"
  inst --check
  if [ "$INST_RC" -eq 3 ] && [ "$(perm_records near-miss | sed 's/  (.*$//' | sort)" = "$want_near" ] \
      && [ "$(perm_records absent)" = "permissions.deny: $RULE" ]; then
    ok "an allow and an ask rule for the tool: --check reports each as a near miss beside the absent deny (exit 3)"
  else
    bad "an allow and an ask rule for the tool: --check reports each as a near miss beside the absent deny (exit 3)" "rc=$INST_RC $(head -c 800 "$C/inst.out")"
  fi
  inst
  if [ "$INST_RC" -eq 0 ] && [ "$(jq -c '.permissions.deny' "$SET" | strip_eol_cr)" = "[\"$RULE\"]" ] \
      && [ "$(but_deny "$SET")" = "$(but_deny "$C/in.json")" ]; then
    ok "an allow and an ask rule for the tool: a run adds the deny and keeps both rules as they were (exit 0)"
  else
    bad "an allow and an ask rule for the tool: a run adds the deny and keeps both rules as they were (exit 0)" "rc=$INST_RC $(jq -c '.permissions' "$SET" 2>&1 | strip_eol_cr)"
  fi
  if grep -qF "permissions.allow: $RULE(Get-ChildItem *)" "$C/inst.err" && grep -qF "permissions.ask: $RULE" "$C/inst.err" \
      && ! grep -qF "Bash(ls)" "$C/inst.err" && ! grep -qF "${RULE}ISE" "$C/inst.err"; then
    ok "an allow and an ask rule for the tool: the run names both on stderr, and neither other rule"
  else
    bad "an allow and an ask rule for the tool: the run names both on stderr, and neither other rule" "$(head -c 600 "$C/inst.err")"
  fi
  inst --check
  if [ "$INST_RC" -eq 0 ] && [ "$(perm_records near-miss | sed 's/  (.*$//' | sort)" = "$want_near" ] \
      && [ "$(perm_records present)" = "permissions.deny: $RULE" ]; then
    ok "an allow and an ask rule for the tool: after the run, near misses alone are information (exit 0)"
  else
    bad "an allow and an ask rule for the tool: after the run, near misses alone are information (exit 0)" "rc=$INST_RC $(head -c 800 "$C/inst.out")"
  fi
}

# refused <label> <fixture> <expected reason text> — exit 1, the file
# byte-identical, the reason in the run's "Not changed" line, and the same
# reason in --check's fault record (exit 1).
refused() {
  local label="$1" fixture="$2" want="$3" rec
  cp "$fixture" "$SET"
  inst
  cp "$C/inst.err" "$C/run.err"
  if [ "$INST_RC" -eq 1 ] && cmp -s "$SET" "$fixture" && grep -qF "exists and differs, and $want" "$C/run.err" \
      && grep -qF ". Not changed." "$C/run.err"; then
    ok "$label: a run refuses (exit 1), the file byte-identical, the reason named"
  else
    bad "$label: a run refuses (exit 1), the file byte-identical, the reason named" "rc=$INST_RC want [$want] got: $(head -c 400 "$C/run.err")"
  fi
  inst --check
  rec="$(awk -F '\t' '$1 == "settings" && $2 == "fault" { print $4 }' "$C/inst.out")"
  if [ "$INST_RC" -eq 1 ] && [ -n "$rec" ] && [[ "$rec" == *"$want"* ]]; then
    ok "$label: --check reports the same reason as a fault (exit 1)"
  else
    bad "$label: --check reports the same reason as a fault (exit 1)" "rc=$INST_RC record: [$rec]"
  fi
}
case_deny_string() {
  jq --arg r "$RULE" '.permissions = {"deny": $r}' "$EARLIER" | strip_eol_cr > "$C/in.json"
  refused "\"deny\" written as a string" "$C/in.json" \
    "\"permissions\" > \"deny\" is a JSON string, not a list (JSON array) of rules"
}
case_permissions_string() {
  jq --arg r "$RULE" '.permissions = ("deny " + $r)' "$EARLIER" | strip_eol_cr > "$C/in.json"
  refused "\"permissions\" written as a string" "$C/in.json" \
    "\"permissions\" is a JSON string, not an object"
}

# enter <name> — in a case's background subshell: its results file and its
# project. leave — the mark that the case reached its end.
enter() { RES="$T/res-$1"; : > "$RES"; project "$1"; }
leave() { printf 'end\n' >> "$RES"; }
CASES=""
CASES="$CASES fresh";              ( enter fresh;              case_fresh;              leave ) &
CASES="$CASES earlier";            ( enter earlier;            case_earlier;            leave ) &
CASES="$CASES no_permissions";     ( enter no_permissions;     case_no_permissions;     leave ) &
CASES="$CASES deny_null";          ( enter deny_null;          case_deny_null;          leave ) &
CASES="$CASES allow";              ( enter allow;              case_allow;              leave ) &
CASES="$CASES deny_string";        ( enter deny_string;        case_deny_string;        leave ) &
CASES="$CASES permissions_string"; ( enter permissions_string; case_permissions_string; leave ) &
wait

# The results, in the order the cases are listed.
echo "== install-hooks.sh — the template denies the PowerShell tool, carried into an existing settings.json (WU-IAENG-458)"
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
  printf 'PowerShell deny result: %s checks passed.\n' "$TOTAL"
  exit 0
fi
printf 'PowerShell deny result: %s of %s checks failed.\n' "$FAILED" "$TOTAL"
exit 1
