#!/usr/bin/env bash
# IA Engineering — hook tests: session-start.sh within a budget, and what it
# reruns on /clear and compaction (WU-IAENG-452, issues #515 and #486)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/session-start-budget.sh [--verbose]
#
# What is proved, and how. Every project here is a throwaway one under
# mktemp -d, its framework a stand-in (FW below) whose generate-agents.sh and
# check-framework-drift.sh only record that they ran and print what the hook
# reads. The hook itself, its lib.sh and context-alert.sh are the real ones,
# copied, so a test can change their time without touching the repository.
# Each run has its own XDG_CACHE_HOME: nothing is written in the user's cache.
#
#   - The read-first part (the pointers, SESSION_STATE's header, Next Step,
#     Blocked On and freshness warnings, the parallel-agent cap) and the
#     repository state are printed on clear and compact exactly as on startup
#     (#304, AC2: what a /clear or a compaction needs back).
#   - On clear and compact the generator is not run while the block the last
#     full run kept is valid, and that block is printed as the run printed it.
#     Each input of the generator, changed, sends the next clear back to it:
#     the tier map created, edited and removed, an agent added, edited and
#     removed, either roster, the generator itself, this hook, and the
#     framework's commit. A kept file that is not whole, is another
#     project's, is a link, or could be written by others is not used.
#   - The drift check and the context-alert threshold check run on startup
#     and resume, and not on clear or compact.
#   - A source other than clear or compact, none, or one that appears only
#     inside another field's value runs every check.
#   - The parallel-agent cap is one line, its numbers read from
#     Core/ORCHESTRATION.md: the real one, and fixtures where a clause or the
#     number is gone.
#   - The process budget, counted with recording stand-ins first on PATH.
#   - install-hooks.sh gives an existing install the SessionStart timeout in
#     place, from either earlier entry, and leaves a project's own entry as it
#     is (a throwaway project with an existing .claude/settings.json).
#
# Exit 0 when every check passes, 1 when any fails, 2 when the environment is
# unusable. With IAENG_HOOK_TESTS_COUNTS set to a file, "<total> <failed>" is
# written there for run.sh. A check that cannot apply on this platform is
# printed as n/a with its reason, and is not counted as passed.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "session-start-budget.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
CC="$(cd "$HOOKS/.." && pwd)"
FRAMEWORK="$(cd "$CC/../../.." && pwd)"

for dep in jq git; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "session-start-budget.sh: $dep is required and is not installed. Reported rather than skipped." >&2
    exit 2
  }
done

FAILED=0
TOTAL=0
ok() { TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0; }
bad() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '         %s\n' "$2"; return 0; }
na() { printf '   n/a   %s: %s\n' "$1" "$2"; return 0; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected: $3" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1" "not expected: $3" ;; *) ok "$1" ;; esac; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
CALLS="$T/calls"
export SSB_CALLS="$CALLS"

# --- The stand-in framework --------------------------------------------------
FW="$T/fw"
mkdir -p "$FW/Core" "$FW/Registry" "$FW/Adapters/ai-runtimes" "$FW/Adapters/scripts" "$FW/Templates"
printf '# Agent Conduct (stand-in)\n' > "$FW/Core/AGENT_CONDUCT.md"
printf '# Main Agent Conduct (stand-in)\n' > "$FW/Core/MAIN_AGENT_CONDUCT.md"
cp "$FRAMEWORK/Core/ORCHESTRATION.md" "$FW/Core/ORCHESTRATION.md"
printf 'employees:\n  - name: Backend Engineer\n' > "$FW/Registry/employees.yml"
# The generator: records its run, prints a map (the project's tier-map's map=
# line when it has one) and a quick-check summary counting the agents. Shell
# builtins only, so the process budget below counts the hook's own starts.
cat > "$FW/Adapters/ai-runtimes/generate-agents.sh" <<'GEN'
#!/usr/bin/env bash
echo gen >> "$SSB_CALLS"
map="map=strategic=s-model,standard=m-model,lightweight=l-model,frontier=f-model"
if [ -f .ia-engineering/tier-map ]; then
  while IFS= read -r l; do case "$l" in map=*) map="$l"; break ;; esac; done < .ia-engineering/tier-map
