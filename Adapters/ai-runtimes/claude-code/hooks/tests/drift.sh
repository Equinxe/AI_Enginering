#!/usr/bin/env bash
# IA Engineering — hook tests: framework drift at session start (WU-IAENG-359)
#
# Run by tests/run.sh, whose result counts these checks, and on its own:
#
#   ./Adapters/ai-runtimes/claude-code/hooks/tests/drift.sh [--verbose]
#
# The bench is the one the adopter drift plan names (§9): a framework
# repository built from this checkout's own files and tagged v1, and an
# adopter holding it as a real submodule, every installer run. session-start.sh
# is run as Claude Code runs it, with CLAUDE_PROJECT_DIR set and XDG_CACHE_HOME
# pointed inside the bench, so nothing is written in the user's own cache.
#
# What is proved:
#
#   - Clean: not one drift line, cold (no cache) and warm (the cache replayed),
#     and a CRLF copy of a current file is still clean.
#   - One cause at a time, each with a clean run before and after: an absent
#     file, a file that differs, a hook command naming a missing script, a tag
#     fetched that the checkout is behind, a checkout the project did not
#     record. Each gives exactly ONE line, naming the item and the full
#     command to run. Each also proves the cache saw the change.
#   - Every cause at once: three lines, never more, the long list cut.
#   - The framework repository itself: the check is not even run.
#   - The time bound, with the real `timeout`: a check that would take 31 s
#     is cut, the hook exits 0, says so once, and is silent at the next
#     session; no process is left behind. Every other run uses a test double
#     of `timeout` with a 120 s limit, so what is reported never depends on
#     how loaded the machine running the tests is (timings are printed as
#     info, never asserted).
#   - A fault (the check exits 3, or prints no summary) is one line, said
#     once; the hook exits 0 in every case.
#   - An incomplete check is said once and never cached.
#   - Read-only: the adopter, its .git and the submodule's git dir are the
#     same after cold and warm runs; the cache lives outside the project, and
#     a --cache-dir inside it is refused.
#   - Hook forms that cannot be resolved (`bash -O extglob x.sh`, `bash -lc`)
#     are never reported as broken, and an escape sequence in a command or
#     in a tampered cache never reaches the session.
#
# Exit 0 when every check passes, 1 when any fails, 2 when the environment is
# unusable. With IAENG_HOOK_TESTS_COUNTS set to a file, "<total> <failed>" is
# written there for run.sh.

set -uo pipefail
export LC_ALL=C

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) sed -n '2,$p' "$0" | awk '/^#/{print; next} /^$/{print; next} {exit}' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "drift.sh: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$(cd "$HERE/.." && pwd)"
SRC="$(cd "$HOOKS/../../../.." && pwd)"

for dep in jq git timeout; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "drift.sh: $dep is required and is not installed. Reported rather than skipped." >&2
    exit 2
  }
done

FAILED=0
TOTAL=0
ok() { TOTAL=$((TOTAL + 1)); [ "$VERBOSE" -eq 1 ] && printf '   ok    %s\n' "$1"; return 0; }
bad() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '   FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/         | /'; return 0; }

T="$(mktemp -d "${TMPDIR:-/tmp}/iaeng-drift359.XXXXXX")" || { echo "drift.sh: mktemp failed" >&2; exit 2; }
T="$(cd "$T" && pwd)"
trap 'cd / && rm -rf "$T"' EXIT
export XDG_CACHE_HOME="$T/cache"
CACHE="$XDG_CACHE_HOME/ia-engineering"
unset IAENG_FRAMEWORK

now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local s="${EPOCHREALTIME/[.,]/}"
    printf '%s' "$(( 10#${s:0:${#s}-3} ))"
  else
    printf '%s' "$(( $(date +%s%N) / 1000000 ))"
  fi
}

# What the hook reports must not depend on how loaded the machine running the
# tests is: on a busy Windows box every fork costs several times its idle
# price, and the 3 s limit then cuts a check that is merely slow. So every
# run below finds, first on PATH, a test double of `timeout` that runs the
# real one with a 120 s limit. The limit itself is proved with the REAL
# timeout (hook_real), against a check that would take 31 s.
REAL_TIMEOUT="$(command -v timeout)"
mkdir -p "$T/bin"
cat > "$T/bin/timeout" <<EOF
#!/usr/bin/env bash
[ "\$1" = -k ] && shift 2
shift
exec "$REAL_TIMEOUT" -k 1 120 "\$@"
EOF
chmod +x "$T/bin/timeout"
HOOK_PATH="$T/bin:$PATH"

