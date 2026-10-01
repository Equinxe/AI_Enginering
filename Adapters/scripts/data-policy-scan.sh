#!/usr/bin/env bash
# IA Engineering — data-policy-scan.sh
#
# Mechanically enforces Standards/DATA_PROTECTION_STANDARD.md: real data,
# secrets, and operational state never enter version control.
#
# ONE SCRIPT, THREE MODES, so the client-side hook and the server-side CI job
# apply the same patterns. Two copies of a pattern list drift; the hook would
# then pass what CI rejects, or the reverse, and the developer learns which one
# is authoritative only by being surprised.
#
#   --staged              paths and added lines about to be committed
#                         (called by Adapters/git-hooks/pre-commit)
#   --tree [<rev>]        every path in a tree (default HEAD)
#   --history <range>     every path INTRODUCED by the commits in <range>,
#                         including paths added and deleted again, plus every
#                         added line — this is the check that counts, because a
#                         file added and removed within a branch is absent from
#                         the tree and present in every clone that fetched it
#
# WHAT IS FLAGGED (paths):
#   - anything under the local data directory (default local_test_data/)
#   - .ia-engineering/SESSION_STATE.md — operational state, never committed
#   - .env and .env.* (except .env.example / .env.sample / .env.template /
#     .env.dist, which hold variable NAMES only)
#   - SSH private key names and key-material extensions
#   - office document formats, database dumps, archives of dumps
#   - text data formats (csv, json, xml, sql, ...) whose NAME is evocative of
#     a real export: dump, export, backup, client, customer, patient, payroll,
#     invoice, prod. Plain `src/export.ts` is not flagged: the name test applies
#     to data-bearing extensions only, because a hook that fires on ordinary
#     source files is a hook developers learn to bypass — and --no-verify
#     disarms every other hook in the same motion.
#
# WHAT IS FLAGGED (content, added lines only):
#   High-confidence secret shapes: private key blocks, AWS access key IDs,
#   GitHub tokens, Slack tokens, Stripe live/test keys. No entropy heuristics —
#   see the noise argument above. The matched VALUE is never printed; the path,
#   the line number, and the pattern's name are.
#   Lines are read as text whatever git thinks of the file (--text), so a path
#   marked -diff or binary in .gitattributes is scanned like any other. In
#   --history, what a MERGE itself authored (a conflict resolution, a line or a
#   file added in the merge commit) is scanned via the dense combined diff
#   (--cc, the same as --diff-merges=dense-combined): it shows only what is in
#   the merge result and in NONE of its parents. What a merge merely carries
#   from a parent is not re-read — it was scanned where it was authored, or it
#   sits on the excluded side of the range. --diff-merges=first-parent was the
#   alternative and was rejected: it re-reads everything the second parent
#   brought in, so `develop` merged into a feature branch would be re-scanned
#   and could be refused for lines an earlier review or the allow file settled.
#
# EXEMPTIONS — named, never fall-throughs:
#   - a basename beginning with SYNTHETIC_ (anchored: a directory called
#     synthetic/ exempts nothing, a file renamed to contain the word exempts
#     nothing)
#   - a committed allow file, default .ia-engineering/data-policy.allow, one
#     extended regular expression per line matched against the full path;
#     lines beginning with "content:" are matched against flagged content
#     lines instead; "#" comments and blank lines ignored. The file is
#     committed so every developer and CI share one list.
#
# Filenames are read with core.quotePath=false and NUL separators where git
# offers them, so a non-ASCII or otherwise unusual name is matched as itself
# rather than as git's quoted rendering of it — a real file once escaped a
# pattern that way.
#
# Configuration (environment, all optional):
#   IAENG_LOCAL_DATA_DIR    directory name treated as local-only (local_test_data)
#   IAENG_DATA_ALLOW_FILE   allow file path (.ia-engineering/data-policy.allow)
#
# Exit codes: 0 clean, 1 findings, 2 usage or environment error.
# Always prints what it scanned (path count, added-line count) so a clean
# result shows its denominator rather than just an exit status.

set -uo pipefail
export LC_ALL=C

LOCAL_DATA_DIR="${IAENG_LOCAL_DATA_DIR:-local_test_data}"
ALLOW_FILE="${IAENG_DATA_ALLOW_FILE:-.ia-engineering/data-policy.allow}"

