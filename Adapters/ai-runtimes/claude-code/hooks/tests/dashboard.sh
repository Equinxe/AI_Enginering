#!/usr/bin/env bash
# IA Engineering — hook tests: the usage dashboard's Stop hook, its settings
# entry, the two installers, and the /dashboard command (WU-IAENG-342)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/dashboard.sh [--verbose]
#
# What is proved, and how:
#
#   - dashboard-refresh.sh never fails, never prints and never holds the
#     runtime's pipes. Every call runs under a command substitution that
#     receives BOTH stdout and stderr, so the substitution ends only when
#     every holder of either pipe has closed it: an exit status other than 0,
#     a byte of output, or a child that kept a pipe open would each show.
#     The fake dashboard script used here prints on both streams, leaves a
#     child running for seconds and exits 3 — everything the hook must absorb.
#   - The same with the REAL usage-dashboard.sh, for a project that does not
#     exist, is not a git work tree, or has a cache git does not ignore (that
#     last one waits for the refresh it started to refuse, and checks it wrote
#     nothing in the work tree).
#   - The settings entry: run as Claude Code runs it (bash -c), with the hook
#     present and with the hook missing (a framework pinned before it).
#   - install-hooks.sh adds the entry once, keeps a project's own entries,
#     counts an entry present only when the same event and matcher hold it
#     equal in every field (a decoy, a neutered copy, another matcher, or the
#     exact command with another timeout or an extra field gets the real
#     entry added beside it and is reported; key order and the spelling of
#     the project directory do not count), warns on stderr and in its report
#     when "disableAllHooks": true is set in settings.json or
#     settings.local.json without changing it (issue #241), and refuses a
#     symbolic link.
#   - install-skills.sh installs /dashboard, quietly on a re-run, and in the
#     framework checkout installs it alone; SKILL.md is well formed and
#     names the command its allowed-tools permits; the launcher prints one
#     line and calls --open --no-wait for the project it is installed in.
#   - Both installers add their LF rule to the project's .gitattributes once
#     (a CRLF .gitattributes, or one without a final newline, included), and
#     a clone made with core.autocrlf=true checks the installed files out LF
#     while a file no rule covers comes out CRLF (issue #242).
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
    *) echo "dashboard.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
CC="$(cd "$HOOKS/.." && pwd)"
FRAMEWORK="$(cd "$CC/../../.." && pwd)"

for dep in jq git; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "dashboard.sh: $dep is required and is not installed. Reported rather than skipped." >&2
    exit 2
  }
done

FAILED=0
TOTAL=0
ok() { TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0; }
bad() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '         %s\n' "$2"; return 0; }
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label"; fi; }

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-dash342.XXXXXX")" || { echo "dashboard.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
trap 'cd / && rm -rf "$T"' EXIT

# Milliseconds, from bash's own clock where it has one (no process started).
now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local us="${EPOCHREALTIME/./}"
    printf '%s' "$((10#$us / 1000))"
  else
    printf '%s000' "$(date +%s)"
  fi
}

# A hook is "fast" well under the 10 s timeout its settings entry carries,
# on a loaded CI runner.
FAST_MS=5000
PAYLOAD='{"hook_event_name":"Stop","stop_hook_active":false}'

# run_cmd <cmd...> — runs it with the payload on stdin, stdout and stderr
# both into one command substitution; sets RUN_RC, RUN_OUT, RUN_MS.
run_cmd() {
  local s e
  s="$(now_ms)"
  RUN_OUT="$(printf '%s' "$PAYLOAD" | "$@" 2>&1)"
  RUN_RC=$?
  e="$(now_ms)"
  RUN_MS=$((e - s))
}

# quiet_fast <label> — the last run_cmd exited 0, printed nothing on either
# stream, and released both pipes within FAST_MS.
quiet_fast() {
  if [ "$RUN_RC" -eq 0 ] && [ -z "$RUN_OUT" ] && [ "$RUN_MS" -lt "$FAST_MS" ]; then
    ok "$1 (${RUN_MS} ms)"
  else
    bad "$1" "exit=$RUN_RC ms=$RUN_MS output=[$(printf '%s' "$RUN_OUT" | head -c 300)]"
  fi
}

# wait_lines <file> <n> [seconds] — until the file has at least n lines.
wait_lines() {
  local f="$1" n="$2" max="${3:-30}" i=0
  while [ "$i" -lt "$max" ]; do
    [ -f "$f" ] && [ "$(wc -l < "$f" | tr -d ' ')" -ge "$n" ] && return 0
    sleep 1; i=$((i + 1))
  done
  return 1
}

new_repo() {
  mkdir -p "$1" && git -C "$1" init -q \
    && git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
}

# =============================================================================
echo "== dashboard-refresh.sh (Stop hook), with a misbehaving fake dashboard script"

FW="$T/fw"
mkdir -p "$FW/Adapters/ai-runtimes/claude-code/hooks" "$FW/Adapters/scripts"
cp "$HOOKS/dashboard-refresh.sh" "$FW/Adapters/ai-runtimes/claude-code/hooks/"
FHOOK="$FW/Adapters/ai-runtimes/claude-code/hooks/dashboard-refresh.sh"
CALLS="$T/calls"
# Prints on both streams, leaves a child running with its streams, exits 3:
# everything the hook must absorb. The child leaves the fixture directory so
# that it never keeps it from being removed.
cat > "$FW/Adapters/scripts/usage-dashboard.sh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_CALLS"
echo "fake usage-dashboard: a line on stdout"
echo "fake usage-dashboard: a line on stderr" >&2
( cd / && exec sleep 8 ) &
exit 3
FAKE
export FAKE_CALLS="$CALLS"

P="$T/proj"
new_repo "$P" || { echo "dashboard.sh: git init failed" >&2; exit 2; }

rm -f "$CALLS"
CLAUDE_PROJECT_DIR="$P" run_cmd bash "$FHOOK"
quiet_fast "hook: exits 0, prints nothing, releases its pipes although the script prints, lingers and exits 3"
if wait_lines "$CALLS" 1; then
  check "hook: calls the script with --refresh-in-background --project-dir \$CLAUDE_PROJECT_DIR" \
    [ "$(tail -n 1 "$CALLS")" = "--refresh-in-background --project-dir $P" ]
else
  bad "hook: calls the script" "no call recorded in 30 s"
fi

rm -f "$CALLS"
CLAUDE_PROJECT_DIR="$P" run_cmd bash "$FHOOK" --bogus 'x y' -- ';exit 9' '--project-dir' "$T"
quiet_fast "hook: arguments given to it are ignored — still exit 0 and silent"
PAYLOAD_SAVED="$PAYLOAD"
PAYLOAD=""
CLAUDE_PROJECT_DIR="$P" run_cmd bash "$FHOOK"
PAYLOAD="$PAYLOAD_SAVED"
quiet_fast "hook: no payload on stdin (closed) — exit 0 and silent"
if wait_lines "$CALLS" 2; then
  check "hook: no argument of its own reaches the script" \
    [ "$(sort -u "$CALLS")" = "--refresh-in-background --project-dir $P" ]