# hook <project> — runs session-start.sh as Claude Code does. Sets OUT (stdout
# and stderr), RC, MS (elapsed), DRIFT (the drift lines alone) and NDRIFT.
hook() {
  local t0
  t0="$(now_ms)"
  OUT="$( (cd "$1" && printf '' | env CLAUDE_PROJECT_DIR="$1" PATH="$HOOK_PATH" bash "$HOOKS/session-start.sh") 2>&1 )"
  RC=$?
  MS=$(( $(now_ms) - t0 ))
  DRIFT="$(printf '%s\n' "$OUT" | grep '^IA Engineering drift' || true)"
  NDRIFT=0
  [ -n "$DRIFT" ] && NDRIFT="$(printf '%s\n' "$DRIFT" | wc -l | tr -d ' ')"
}

# hook_real <project> — the same, with the real timeout and its 3 s limit.
hook_real() {
  local saved="$HOOK_PATH"
  HOOK_PATH="$PATH"
  hook "$1"
  HOOK_PATH="$saved"
}

# expect_lines <n> <label> — the last hook run exited 0 with exactly n drift lines.
expect_lines() {
  if [ "$RC" -eq 0 ] && [ "$NDRIFT" -eq "$1" ]; then ok "$2"; else bad "$2" "exit $RC, $NDRIFT drift line(s), want $1:
$DRIFT"; fi
}
# expect_drift <text> <label> — a drift line of the last run contains text.
expect_drift() {
  case "$DRIFT" in *"$1"*) ok "$2" ;; *) bad "$2" "no drift line contains: $1
got: $DRIFT" ;; esac
}

new_repo() {
  mkdir -p "$1" && cd "$1" || exit 2
  git init -q -b main .
  git config user.email test@example.invalid
  git config user.name "Test Runner"
  git config commit.gpgsign false
  git config core.autocrlf false
}

# snapshot — everything a write could touch (as Adapters/scripts/tests/run.sh
# snapshot_353): every file under .git, the submodule's git dir included, the
# tree, status, local config, refs and the object count.
snapshot() {
  {
    echo "== .git"; find .git -type f -exec md5sum {} + | LC_ALL=C sort -k2
    echo "== tree"; find . -path ./.git -prune -o -type f -exec md5sum {} + | LC_ALL=C sort -k2
    echo "== status"; git --no-optional-locks status --porcelain --ignored
    echo "== config"; git config --local --list
    echo "== refs"; git for-each-ref
    echo "== objects"; git count-objects -v
  } 2>&1
}

# cache_file — sets CACHE_FILE to the kept --quick result, or to nothing.
cache_file() {
  local f
  CACHE_FILE=""
  for f in "$CACHE"/drift-*.tsv; do
    case "$f" in *.files.tsv) continue ;; esac
    [ -f "$f" ] && { CACHE_FILE="$f"; return 0; }
  done
  return 0
}

TAB=$'\t'
RUN_CMD="Run: bash ia-engineering/Adapters/scripts/check-framework-drift.sh"

# =============================================================================
echo "== session-start.sh — framework drift (WU-IAENG-359)"

# --- the bench ----------------------------------------------------------------
new_repo "$T/fw"
cp -R "$SRC/Adapters" "$SRC/Registry" "$SRC/Core" "$SRC/Templates" .
cp "$SRC/.gitattributes" .
git add -A && git commit -q -m "framework" && git tag v1
FW="$PWD"

new_repo "$T/ad"
echo seed > seed.txt && git add seed.txt && git commit -q -m seed
git -c protocol.file.allow=always submodule add -q "$FW" ia-engineering >/dev/null 2>&1
git -C ia-engineering checkout -q v1
git add -A && git commit -q -m "chore(adopt): add the framework at v1"
bash ./ia-engineering/Adapters/scripts/setup-project-bootstrap.sh generic >/dev/null 2>&1
bash ./ia-engineering/Adapters/ai-runtimes/claude-code/install-hooks.sh >/dev/null 2>&1
bash ./ia-engineering/Adapters/ai-runtimes/claude-code/install-skills.sh >/dev/null 2>&1
AD="$PWD"
if [ -f Registry/work-units.yml ] && [ -f .claude/settings.json ] && [ -f .github/workflows/pr-validation.yml ]; then
  ok "bench: the adopter is installed"
