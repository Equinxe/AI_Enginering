#!/usr/bin/env bash
# IA Engineering — check-risk-map.sh
#
# Verifies a project's Risk Map (Standards/RISK_STANDARD.md, The Risk Map) and,
# with --range, reports the highest change-zone level a change set touches.
#
# WHY A MAP NEEDS A CHECK OF ITS OWN
#
# A wrong Risk Map does not fail. It quietly classifies something important as
# ordinary, and every control downstream then behaves correctly on a false
# input. Templates/RISK_MAP.md lists five ways that happens; the first four
# were found by running commands and none by re-reading a map, and this script
# is those commands. The fifth — a zone drawn too wide, so a Risk Record is
# demanded on every commit and stops meaning anything — is a judgement this
# script cannot make: it does not know which of two files is a trust boundary.
# It surfaced on the first Pull Request after this repository's own map merged.
#
# AN UNMAPPED PROJECT IS UNCLASSIFIED, NOT SAFE. Without a map every path falls
# back to standard, which is the sensitive paths silently losing whatever the
# project requires of them. That state is reported, never passed.
#
# GLOB SEMANTICS, MADE EXPLICIT because trap 1 depends on them. A pattern is
# translated to a regular expression, where `*` becomes `.*` — so `*` CROSSES
# `/`, and `*.md` matches every markdown file in the repository rather than
# only those at the root. `**` is not special; it behaves exactly like `*`.
# Write specific patterns before general ones: first match wins.
#
# The translation is done rather than delegated to shell `case` on purpose.
# `case` has the same semantics, but reading it requires knowing that; a regex
# built here can be printed, and --explain does print the resolved level of
# every file so the semantics are checkable rather than trusted.
#
# USAGE
#
#   check-risk-map.sh [project-root]              validate the map
#   check-risk-map.sh --explain [project-root]    print the level of every tracked file
#   check-risk-map.sh --range <base> <head> [project-root]
#                                                 highest level a change set touches
#
# --range diffs from the MERGE BASE of <base> and <head>, as check-pr-size.sh
# does, so only what the change set itself changed is classified. When a
# sensitive zone is touched it requires the Risk Record of
# Standards/RISK_STANDARD.md in a commit message of the range: a paragraph
# starting with `RISK:` at column 0 that carries tier= (one of Low, Medium,
# High, Critical), mitigation= and decided_by=. An indented or quoted example
# does not count, which is what the other checks tell authors. The check is
# advisory: it verifies the record is there and has its fields, not that the
# tier or the decision is the right one.
#
# Exit 0 when the map is sound (or, in --range, when the change set is
# acceptable), 1 otherwise, 2 on a usage error.

set -uo pipefail
export LC_ALL=C

# The closed list from Standards/RISK_STANDARD.md. Closed so that coverage can
# be checked: a category is present with its paths, or declared absent with a
# reason. Adding to this list is a change to the Standard first.
CATEGORIES="authentication authorization personal_data payments_and_spend cryptography_and_secrets migrations_and_data_integrity infrastructure_and_ci core_architecture"
LEVELS="routine standard sensitive"

err() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error::%s\n' "$1" >&2
  else
    printf 'check-risk-map: ERROR: %s\n' "$1" >&2
  fi
}

note() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::notice::%s\n' "$1"
  else
    printf 'check-risk-map: %s\n' "$1"
  fi
}

MODE=validate
BASE=""
HEAD_REF=""
ROOT="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --explain) MODE=explain; shift ;;
    --range)
      MODE=range
      if [ "$#" -lt 3 ]; then
        echo "Usage: $0 --range <base> <head> [project-root]" >&2
        exit 2
      fi
      BASE="$2"; HEAD_REF="$3"; shift 3
      ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *)  ROOT="$1"; shift ;;
  esac
done

if [ ! -d "$ROOT" ]; then
  err "no such directory: $ROOT"
  exit 1
fi
cd "$ROOT" || exit 1

MAP=".ia-engineering/risk-map.yml"
if [ ! -f "$MAP" ]; then
  err "no Risk Map at $MAP. Standards/RISK_STANDARD.md: a project without one is UNCLASSIFIED, not safe — every path falls back to standard and the sensitive ones silently lose what the project requires of them. Write one from Templates/RISK_MAP.md, and commit it: a map CI cannot read classifies nothing."
  exit 1
fi