else
  bad "hook: calls the script with junk arguments or no stdin" "fewer than 2 calls recorded in 30 s"
fi

# Opt-out: none of these may start the script. A normal call afterwards is
# the sentinel: once it is recorded, the file holds exactly what was started.
rm -f "$CALLS"
for v in 0 off OFF false False no NO; do
  IAENG_USAGE_AUTO_REFRESH="$v" CLAUDE_PROJECT_DIR="$P" run_cmd bash "$FHOOK"
  quiet_fast "hook: IAENG_USAGE_AUTO_REFRESH=$v — exit 0 and silent"
done
mkdir -p "$P/.ia-engineering"
: > "$P/.ia-engineering/usage-auto-refresh.off"
CLAUDE_PROJECT_DIR="$P" run_cmd bash "$FHOOK"
quiet_fast "hook: .ia-engineering/usage-auto-refresh.off present — exit 0 and silent"
rm -f "$P/.ia-engineering/usage-auto-refresh.off"
IAENG_USAGE_AUTO_REFRESH=on CLAUDE_PROJECT_DIR="$P" run_cmd bash "$FHOOK"
quiet_fast "hook: IAENG_USAGE_AUTO_REFRESH=on — exit 0 and silent"
if wait_lines "$CALLS" 1; then
  sleep 1
  check "hook: opted out (env 0/off/false/no in any case, or the marker file) — the script is never started; 'on' starts it" \
    [ "$(wc -l < "$CALLS" | tr -d ' ')" -eq 1 ]
else
  bad "hook: IAENG_USAGE_AUTO_REFRESH=on starts the script" "no call recorded in 30 s"
fi

# Without CLAUDE_PROJECT_DIR (run by hand): the current directory.
rm -f "$CALLS"
if ( cd "$P" && unset CLAUDE_PROJECT_DIR && run_cmd bash "$FHOOK" && [ "$RUN_RC" -eq 0 ] && [ -z "$RUN_OUT" ] ); then ok "hook: without CLAUDE_PROJECT_DIR — exit 0 and silent"; else bad "hook: without CLAUDE_PROJECT_DIR — exit 0 and silent"; fi
if wait_lines "$CALLS" 1; then
  check "hook: without CLAUDE_PROJECT_DIR the project is the current directory" \
    [ "$(tail -n 1 "$CALLS")" = "--refresh-in-background --project-dir $P" ]
else
  bad "hook: without CLAUDE_PROJECT_DIR the script is called" "no call recorded in 30 s"
fi

# The dashboard script absent beside the hook: a framework pinned before it.
FW2="$T/fw-old"
mkdir -p "$FW2/Adapters/ai-runtimes/claude-code/hooks"
cp "$HOOKS/dashboard-refresh.sh" "$FW2/Adapters/ai-runtimes/claude-code/hooks/"
CLAUDE_PROJECT_DIR="$P" run_cmd bash "$FW2/Adapters/ai-runtimes/claude-code/hooks/dashboard-refresh.sh"
quiet_fast "hook: dashboard script missing — skipped silently, exit 0"

# =============================================================================
echo "== dashboard-refresh.sh with the real usage-dashboard.sh"

[ -f "$FRAMEWORK/Adapters/scripts/usage-dashboard.sh" ] \
  || { echo "dashboard.sh: $FRAMEWORK/Adapters/scripts/usage-dashboard.sh is missing" >&2; exit 2; }

CLAUDE_PROJECT_DIR="$T/does-not-exist" run_cmd bash "$HOOKS/dashboard-refresh.sh"
quiet_fast "real script: a project directory that does not exist — exit 0 and silent"
mkdir -p "$T/plain"
CLAUDE_PROJECT_DIR="$T/plain" run_cmd bash "$HOOKS/dashboard-refresh.sh"
quiet_fast "real script: a directory that is not a git work tree — exit 0 and silent"

# A cache git does not ignore: the refresh the hook starts must refuse it,
# record why in the git directory, and write nothing in the work tree.
NI="$T/not-ignored"
new_repo "$NI" || { echo "dashboard.sh: git init failed" >&2; exit 2; }
CLAUDE_PROJECT_DIR="$NI" run_cmd bash "$HOOKS/dashboard-refresh.sh"
quiet_fast "real script: a project whose .ia-engineering/usage/ git does not ignore — exit 0 and silent"
i=0
while [ "$i" -lt 180 ] && [ ! -f "$NI/.git/ia-engineering-usage.refused" ]; do sleep 1; i=$((i + 1)); done
if [ -f "$NI/.git/ia-engineering-usage.refused" ]; then
  sleep 1
  ok "real script: the refresh the hook started refused the cache and recorded why in .git (${i} s)"
  check "real script: nothing was written in that project's work tree" \
    [ -z "$(git -C "$NI" status --porcelain --untracked-files=all 2>/dev/null)" ]
  CLAUDE_PROJECT_DIR="$NI" run_cmd bash "$HOOKS/dashboard-refresh.sh"
  quiet_fast "real script: called again within the interval after a refusal — exit 0 and silent"
else
  bad "real script: the refresh the hook started refused the cache and recorded why in .git" "no record after 180 s"
fi

# =============================================================================
echo "== settings.example.json — the Stop entry"

TPL="$CC/settings.example.json"
check "template: is valid JSON" jq -e 'type == "object"' "$TPL"
STOP_SCRIPTS="$(jq -r '[.hooks.Stop[] | [.hooks[].command | capture("hooks/(?<n>[A-Za-z0-9._-]+[.]sh)").n] | join(",")] | join(" ")' "$TPL" | tr -d '\r')"
check "template: Stop runs stop-gate.sh, then dashboard-refresh.sh, each in its own group" \
  [ "$STOP_SCRIPTS" = "stop-gate.sh dashboard-refresh.sh" ]
DCMD="$(jq -r '.hooks.Stop[].hooks[] | select(.command | test("dashboard-refresh[.]sh")) | .command' "$TPL" | tr -d '\r')"
DTIMEOUT="$(jq -r '.hooks.Stop[].hooks[] | select(.command | test("dashboard-refresh[.]sh")) | .timeout' "$TPL" | tr -d '\r')"
case "$DCMD" in
  *'dashboard-refresh.sh" >/dev/null 2>&1 || true') ok "template: the refresh command discards both streams and cannot fail, even with the hook file missing" ;;
  *) bad "template: the refresh command discards both streams and cannot fail" "command: $DCMD" ;;