else
  bad "bench: the adopter is installed" "the installers did not write the expected files; every check below would prove nothing"
fi
QUICK=(bash ./ia-engineering/Adapters/scripts/check-framework-drift.sh --quick --format tsv --cache-dir "$CACHE")

# --- clean: cold, then warm ---------------------------------------------------
SNAP_A="$(snapshot)"
hook "$AD"
COLD_MS="$MS"
expect_lines 0 "clean adopter, cold (no cache): not one drift line"
cache_file
if [ -n "$CACHE_FILE" ] && [ -f "$CACHE_FILE" ]; then ok "the cold run kept its result in the user-level cache"; else bad "the cold run kept its result in the user-level cache" "$(ls -la "$CACHE" 2>&1)"; fi
hook "$AD"
WARM_MS="$MS"
expect_lines 0 "clean adopter, warm (cache replayed): not one drift line"
Q_OUT="$("${QUICK[@]}" 2>&1)"
case "$Q_OUT" in *"# --quick: cache hit"*) ok "an unchanged project is replayed from the cache (hit)" ;; *) bad "an unchanged project is replayed from the cache (hit)" "$Q_OUT" ;; esac
case "$Q_OUT" in *"config${TAB}not-evaluated${TAB}(--quick)"*) ok "--quick says the config family was not evaluated" ;; *) bad "--quick says the config family was not evaluated" "$Q_OUT" ;; esac
SNAP_B="$(snapshot)"
if [ "$SNAP_A" = "$SNAP_B" ]; then ok "read-only: the adopter, .git and the submodule's git dir are unchanged by cold and warm runs"; else bad "read-only: the adopter, .git and the submodule's git dir are unchanged by cold and warm runs" "$(diff <(printf '%s\n' "$SNAP_A") <(printf '%s\n' "$SNAP_B"))"; fi

# Timings, measured on the machine running the tests: the hook as a whole,
# and the check alone exactly as the hook calls it.
rm -f "$CACHE"/drift-*.tsv
t0="$(now_ms)"; "${QUICK[@]}" >/dev/null 2>&1; Q_COLD=$(( $(now_ms) - t0 ))
t0="$(now_ms)"; "${QUICK[@]}" >/dev/null 2>&1; Q_WARM=$(( $(now_ms) - t0 ))
printf '   info  session-start.sh, whole hook: %s ms cold, %s ms warm\n' "$COLD_MS" "$WARM_MS"
printf '   info  check-framework-drift.sh --quick --cache-dir (the hook arguments, no time limit): %s ms cold, %s ms warm\n' "$Q_COLD" "$Q_WARM"

# B, the installers' records, is kept on its own: a run that cannot keep the
# whole result (cut by the time limit, or with an indeterminate item) still
# leaves it, and the next run does not run the installers again.
"${QUICK[@]}" >/dev/null 2>&1
cache_file
rm -f "$CACHE_FILE"
Q_OUT="$("${QUICK[@]}" 2>&1)"
case "$Q_OUT" in *"# --quick: cache miss, file records replayed"*) ok "the whole result gone, the file records are replayed, not recomputed" ;; *) bad "the whole result gone, the file records are replayed, not recomputed" "$Q_OUT" ;; esac
case "$Q_OUT" in *"14 file(s) compared: 8 current, 6 project-owned."*) ok "the replayed file records are the same 14" ;; *) bad "the replayed file records are the same 14" "$Q_OUT" ;; esac
# The whole result that run kept watches the files B was read from too.
echo "# edit" >> .github/workflows/pr-validation.yml
Q_OUT="$("${QUICK[@]}" 2>&1)"
case "$Q_OUT" in *"file${TAB}differs${TAB}.github/workflows/pr-validation.yml"*) ok "a result built on replayed file records still sees a managed file edited" ;; *) bad "a result built on replayed file records still sees a managed file edited" "$Q_OUT" ;; esac
git -C ia-engineering show HEAD:Adapters/github-actions/pr-validation.yml > .github/workflows/pr-validation.yml
"${QUICK[@]}" >/dev/null 2>&1
cp .claude/settings.json "$T/settings0.json"
printf '{ not json' > .claude/settings.json
Q_OUT="$("${QUICK[@]}" 2>&1)"
case "$Q_OUT" in *"path${TAB}indeterminate${TAB}.claude/settings.json"*"# --quick: cache miss, file records replayed"*) ok "settings.json edited (here unreadable): only the paths are read again" ;; *) bad "settings.json edited (here unreadable): only the paths are read again" "$Q_OUT" ;; esac
Q_OUT="$("${QUICK[@]}" 2>&1)"
case "$Q_OUT" in *"# --quick: cache miss, file records replayed"*) ok "an indeterminate result is not kept, but its file records still are" ;; *) bad "an indeterminate result is not kept, but its file records still are" "$Q_OUT" ;; esac
cp "$T/settings0.json" .claude/settings.json
echo "# edit" >> .github/workflows/pr-validation.yml
Q_OUT="$("${QUICK[@]}" 2>&1)"
case "$Q_OUT" in *"# --quick: cache miss"$'\n'*|*"# --quick: cache miss") ok "a managed file edited: the file records are computed again" ;; *) bad "a managed file edited: the file records are computed again" "$Q_OUT" ;; esac
case "$Q_OUT" in *"file${TAB}differs${TAB}.github/workflows/pr-validation.yml"*) ok "... and see the edit" ;; *) bad "... and see the edit" "$Q_OUT" ;; esac
git -C ia-engineering show HEAD:Adapters/github-actions/pr-validation.yml > .github/workflows/pr-validation.yml