# --- parse -------------------------------------------------------------------
#
# The parsing contract, the same shape Registry/ uses: a zone opens with a line
# `  - pattern: <glob>` and its fields are `    level:`, `    category:` and
# `    reason:`. Quotes around the glob are optional and stripped.
#
# Each zone becomes one tab-separated record ending in the regex its glob
# translates to, computed ONCE here rather than per file — the alternative is
# patterns times files invocations of an interpreter, which turns a check into
# a wait.
ZONES="$(awk '
  function glob_to_regex(g,   i, n, c, out) {
    out = "^"; n = length(g)
    for (i = 1; i <= n; i++) {
      c = substr(g, i, 1)
      if (c == "*")                              out = out ".*"
      else if (c == "?")                         out = out "."
      else if (index(".[]^$+(){}|" BS, c) > 0)   out = out BS c
      else                                       out = out c
    }
    return out "$"
  }
  BEGIN { BS = sprintf("%c", 92) }
  function flush() {
    if (pat != "")
      print pat "\t" (lvl == "" ? "-" : lvl) "\t" (cat == "" ? "-" : cat) "\t" (reason == "" ? "-" : "yes") "\t" glob_to_regex(pat)
  }
  /^  - pattern:/ {
    flush()
    pat = $0; sub(/^  - pattern:[ \t]*/, "", pat); gsub(/\r/, "", pat)
    gsub(/^"|"$/, "", pat)
    lvl = ""; cat = ""; reason = ""
    next
  }
  /^    level:/    { lvl = $0; sub(/^    level:[ \t]*/, "", lvl); gsub(/\r/, "", lvl); next }
  /^    category:/ { cat = $0; sub(/^    category:[ \t]*/, "", cat); gsub(/\r/, "", cat); next }
  /^    reason:/   { reason = "yes"; next }
  END { flush() }
' "$MAP")"

ZONE_COUNT="$(printf '%s\n' "$ZONES" | grep -c . || true)"
if [ "$ZONE_COUNT" -eq 0 ]; then
  err "$MAP yielded no zones. The parsing contract is a line of the exact form '  - pattern: <glob>' with '    level:' beneath it (two spaces, dash, space). Failing rather than treating an unreadable map as an empty one, which would classify the whole project as unmapped without ever saying the file could not be read."
  exit 1
fi

if ! TRACKED="$(git ls-files)"; then
  err "git ls-files failed. The map is checked against tracked paths; without them nothing can be verified."
  exit 1
fi
TRACKED_COUNT="$(printf '%s\n' "$TRACKED" | grep -c . || true)"

# Files present in the working tree but not yet committed (respecting
# .gitignore, so node_modules and the like do not appear). Used ONLY to tell a
# zone that matches nothing TRACKED from one that matches a file the project has
# but has not staged — the state EVERY adopter is in the first time they run
# this, immediately after bootstrap installs the workflows, Dockerfile and the
# map itself. "Remove the entry" is the wrong advice then; "commit the file" is
# right. Captured once; matched with here-strings (TROUBLESHOOTING X).
UNTRACKED="$(git ls-files --others --exclude-standard 2>/dev/null || true)"

# NO FIELD IS EVER EMPTY in the records above, and that is not tidiness.
#
# A tab is an IFS *whitespace* character, so `read` collapses a run of them even
# when IFS is set to a tab alone. A zone with no category emitted two tabs in a
# row, the pair became one, and every later column shifted left: `reason` was
# read out of the regex column, and all eight routine zones were reported as
# having no reason. The check was wrong about the map and said so with the same
# confidence it uses when it is right.
#
# Absent fields are written "-" so the column count is fixed and the collapse
# has nothing to collapse.
TAB="$(printf '\t')"

# level_of <path> — first match wins, exactly as the map documents.
level_of() {
  local file="$1" pat lvl re
  while IFS="$TAB" read -r pat lvl _cat _reason re; do
    [ -n "$pat" ] || continue
    # here-string, not `printf | grep -q`. grep -q closes the pipe on its first
    # match; the producer then takes SIGPIPE, and `set -o pipefail` reports that
    # as the pipeline's failure — so a real match reads as a miss whenever the
    # producer had more to write. Harmless for one filename, wrong for the large
    # producers below, uniform here so the footgun is not copied. TROUBLESHOOTING X.
    if grep -qE "$re" <<< "$file"; then
      printf '%s\n' "$lvl"
      return 0
    fi
  done <<EOF
$ZONES
EOF
  printf 'UNMATCHED\n'
}