esac
if [[ "$DTIMEOUT" =~ ^[0-9]+$ ]] && [ "$DTIMEOUT" -ge 1 ] && [ "$DTIMEOUT" -le 10 ]; then ok "template: the refresh entry carries a timeout of at most 10 s"; else bad "template: the refresh entry carries a timeout of at most 10 s"; fi
check "template: dashboard-refresh.sh is registered under Stop only (not SubagentStop, see hooks/README.md)" \
  [ "$(jq -r '[.hooks | to_entries[] | select([.value[].hooks[].command] | any(test("dashboard-refresh"))) | .key] | join(",")' "$TPL" | tr -d '\r')" = "Stop" ]

# The command as Claude Code runs it: bash -c, CLAUDE_PROJECT_DIR set.
SP3="$T/settings-project"
mkdir -p "$SP3"
cp -R "$FW" "$SP3/ia-engineering"
RCMD="${DCMD//__IAENG_ROOT__/ia-engineering}"
rm -f "$CALLS"
CLAUDE_PROJECT_DIR="$SP3" run_cmd bash -c "$RCMD"
quiet_fast "settings command: run as Claude Code runs it — exit 0 and silent"
if wait_lines "$CALLS" 1; then
  check "settings command: reaches the hook, which calls the script for \$CLAUDE_PROJECT_DIR" \
    [ "$(tail -n 1 "$CALLS")" = "--refresh-in-background --project-dir $SP3" ]
else
  bad "settings command: reaches the hook" "no call recorded in 30 s"
fi
mkdir -p "$T/no-framework"
CLAUDE_PROJECT_DIR="$T/no-framework" run_cmd bash -c "$RCMD"
quiet_fast "settings command: the hook file itself missing (older framework pin) — exit 0 and silent"

if [ -f "$FRAMEWORK/.claude/settings.json" ] && [ -f "$FRAMEWORK/Core/AI_MANIFEST.md" ]; then
  check "this repository's .claude/settings.json is the template rendered for '.' (install-hooks.sh output)" \
    [ "$(cat "$FRAMEWORK/.claude/settings.json")" = "$(sed 's#__IAENG_ROOT__#.#g' "$TPL")" ]
else
  bad "this repository's .claude/settings.json exists" "$FRAMEWORK/.claude/settings.json not found"
fi

# =============================================================================
echo "== install-hooks.sh — merge into an existing settings.json"