# Line endings aside: a CRLF copy of a current file is current.
cp .github/workflows/data-policy.yml "$T/data-policy.yml"
sed 's/$/\r/' "$T/data-policy.yml" > .github/workflows/data-policy.yml
hook "$AD"
expect_lines 0 "a CRLF copy of a current file is not drift"
cp "$T/data-policy.yml" .github/workflows/data-policy.yml

# --- one cause at a time -------------------------------------------------------
hook "$AD"; expect_lines 0 "clean before: an absent file"
mv Registry/work-units.yml "$T/work-units.yml"
hook "$AD"
expect_lines 1 "an absent file alone: one line"
expect_drift "1 of 14 framework-managed file(s) to act on (absent: Registry/work-units.yml)" "the absent file is named, with the count"
expect_drift "$RUN_CMD, which tells a stale file (copy it) from a modified one (review it)" "the absent-file line names the full command"
# Put back with an OLD mtime: only the presence check can see it came back.
mv "$T/work-units.yml" Registry/work-units.yml
touch -t 202001010000 Registry/work-units.yml
hook "$AD"; expect_lines 0 "clean after: the file put back (an old mtime: seen by presence)"

echo "# the project's own line" >> .github/workflows/pr-validation.yml
hook "$AD"
expect_lines 1 "a managed file that differs alone: one line"
expect_drift "differ from the framework: .github/workflows/pr-validation.yml" "the differing file is named"
git -C ia-engineering show HEAD:Adapters/github-actions/pr-validation.yml > .github/workflows/pr-validation.yml
hook "$AD"; expect_lines 0 "clean after: the file restored"

cp .claude/settings.json "$T/settings.json"
jq '.hooks.Stop[0].hooks += [{"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/gone.sh\""}]' "$T/settings.json" | sed $'s/\r$//' > .claude/settings.json
hook "$AD"
expect_lines 1 "a hook command naming a missing script alone: one line"
expect_drift "1 hook command(s) or core.hooksPath name a path that does not work, so that guard is silently off: .claude/hooks/gone.sh (not found). $RUN_CMD" "the broken path is named, with why and the command"
cp "$T/settings.json" .claude/settings.json
hook "$AD"; expect_lines 0 "clean after: settings.json restored"

# Hook forms a shell reads that this check cannot resolve are never drift
# (the WU-IAENG-358 lessons: -O takes an argument, a c in a flag cluster is
# inline code).
jq '.hooks.Stop[0].hooks += [{"type":"command","command":"bash -O extglob .claude/hooks/x.sh"},{"type":"command","command":"bash -lc \"echo hi\""}]' "$T/settings.json" | sed $'s/\r$//' > .claude/settings.json
hook "$AD"
expect_lines 0 "bash -O extglob x.sh and bash -lc are unresolved, never reported as broken"
cp "$T/settings.json" .claude/settings.json