DOC_EXTENSIONS="xlsx xls xlsm xlsb pdf docx doc pptx ppt odt ods odp rtf"
DUMP_EXTENSIONS="sqlite sqlite3 db dump bak mdb accdb pst ost sav"
KEY_EXTENSIONS="pem key p12 pfx jks keystore ppk"
TEXT_DATA_EXTENSIONS="csv tsv json jsonl ndjson xml sql txt parquet"
EVOCATIVE_NAMES='(dump|export|backup|client|customer|patient|payroll|salar|invoice|facture|prod)'

# name|ERE — the name is what gets printed; the value never is.
SECRET_PATTERNS=(
  'private-key-block|-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'aws-access-key-id|AKIA[0-9A-Z]{16}'
  'github-token|gh[pousr]_[A-Za-z0-9]{36,}'
  'slack-token|xox[baprs]-[0-9A-Za-z-]{10,}'
  'stripe-key|sk_(live|test)_[0-9A-Za-z]{20,}'
)

usage() {
  # Stop at the first line that is not a comment, rather than at a hard-coded
  # line number. The number was 66 and the header had grown past it, so --help
  # ended by printing `set -uo pipefail` and `export LC_ALL=C` — a range that
  # silently stops describing the file it documents the moment either changes.
  sed -n '2,$p' "$0" | sed -n '/^#/!q; s/^# \{0,1\}//p'
}

die() { printf 'data-policy: %s\n' "$1" >&2; exit 2; }

MODE=""
ARG=""
case "${1:-}" in
  --staged)  MODE=staged ;;
  --tree)    MODE=tree;    ARG="${2:-HEAD}" ;;
  --history) MODE=history; ARG="${2:-}"; [ -n "$ARG" ] || die "--history needs a <range>" ;;
  --help|-h) usage; exit 0 ;;
  "")        usage >&2; exit 2 ;;
  *)         die "unknown option '$1' (see --help)" ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree"

# --- Allow list ----------------------------------------------------------------

PATH_ALLOW=()
CONTENT_ALLOW=()
if [ -f "$ALLOW_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      ''|'#'*) continue ;;
      content:*) CONTENT_ALLOW+=("${line#content:}") ;;
      *) PATH_ALLOW+=("$line") ;;
    esac
  done < "$ALLOW_FILE"
fi

allowed_path() {
  local p="$1" re
  for re in ${PATH_ALLOW[@]+"${PATH_ALLOW[@]}"}; do
    if printf '%s\n' "$p" | grep -qE -- "$re"; then return 0; fi
  done
  return 1
}

allowed_content() {
  local l="$1" re
  for re in ${CONTENT_ALLOW[@]+"${CONTENT_ALLOW[@]}"}; do
    if printf '%s\n' "$l" | grep -qE -- "$re"; then return 0; fi
  done
  return 1
}

# --- Path classification -------------------------------------------------------
# Prints the reason a path is refused; prints nothing for an acceptable path.

