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
#     and never duplicates on a re-run or beside a hand-merged entry.
#   - install-skills.sh installs /dashboard, quietly on a re-run, and in the
#     framework checkout installs it alone; SKILL.md is well formed and
#     names the command its allowed-tools permits; the launcher prints one
#     line and calls --open --no-wait for the project it is installed in.
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

inst --print
if [ "$INST_RC" -eq 0 ] && [ ! -e "$SET" ]; then ok "--print: exit 0 and writes nothing"; else bad "--print: exit 0 and writes nothing"; fi
cp "$T/inst.out" "$T/rendered.json"

inst
if [ "$INST_RC" -eq 0 ] && cmp -s "$SET" "$T/rendered.json"; then ok "fresh project: settings.json written, equal to --print"; else bad "fresh project: settings.json written, equal to --print"; fi
cp "$SET" "$T/before.json"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "already current" "$T/inst.out" && cmp -s "$SET" "$T/before.json"; then ok "re-run on a current file: exit 0, 'already current', byte-identical"; else bad "re-run on a current file: exit 0, 'already current', byte-identical"; fi

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
cp "$SET" "$T/merged.json"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "already has every IA Engineering hook" "$T/inst.out" && cmp -s "$SET" "$T/merged.json"; then ok "re-run after a merge: exit 0, nothing added, byte-identical"; else bad "re-run after a merge: exit 0, nothing added, byte-identical"; fi

# Hand-merged with another spelling of the path: not added a second time.
jq '.hooks.Stop |= map(if ([.hooks[].command] | any(test("dashboard-refresh"))) then .hooks[0].command = "bash ./ia-engineering/Adapters/ai-runtimes/claude-code/hooks/dashboard-refresh.sh" else . end)' \
  "$T/merged.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && grep -q "already has every IA Engineering hook" "$T/inst.out" && [ "$(count_cmd Stop dashboard-refresh.sh)" = 1 ]; then ok "hand-merged entry spelled differently: recognised, not duplicated"; else bad "hand-merged entry spelled differently: recognised, not duplicated"; fi

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
echo "fake usage-dashboard: opened"
[ "${FAKE_RC:-0}" -eq 0 ] || { echo "fake usage-dashboard: boom, the reason" >&2; exit "$FAKE_RC"; }
exit 0
FAKE
export FAKE_LAUNCHER_CALLS="$LCALLS"

( cd "$SP" && bash "$SFW/install-skills.sh" ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
check "adopter: install-skills.sh exits 0" [ "$rc" -eq 0 ]
if [ -f "$SP/.claude/skills/dashboard/SKILL.md" ] && [ -f "$SP/.claude/skills/dashboard/open-dashboard.sh" ] && [ -f "$SP/.claude/skills/create-project/SKILL.md" ]; then ok "adopter: /dashboard and /create-project installed"; else bad "adopter: /dashboard and /create-project installed"; fi
( cd "$SP" && bash "$SFW/install-skills.sh" ) > "$T/sk.out" 2> "$T/sk.err"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(grep -c "^  = .* already current$" "$T/sk.out")" -eq 2 ] && [ ! -s "$T/sk.err" ]; then ok "adopter: re-run exits 0, says 'already current', warns nothing"; else bad "adopter: re-run exits 0, says 'already current', warns nothing"; fi
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
echo
[ -z "${IAENG_HOOK_TESTS_COUNTS:-}" ] || printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
if [ "$FAILED" -eq 0 ]; then
  printf 'Dashboard result: %s checks passed.\n' "$TOTAL"
  exit 0
fi
printf 'Dashboard result: %s of %s checks failed.\n' "$FAILED" "$TOTAL"
exit 1