git -C "$FW" commit -q --allow-empty -m "after v1" && git -C "$FW" tag v2
git -C ia-engineering fetch -q origin --tags 2>/dev/null
hook "$AD"
expect_lines 1 "a tag fetched that the checkout is behind, alone: one line"
expect_drift "the framework (ia-engineering): last tag known locally: v2, 1 tag(s) behind. $RUN_CMD" "the version line says how far behind, and the command"
git -C ia-engineering tag -d v2 >/dev/null
hook "$AD"; expect_lines 0 "clean after: the tag removed"

git -C ia-engineering checkout -q "$(git -C "$FW" rev-parse main)"
hook "$AD"
expect_lines 1 "a checkout the project did not record, alone: one line"
expect_drift "the checkout is not the commit the project recorded (gitlink +): an upgrade not committed. $RUN_CMD" "the gitlink line says what it means, and the command"
git -C ia-engineering checkout -q v1
hook "$AD"; expect_lines 0 "clean after: back on the recorded commit"

# --- every cause at once: three lines, never more --------------------------------
mv Registry/work-units.yml "$T/work-units.yml"
rm .github/workflows/data-policy.yml .github/workflows/control-path-guard.yml .github/PULL_REQUEST_TEMPLATE.md
echo "# edit" >> .github/workflows/pr-validation.yml
jq '.hooks.Stop[0].hooks += [{"type":"command","command":"bash .claude/hooks/a.sh"},{"type":"command","command":"bash .claude/hooks/b.sh"},{"type":"command","command":"bash .claude/hooks/c.sh"}]' "$T/settings.json" | sed $'s/\r$//' > .claude/settings.json
git -C ia-engineering fetch -q origin --tags 2>/dev/null
hook "$AD"
expect_lines 3 "every family drifting at once: exactly three lines"
expect_drift "and 1 more; differ from the framework: .github/workflows/pr-validation.yml" "a long list is cut, with how many more"
expect_drift "and 1 more. $RUN_CMD" "the path list is cut too"
mv "$T/work-units.yml" Registry/work-units.yml
for f in data-policy.yml control-path-guard.yml pr-validation.yml; do
  git -C ia-engineering show HEAD:Adapters/github-actions/$f > .github/workflows/$f
done
git -C ia-engineering show HEAD:Adapters/github/PULL_REQUEST_TEMPLATE.md > .github/PULL_REQUEST_TEMPLATE.md
cp "$T/settings.json" .claude/settings.json
git -C ia-engineering tag -d v2 >/dev/null
hook "$AD"; expect_lines 0 "clean once more after every cause"

# --- an escape sequence never reaches the session --------------------------------
ESC=$'\033'
jq --arg c "bash .claude/hooks/x${ESC}[31mRED.sh" '.hooks.Stop[0].hooks += [{"type":"command","command":$c}]' "$T/settings.json" | sed $'s/\r$//' > .claude/settings.json
hook "$AD"
expect_lines 1 "a broken command carrying ESC: one line"
case "$OUT" in *"$ESC"*) bad "no ESC byte reaches the session from a settings command" ;; *) ok "no ESC byte reaches the session from a settings command" ;; esac
cp "$T/settings.json" .claude/settings.json
hook "$AD"; expect_lines 0 "clean after: settings.json restored (ESC case)"
# A cache tampered with by hand is still data: a row carrying ESC is
# flattened when it is replayed.
cache_file
if [ -n "$CACHE_FILE" ]; then
  while IFS= read -r l; do
    [ "$l" = end ] && printf 'row\tpath\tbroken\t.claude/hooks/x%s[31mX\tnot found; tampered\n' "$ESC"
    printf '%s\n' "$l"
  done < "$CACHE_FILE" > "$T/tampered"
  touch -r "$CACHE_FILE" "$T/tampered"
  cp -p "$T/tampered" "$CACHE_FILE"
  hook "$AD"
  expect_drift ".claude/hooks/x [31mX (not found)" "a tampered cache is still data: its row is replayed, flattened"
  case "$OUT" in *"$ESC"*) bad "no ESC byte reaches the session from a tampered cache" ;; *) ok "no ESC byte reaches the session from a tampered cache" ;; esac
  rm -f "$CACHE_FILE"
else
  bad "no ESC byte reaches the session from a tampered cache" "no cache file to tamper with"
fi
hook "$AD"; expect_lines 0 "clean after the tampered cache is gone"