IP="$T/hooks-project"
IFW="$IP/ia-engineering/Adapters/ai-runtimes/claude-code"
mkdir -p "$IFW/hooks"
cp -p "$CC/install-hooks.sh" "$CC/settings.example.json" "$IFW/"
cp -p "$HOOKS"/*.sh "$IFW/hooks/"
chmod +x "$IFW"/hooks/*.sh "$IFW/install-hooks.sh"
SET="$IP/.claude/settings.json"
inst() { ( cd "$IP" && bash "$IFW/install-hooks.sh" "$@" ) > "$T/inst.out" 2> "$T/inst.err"; INST_RC=$?; }
count_cmd() { jq -r --arg ev "$1" --arg n "$2" '[.hooks[$ev][]?.hooks[]?.command | select(contains($n))] | length' "$SET" | tr -d '\r'; }

SET_RULE='/.claude/settings.json text eol=lf'
GA="$IP/.gitattributes"
# rule_count <file> <rule> — lines equal to the rule, a CR at the end ignored.
rule_count() { tr -d '\r' 2>/dev/null < "$1" | grep -cxF "$2"; }

inst --print
if [ "$INST_RC" -eq 0 ] && [ ! -e "$SET" ] && [ ! -e "$GA" ]; then ok "--print: exit 0 and writes nothing (no settings.json, no .gitattributes)"; else bad "--print: exit 0 and writes nothing (no settings.json, no .gitattributes)"; fi
cp "$T/inst.out" "$T/rendered.json"

inst
if [ "$INST_RC" -eq 0 ] && cmp -s "$SET" "$T/rendered.json"; then ok "fresh project: settings.json written, equal to --print"; else bad "fresh project: settings.json written, equal to --print"; fi
if [ "$(rule_count "$GA" "$SET_RULE")" = 1 ] && grep -qF "+ .gitattributes: $SET_RULE" "$T/inst.out"; then ok "#242: fresh project — .gitattributes gets the settings.json LF rule, reported"; else bad "#242: fresh project — .gitattributes gets the settings.json LF rule, reported" "$(cat "$GA" 2>/dev/null)"; fi
cp "$SET" "$T/before.json"
cp "$GA" "$T/ga.before"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "already current" "$T/inst.out" && cmp -s "$SET" "$T/before.json"; then ok "re-run on a current file: exit 0, 'already current', byte-identical"; else bad "re-run on a current file: exit 0, 'already current', byte-identical"; fi
if cmp -s "$GA" "$T/ga.before" && ! grep -q "gitattributes" "$T/inst.out"; then ok "#242: re-run — .gitattributes byte-identical, nothing said about it"; else bad "#242: re-run — .gitattributes byte-identical, nothing said about it"; fi

# The rule already there in a CRLF .gitattributes: found, not appended again.
printf '*.png binary\r\n/.claude/settings.json text eol=lf\r\n' > "$GA"
cp "$GA" "$T/ga.before"
inst
if [ "$INST_RC" -eq 0 ] && cmp -s "$GA" "$T/ga.before"; then ok "#242: the rule in a CRLF .gitattributes is found — the file is left byte-identical"; else bad "#242: the rule in a CRLF .gitattributes is found — the file is left byte-identical" "$(od -c "$GA" | head -5)"; fi
# A .gitattributes without a final newline: the rule goes on a line of its own.
printf '*.png binary' > "$GA"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(head -n 1 "$GA")" = '*.png binary' ] && [ "$(rule_count "$GA" "$SET_RULE")" = 1 ]; then ok "#242: no final newline — the project's last line kept intact, the rule on its own line"; else bad "#242: no final newline — the project's last line kept intact, the rule on its own line" "$(cat "$GA")"; fi
inst
check "#242: and a re-run still holds it exactly once" [ "$(rule_count "$GA" "$SET_RULE")" = 1 ]

# A file from the previous template, plus the project's own entries.
jq '.hooks.Stop |= map(select([.hooks[].command] | any(test("dashboard-refresh")) | not))
    | .hooks.Stop += [{"hooks":[{"type":"command","command":"bash ./tools/my-stop.sh"}]}]
    | .hooks.PreToolUse += [{"matcher":"Read","hooks":[{"type":"command","command":"bash ./tools/my-own-hook.sh"}]}]
    | .env = {"FOO":"1"}
    | .permissions = {"allow":["Bash(ls)"]}' "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "Stop: dashboard-refresh.sh" "$T/inst.out"; then ok "older file: exit 0, reports the entry it added"; else bad "older file: exit 0, reports the entry it added"; fi
check "older file: dashboard-refresh.sh added exactly once" [ "$(count_cmd Stop dashboard-refresh.sh)" = 1 ]
FIRST_STOP="$(jq -r '.hooks.Stop[0].hooks[0].command | contains("stop-gate.sh")' "$SET" | tr -d '\r')"
if [ "$(count_cmd Stop stop-gate.sh)" = 1 ] && [ "$FIRST_STOP" = true ]; then ok "older file: stop-gate.sh still exactly once, and still first under Stop"; else bad "older file: stop-gate.sh still exactly once, and still first under Stop"; fi
if [ "$(count_cmd Stop my-stop.sh)" = 1 ] && [ "$(count_cmd PreToolUse my-own-hook.sh)" = 1 ]; then ok "older file: the project's own Stop and PreToolUse hooks are kept"; else bad "older file: the project's own Stop and PreToolUse hooks are kept"; fi
check "older file: the project's env and permissions are kept" \
  [ "$(jq -c '[.env, .permissions]' "$SET" | tr -d '\r')" = '[{"FOO":"1"},{"allow":["Bash(ls)"]}]' ]
check "older file: every other framework hook still exactly once" \
  [ "$(count_cmd SessionStart session-start.sh)$(count_cmd PreToolUse block-escape-hatches.sh)$(count_cmd PreToolUse block-inline-suppression.sh)$(count_cmd PostToolUse post-edit-lint.sh)" = 1111 ]
if grep -q "^  Hooks: " "$T/inst.out"; then bad "older file: the report lists only what was added or found, not a fixed list"; else ok "older file: the report lists only what was added or found, not a fixed list"; fi
cp "$SET" "$T/merged.json"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "every IA Engineering hook entry is present exactly" "$T/inst.out" && cmp -s "$SET" "$T/merged.json"; then ok "re-run after a merge: exit 0, nothing added, byte-identical"; else bad "re-run after a merge: exit 0, nothing added, byte-identical"; fi
if [ ! -s "$T/inst.err" ]; then ok "re-run after a merge: no near-miss warning"; else bad "re-run after a merge: no near-miss warning" "$(head -c 300 "$T/inst.err")"; fi

# PRESENCE IS EXACT (PR #239 security review, F1). The template commands:
TPL_ESC="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[0].command' "$T/rendered.json" | tr -d '\r')"
TPL_SUP="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit") | .hooks[0].command' "$T/rendered.json" | tr -d '\r')"
TPL_GATE="$(jq -r '.hooks.Stop[0].hooks[0].command' "$T/rendered.json" | tr -d '\r')"
TPL_DASH="$(jq -r '.hooks.Stop[1].hooks[0].command' "$T/rendered.json" | tr -d '\r')"
# exact_count <event> <matcher, empty for none> <command> — groups running it exactly.
exact_count() {
  jq -r --arg ev "$1" --arg m "$2" --arg c "$3" \
    '[.hooks[$ev][]? | select((.matcher // "") == $m) | .hooks[]? | select(.command == $c)] | length' "$SET" | tr -d '\r'
}

# Row 1: the escape-hatch guard under a matcher that never fires.
jq --arg c "$TPL_ESC" '.hooks.PreToolUse |= map(select(.matcher != "Bash"))
    | .hooks.PreToolUse += [{"matcher":"NoSuchTool","hooks":[{"type":"command","command":$c}]}]' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(exact_count PreToolUse Bash "$TPL_ESC")" = 1 ] && grep -q 'added: *PreToolUse \[Bash\]: block-escape-hatches.sh' "$T/inst.out"; then ok "F1: a guard under a matcher that never fires — the real Bash entry is added and reported"; else bad "F1: a guard under a matcher that never fires — the real Bash entry is added and reported" "rc=$INST_RC $(cat "$T/inst.out")"; fi
if grep -q 'PreToolUse \[NoSuchTool\]: .*block-escape-hatches.sh' "$T/inst.err"; then ok "F1: ... and the NoSuchTool entry is reported as a near miss"; else bad "F1: ... and the NoSuchTool entry is reported as a near miss"; fi

# Row 2: the guard neutered with "|| true" (its exit 2 can block nothing).
jq --arg c "$TPL_ESC" '.hooks.PreToolUse |= map(if .matcher == "Bash" then .hooks[0].command = ($c + " || true") else . end)' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(exact_count PreToolUse Bash "$TPL_ESC")" = 1 ] && [ "$(exact_count PreToolUse Bash "$TPL_ESC || true")" = 1 ]; then ok "F1: a guard neutered with || true — the real entry is added beside it, the project's kept"; else bad "F1: a guard neutered with || true — the real entry is added beside it, the project's kept"; fi
if grep -q 'block-escape-hatches.sh" || true' "$T/inst.err"; then ok "F1: ... and the neutered command is reported as a near miss"; else bad "F1: ... and the neutered command is reported as a near miss"; fi

# Row 3: decoys that only name the scripts.
jq '.hooks.PreToolUse = [{"matcher":"Bash","hooks":[{"type":"command","command":"echo hooks/block-escape-hatches.sh hooks/block-inline-suppression.sh"}]}]
    | .hooks.Stop = [{"hooks":[{"type":"command","command":"true # hooks/stop-gate.sh hooks/dashboard-refresh.sh"}]}]' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(exact_count PreToolUse Bash "$TPL_ESC")" = 1 ] && [ "$(exact_count PreToolUse 'Edit|Write|MultiEdit' "$TPL_SUP")" = 1 ] \
    && [ "$(exact_count Stop '' "$TPL_GATE")" = 1 ] && [ "$(exact_count Stop '' "$TPL_DASH")" = 1 ]; then
  ok "F1: echo / true # decoys naming the scripts — all four real entries are added"
else
  bad "F1: echo / true # decoys naming the scripts — all four real entries are added" "$(cat "$T/inst.out")"
fi
if [ "$(grep -c '^ *added: ' "$T/inst.out")" -eq 4 ] && grep -q 'echo hooks/block-escape-hatches.sh' "$T/inst.err" && grep -q 'true # hooks/stop-gate.sh' "$T/inst.err"; then ok "F1: ... reported as four additions, the decoys as near misses"; else bad "F1: ... reported as four additions, the decoys as near misses"; fi

# Row 4 (PR #239 code review): the project's own script of the same name
# under another hooks/ folder is not the framework's stop gate.
jq '.hooks.Stop = [{"hooks":[{"type":"command","command":"bash ./scripts/hooks/stop-gate.sh"}]}]' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(exact_count Stop '' "$TPL_GATE")" = 1 ] && [ "$(exact_count Stop '' "bash ./scripts/hooks/stop-gate.sh")" = 1 ]; then ok "a project's own scripts/hooks/stop-gate.sh: the framework stop gate is still added, the project's kept"; else bad "a project's own scripts/hooks/stop-gate.sh: the framework stop gate is still added, the project's kept" "$(cat "$T/inst.out")"; fi
if grep -q 'scripts/hooks/stop-gate.sh' "$T/inst.err"; then ok "a project's own scripts/hooks/stop-gate.sh: reported as a near miss"; else bad "a project's own scripts/hooks/stop-gate.sh: reported as a near miss"; fi

# The project directory's spelling alone does not make a different entry.
jq '.hooks.Stop |= map(.hooks |= map(.command |= gsub("[$]CLAUDE_PROJECT_DIR"; "${CLAUDE_PROJECT_DIR}")))' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "present exactly" "$T/inst.out" && [ ! -s "$T/inst.err" ] && [ "$(count_cmd Stop stop-gate.sh)" = 1 ]; then ok "\${CLAUDE_PROJECT_DIR} for \$CLAUDE_PROJECT_DIR: still the same entry, nothing added, no warning"; else bad "\${CLAUDE_PROJECT_DIR} for \$CLAUDE_PROJECT_DIR: still the same entry, nothing added, no warning"; fi

# EVERY FIELD OF THE ENTRY, NOT ITS COMMAND ALONE (issue #241, L1).
# entry_count <event> <matcher, empty for none> <entry as JSON> — entries equal to it.
entry_count() {
  jq -r --arg ev "$1" --arg m "$2" --argjson e "$3" \
    '[.hooks[$ev][]? | select((.matcher // "") == $m) | .hooks[]? | select(. == $e)] | length' "$SET" | tr -d '\r'
}
E_ESC="$(jq -c '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[0]' "$T/rendered.json" | tr -d '\r')"
E_GATE="$(jq -c '.hooks.Stop[0].hooks[0]' "$T/rendered.json" | tr -d '\r')"
E_DASH="$(jq -c '.hooks.Stop[1].hooks[0]' "$T/rendered.json" | tr -d '\r')"

# Row 5: the escape-hatch guard, its exact command, a one-second timeout.
jq '.hooks.PreToolUse |= map(if .matcher == "Bash" then .hooks[0].timeout = 1 else . end)' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(entry_count PreToolUse Bash "$E_ESC")" = 1 ] \
    && [ "$(entry_count PreToolUse Bash "$(jq -c '.timeout = 1' <<< "$E_ESC" | tr -d '\r')")" = 1 ] \
    && grep -q 'added: *PreToolUse \[Bash\]: block-escape-hatches.sh' "$T/inst.out"; then
  ok "#241 L1: the exact guard command with \"timeout\": 1 — the real entry is added and reported, the project's kept"
else
  bad "#241 L1: the exact guard command with \"timeout\": 1 — the real entry is added and reported, the project's kept" "rc=$INST_RC $(cat "$T/inst.out")"
fi
if grep -q 'PreToolUse \[Bash\]: .*block-escape-hatches.sh".*differs in: timeout)$' "$T/inst.err"; then ok "#241 L1: ... and it is reported as a near miss naming the field that differs (timeout)"; else bad "#241 L1: ... and it is reported as a near miss naming the field that differs (timeout)" "$(cat "$T/inst.err")"; fi
cp "$SET" "$T/l1.json"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "present exactly" "$T/inst.out" && cmp -s "$SET" "$T/l1.json" && grep -q 'differs in: timeout' "$T/inst.err"; then ok "#241 L1: re-run — nothing added, byte-identical, the near miss still reported"; else bad "#241 L1: re-run — nothing added, byte-identical, the near miss still reported"; fi

# Row 6: a field missing (the refresh entry without its timeout) and a field
# added (the stop gate with a statusMessage) — "any other field".
jq '.hooks.Stop[1].hooks[0] |= del(.timeout) | .hooks.Stop[0].hooks[0].statusMessage = "checking"' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(entry_count Stop '' "$E_GATE")" = 1 ] && [ "$(entry_count Stop '' "$E_DASH")" = 1 ] \
    && [ "$(grep -c '^ *added: ' "$T/inst.out")" -eq 2 ]; then
  ok "#241 L1: a timeout missing, a statusMessage added — both real entries are added, two additions reported"
else
  bad "#241 L1: a timeout missing, a statusMessage added — both real entries are added, two additions reported" "$(cat "$T/inst.out")"
fi
if grep -q 'Stop: .*dashboard-refresh.sh.*differs in: timeout)$' "$T/inst.err" && grep -q 'Stop: .*stop-gate.sh".*differs in: statusMessage)$' "$T/inst.err"; then ok "#241 L1: ... each reported as a near miss naming its field"; else bad "#241 L1: ... each reported as a near miss naming its field" "$(cat "$T/inst.err")"; fi

# Row 7: every field equal, keys in another order — the same entry.
jq '.hooks |= map_values(map(.hooks |= map(to_entries | reverse | from_entries)))' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
cp "$SET" "$T/reordered.json"
if [ "$(jq -c '.hooks.Stop[1].hooks[0] | keys_unsorted' "$SET" | tr -d '\r')" = '["timeout","command","type"]' ]; then
  inst
  if [ "$INST_RC" -eq 0 ] && grep -q "present exactly" "$T/inst.out" && [ ! -s "$T/inst.err" ] && cmp -s "$SET" "$T/reordered.json"; then ok "#241 L1: the same fields in another key order — present, nothing added, no warning"; else bad "#241 L1: the same fields in another key order — present, nothing added, no warning" "$(cat "$T/inst.out" "$T/inst.err")"; fi
else
  bad "#241 L1: the same fields in another key order" "the fixture did not reorder the keys"
fi

# HOOKS SWITCHED OFF ARE SAID (issue #241, L2).
DISABLED_SAID='"disableAllHooks": true is set in:'
jq '.disableAllHooks = true | .hooks.Stop |= map(select([.hooks[].command] | any(test("dashboard-refresh")) | not))' \
  "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && grep -qF "$DISABLED_SAID" "$T/inst.err" && grep -q '^    \.claude/settings\.json$' "$T/inst.err" \
    && grep -q 'WARNING: every hook is switched off ("disableAllHooks": true in \.claude/settings\.json)' "$T/inst.out"; then
  ok "#241 L2: disableAllHooks true in settings.json — named on stderr and in the report"
else
  bad "#241 L2: disableAllHooks true in settings.json — named on stderr and in the report" "$(cat "$T/inst.out" "$T/inst.err")"
fi
if [ "$(jq -r '.disableAllHooks' "$SET" | tr -d '\r')" = true ] && [ "$(entry_count Stop '' "$E_DASH")" = 1 ]; then ok "#241 L2: ... the setting is kept as the project's, and the merge still adds the missing entry"; else bad "#241 L2: ... the setting is kept as the project's, and the merge still adds the missing entry"; fi
cp "$T/rendered.json" "$SET"
printf '{"disableAllHooks": true}\n' > "$IP/.claude/settings.local.json"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "already current" "$T/inst.out" && grep -q '^    \.claude/settings\.local\.json$' "$T/inst.err" \
    && grep -q 'WARNING: every hook is switched off ("disableAllHooks": true in \.claude/settings\.local\.json)' "$T/inst.out"; then
  ok "#241 L2: disableAllHooks true in settings.local.json, settings.json current — still said"
else
  bad "#241 L2: disableAllHooks true in settings.local.json, settings.json current — still said" "$(cat "$T/inst.out" "$T/inst.err")"
fi
printf '{"disableAllHooks": false}\n' > "$IP/.claude/settings.local.json"
inst
if [ "$INST_RC" -eq 0 ] && [ ! -s "$T/inst.err" ] && ! grep -q WARNING "$T/inst.out"; then ok "#241 L2: disableAllHooks false — no warning"; else bad "#241 L2: disableAllHooks false — no warning" "$(cat "$T/inst.err")"; fi
rm -f "$IP/.claude/settings.local.json"
# A refused merge (not JSON jq can read) still says it, read without jq's help.
printf '{ "disableAllHooks" : true, "hooks": { "Stop": [ }' > "$SET"
inst
if [ "$INST_RC" -eq 1 ] && grep -qF "$DISABLED_SAID" "$T/inst.err"; then ok "#241 L2: a settings.json jq cannot read — refused, and the switch is still named"; else bad "#241 L2: a settings.json jq cannot read — refused, and the switch is still named" "rc=$INST_RC $(cat "$T/inst.err")"; fi

# A symbolic link is refused, not replaced by a file. MSYS=winsymlinks:sys
# makes a link Git Bash reads as one on Windows; elsewhere it is ignored.
jq '.hooks.Stop = []' "$T/rendered.json" | tr -d '\r' > "$T/link-target.json"
cp "$T/link-target.json" "$T/link-target.before"
rm -f "$SET"
MSYS=winsymlinks:sys ln -s "$T/link-target.json" "$SET" 2>/dev/null
if [ -L "$SET" ]; then
  inst
  if [ "$INST_RC" -eq 1 ] && [ -L "$SET" ] && cmp -s "$T/link-target.json" "$T/link-target.before" && grep -q "symbolic link" "$T/inst.err"; then ok "a symlinked settings.json: refused, the link and its target untouched"; else bad "a symlinked settings.json: refused, the link and its target untouched" "rc=$INST_RC"; fi
  rm -f "$SET"
else
  bad "a symlinked settings.json: refused" "could not create a symbolic link here to test it"
fi

printf '{ "hooks": { "Stop": [ }' > "$SET"; cp "$SET" "$T/broken.json"
inst
if [ "$INST_RC" -eq 1 ] && cmp -s "$SET" "$T/broken.json"; then ok "malformed settings.json: exit 1, file untouched"; else bad "malformed settings.json: exit 1, file untouched"; fi
printf '{"hooks": []}\n' > "$SET"; cp "$SET" "$T/broken.json"
inst
if [ "$INST_RC" -eq 1 ] && cmp -s "$SET" "$T/broken.json"; then ok "'hooks' not an object: exit 1, file untouched"; else bad "'hooks' not an object: exit 1, file untouched"; fi
check "a refused merge leaves no temporary file behind" [ -z "$(find "$IP/.claude" -name '*.iaeng-merge.*' 2>/dev/null)" ]

# =============================================================================
echo "== install-skills.sh and /dashboard"

SP="$T/skills-project"
SFW="$SP/ia-engineering/Adapters/ai-runtimes/claude-code"
mkdir -p "$SFW" "$SP/ia-engineering/Adapters/scripts"
cp -p "$CC/install-skills.sh" "$SFW/"
cp -R "$CC/skills" "$SFW/"
LCALLS="$T/launcher-calls"
cat > "$SP/ia-engineering/Adapters/scripts/usage-dashboard.sh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_LAUNCHER_CALLS"
echo "${FAKE_SAY:-Usage dashboard opened as it is; refreshing it in the background (log: .ia-engineering/usage/refresh.log).}"
[ -z "${FAKE_NOTE:-}" ] || echo "$FAKE_NOTE" >&2
[ "${FAKE_RC:-0}" -eq 0 ] || { echo "fake usage-dashboard: boom, the reason" >&2; exit "$FAKE_RC"; }
exit 0
FAKE
export FAKE_LAUNCHER_CALLS="$LCALLS"

( cd "$SP" && bash "$SFW/install-skills.sh" ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
check "adopter: install-skills.sh exits 0" [ "$rc" -eq 0 ]
if [ -f "$SP/.claude/skills/dashboard/SKILL.md" ] && [ -f "$SP/.claude/skills/dashboard/open-dashboard.sh" ] && [ -f "$SP/.claude/skills/create-project/SKILL.md" ]; then ok "adopter: /dashboard and /create-project installed"; else bad "adopter: /dashboard and /create-project installed"; fi
SKILL_RULE='/.claude/skills/** text eol=lf'
if [ "$(rule_count "$SP/.gitattributes" "$SKILL_RULE")" = 1 ] && grep -qF "+ .gitattributes: $SKILL_RULE" "$T/sk.out"; then ok "#242: adopter — .gitattributes gets the .claude/skills/** LF rule, reported"; else bad "#242: adopter — .gitattributes gets the .claude/skills/** LF rule, reported" "$(cat "$SP/.gitattributes" 2>/dev/null)"; fi
cp "$SP/.gitattributes" "$T/ga.before" 2>/dev/null
( cd "$SP" && bash "$SFW/install-skills.sh" ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(grep -c "^  = .* already current$" "$T/sk.out")" -eq 2 ] && [ ! -s "$T/sk.err" ]; then ok "adopter: re-run exits 0, says 'already current', warns nothing"; else bad "adopter: re-run exits 0, says 'already current', warns nothing"; fi
if cmp -s "$SP/.gitattributes" "$T/ga.before" && ! grep -q gitattributes "$T/sk.out"; then ok "#242: adopter re-run — .gitattributes byte-identical, nothing said about it"; else bad "#242: adopter re-run — .gitattributes byte-identical, nothing said about it"; fi
SL="$T/skills-list"
mkdir -p "$SL"
( cd "$SL" && bash "$SFW/install-skills.sh" --list ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$SL/.gitattributes" ] && [ ! -e "$SL/.claude" ]; then ok "#242: --list writes nothing, no .gitattributes either"; else bad "#242: --list writes nothing, no .gitattributes either"; fi
echo "edited by the project" >> "$SP/.claude/skills/dashboard/SKILL.md"
( cd "$SP" && bash "$SFW/install-skills.sh" ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
if [ "$rc" -eq 0 ] && grep -q "edited by the project" "$SP/.claude/skills/dashboard/SKILL.md" && grep -q "left untouched" "$T/sk.err"; then ok "adopter: an edited skill is left untouched without --force"; else bad "adopter: an edited skill is left untouched without --force"; fi
( cd "$SP" && bash "$SFW/install-skills.sh" --force ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
if [ "$rc" -eq 0 ] && diff -r "$CC/skills/dashboard" "$SP/.claude/skills/dashboard" >/dev/null; then ok "adopter: --force restores it"; else bad "adopter: --force restores it"; fi

FC="$T/framework-checkout"
mkdir -p "$FC/Core" "$FC/Adapters/ai-runtimes/claude-code"
: > "$FC/Core/AI_MANIFEST.md"
cp -p "$CC/install-skills.sh" "$FC/Adapters/ai-runtimes/claude-code/"
cp -R "$CC/skills" "$FC/Adapters/ai-runtimes/claude-code/"
( cd "$FC" && bash Adapters/ai-runtimes/claude-code/install-skills.sh ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$FC/.claude/skills/dashboard/SKILL.md" ] && [ ! -e "$FC/.claude/skills/create-project" ]; then ok "framework checkout: exit 0, /dashboard installed, /create-project not"; else bad "framework checkout: exit 0, /dashboard installed, /create-project not"; fi

if [ -d "$FRAMEWORK/.claude/skills/dashboard" ]; then
  check "this repository's committed .claude/skills/dashboard is identical to its source" \
    diff -r "$CC/skills/dashboard" "$FRAMEWORK/.claude/skills/dashboard"
else
  bad "this repository's committed .claude/skills/dashboard exists" "run install-skills.sh from the framework root"
fi

# SKILL.md: frontmatter, and the one command it runs is the one it permits.
SK="$CC/skills/dashboard/SKILL.md"
FM="$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}' "$SK")"
if [ "$(head -n 1 "$SK")" = "---" ] && [ "$(grep -c "^---$" "$SK")" -ge 2 ]; then ok "SKILL.md: opens with a frontmatter block that closes"; else bad "SKILL.md: opens with a frontmatter block that closes"; fi
check "SKILL.md: name is dashboard (the /dashboard command)" grep -qx 'name: dashboard' <<< "$FM"
check "SKILL.md: has a non-empty description" grep -qE '^description: .{20,}' <<< "$FM"
check "SKILL.md: user-invoked only" grep -qx 'disable-model-invocation: true' <<< "$FM"
ALLOWED="$(sed -n 's/^allowed-tools: Bash(\(.*\))$/\1/p' <<< "$FM")"
RUNS="$(awk '/^```$/{f=!f; next} f{print; exit}' "$SK")"
if [ -n "$ALLOWED" ] && [ "$ALLOWED" = "$RUNS" ]; then ok "SKILL.md: allowed-tools permits exactly the command it tells the model to run"; else bad "SKILL.md: allowed-tools permits exactly the command it tells the model to run"; fi
if [ "$RUNS" = "bash .claude/skills/dashboard/open-dashboard.sh" ] && [ -f "$CC/skills/dashboard/open-dashboard.sh" ]; then ok "SKILL.md: that command runs the launcher installed beside it"; else bad "SKILL.md: that command runs the launcher installed beside it"; fi
check "launcher: valid bash" bash -n "$CC/skills/dashboard/open-dashboard.sh"
# Prompt Engineer review of PR #239: run as written, a timeout and what to do
# when it expires, the moved-directory case, and instructions only.
AS_WRITTEN="Run it exactly as written: no \`cd\`, no prefix, no redirection."
check "SKILL.md: says to run the command as written, with no cd or prefix" grep -qF "$AS_WRITTEN" "$SK"
check "SKILL.md: sets a 600000 ms timeout and says not to run it again" grep -qF 'Set the Bash tool'"'"'s timeout to 600000 ms. If it still times out, say so and stop; do not run it again.' "$SK"
check "SKILL.md: says what to do when the file is not found (directory moved)" grep -qF 'the session'"'"'s working directory has moved off the project root, and stop.' "$SK"
if grep -qi 'why this file lives' "$SK"; then bad "SKILL.md: the body is instructions only (maintainer notes live in hooks/README.md)"; else ok "SKILL.md: the body is instructions only (maintainer notes live in hooks/README.md)"; fi

# Acceptance from that review: cd Adapters, then /dashboard. The exact
# command, from a subdirectory, fails as "not found" and starts nothing,
# which is the case SKILL.md tells the model to explain and stop on.
mkdir -p "$SP/Adapters"
rm -f "$LCALLS"
out="$(cd "$SP/Adapters" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && bash .claude/skills/dashboard/open-dashboard.sh 2>&1)"; rc=$?
case "$rc:$out" in
  127:*"No such file"*) if [ ! -e "$LCALLS" ]; then ok "acceptance: from a subdirectory the exact command fails as not found and opens nothing"; else bad "acceptance: from a subdirectory the exact command opens nothing"; fi ;;
  *) bad "acceptance: from a subdirectory the exact command fails as not found" "rc=$rc got: $out" ;;
esac

# A root-level Adapters/scripts/ of an adopter's own never shadows the pinned
# framework's script (PR #239 security review, info).
mkdir -p "$SP/Adapters/scripts"
cat > "$SP/Adapters/scripts/usage-dashboard.sh" <<'FAKE'
#!/usr/bin/env bash
echo "shadow" >> "$FAKE_LAUNCHER_CALLS"
FAKE
rm -f "$LCALLS"
out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && bash "$SP/.claude/skills/dashboard/open-dashboard.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$LCALLS" 2>/dev/null)" = "--open --no-wait --project-dir $SP" ]; then ok "launcher: the pinned ia-engineering/ script is used, not a root-level Adapters/scripts/ copy"; else bad "launcher: the pinned ia-engineering/ script is used, not a root-level Adapters/scripts/ copy" "calls: $(cat "$LCALLS" 2>/dev/null)"; fi
rm -rf "$SP/Adapters"

# The launcher, installed, run from elsewhere: the project is found from its place.
LAUNCH="$SP/.claude/skills/dashboard/open-dashboard.sh"
rm -f "$LCALLS"
out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && bash "$LAUNCH" 2>&1)"; rc=$?
LINES="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
if [ "$rc" -eq 0 ] && [ "$LINES" -eq 1 ]; then ok "launcher: exit 0 and exactly one line"; else bad "launcher: exit 0 and exactly one line"; fi
case "$out" in
  *dashboard.html*"keeps itself fresh"*) ok "launcher: the line names the page and says it keeps itself fresh" ;;
  *) bad "launcher: the line names the page and says it keeps itself fresh" "got: $out" ;;
esac
check "launcher: calls --open --no-wait for the project it is installed in, whatever the current directory" \
  [ "$(cat "$LCALLS" 2>/dev/null)" = "--open --no-wait --project-dir $SP" ]
out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && IAENG_USAGE_AUTO_REFRESH=off bash "$LAUNCH" 2>&1)"
case "$out" in
  *"is off"*) ok "launcher: says when the automatic refresh is off" ;;
  *) bad "launcher: says when the automatic refresh is off" "got: $out" ;;
esac

# The line says what happened (PR #239 code review, QA). This project has no
# .claude/settings.json yet: the Stop hook is not credited.
lrun() { out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK IAENG_USAGE_AUTO_REFRESH && bash "$LAUNCH" 2>&1)"; rc=$?; }
lrun
case "$out" in
  *"a refresh is running now"*"Stop hook is not installed"*) ok "launcher: a warm page — says a refresh is running; no Stop hook in settings, says it is not installed" ;;
  *) bad "launcher: a warm page — says a refresh is running; no Stop hook in settings, says it is not installed" "got: $out" ;;
esac
mkdir -p "$SP/.claude"
jq -n --arg c "bash ./ia-engineering/Adapters/ai-runtimes/claude-code/hooks/dashboard-refresh.sh" \
  '{hooks: {Stop: [{hooks: [{type: "command", command: $c}]}]}}' > "$SP/.claude/settings.json"
lrun
case "$out" in
  *"after every turn by the Stop hook"*) ok "launcher: the Stop hook registered in settings — credited" ;;
  *) bad "launcher: the Stop hook registered in settings — credited" "got: $out" ;;
esac
out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && FAKE_SAY="Usage dashboard written: x" bash "$LAUNCH" 2>&1)"
case "$out" in
  *"a refresh is running now"*) bad "launcher: a cold page built in the foreground — no claim of a running refresh" "got: $out" ;;
  *"built just now"*) ok "launcher: a cold page built in the foreground — says built just now, no claim of a running refresh" ;;
  *) bad "launcher: a cold page built in the foreground — says built just now" "got: $out" ;;
esac
out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && FAKE_NOTE="usage-dashboard: could not open a browser; open x yourself." bash "$LAUNCH" 2>&1)"; rc=$?
case "$rc:$out" in
  0:*"no browser could be opened; open it yourself"*) if [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 1 ]; then ok "launcher: the opener failed — says so in its one line instead of 'opened'"; else bad "launcher: the opener failed — one line" "got: $out"; fi ;;
  *) bad "launcher: the opener failed — says so instead of 'opened'" "rc=$rc got: $out" ;;
esac
out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && FAKE_RC=1 bash "$LAUNCH" 2>&1)"; rc=$?
case "$rc:$out" in
  1:*"not opened"*"boom, the reason"*) ok "launcher: a failing script — exit 1, says it did not open and why" ;;
  *) bad "launcher: a failing script — exit 1, says it did not open and why" "rc=$rc got: $out" ;;
esac
mv "$SP/ia-engineering/Adapters/scripts" "$SP/ia-engineering/Adapters/scripts.gone"
out="$(cd "$T" && unset CLAUDE_PROJECT_DIR IAENG_FRAMEWORK && bash "$LAUNCH" 2>&1)"; rc=$?
case "$rc:$out" in
  1:*"not opened"*) ok "launcher: no dashboard script in the framework — exit 1, says so" ;;
  *) bad "launcher: no dashboard script in the framework — exit 1, says so" "rc=$rc got: $out" ;;
esac

# =============================================================================
echo "== line endings in a clone made with core.autocrlf=true (issue #242)"

# An adopter installs both, commits, and is cloned with core.autocrlf=true
# set explicitly, so the run means the same on Linux as on Windows. A file no
# rule covers is the control: it must come out CRLF, or this clone would
# prove nothing about the rules.
CR="$T/crlf-src"
new_repo "$CR" || { echo "dashboard.sh: git init failed" >&2; exit 2; }
git -C "$CR" config core.autocrlf true
CFW="$CR/ia-engineering/Adapters/ai-runtimes/claude-code"
mkdir -p "$CFW/hooks"
cp -p "$CC/install-hooks.sh" "$CC/install-skills.sh" "$CC/settings.example.json" "$CFW/"
cp -p "$HOOKS"/*.sh "$CFW/hooks/"
cp -R "$CC/skills" "$CFW/"
chmod +x "$CFW"/hooks/*.sh
printf 'ia-engineering/\n' >> "$CR/.git/info/exclude"
printf 'a line\nanother line\n' > "$CR/notes.txt"
( cd "$CR" && bash "$CFW/install-hooks.sh" && bash "$CFW/install-skills.sh" ) > "$T/cr.out" 2>&1; rc=$?
check "#242 clone: both installers exit 0 in a repository with core.autocrlf=true" [ "$rc" -eq 0 ]
if ! { git -C "$CR" add -A 2>/dev/null \
       && git -C "$CR" -c user.name=t -c user.email=t@example.invalid commit -q -m install 2>/dev/null; }; then
  echo "dashboard.sh: could not commit the crlf fixture" >&2
  exit 2
fi
CL="$T/crlf-clone"
git clone -q -c core.autocrlf=true "$CR" "$CL" 2>/dev/null || { echo "dashboard.sh: git clone failed" >&2; exit 2; }
# Counted with tr: Git for Windows' grep does not match a carriage return.
has_cr() { [ "$(tr -cd '\r' < "$1" | wc -c | tr -d ' ')" -gt 0 ]; }
if has_cr "$CL/notes.txt"; then ok "#242 clone: control — a file no rule covers is checked out CRLF"; else bad "#242 clone: control — a file no rule covers is checked out CRLF" "the clone did not convert; the checks below would prove nothing"; fi
for f in .claude/settings.json .claude/skills/dashboard/open-dashboard.sh .claude/skills/dashboard/SKILL.md .claude/skills/create-project/SKILL.md; do
  if [ -f "$CL/$f" ] && ! has_cr "$CL/$f"; then ok "#242 clone: $f checked out LF"; else bad "#242 clone: $f checked out LF"; fi
done
ATTRS="$(git -C "$CL" check-attr eol -- .claude/settings.json .claude/skills/dashboard/open-dashboard.sh | tr -d '\r')"
if [ "$(grep -c ': eol: lf$' <<< "$ATTRS")" -eq 2 ]; then ok "#242 clone: git reports eol=lf for settings.json and the launcher"; else bad "#242 clone: git reports eol=lf for settings.json and the launcher" "$ATTRS"; fi

# =============================================================================
echo
[ -z "${IAENG_HOOK_TESTS_COUNTS:-}" ] || printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
if [ "$FAILED" -eq 0 ]; then
  printf 'Dashboard result: %s checks passed.\n' "$TOTAL"
  exit 0
fi
printf 'Dashboard result: %s of %s checks failed.\n' "$FAILED" "$TOTAL"
exit 1