# --- explain -----------------------------------------------------------------
if [ "$MODE" = explain ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s %s\n' "$f" "$(level_of "$f")"
  done <<EOF
$TRACKED
EOF
  exit 0
fi

# --- range -------------------------------------------------------------------
if [ "$MODE" = range ]; then
  # THE DIFF IS FROM THE MERGE BASE, not the base branch tip — the same rule
  # as check-pr-size.sh. An endpoint diff `git diff <base> <head>` also
  # contains the inverse of every commit the base gained after the fork
  # point, so a sensitive file somebody else moved on was attributed to a
  # Pull Request that never touched it and a record was demanded for it;
  # and a file the change DID touch disappeared from the diff whenever the
  # base had since made the same edit (PT2-05). The commit-message scan
  # below uses `<base>..<head>`, which is already merge-base-relative.
  if ! MERGE_BASE="$(git merge-base "$BASE" "$HEAD_REF")"; then
    err "Could not compute the merge base of $BASE and $HEAD_REF. Nothing was classified, so nothing is established."
    exit 1
  fi
  if ! CHANGED="$(git diff --name-only "$MERGE_BASE" "$HEAD_REF")"; then
    err "git diff failed between the merge base $MERGE_BASE and $HEAD_REF. Nothing was classified, so nothing is established."
    exit 1
  fi
  n="$(printf '%s\n' "$CHANGED" | grep -c . || true)"
  if [ "$n" -eq 0 ]; then
    note "no files changed between $BASE and $HEAD_REF; no zone touched."
    exit 0
  fi

  highest=routine
  sensitive_paths=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    l="$(level_of "$f")"
    if [ "$l" = sensitive ]; then
      highest=sensitive
      sensitive_paths="$sensitive_paths $f"
    elif [ "$l" != routine ] && [ "$highest" != sensitive ]; then
      highest=standard
    fi
  done <<EOF
$CHANGED
EOF

  echo "Files changed: $n — highest change zone: $highest"

  if [ "$highest" != sensitive ]; then
    exit 0
  fi

  echo "Sensitive paths touched:$sensitive_paths"

  # A sensitive change carries a Risk Record. Standards/RISK_STANDARD.md
  # already defines the line and requires it for any Medium or higher action;
  # a change landing in a sensitive zone is the mechanical trigger this
  # framework was missing. Read from git alone, so every forge gets it.
  # Captured, then matched with a here-string. `git log | grep -q` is the
  # dangerous form of this bug: git log over a real range easily exceeds the
  # 64 KB pipe buffer, and a RISK record on an early commit makes grep -q exit
  # while git keeps writing — SIGPIPE, which `set -o pipefail` returns as the
  # pipeline's status. The check would then report NO record while one is right
  # there, and block a valid change. TROUBLESHOOTING X.
  RANGE_MSGS="$(git log --format=%B "$BASE..$HEAD_REF")"

  # THE RECORD MUST BE A RECORD, not a mention of one (PT2-06). The line is
  # the one Standards/RISK_STANDARD.md defines —
  #     RISK: <hazard> | tier=<Low|Medium|High|Critical> | mitigation=<...> | decided_by=<...>
  # — and the test is the one check-work-units.sh and check-employee-trailers.sh
  # apply to their trailers: it starts at column 0, so an author keeps an
  # example from counting by indenting it, exactly as those checks tell them
  # to. `^[[:space:]]*RISK:` accepted the indented example above and so did
  # the opposite of the rest of the framework.
  #
  # A record is the paragraph that starts with `RISK:` at column 0: commit
  # bodies are wrapped, and most records in this repository's own history run
  # over several lines, so the lines up to the next blank line are read as
  # part of it. It must carry the three fields the Standard names. tier= is
  # checked against the Standard's closed list (case-insensitively);
  # mitigation= and decided_by= are checked for presence only — whether the
  # tier is right and who may decide at that tier are review judgements this
  # script cannot make. Separators are not checked.
  if awk '
    function flush() {
      if (rec != "" &&
          tolower(rec) ~ /tier=(low|medium|high|critical)([^a-z]|$)/ &&
          rec ~ /mitigation=/ && rec ~ /decided_by=/) found = 1
      rec = ""
    }
    /^RISK:/ { flush(); rec = $0; next }
    /^[[:space:]]*$/ { flush(); next }
    rec != "" { rec = rec " " $0 }
    END { flush(); exit(found ? 0 : 1) }
  ' <<< "$RANGE_MSGS"; then
    note "a sensitive zone was touched and a RISK: record is present in the range."
    exit 0
  fi

  err "a sensitive zone was touched and no well-formed RISK: record appears in any commit message in $BASE..$HEAD_REF. A record starts at column 0 (an indented line is read as an example) and carries tier= (Low, Medium, High or Critical), mitigation= and decided_by=. Standards/RISK_STANDARD.md requires the one-line record for any Medium or higher action, and a change landing in a sensitive zone is one. Add it to a commit in this Pull Request — ideally the commit that makes the change, or a follow-up commit in the same PR if it was forgotten (never an amend + force-push): RISK: <hazard> | tier=<...> | mitigation=<...> | decided_by=<...>"
  exit 1
fi

# --- validate ----------------------------------------------------------------
FAILURES=0
fail() { err "$1"; FAILURES=$((FAILURES + 1)); }

echo "Map: $MAP — $ZONE_COUNT zone(s), $TRACKED_COUNT tracked file(s)"

seen_categories=""
while IFS="$TAB" read -r pat lvl cat reason re; do
  [ -n "$pat" ] || continue

  case " $LEVELS " in
    *" $lvl "*) ;;
    *) fail "zone '$pat' has level '${lvl:-<missing>}', which is not one of: $LEVELS" ;;
  esac

  if [ "$lvl" = sensitive ]; then
    if [ "$cat" = "-" ]; then
      fail "zone '$pat' is sensitive and names no category. A sensitive entry without one is not acceptable — it is what makes coverage uncheckable."
    else
      case " $CATEGORIES " in
        *" $cat "*) seen_categories="$seen_categories $cat" ;;
        *) fail "zone '$pat' names category '$cat', which is not in the closed list: $CATEGORIES" ;;
      esac
    fi
  fi

  if [ "$reason" != yes ]; then
    fail "zone '$pat' has no reason. A map without reasons goes stale and nobody dares touch it; the reason states what breaks and why no test would catch it."
  fi

  # Trap 4: a pattern matching nothing reassures without protecting anything.
  # here-string, not `printf | grep -q`: $TRACKED is git ls-files, which in a
  # real project exceeds the pipe buffer, and grep -q short-circuiting it would
  # make a LIVE zone read as dead under pipefail. TROUBLESHOOTING X.
  if ! grep -qE "$re" <<< "$TRACKED"; then
    # Present-but-untracked is not a dead zone. The file exists; it is not
    # committed yet. That is the expected state right after bootstrap, so the
    # honest fix is to stage it, not to delete the entry the installer wrote.
    if untracked_hit="$(grep -m1 -E "$re" <<< "$UNTRACKED")" && [ -n "$untracked_hit" ]; then
      fail "zone '$pat' matches a file that exists but is not tracked yet (e.g. $untracked_hit). The map classifies committed files; stage and commit it — right after bootstrap this is expected, since the installed files are not committed yet. Until then the zone protects nothing."
    else
      fail "zone '$pat' matches no tracked file. A dead entry reassures without keeping anything — trap 4 in Templates/RISK_MAP.md. Remove it, or fix the pattern."
    fi
  fi