# --- an incomplete check: said once, never cached --------------------------------
git -C ia-engineering tag -d v1 >/dev/null
hook "$AD"
expect_lines 1 "no tag known locally: one line"
expect_drift "IA Engineering drift check: incomplete, ia-engineering: no tag is known locally; nothing to count from (said once). $RUN_CMD" "the incomplete check names its cause and the command"
Q_OUT="$("${QUICK[@]}" 2>&1)"
case "$Q_OUT" in *"# --quick: cache miss"*) ok "an incomplete result is never kept (cache miss again)" ;; *) bad "an incomplete result is never kept (cache miss again)" "$Q_OUT" ;; esac
hook "$AD"
expect_lines 0 "the incomplete check is not said again at the next session"
git -C ia-engineering fetch -q origin --tags 2>/dev/null
git -C ia-engineering tag -d v2 >/dev/null 2>&1
hook "$AD"; expect_lines 0 "clean after the tag is back"

# --- the time bound and the faults ------------------------------------------------
DRIFT_SH="ia-engineering/Adapters/scripts/check-framework-drift.sh"
cp "$DRIFT_SH" "$T/check-framework-drift.sh"
# The fake check leaves a child holding the hook's pipe: if the time bound
# did not end the whole process group, the hook would wait 31 s for it.
printf '#!/usr/bin/env bash\necho $$ > "%s/pid1"\nsleep 31 &\necho $! > "%s/pid2"\nwait\n' "$T" "$T" > "$DRIFT_SH"
hook_real "$AD"
OVER_MS="$MS"
printf '   info  session-start.sh with a check that never ends: %s ms\n' "$OVER_MS"
# Under 15 s whatever the machine's load: the check alone would hold the hook
# 31 s. The 3 s figure is timeout's own (TERM 2.8 s, KILL 0.2 s later).
if [ "$RC" -eq 0 ] && [ "$MS" -lt 15000 ]; then ok "a check that never ends is cut by the real timeout: the hook exits 0 ($MS ms, not 31 s)"; else bad "a check that never ends is cut by the real timeout: the hook exits 0 ($MS ms, not 31 s)" "exit $RC"; fi
expect_lines 1 "the overrun is said in one line"
expect_drift "not finished within the 3 s session-start budget" "the overrun line says why"
LEFT=""
for f in pid1 pid2; do
  [ -s "$T/$f" ] || { LEFT="$LEFT $f: never written;"; continue; }
  kill -0 "$(cat "$T/$f")" 2>/dev/null && LEFT="$LEFT $f: $(cat "$T/$f") still running;"
done
if [ -z "$LEFT" ]; then ok "no process outlives the hook (the check and its child are gone)"; else bad "no process outlives the hook (the check and its child are gone)" "$LEFT"; fi
hook_real "$AD"
expect_lines 0 "the overrun is not said again at the next session"

printf '#!/usr/bin/env bash\nprintf "file\\tabsent\\tx\\tr\\n"\n' > "$DRIFT_SH"
hook "$AD"
expect_lines 1 "output with no summary line: one line, nothing from it shown"
expect_drift "it gave no summary line" "a cut-short output is said, not trusted"

# A drift status this hook has no line for is still never silence.
printf '#!/usr/bin/env bash\nprintf "config\\tmissing\\tx\\tr\\n# check-framework-drift: 1 to act on, 0 indeterminate.\\n"\n' > "$DRIFT_SH"
hook "$AD"
expect_lines 1 "a drift status with no line of its own: one line, never silence"
expect_drift "IA Engineering drift: 1 item(s) to act on. $RUN_CMD" "the fallback line gives the count and the command"

printf '#!/usr/bin/env bash\nexit 3\n' > "$DRIFT_SH"
hook "$AD"
expect_lines 1 "a check that fails (exit 3): one line, and the hook exits 0"
expect_drift "IA Engineering drift check: it failed (exit 3), so nothing is reported (said once). Run it by hand: bash ia-engineering/Adapters/scripts/check-framework-drift.sh" "the fault line gives the exit code and the command"
hook "$AD"
expect_lines 0 "the fault is not said again at the next session"

# The same fault after a run that completed is a new episode: said again.
cp "$T/check-framework-drift.sh" "$DRIFT_SH"
hook "$AD"; expect_lines 0 "clean once the real check is back"
printf '#!/usr/bin/env bash\nexit 3\n' > "$DRIFT_SH"
hook "$AD"
expect_lines 1 "after a completed run, the same fault is said again (once per episode)"
cp "$T/check-framework-drift.sh" "$DRIFT_SH"