fi
echo "# mapping: stub"
echo "$map"
echo "effort-map=strategic=high,standard=,lightweight=,frontier="
n=0
for f in .claude/agents/*.md; do [ -e "$f" ] && n=$((n + 1)); done
echo "# generate-agents.sh --check --quick: 0 to act on. $n agent(s): $n present, 0 missing, 0 stale."
exit 0
GEN
cat > "$FW/Adapters/scripts/check-framework-drift.sh" <<'DRIFT'
#!/usr/bin/env bash
echo drift >> "$SSB_CALLS"
echo "# check-framework-drift: 0 to act on."
exit 0
DRIFT
git -C "$FW" init -q
git -C "$FW" config user.email t@t.invalid
git -C "$FW" config user.name t
git -C "$FW" config commit.gpgsign false
git -C "$FW" add -A 2>/dev/null
git -C "$FW" commit -qm "stand-in framework" >/dev/null

# The real hooks, copied.
HC="$T/hooks"
mkdir -p "$HC"
cp -p "$HOOKS"/*.sh "$HOOKS"/*.awk "$HC/" 2>/dev/null
HOOK="$HC/session-start.sh"

# --- The project ----------------------------------------------------------------
P="$T/project"
mkdir -p "$P/.ia-engineering" "$P/.claude/agents"
git -C "$P" init -q
git -C "$P" config user.email t@t.invalid
git -C "$P" config user.name t
git -C "$P" config commit.gpgsign false
printf '# Project contract\n' > "$P/CLAUDE.md"
printf '/.ia-engineering/\n/.claude/agents/\n' > "$P/.gitignore"
git -C "$P" add -A 2>/dev/null
git -C "$P" commit -qm init >/dev/null
printf 'agent a\n' > "$P/.claude/agents/backend-engineer.md"
printf 'agent b\n' > "$P/.claude/agents/code-reviewer.md"
{
  echo '# SESSION STATE — test'
  echo '_Last updated: 24 September 2026, afternoon by Tester_'
  echo '## Next Step'
  echo 'dispatch WU-9 to the Backend Engineer once PR #12 merges'
  echo '## Blocked On'
  echo 'PR #12 waits for the Director'
} > "$P/.ia-engineering/SESSION_STATE.md"
# Behind the repository: the freshness warning must come back on clear too.
touch -d '2020-01-01 12:00:00' "$P/.ia-engineering/SESSION_STATE.md"
printf 'work in progress\n' > "$P/wip.txt"
# The kept file's time is one second before the run that wrote it started,
# so an input changed in the two seconds before a run is newer than it and
# the next clear runs the generator once more. Every change below is
# followed by two seconds, so each check sees the case it names, on a
# machine where a run takes milliseconds.
sleep 2

# ss <source> [cache] — runs the hook as Claude Code does, the payload on
# stdin; SS_OUT its stdout and stderr, SS_GEN and SS_DRIFT how many times the
# generator and the drift check ran.
ss() {
  local src="$1" cache="${2:-$T/cache}" pay
  pay="{\"session_id\":\"t\",\"transcript_path\":\"/nonexistent\",\"cwd\":\"$P\",\"hook_event_name\":\"SessionStart\",\"source\":\"$src\"}"
  [ "$src" = none ] && pay=""
  : > "$CALLS"
  SS_OUT="$(printf '%s' "$pay" | CLAUDE_PROJECT_DIR="$P" IAENG_FRAMEWORK="$FW" XDG_CACHE_HOME="$cache" bash "$HOOK" 2>&1)"
  SS_RC=$?
  SS_GEN="$(grep -c '^gen$' "$CALLS")"
  SS_DRIFT="$(grep -c '^drift$' "$CALLS")"
}
# ss_raw <payload> — the same, with a payload given whole.
ss_raw() {
  : > "$CALLS"
  SS_OUT="$(printf '%s' "$1" | CLAUDE_PROJECT_DIR="$P" IAENG_FRAMEWORK="$FW" XDG_CACHE_HOME="$T/cache" bash "$HOOK" 2>&1)"
  SS_RC=$?
  SS_GEN="$(grep -c '^gen$' "$CALLS")"
  SS_DRIFT="$(grep -c '^drift$' "$CALLS")"
}
# part <text> — the read-first part: from the first line to the line before
# the tier map.
part_read_first() { printf '%s\n' "$1" | awk '/^Tier map in force/{exit} {print}'; }
part_tier() { printf '%s\n' "$1" | awk '/^Tier map in force/{f=1} /^Repository state now:/{f=0} f'; }
part_repo() { printf '%s\n' "$1" | awk '/^Repository state now:/{f=1} f && /^$/{exit} f'; }

HAVE_TIMEOUT=0
command -v timeout >/dev/null 2>&1 && HAVE_TIMEOUT=1

# =============================================================================
echo "== session-start.sh: what clear and compact print (#304 AC2)"

ss startup
START_OUT="$SS_OUT"
if [ "$SS_RC" -eq 0 ]; then ok "startup: exit 0"; else bad "startup: exit 0" "exit $SS_RC"; fi
has   "startup: the Next Step is printed" "$SS_OUT" "dispatch WU-9 to the Backend Engineer once PR #12 merges"
has   "startup: Blocked On is printed" "$SS_OUT" "PR #12 waits for the Director"
has   "startup: the behind-warning is printed" "$SS_OUT" "behind the repository"
has   "startup: the repository state shows the work in progress" "$SS_OUT" "?? wip.txt"
has   "startup: the tier map is printed" "$SS_OUT" "map=strategic=s-model,standard=m-model"
if [ "$SS_GEN" -eq 1 ]; then ok "startup: the generator ran once"; else bad "startup: the generator ran once" "ran $SS_GEN times"; fi
if [ "$HAVE_TIMEOUT" -eq 1 ]; then
  if [ "$SS_DRIFT" -eq 1 ]; then ok "startup: the drift check ran"; else bad "startup: the drift check ran" "ran $SS_DRIFT times"; fi
else
  na "startup: the drift check ran" "no timeout command on this platform, so the hook does not run it at all"
fi
for src in clear compact resume; do
  ss "$src"
  if [ "$SS_RC" -eq 0 ]; then ok "$src: exit 0"; else bad "$src: exit 0" "exit $SS_RC"; fi
  if [ "$(part_read_first "$SS_OUT")" = "$(part_read_first "$START_OUT")" ]; then
    ok "$src: the read-first part (pointers, SESSION_STATE, its warnings, the cap) is startup's"
  else
    bad "$src: the read-first part (pointers, SESSION_STATE, its warnings, the cap) is startup's" \
      "$(diff <(part_read_first "$START_OUT") <(part_read_first "$SS_OUT") | head -5 | tr '\n' ' ')"
  fi
  if [ "$(part_repo "$SS_OUT")" = "$(part_repo "$START_OUT")" ] && [ -n "$(part_repo "$SS_OUT")" ]; then
    ok "$src: the repository state is printed, as on startup"
  else
    bad "$src: the repository state is printed, as on startup" "$(part_repo "$SS_OUT" | tr '\n' ' ')"
  fi
  if [ "$(part_tier "$SS_OUT")" = "$(part_tier "$START_OUT")" ]; then
    ok "$src: the tier map block is startup's, word for word"
  else
    bad "$src: the tier map block is startup's, word for word" "$(part_tier "$SS_OUT" | head -3 | tr '\n' ' ')"
  fi
done

# =============================================================================
echo "== session-start.sh: clear and compact reuse the kept block"

ss startup
for src in clear compact; do
  ss "$src"
  if [ "$SS_GEN" -eq 0 ]; then ok "$src: the generator is not run while the kept block is valid"; else bad "$src: the generator is not run while the kept block is valid" "ran $SS_GEN times"; fi
done
ss resume
if [ "$SS_GEN" -eq 1 ]; then ok "resume: the generator runs (a full run)"; else bad "resume: the generator runs (a full run)" "ran $SS_GEN times"; fi

# invalidates <label> <command...> — the change, then a clear must run the
# generator, and the clear after it must not (the kept block was refreshed).
invalidates() {
  local label="$1"; shift
  ss startup
  "$@"
  sleep 2
  ss clear
  local first="$SS_GEN" out="$SS_OUT"
  ss clear
  if [ "$first" -eq 1 ] && [ "$SS_GEN" -eq 0 ]; then
    ok "clear after $label: the generator runs again, then the next clear reuses its block"
  else
    bad "clear after $label: the generator runs again, then the next clear reuses its block" "runs: $first then $SS_GEN"
  fi
  INV_OUT="$out"
}
invalidates "the tier map is created" sh -c "printf 'map=strategic=t1,standard=t1,lightweight=t1,frontier=t1\n' > '$P/.ia-engineering/tier-map'"
has "... and the clear prints the new map" "$INV_OUT" "map=strategic=t1,standard=t1"
invalidates "the tier map is edited" sh -c "printf 'map=strategic=t2,standard=t2,lightweight=t2,frontier=t2\n' > '$P/.ia-engineering/tier-map'"
has "... and the clear prints the edited map" "$INV_OUT" "map=strategic=t2,standard=t2"
invalidates "the tier map is removed" rm -f "$P/.ia-engineering/tier-map"
has "... and the clear prints the defaults again" "$INV_OUT" "map=strategic=s-model,standard=m-model"
invalidates "an agent is added" sh -c "printf 'agent c\n' > '$P/.claude/agents/qa-engineer.md'"
invalidates "an agent is edited in place" sh -c "printf 'more\n' >> '$P/.claude/agents/qa-engineer.md'"
invalidates "an agent is removed" rm -f "$P/.claude/agents/qa-engineer.md"
invalidates "the framework's roster is edited" sh -c "printf '  - name: QA Engineer\n' >> '$FW/Registry/employees.yml'"
invalidates "the project's roster is created" sh -c "mkdir -p '$P/.ia-engineering/Registry' && printf 'employees:\n' > '$P/.ia-engineering/Registry/employees.yml'"
invalidates "the generator is edited" sh -c "printf '# edited\n' >> '$FW/Adapters/ai-runtimes/generate-agents.sh'"
invalidates "this hook is replaced" touch "$HOOK"
invalidates "the framework's commit moves" git -C "$FW" commit -q --allow-empty -m "an upgrade"

# Kept files that are not used.
KEPT="$(find "$T/cache/ia-engineering" -maxdepth 1 -type f -name 'ss-*' ! -name '*.tmp' | head -1)"
if [ -n "$KEPT" ] && [ -f "$KEPT" ]; then
  ok "a full run keeps its block in the cache directory (ss-<project>)"
  cp -p "$KEPT" "$T/kept.good"
  # Not whole: its end line cut.
  head -n -1 "$T/kept.good" > "$KEPT"; touch -r "$T/kept.good" "$KEPT"
  ss clear
  if [ "$SS_GEN" -eq 1 ]; then ok "a kept file without its end line is not used"; else bad "a kept file without its end line is not used" "generator ran $SS_GEN times"; fi
  # Another project's.
  ss startup
  cp -p "$KEPT" "$T/kept.good"
  sed '2s#.*#project	/somewhere/else#' "$T/kept.good" > "$KEPT"; touch -r "$T/kept.good" "$KEPT"
  ss clear
  if [ "$SS_GEN" -eq 1 ]; then ok "a kept file about another project is not used"; else bad "a kept file about another project is not used" "generator ran $SS_GEN times"; fi
  # A forged block with the right header: used only if valid; a block whose
  # inputs line is not this project's is not.
  ss startup
  cp -p "$KEPT" "$T/kept.good"
  sed '3s#$# extra#' "$T/kept.good" > "$KEPT"; touch -r "$T/kept.good" "$KEPT"
  ss clear
  if [ "$SS_GEN" -eq 1 ]; then ok "a kept file whose inputs line differs is not used"; else bad "a kept file whose inputs line differs is not used" "generator ran $SS_GEN times"; fi
  # A link in its place.
  ss startup
  cp -p "$KEPT" "$T/kept.target"
  rm -f "$KEPT"
  if ln -s "$T/kept.target" "$KEPT" 2>/dev/null && [ -L "$KEPT" ]; then
    ss clear
    if [ "$SS_GEN" -eq 1 ]; then ok "a link in the kept file's place is not followed"; else bad "a link in the kept file's place is not followed" "generator ran $SS_GEN times"; fi
    if [ -L "$KEPT" ]; then ok "... and is not written through"; else bad "... and is not written through" "the link was replaced"; fi
    rm -f "$KEPT"
  else
    rm -f "$KEPT"
    na "a link in the kept file's place is not followed" "ln -s makes no symbolic link here"
  fi
  # Writable by the group.
  ss startup
  chmod g+w "$KEPT" 2>/dev/null
  if [ -n "$(find "$KEPT" -prune -perm -020 2>/dev/null)" ]; then
    ss clear
    if [ "$SS_GEN" -eq 1 ]; then ok "a kept file the group can write is not used"; else bad "a kept file the group can write is not used" "generator ran $SS_GEN times"; fi
    # Replaced by that clear's run, though its block was valid and the same.
    ss clear
    if [ "$SS_GEN" -eq 0 ] && [ -z "$(find "$KEPT" -prune -perm -020 2>/dev/null)" ]; then
      ok "... and is replaced by that run, so the next clear uses the kept block again"
    else
      bad "... and is replaced by that run, so the next clear uses the kept block again" "generator ran $SS_GEN times"
    fi
  else
    na "a kept file the group can write is not used" "chmod g+w has no effect on this file system"
  fi
else
  bad "a full run keeps its block in the cache directory (ss-<project>)" "no ss-* file in $T/cache/ia-engineering"
fi

# Without a cache directory, every event runs the generator: the user's
# cache and the $TMPDIR one both inside the project, which iaeng_cache_dir
# refuses.
for src in startup clear; do
  : > "$CALLS"
  printf '{"source":"%s"}' "$src" | CLAUDE_PROJECT_DIR="$P" IAENG_FRAMEWORK="$FW" XDG_CACHE_HOME="$P/inside" \
    TMPDIR="$P/inside-tmp" bash "$HOOK" >/dev/null 2>&1
done
SS_GEN="$(grep -c '^gen$' "$CALLS")"
if [ "$SS_GEN" -eq 1 ]; then ok "no usable cache directory (both inside the project): clear runs the generator"; else bad "no usable cache directory (both inside the project): clear runs the generator" "ran $SS_GEN times"; fi
if [ -z "$(find "$P/inside" "$P/inside-tmp" -name 'ss-*' 2>/dev/null)" ]; then
  ok "... and nothing is kept inside the project"
else
  bad "... and nothing is kept inside the project" "$(find "$P/inside" "$P/inside-tmp" -name 'ss-*' 2>/dev/null | head -2)"
fi

# =============================================================================
echo "== session-start.sh: the drift and context-alert checks run on startup and resume only"

for src in clear compact; do
  ss startup; ss "$src"
  if [ "$SS_DRIFT" -eq 0 ]; then ok "$src: the drift check is not run"; else bad "$src: the drift check is not run" "ran $SS_DRIFT times"; fi
done
ss resume
if [ "$HAVE_TIMEOUT" -eq 1 ]; then
  if [ "$SS_DRIFT" -eq 1 ]; then ok "resume: the drift check runs"; else bad "resume: the drift check runs" "ran $SS_DRIFT times"; fi
else
  na "resume: the drift check runs" "no timeout command on this platform"
fi
CTX_WORDS="IAENG_CTX_ALERT_PCT is not a whole number"
for src in startup resume clear compact; do
  SS_OUT="$(printf '{"source":"%s"}' "$src" | CLAUDE_PROJECT_DIR="$P" IAENG_FRAMEWORK="$FW" XDG_CACHE_HOME="$T/cache" IAENG_CTX_ALERT_PCT=abc bash "$HOOK" 2>&1)"
  case "$src" in
    startup|resume) has "$src: the context-alert threshold check runs (a bad IAENG_CTX_ALERT_PCT is said)" "$SS_OUT" "$CTX_WORDS" ;;
    *) hasnt "$src: the context-alert threshold check is not run" "$SS_OUT" "$CTX_WORDS" ;;
  esac
done

# =============================================================================
echo "== session-start.sh: only clear and compact take the shorter path"

ss startup
for pay in "" '{}' 'not json' '{"source":"fork"}' '{"source":"Clear"}' \
           "{\"cwd\":\"x\\\"source\\\":\\\"clear\\\"\",\"source\":\"startup\"}" \
           '{"other_source":"clear"}' $'{"source"\xa0:"clear"}'; do
  ss_raw "$pay"
  printf -v pay_shown '%q' "$pay"
  if [ "$SS_GEN" -eq 1 ]; then ok "payload $pay_shown: every check runs"; else bad "payload $pay_shown: every check runs" "generator ran $SS_GEN times"; fi
done
ss_raw $'{"source"\r\n:\t"clear"}'
if [ "$SS_GEN" -eq 0 ]; then ok "payload with JSON's own white space (CR, LF, TAB) around the colon: clear is read"; else bad "payload with JSON's own white space (CR, LF, TAB) around the colon: clear is read" "generator ran $SS_GEN times"; fi
ss_raw '{"source" : "compact"}'
if [ "$SS_GEN" -eq 0 ]; then ok "payload with spaces around the colon: compact is read"; else bad "payload with spaces around the colon: compact is read" "generator ran $SS_GEN times"; fi

# =============================================================================
echo "== session-start.sh: the parallel-agent cap, from Core/ORCHESTRATION.md (#486)"

CORE_PARA="$(grep -m1 '^\*\*Parallel-agent cap\.\*\*' "$FRAMEWORK/Core/ORCHESTRATION.md")"
CORE_N="$(printf '%s' "$CORE_PARA" | grep -o 'At most [0-9]* subagents run at once per machine' | grep -o '[0-9][0-9]*')"
CORE_V="$(printf '%s' "$CORE_PARA" | grep -o 'runs a framework at v[0-9.]* or earlier, the cap is [0-9]*')"
CORE_VV="$(printf '%s' "$CORE_V" | grep -o 'v[0-9][0-9.]*[0-9]')"
CORE_VN="${CORE_V##* }"
if [ -n "$CORE_N" ]; then
  WANT="Parallel-agent cap: at most $CORE_N subagents at once on this machine, counting every Claude Code session's"
  [ -n "$CORE_V" ] && WANT="$WANT; $CORE_VN while any session on it runs $CORE_VV or earlier"
  case "$CORE_PARA" in *'Every main session open on the machine beyond the first lowers the cap by one.'*) WANT="$WANT; one fewer for each main session beyond the first" ;; esac
  ss startup
  has "the cap line states Core's numbers ($CORE_N${CORE_VN:+, $CORE_VN with $CORE_VV})" "$SS_OUT" "  $WANT. At the cap, a dispatch waits and the Director is told ("
  if [ "$(printf '%s\n' "$SS_OUT" | grep -c 'Parallel-agent cap')" = 1 ]; then ok "the cap is one line"; else bad "the cap is one line" "$(printf '%s\n' "$SS_OUT" | grep -c 'Parallel-agent cap') lines"; fi
  has "the cap line names where the rule is" "$SS_OUT" "Core/ORCHESTRATION.md, Dispatch Rules)."
else
  bad "Core/ORCHESTRATION.md states the cap in its Parallel-agent cap paragraph" "no 'At most N subagents run at once per machine' in it"
fi
ORCH_SAVE="$T/orch.save"
cp "$FW/Core/ORCHESTRATION.md" "$ORCH_SAVE"
# Core without the v0.0.15 clause: not said.
sed 's/While any session on the machine runs a framework at v0\.0\.15 or earlier, the cap is 3\. //' "$ORCH_SAVE" > "$FW/Core/ORCHESTRATION.md"
ss startup
has   "Core without the v0.0.15 sentence: the cap is still said" "$SS_OUT" "Parallel-agent cap: at most"
hasnt "Core without the v0.0.15 sentence: no v0.0.15 clause" "$SS_OUT" "or earlier;"
# Core whose number cannot be read: the pointer alone, no number.
sed 's/At most [0-9]* subagents run at once per machine/Few subagents run at once per machine/' "$ORCH_SAVE" > "$FW/Core/ORCHESTRATION.md"
ss startup
has   "Core whose number cannot be read: the pointer alone" "$SS_OUT" "Parallel-agent cap: read it in "
hasnt "Core whose number cannot be read: no number of the hook's own" "$SS_OUT" "Parallel-agent cap: at most"
# No paragraph at all: the pointer.
grep -v '^\*\*Parallel-agent cap\.\*\*' "$ORCH_SAVE" > "$FW/Core/ORCHESTRATION.md"
ss startup
has   "Core with no cap paragraph: the pointer alone" "$SS_OUT" "Parallel-agent cap: read it in "
# CRLF Core: the same line.
sed 's/$/\r/' "$ORCH_SAVE" > "$FW/Core/ORCHESTRATION.md"
ss startup
has   "a CRLF Core/ORCHESTRATION.md: the same cap line" "$SS_OUT" "  ${WANT:-none}. At the cap"
cp "$ORCH_SAVE" "$FW/Core/ORCHESTRATION.md"

# =============================================================================
echo "== session-start.sh: the process budget (recording stand-ins first on PATH)"

# Counted: every command the hook started before this Work Unit, and bash
# itself (the hook's own start, the generator, the drift check, the
# context-alert check). A log without git means nothing was counted, which
# is not a pass (CR M1 and QA F1 of PR #388).
SHIMS="$T/shims"
SHIMLOG="$T/shims.log"
SHIMS_ON_PATH="$SHIMS"
command -v cygpath >/dev/null 2>&1 && SHIMS_ON_PATH="$(cygpath -u "$SHIMS")"
SHIM_CMDS="awk bash cat date find git grep head mkdir mv rm sed timeout touch tr"
mkdir -p "$SHIMS"
for c in $SHIM_CMDS; do
  real="$(command -v "$c")" || continue
  printf '#!/bin/sh\necho %s >> "%s"\nexec "%s" "$@"\n' "$c" "$SHIMLOG" "$real" > "$SHIMS/$c"
  chmod +x "$SHIMS/$c"
done
# budget <label> <source> <most> <bash wanted> — runs the hook with the
# stand-ins, the kept block valid (a full run just before, without them).
budget() {
  local label="$1" src="$2" most="$3" want_bash="$4" n_all n_bash n_git seen
  ss startup
  : > "$SHIMLOG"
  printf '{"source":"%s"}' "$src" | PATH="$SHIMS_ON_PATH:$PATH" CLAUDE_PROJECT_DIR="$P" IAENG_FRAMEWORK="$FW" \
    XDG_CACHE_HOME="$T/cache" bash "$HOOK" >/dev/null 2>&1
  n_all="$(wc -l < "$SHIMLOG" | tr -d ' ')"
  n_bash="$(grep -c '^bash$' "$SHIMLOG")"
  n_git="$(grep -c '^git$' "$SHIMLOG")"
  if [ "$n_git" -ge 1 ] && [ "$n_bash" -eq "$want_bash" ] && [ "$n_all" -le "$most" ] \
     && ! grep -qE '^(grep|sed|head|tr)$' "$SHIMLOG"; then
    ok "$label"
  else
    seen="$(sort "$SHIMLOG" | uniq -c | awk '{printf "%s x%s, ", $2, $1}')"
    bad "$label" "started ${seen:-nothing (no stand-in ran, so nothing was counted)}(want bash x$want_bash, at most $most of: $SHIM_CMDS, and no grep, sed, head or tr)"
  fi
}
# clear and compact: the hook's own bash, cat (lib.sh), awk, date, git four
# times (the status, which is also the work-tree test, HEAD's time, the
# count of commits SESSION_STATE is behind, the framework's commit for the
# kept block), find (who can write the kept file): no bash for the
# generator, the drift check or the alert check. Develop started bash four
# times, sed five times, grep and head twice and tr once (WU-IAENG-452).
budget "budget — clear, the kept block valid: no generator, drift or alert bash, at most 10 starts" clear 10 1
budget "budget — compact, the kept block valid: no generator, drift or alert bash, at most 10 starts" compact 10 1
# startup: the same reads, then the generator, the drift check under
# timeout and the alert check (bash four times with the hook's own), and no
# find or write when the kept block is unchanged.
if [ "$HAVE_TIMEOUT" -eq 1 ]; then
  budget "budget — startup, nothing changed: bash for the hook, generator, drift and alert, at most 12 starts" startup 12 4
else
  na "budget — startup" "no timeout command, so the drift check is not started here"
fi

# =============================================================================
echo "== install-hooks.sh: the SessionStart timeout, given in place"

TPL="$CC/settings.example.json"
SS_TO="$(jq -r '.hooks.SessionStart[0].hooks[0].timeout // empty' "$TPL" | tr -d '\r')"
if [[ $SS_TO =~ ^[0-9]+$ ]] && [ "$SS_TO" -ge 1 ] && [ "$SS_TO" -lt 600 ]; then
  ok "the template's SessionStart entry has a timeout under the 600 s default ($SS_TO s)"
else
  bad "the template's SessionStart entry has a timeout under the 600 s default" "got: ${SS_TO:-none}"
fi
if [ "$(jq -r '[.hooks.SessionStart[].hooks[] | select(has("onFailure"))] | length' "$TPL" | tr -d '\r')" = 0 ]; then
  ok "the template's SessionStart entry has no onFailure (a SessionStart failure blocks nothing)"
else
  bad "the template's SessionStart entry has no onFailure (a SessionStart failure blocks nothing)"
fi

IP="$T/hooks-project"
IFW="$IP/ia-engineering/Adapters/ai-runtimes/claude-code"
mkdir -p "$IFW/hooks" "$IP/ia-engineering/Core"
printf '# stand-in\n' > "$IP/ia-engineering/Core/AGENT_CONDUCT.md"
cp -p "$CC/install-hooks.sh" "$CC/settings.example.json" "$IFW/"
cp -p "$HOOKS"/*.sh "$IFW/hooks/"
chmod +x "$IFW"/hooks/*.sh "$IFW/install-hooks.sh"
SET="$IP/.claude/settings.json"
inst() { ( cd "$IP" && bash "$IFW/install-hooks.sh" "$@" ) > "$T/inst.out" 2> "$T/inst.err"; INST_RC=$?; }
ss_groups() { jq -r '.hooks.SessionStart[] | "\(.matcher // "")#\(.hooks | length)#\(.hooks[0].timeout // "-")"' "$SET" | tr -d '\r' | tr '\n' ' '; }
inst --print
cp "$T/inst.out" "$T/rendered.json"
mkdir -p "$IP/.claude"
SS_NEW='startup|resume|clear|compact'
SS_OLD='startup|resume|compact'

# earlier <matcher> — the installed file of an earlier framework: the
# SessionStart entry without its timeout under <matcher>, the project's own
# entries and env kept.
earlier() {
  jq --arg m "$1" '.hooks.SessionStart[0].matcher = $m | .hooks.SessionStart[0].hooks[0] |= del(.timeout)
      | .hooks.PreToolUse += [{"matcher":"Read","hooks":[{"type":"command","command":"bash ./tools/my-own-hook.sh"}]}]
      | .env = {"FOO":"1"}' "$T/rendered.json" | tr -d '\r' > "$SET"
}
for m in "$SS_NEW" "$SS_OLD"; do
  earlier "$m"
  cp "$SET" "$T/earlier.json"
  inst --check
  if [ "$m" = "$SS_NEW" ]; then WHY="without timeout"; else WHY="under [$SS_OLD] without timeout"; fi
  if [ "$INST_RC" -eq 3 ] && grep -qF -- "hook	absent	.claude/settings.json	SessionStart [$SS_NEW]: session-start.sh  (a run updates the framework's earlier entry $WHY in place)" "$T/inst.out" \
      && ! grep -q near-miss "$T/inst.out"; then
    ok "[$m] without the timeout: --check reports the in-place update ($WHY), no near miss"
  else
    bad "[$m] without the timeout: --check reports the in-place update ($WHY), no near miss" "rc=$INST_RC $(grep SessionStart "$T/inst.out")"
  fi
  inst
  if [ "$INST_RC" -eq 0 ] && [ "$(ss_groups)" = "$SS_NEW#1#$SS_TO " ]; then
    ok "[$m] without the timeout: updated in place — one SessionStart group, matcher $SS_NEW, timeout $SS_TO"
  else
    bad "[$m] without the timeout: updated in place — one SessionStart group, matcher $SS_NEW, timeout $SS_TO" "rc=$INST_RC groups: $(ss_groups)"
  fi
  if [ "$m" = "$SS_NEW" ]; then WHY="added: timeout"; else WHY="matcher was [$SS_OLD]; added: timeout"; fi
  if grep -qF -- "updated: SessionStart [$SS_NEW]: session-start.sh  ($WHY)" "$T/inst.out" && ! grep -q -- "^ *added: " "$T/inst.out" && [ ! -s "$T/inst.err" ]; then
    ok "[$m] ... reported as updated ($WHY), nothing added, no near-miss warning"
  else
    bad "[$m] ... reported as updated ($WHY), nothing added, no near-miss warning" "$(cat "$T/inst.out" "$T/inst.err" | tr '\n' ' ')"
  fi
  if [ "$(jq -S --arg m "$SS_NEW" --argjson t "$SS_TO" '.hooks.SessionStart[0].matcher = $m | .hooks.SessionStart[0].hooks[0].timeout = $t' "$T/earlier.json" | tr -d '\r')" = "$(jq -S . "$SET" | tr -d '\r')" ]; then
    ok "[$m] ... the matcher and the timeout are the only change (the project's own entries and env kept)"
  else
    bad "[$m] ... the matcher and the timeout are the only change (the project's own entries and env kept)"
  fi
  cp "$SET" "$T/upgraded.json"
  inst
  if [ "$INST_RC" -eq 0 ] && grep -q "present exactly" "$T/inst.out" && cmp -s "$SET" "$T/upgraded.json"; then
    ok "[$m] re-run after the update: present exactly, byte-identical"
  else
    bad "[$m] re-run after the update: present exactly, byte-identical" "$(cat "$T/inst.out" | tr '\n' ' ')"
  fi
  inst --check
  if [ "$INST_RC" -eq 0 ]; then ok "[$m] --check after the update: nothing to act on"; else bad "[$m] --check after the update: nothing to act on" "rc=$INST_RC"; fi
done
# The project's own SessionStart timeout: its entry, kept, the framework's beside it.
jq '.hooks.SessionStart[0].hooks[0].timeout = 5' "$T/rendered.json" | tr -d '\r' > "$SET"
inst
if [ "$INST_RC" -eq 0 ] && [ "$(ss_groups)" = "$SS_NEW#1#5 $SS_NEW#1#$SS_TO " ] && grep -qF -- "SessionStart [$SS_NEW]: " "$T/inst.err"; then
  ok "a SessionStart entry with a timeout of its own (5): kept, the framework's added beside it, near miss reported"
else
  bad "a SessionStart entry with a timeout of its own (5): kept, the framework's added beside it, near miss reported" "groups: $(ss_groups) err: $(head -c 300 "$T/inst.err")"
fi

# =============================================================================
if [ -n "${IAENG_HOOK_TESTS_COUNTS:-}" ]; then
  printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
fi
if [ "$FAILED" -eq 0 ]; then
  printf '   %s checks passed\n' "$TOTAL"
  exit 0
fi
printf '   %s of %s checks failed\n' "$FAILED" "$TOTAL"
exit 1