classify_path() {
  local p="$1" base lower ext
  base="${p##*/}"

  case "$base" in SYNTHETIC_*) return 0 ;; esac
  if allowed_path "$p"; then return 0; fi

  case "/$p" in
    */"$LOCAL_DATA_DIR"/*)
      printf 'inside the local data directory %s/ — that directory is never committed\n' "$LOCAL_DATA_DIR"; return 0 ;;
  esac
  case "$p" in
    .ia-engineering/SESSION_STATE.md|SESSION_STATE.md)
      printf 'operational state file — never committed (Templates/SESSION_STATE.md)\n'; return 0 ;;
  esac

  lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"

  case "$lower" in
    .env.example|.env.sample|.env.template|.env.dist) return 0 ;;
    .env|.env.*) printf 'environment file — secrets live outside the repository (.env.example holds names only)\n'; return 0 ;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519) printf 'SSH private key\n'; return 0 ;;
  esac

  ext="${lower##*.}"
  [ "$ext" = "$lower" ] && ext=""
  [ -n "$ext" ] || return 0

  case " $DOC_EXTENSIONS " in *" $ext "*)
    printf 'document format (.%s) — real documents belong in %s/; a synthetic fixture carries the SYNTHETIC_ prefix\n' "$ext" "$LOCAL_DATA_DIR"; return 0 ;;
  esac
  case " $DUMP_EXTENSIONS " in *" $ext "*)
    printf 'database dump or mailbox format (.%s)\n' "$ext"; return 0 ;;
  esac
  case " $KEY_EXTENSIONS " in *" $ext "*)
    printf 'key material format (.%s)\n' "$ext"; return 0 ;;
  esac
  case " $TEXT_DATA_EXTENSIONS " in *" $ext "*)
    if printf '%s\n' "$lower" | grep -qE -- "$EVOCATIVE_NAMES"; then
      printf 'text data (.%s) with a name that reads like a real export — rename with SYNTHETIC_ if it is synthetic, move to %s/ if it is not\n' "$ext" "$LOCAL_DATA_DIR"; return 0
    fi ;;
  esac
  return 0
}

# --- Content scan --------------------------------------------------------------
# Reads a unified diff on stdin; prints "path<TAB>lineno<TAB>pattern-name" for
# every ADDED line matching a secret pattern. Values are never echoed.

scan_diff_content() {
  local re_all="" entry
  for entry in "${SECRET_PATTERNS[@]}"; do
    re_all="$re_all|${entry#*|}"
  done
  re_all="${re_all#|}"

  awk -v re="$re_all" '
    /^\+\+\+ / { path = substr($0, 5); sub(/^b\//, "", path); next }
    /^@@ /     { split($0, h, /\+/); split(h[2], n, /[, ]/); ln = n[1] - 1; next }
    /^\+/      { ln++; if ($0 ~ re) print path "\t" ln "\t" substr($0, 2); next }
    /^[^-]/    { ln++ }
  '
}

# Reads a COMBINED diff (git log --cc) on stdin. A hunk header carries one "@"
# pair-plus-one per parent ("@@@" for two parents), and every content line starts
# with one column per parent: "+" = absent from that parent, " " = present, "-" =
# removed relative to it. A line is merge-authored when EVERY column is "+".
# Line numbers count result lines only (no "-" in any column).
#   count -> prints the number of merge-authored lines (the denominator)
#   match -> prints "path<TAB>lineno<TAB>text" for those matching a secret shape
# File headers are recognised only between a "diff --" line and the first hunk,
# so an added line whose text begins with "++ " is not mistaken for one.
scan_combined_diff() {
  local re_all="" entry
  for entry in "${SECRET_PATTERNS[@]}"; do
    re_all="$re_all|${entry#*|}"
  done
  re_all="${re_all#|}"

  awk -v re="$re_all" -v mode="$1" '
    /^diff --/ { inhunk = 0; next }
    !inhunk && /^\+\+\+ / { path = substr($0, 5); sub(/^b\//, "", path); next }
    /^@@@+ / {
      inhunk = 1
      np = index($0, " ") - 2
      s = $0; sub(/^[^+]*[+]/, "", s); split(s, n, /[, ]/); ln = n[1] - 1
      # Built by a loop: a "*" width in printf is not POSIX awk, and the CI
      # runner awk is mawk.
      allplus = ""; for (i = 0; i < np; i++) allplus = allplus "+"
      next
    }
    inhunk && /^\\/ { next }
    inhunk {
      col = substr($0, 1, np)
      if (col ~ /-/) next
      ln++
      if (col == allplus) {
        total++
        if (mode == "match" && substr($0, np + 1) ~ re) print path "\t" ln "\t" substr($0, np + 1)
      }
    }
    END { if (mode == "count") print total + 0 }
  '
}

name_of_pattern() {
  local l="$1" entry
  for entry in "${SECRET_PATTERNS[@]}"; do
    if printf '%s\n' "$l" | grep -qE -- "${entry#*|}"; then printf '%s' "${entry%%|*}"; return 0; fi
  done
  printf 'secret'
}

# --- Collect inputs per mode ---------------------------------------------------

FINDINGS=0
PATHS_SCANNED=0
LINES_SCANNED=0

report_path() { FINDINGS=$((FINDINGS + 1)); printf 'data-policy: REFUSED  %s\n    %s\n' "$1" "$2" >&2; }
report_line() { FINDINGS=$((FINDINGS + 1)); printf 'data-policy: REFUSED  %s:%s\n    added line matches secret pattern <%s> — revoke it first, then remove it\n' "$1" "$2" "$3" >&2; }

scan_paths_nul() {
  local p reason
  while IFS= read -r -d '' p; do
    [ -n "$p" ] || continue
    PATHS_SCANNED=$((PATHS_SCANNED + 1))
    reason="$(classify_path "$p")"
    [ -z "$reason" ] || report_path "$p" "$reason"
  done
}

scan_paths_lines() {
  local p reason
  while IFS= read -r p || [ -n "$p" ]; do
    [ -n "$p" ] || continue
    PATHS_SCANNED=$((PATHS_SCANNED + 1))
    reason="$(classify_path "$p")"
    [ -z "$reason" ] || report_path "$p" "$reason"
  done
}

scan_content() {
  local path ln text
  while IFS=$'\t' read -r path ln text; do
    LINES_SCANNED=$((LINES_SCANNED + 1))
    allowed_content "$text" && continue
    report_line "$path" "$ln" "$(name_of_pattern "$text")"
  done
}

count_added_lines() {
  # Denominator for the content scan: how many added lines were examined.
  grep -c '^+[^+]' || true
}

case "$MODE" in
  staged)
    scan_paths_nul < <(git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR -z)
    # --text: see the history branch below. A file git classifies as binary
    # (a NUL byte, or -diff / binary in .gitattributes) prints "Binary files
    # differ" and no lines, so a secret added to it would never be scanned.
    DIFF="$(git -c core.quotePath=false diff --cached --text -U0 --no-color --no-ext-diff --no-textconv --diff-filter=ACMR)"
    ADDED="$(printf '%s\n' "$DIFF" | count_added_lines)"
    scan_content < <(printf '%s\n' "$DIFF" | scan_diff_content)
    LINES_SCANNED="$ADDED"
    ;;
  tree)
    git rev-parse --verify --quiet "$ARG^{tree}" >/dev/null || die "cannot resolve tree '$ARG'"
    scan_paths_nul < <(git -c core.quotePath=false ls-tree -r -z --name-only "$ARG")
    ;;
  history)
    # rev-list --objects lists "sha path" for every blob and tree reachable in
    # the range and not from its excluded side — so a file added in commit 3
    # and deleted in commit 4 is still listed. Commits have no path field and
    # are dropped by the NF test. Paths are newline-separated here (git offers
    # no -z for rev-list); a newline inside a filename is the one shape this
    # mode cannot represent, and it is refused by the tree scan of the same
    # range's head in the CI job.
    git rev-list --objects "$ARG" >/dev/null 2>&1 || die "cannot resolve range '$ARG'"

    # TWO SOURCES, UNIONED, because neither alone is complete.
    #
    # `rev-list --objects` enumerates each OBJECT once. A blob already
    # reachable from the excluded side is never listed, so its path is never
    # classified — and an empty file hits this every time, because the empty
    # blob almost always already exists. Demonstrated: `.env` added empty and
    # deleted again inside a two-commit range scanned 0 paths and reported
    # clean. That is the exact scenario this mode exists for.
    #
    # `log --name-only --diff-filter=ACMR` enumerates each PATH touched by
    # each commit, regardless of whether its blob is new, which covers that
    # gap. It is unioned with the object walk rather than replacing it, so a
    # path reachable as an object but not named by any diff in the range is
    # still classified.
    #
    # `--cc` (PT2-01): without it `log --name-only` prints nothing for a merge
    # commit, so a path the MERGE ITSELF added (`git merge --no-commit`, then
    # `git add .env`) was named by no diff — and when its blob already existed
    # on the excluded side (an empty .env always does, once any empty file
    # has) the object walk missed it too. The combined diff names only paths
    # whose merge result differs from EVERY parent: a clean merge, or a
    # resolution that takes one side verbatim, names nothing, so the all-merge
    # back-merge range below still enumerates zero paths.
    scan_paths_lines < <(
      {
        git -c core.quotePath=false log --cc --format= --name-only --diff-filter=ACMR "$ARG"
        git -c core.quotePath=false rev-list --objects "$ARG" \
          | awk 'NF > 1 { sub(/^[0-9a-f]+ /, ""); print }'
      } | sort -u
    )
    # --text (PT2-02): a path marked -diff or binary in .gitattributes, or a
    # file with a NUL byte, otherwise prints "Binary files differ" and no
    # lines; the secret added to it would never reach the matcher. The added
    # lines are scanned as text whatever git thinks of the file. A genuinely
    # binary file then yields garbage "lines", which only matter if they match
    # a secret shape — the same trade the suppression check makes.
    # --no-textconv and --no-ext-diff stay: a configured converter or external
    # driver must not rewrite the bytes being scanned.
    DIFF="$(git -c core.quotePath=false log -p --text -U0 --no-color --no-ext-diff --no-textconv --format= "$ARG")"
    ADDED="$(printf '%s\n' "$DIFF" | count_added_lines)"
    scan_content < <(printf '%s\n' "$DIFF" | scan_diff_content)

    # MERGE-AUTHORED CONTENT (PT2-01). `log -p` prints nothing for a merge, so a
    # line typed while resolving a conflict, or smuggled into a merge commit,
    # was in no patch at all. `--cc` is the dense combined diff: it shows only
    # the lines of the merge result that are in NONE of the parents (columns of
    # every parent are "+"). That is exactly what the merge authored — a line
    # present in one parent was already in a commit of this range (scanned
    # above) or on the excluded side (already accepted there). Choosing
    # `--diff-merges=first-parent` instead would re-scan everything a merge
    # brought in from the other side, including a whole `develop` merged into a
    # feature branch, and could refuse lines the allow file or earlier review
    # already settled. A line a resolution copies from a parent is not
    # re-scanned, and need not be. The content allow file applies to these
    # lines exactly as to ordinary added lines (same scan_content).
    MERGE_DIFF="$(git -c core.quotePath=false log --merges --cc --text -U0 --no-color --no-ext-diff --no-textconv --format= "$ARG")"
    MERGE_ADDED="$(printf '%s\n' "$MERGE_DIFF" | scan_combined_diff count)"
    scan_content < <(printf '%s\n' "$MERGE_DIFF" | scan_combined_diff match)
    LINES_SCANNED=$((ADDED + MERGE_ADDED))
    ;;
esac

# --- Verdict -----------------------------------------------------------------

# A ZERO-PATH SCAN OVER A NON-EMPTY RANGE IS A FAILURE, not a clean result.
# The Check Convention's third rule — a check that iterates a set reports its
# denominator — is only worth anything if a denominator of zero is treated as
# the absence of evidence it is. This scan printed "scanned 0 path(s)" and
# "clean" over a two-commit range while the defect above hid a staged `.env`.
#
# WITH ONE EXCEPTION, ESTABLISHED THE SAME WAY THE RULE WAS. A range whose
# commits are ALL merges introduces no objects and touches no paths, by
# construction: every blob in it is already reachable from the excluded side,
# which is what makes it a merge rather than a change. Workflows/RELEASE.md
# Step 8 carries `main` back into `develop` through exactly such a range, and
# in the normal case that is the only kind of Pull Request that produces one.
# Refusing it made this required check unsatisfiable for the back-merge, which
# in turn made the NEXT release unmergeable once `main` required branches to
# be up to date — found on v0.0.12, alongside the same defect in PR Size.
#
# The exception is a named allow-list of one shape, not a fall-through: a
# range holding even one non-merge commit and still enumerating no paths is
# the original defect and still fails. Nothing is waved through on the
# strength of its own emptiness.
if [ "$MODE" = history ] && [ "$PATHS_SCANNED" -eq 0 ]; then
  COMMITS="$(git rev-list --count "$ARG" 2>/dev/null || echo 0)"
  NONMERGE="$(git rev-list --count --no-merges "$ARG" 2>/dev/null || echo 0)"
  if [ "${COMMITS:-0}" -gt 0 ] && [ "${NONMERGE:-0}" -eq 0 ]; then
    printf 'data-policy: mode=history scanned 0 path(s) over %s commit(s), every one a merge — a back-merge introduces no objects, so there is nothing to scan.\n' "$COMMITS"
  elif [ "${COMMITS:-0}" -gt 0 ]; then
    printf 'data-policy: mode=history scanned 0 path(s) over %s commit(s), %s of them not merges — the path enumeration produced nothing for a range that is not empty.\n' "$COMMITS" "$NONMERGE" >&2
    printf '  This is reported rather than passed: a scan that examined nothing has established nothing.\n' >&2
    exit 1
  fi
fi

printf 'data-policy: mode=%s scanned %s path(s), %s added line(s), allow-file=%s (%s path rule(s), %s content rule(s))\n' \
  "$MODE" "$PATHS_SCANNED" "$LINES_SCANNED" \
  "$([ -f "$ALLOW_FILE" ] && printf '%s' "$ALLOW_FILE" || printf 'none')" \
  "${#PATH_ALLOW[@]}" "${#CONTENT_ALLOW[@]}"

if [ "$FINDINGS" -gt 0 ]; then
  {
    printf 'data-policy: %s finding(s). Standards/DATA_PROTECTION_STANDARD.md governs.\n' "$FINDINGS"
    printf '  Real data      -> git rm --cached <path>; move it to %s/ (gitignored)\n' "$LOCAL_DATA_DIR"
    printf '  Synthetic      -> rename so the basename starts with SYNTHETIC_\n'
    printf '  Legitimate     -> add an anchored regex to %s and commit that file\n' "$ALLOW_FILE"
    printf '  Secret         -> REVOKE it before anything else; then remove it\n'
    printf '  Never          -> git commit --no-verify: it disarms every other hook too\n'
  } >&2
  exit 1
fi

printf 'data-policy: clean\n'
exit 0