# --- the cache stays out of the project ------------------------------------------
"${QUICK[@]:0:5}" --cache-dir "$AD/.drift-cache" >/dev/null 2>&1
if [ ! -e "$AD/.drift-cache" ] || [ -z "$(ls -A "$AD/.drift-cache" 2>/dev/null)" ]; then ok "a --cache-dir inside the project is never written"; else bad "a --cache-dir inside the project is never written" "$(ls -la "$AD/.drift-cache")"; fi
rm -rf "$AD/.drift-cache"
bash ./ia-engineering/Adapters/scripts/check-framework-drift.sh --quick --cache-dir relative/dir >/dev/null 2>&1
if [ $? -eq 64 ]; then ok "a relative --cache-dir is a usage error (64)"; else bad "a relative --cache-dir is a usage error (64)"; fi
bash ./ia-engineering/Adapters/scripts/check-framework-drift.sh --cache-dir "$CACHE" >/dev/null 2>&1
if [ $? -eq 64 ]; then ok "--cache-dir without --quick is a usage error (64)"; else bad "--cache-dir without --quick is a usage error (64)"; fi
bash ./ia-engineering/Adapters/scripts/check-framework-drift.sh --quick --remote >/dev/null 2>&1
if [ $? -eq 64 ]; then ok "--quick never asks the remote: --quick --remote is a usage error (64)"; else bad "--quick never asks the remote: --quick --remote is a usage error (64)"; fi
# The harder case: the restores above rewrote a file inside the submodule, so
# its index is stale, which a git command with optional locks would refresh.
# The check alone, as the hook runs it (cold then warm), writes nothing.
touch ia-engineering/Adapters/scripts/check-framework-drift.sh
SNAP_C="$(snapshot)"
rm -f "$CACHE"/drift-*.tsv
"${QUICK[@]}" >/dev/null 2>&1
"${QUICK[@]}" >/dev/null 2>&1
SNAP_D="$(snapshot)"
if [ "$SNAP_C" = "$SNAP_D" ]; then ok "read-only: the check, cold and warm, leaves a stale submodule index as it was"; else bad "read-only: the check, cold and warm, leaves a stale submodule index as it was" "$(diff <(printf '%s\n' "$SNAP_C") <(printf '%s\n' "$SNAP_D"))"; fi
# The whole hook, with git's optional locks off: session-start.sh's own
# `git status` (older than this check) refreshes a stale index otherwise.
export GIT_OPTIONAL_LOCKS=0
hook "$AD"; hook "$AD"
unset GIT_OPTIONAL_LOCKS
SNAP_E="$(snapshot)"
if [ "$SNAP_C" = "$SNAP_E" ]; then ok "read-only: the whole hook, run twice, changes nothing in the project"; else bad "read-only: the whole hook, run twice, changes nothing in the project" "$(diff <(printf '%s\n' "$SNAP_C") <(printf '%s\n' "$SNAP_E"))"; fi

# --- the framework repository itself: never run ------------------------------------
# A sentinel in place of the check: if the hook ran it, it would leave a file
# and print a drift line.
cd "$FW" || exit 2
cp Adapters/scripts/check-framework-drift.sh "$T/fw-check.sh"
printf '#!/usr/bin/env bash\n: > "%s/ran"\nprintf "version\\tbehind\\tx\\tr\\n# check-framework-drift: 1 to act on, 0 indeterminate.\\n"\n' "$T" > Adapters/scripts/check-framework-drift.sh
hook "$FW"
expect_lines 0 "in the framework repository: nothing is printed"
if [ ! -e "$T/ran" ]; then ok "in the framework repository: the check is not even run"; else bad "in the framework repository: the check is not even run"; fi
cp "$T/fw-check.sh" Adapters/scripts/check-framework-drift.sh
cd "$AD" || exit 2

# =============================================================================
echo
[ -z "${IAENG_HOOK_TESTS_COUNTS:-}" ] || printf '%s %s\n' "$TOTAL" "$FAILED" > "$IAENG_HOOK_TESTS_COUNTS"
if [ "$FAILED" -eq 0 ]; then
  printf 'Drift result: %s checks passed.\n' "$TOTAL"
  exit 0
fi
printf 'Drift result: %s of %s checks failed.\n' "$FAILED" "$TOTAL"
exit 1