done <<EOF
$ZONES
EOF

# Trap 3: verify by computing the level of every tracked file, not by reading
# the list. A core module that fell through to a catch-all is invisible
# otherwise, and a file matching nothing at all is unclassified.
unmatched=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ "$(level_of "$f")" = UNMATCHED ]; then
    unmatched=$((unmatched + 1))
  fi
done <<EOF
$TRACKED
EOF
if [ "$unmatched" -gt 0 ]; then
  fail "$unmatched of $TRACKED_COUNT tracked file(s) match no zone. Every path must resolve to a level; add a final '**' zone at level standard, which is the documented default."
fi

# Coverage of the closed list: present with paths, or declared absent with a
# reason. A false declaration of absence is worse than an omission, so the
# declaration is required to EXIST — whether it is true is a reading task, and
# Templates/RISK_MAP.md says to have someone else do it.
declared_absent="$(grep -E '^[[:space:]]*- category:' "$MAP" | sed 's/.*category:[[:space:]]*//' | tr -d '\r' | tr '\n' ' ')"
for c in $CATEGORIES; do
  case " $seen_categories " in *" $c "*) continue ;; esac
  case " $declared_absent " in *" $c "*) continue ;; esac
  fail "category '$c' is neither mapped to a path nor declared absent. Search for it and record what you found: a category left unmentioned is switched off silently."
done

if [ "$FAILURES" -eq 0 ]; then
  echo "Risk Map is sound: every zone valid and live, every tracked file classified, all 8 categories accounted for."
  exit 0
fi
echo "check-risk-map: $FAILURES problem(s)." >&2
exit 1
