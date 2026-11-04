#!/usr/bin/env bash
# IA Engineering — check-inline-suppression.sh
#
# Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression, applies to every
# Employee and every human: a linter, type-checker or test-runner directive is
# not written into code; a rule that is wrong for the project is tuned in the
# tool's configuration, where the change is a reviewed diff.
#
# The Claude Code hook (ai-runtimes/claude-code/hooks/block-inline-suppression.sh)
# enforces that first, but it only sees Edit / Write / MultiEdit. A directive
# written through the Bash tool (`sed -i`, `tee`, `>`), by a human, or by
# another runtime never reaches it. This script is the check where those paths
# meet: it reads the ADDED lines of the change and reports every one that
# matches a suppression pattern.
#
# USAGE
#
#   check-inline-suppression.sh <base-ref> <head-ref>
#   check-inline-suppression.sh --staged
#
# WHAT IS SCANNED
#
# Only ADDED lines of
#   git diff -U0 --diff-filter=ACMR "$(git merge-base <base> <head>)" <head>
# — the merge base, not the base tip, so content a merge commit introduces is
# in the diff, and lines that already existed are never re-reported. Patterns
# are the ones in suppression-patterns.tsv, shared with the hook and matched
# case-insensitively, one line at a time, with a here-string (never
# `printf | grep -q`: under pipefail grep closing the pipe makes the printf
# take SIGPIPE, and a match near the top of a large payload reads as absent).
#
# EXEMPTIONS — named, by path, none a fall-through
#   - documentation: a FINAL extension of .md .rst .txt .adoc (`notes.md.py`
#     is code). The Standard quotes every directive in order to forbid it.
#   - the framework's own hook test corpus, Adapters/ai-runtimes/claude-code/hooks/tests/
#     (or under an adopter's ia-engineering/): it has to contain what the hook
#     refuses. Anchored to that path, not to any hooks/tests/ directory.
#   - Adapters/scripts/suppression-patterns.tsv itself (same anchoring).
#   - files marked `linguist-generated` in .gitattributes: nobody edits them.
#   - a committed allow file, .ia-engineering/suppression.allow. One entry per
#     line: <path ERE> TAB <line ERE> TAB <reason>. A finding is allowed only
#     when BOTH expressions match. The path expression must be anchored (^...$)
#     and neither expression may match the empty string, so no entry is a
#     blanket. An entry with an empty reason, a missing field, or an expression
#     grep cannot compile is INVALID, and an invalid allow file fails the check:
#     an exemption nobody explained is not an exemption. Blank lines and lines
#     beginning with # are ignored.
#
# THE ALLOW FILE IS READ FROM THE CHECKED-OUT TREE, which on a Pull Request is
# the PR's own. A PR can therefore add the entry that excuses its own
# directive. This check is ADVISORY for that reason and no other: the
# entry is a visible line in the diff, but a required check that the change
# under review can edit is a check it can grade itself on
# (PT-07 of the #112 Purple exercise - a Director decision).
#
# OUT OF SCOPE: the content of a git submodule. The superproject diff shows a
# submodule only as a changed commit id, so an adopter's ia-engineering/ is not
# scanned here; that repository runs its own checks.
#
# A path containing a newline is REFUSED (exit 2, not evaluated): the
# exemption lists are line-oriented, and a name that a list cannot represent
# is a name it could be made to exempt another file with.
#
# OUTPUT
#   path:line: <label>: <the line, at most 200 characters>
# followed by a summary.
#
# EXIT CODES (Standards/CODE_QUALITY_STANDARD.md, The Check Convention, Shell
# Scripts rule 1)
#   0  clean: every added line was scanned and none needs action
#   1  a finding: an added line matches a pattern no allow entry excuses
#   2  could not evaluate, or a usage error: an invalid allow file or pattern
#      file, a git command that failed, a ref or merge base that does not
#      resolve, a changed path holding a newline, or an empty diff over
#      non-merge commits. Nothing was established.

set -uo pipefail
export LC_ALL=C

err() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error::%s\n' "$1" >&2
  else
    printf 'check-inline-suppression: ERROR: %s\n' "$1" >&2
  fi
}

# One place for "git could not tell me", so every such exit says the same
# thing: a check that examined nothing has established nothing.
nothing() { err "$1 — nothing was established."; exit 2; }

STAGED=0
BASE_REF=""
HEAD_REF=""
case "${1:-}" in
  --staged)
    [ "$#" -eq 1 ] || { echo "Usage: $0 <base-ref> <head-ref> | --staged" >&2; exit 2; }
    STAGED=1 ;;
  ""|-*)
    echo "Usage: $0 <base-ref> <head-ref> | --staged" >&2
    echo "  Reports suppression directives on the ADDED lines of a change." >&2
    exit 2 ;;
  *)
    [ "$#" -eq 2 ] || { echo "Usage: $0 <base-ref> <head-ref> | --staged" >&2; exit 2; }
    BASE_REF="$1"; HEAD_REF="$2" ;;
esac

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || nothing "not inside a git work tree"
cd "$TOP" || nothing "cannot enter the work tree root"

PATTERNS_FILE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/suppression-patterns.tsv"
ALLOW_FILE=".ia-engineering/suppression.allow"

WORK="$(mktemp -d)" || nothing "cannot create a scratch directory"
trap 'rm -rf "$WORK"' EXIT

# --- Patterns -------------------------------------------------------------------

[ -f "$PATTERNS_FILE" ] || nothing "$PATTERNS_FILE is missing, so no pattern can be applied"

LABELS=()
REGEXES=()
while IFS= read -r row || [ -n "$row" ]; do
  row="${row%$'\r'}"
  case "$row" in ''|'#'*) continue ;; esac
  case "$row" in *$'\t'*) ;; *) nothing "suppression-patterns.tsv: row without a TAB: $row" ;; esac
  label="${row%%$'\t'*}"
  re="${row#*$'\t'}"
  if [ -z "$label" ] || [ -z "$re" ]; then nothing "suppression-patterns.tsv: empty label or pattern: $row"; fi
  rc=0; grep -E -- "$re" </dev/null >/dev/null 2>&1 || rc=$?
  [ "$rc" -le 1 ] || nothing "suppression-patterns.tsv: '$label' is not a valid extended regular expression"
  LABELS+=("$label")
  REGEXES+=("$re")
done < "$PATTERNS_FILE"
[ "${#LABELS[@]}" -gt 0 ] || nothing "suppression-patterns.tsv holds no patterns"

# --- Allow file -----------------------------------------------------------------

ALLOW_PATHS=()
ALLOW_LINES=()
if [ -f "$ALLOW_FILE" ]; then
  n=0
  while IFS= read -r row || [ -n "$row" ]; do
    n=$((n + 1))
    row="${row%$'\r'}"
    case "$row" in ''|'#'*) continue ;; esac
    ap="${row%%$'\t'*}"
    rest="${row#*$'\t'}"
    case "$row" in *$'\t'*$'\t'*) ;; *)
      err "$ALLOW_FILE:$n: an entry is <path ERE> TAB <line ERE> TAB <reason>; this one has fewer than three fields. An invalid allow file fails the check." ; exit 2 ;;
    esac
    al="${rest%%$'\t'*}"
    reason="${rest#*$'\t'}"
    if [ -z "${reason//[[:space:]]/}" ]; then
      err "$ALLOW_FILE:$n: the entry has an empty reason. An exemption nobody explained is not an exemption; the file is invalid."
      exit 2
    fi
    if [ -z "$ap" ] || [ -z "$al" ]; then
      err "$ALLOW_FILE:$n: an empty path or line expression would match everything. The file is invalid."
      exit 2
    fi
    for re in "$ap" "$al"; do
      rc=0; grep -E -- "$re" </dev/null >/dev/null 2>&1 || rc=$?
      if [ "$rc" -gt 1 ]; then
        err "$ALLOW_FILE:$n: '$re' is not a valid extended regular expression. The file is invalid."
        exit 2
      fi
      # An expression that matches the empty string matches every line or path.
      if grep -qE -- "$re" <<< ""; then
        err "$ALLOW_FILE:$n: '$re' matches the empty string, so the entry would allow everything. The file is invalid."
        exit 2
      fi
    done
    # The path expression is anchored, so 'a\.py' cannot excuse src/a.py.py.
    case "$ap" in
      '^'*'$') ;;
      *) err "$ALLOW_FILE:$n: the path expression '$ap' must be anchored (^...$). The file is invalid."; exit 2 ;;
    esac
    ALLOW_PATHS+=("$ap")
    ALLOW_LINES+=("$al")
  done < "$ALLOW_FILE"
fi

# --- The diff -------------------------------------------------------------------

# Explicit prefixes and quotePath: a user's diff.noprefix or diff.mnemonicPrefix
# would otherwise change what the header parse below is reading.
GITD=(git -c core.quotePath=false -c diff.renames=true diff --no-color --no-ext-diff --no-textconv
      --src-prefix=a/ --dst-prefix=b/ --diff-filter=ACMRT)

if [ "$STAGED" -eq 1 ]; then
  SPEC=(--cached)
  DESC="staged changes"
else
  git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null || nothing "cannot resolve base '$BASE_REF'"
  git rev-parse --verify --quiet "${HEAD_REF}^{commit}" >/dev/null || nothing "cannot resolve head '$HEAD_REF'"
  MB="$(git merge-base "$BASE_REF" "$HEAD_REF" 2>/dev/null)" || nothing "no merge base between '$BASE_REF' and '$HEAD_REF'"
  [ -n "$MB" ] || nothing "no merge base between '$BASE_REF' and '$HEAD_REF'"
  SPEC=("$MB" "$HEAD_REF")
  DESC="${MB:0:12}..${HEAD_REF}"
fi

"${GITD[@]}" --name-only -z "${SPEC[@]}" > "$WORK/names" 2>/dev/null || nothing "git diff --name-only failed for $DESC"
# --text: a file git classifies as binary (a NUL byte, or -diff / binary in
# .gitattributes) prints "Binary files differ" and no lines; its directive would
# never be scanned. The added lines are scanned as text whatever git thinks.
"${GITD[@]}" --text -U0 "${SPEC[@]}" > "$WORK/diff" 2>/dev/null || nothing "git diff failed for $DESC"

# --- Exemptions, by path --------------------------------------------------------

# One check-attr call for the whole list (NUL-separated triples: path, attribute,
# value) rather than one process per file.
git check-attr -z --stdin linguist-generated < "$WORK/names" > "$WORK/attrs" 2>/dev/null \
  || nothing "git check-attr failed for $DESC"
: > "$WORK/generated"
while IFS= read -r -d '' ap_ && IFS= read -r -d '' _ && IFS= read -r -d '' av_; do
  if [ "$av_" = "set" ] || [ "$av_" = "true" ]; then printf '%s\n' "$ap_" >> "$WORK/generated"; fi
done < "$WORK/attrs"

FILES=0
EXEMPT=0
: > "$WORK/exempt"
while IFS= read -r -d '' p; do
  [ -n "$p" ] || continue
  case "$p" in
    *$'\n'*) nothing "a changed path contains a newline (the exemption lists are line-oriented and cannot represent it)" ;;
  esac
  FILES=$((FILES + 1))
  skip=0
  # Extensions fold case (README.MD is documentation); the path exemptions
  # below do not: on a case-sensitive filesystem a differently-cased directory
  # is a different directory.
  shopt -s nocasematch
  case "$p" in
    *.md|*.rst|*.txt|*.adoc) skip=1 ;;
  esac
  shopt -u nocasematch
  case "$p" in
    Adapters/ai-runtimes/claude-code/hooks/tests/*|ia-engineering/Adapters/ai-runtimes/claude-code/hooks/tests/*) skip=1 ;;
    Adapters/scripts/suppression-patterns.tsv|ia-engineering/Adapters/scripts/suppression-patterns.tsv) skip=1 ;;
  esac
  if [ "$skip" -eq 0 ] && grep -qxF -- "$p" "$WORK/generated"; then skip=1; fi
  if [ "$skip" -eq 1 ]; then
    EXEMPT=$((EXEMPT + 1))
    printf '%s\n' "$p" >> "$WORK/exempt"
  fi
done < "$WORK/names"

# A diff of zero files is a back-merge or wrong refs. Wrong refs are caught
# above; here the only remaining cause is that a non-merge commit changed
# nothing, which the caller should hear about rather than read as clean.
if [ "$FILES" -eq 0 ] && [ "$STAGED" -eq 0 ]; then
  NONMERGE="$(git rev-list --count --no-merges "$MB..$HEAD_REF" 2>/dev/null)" || nothing "cannot count commits in $DESC"
  if [ "${NONMERGE:-0}" -gt 0 ]; then
    nothing "the diff $DESC lists no files although it holds $NONMERGE non-merge commit(s)"
  fi
  printf 'check-inline-suppression: clean — %s lists no files (a back-merge introduces no content); nothing to scan.\n' "$DESC"
  exit 0
fi

# --- Added lines: meta (path, line) and text kept in parallel files --------------
#
# `+++ ` is a path header only between a `diff --git` line and its first hunk.
# An added line whose text begins `++ ` reads `+++ ` in the diff, and taking it
# for a header would misattribute every later line to a path that does not
# exist. Paths git had to quote are not in the exempt list, so they are scanned:
# the failure direction is over-reporting.
awk -v meta="$WORK/meta" -v text="$WORK/text" -v exf="$WORK/exempt" '
  BEGIN { while ((getline line < exf) > 0) ex[line] = 1; close(exf) }
  /^diff --git / { inhdr = 1; path = ""; next }
  inhdr && /^\+\+\+ / { path = substr($0, 5); sub(/^b\//, "", path); sub(/\t$/, "", path); next }
  /^@@ / {
    inhdr = 0
    s = $0; sub(/^@@ -[0-9,]+ \+/, "", s); sub(/[ ,].*$/, "", s)
    ln = s + 0 - 1
    next
  }
  !inhdr && /^\+/ {
    ln++
    if (path in ex) next
    print path "\t" ln >> meta
    print substr($0, 2) >> text
  }
' "$WORK/diff"
[ -f "$WORK/meta" ] || : > "$WORK/meta"
[ -f "$WORK/text" ] || : > "$WORK/text"

LINES="$(wc -l < "$WORK/text" | tr -d ' ')"
SCANNED_FILES=$((FILES - EXEMPT))

# --- Match ----------------------------------------------------------------------

FINDINGS=0
ALLOWED=0
: > "$WORK/reported"
i=0
while [ "$i" -lt "${#LABELS[@]}" ]; do
  label="${LABELS[$i]}"
  re="${REGEXES[$i]}"
  i=$((i + 1))
  rc=0
  grep -inaE -- "$re" "$WORK/text" > "$WORK/hits" 2>/dev/null || rc=$?
  [ "$rc" -le 1 ] || nothing "grep failed applying the '$label' pattern"
  while IFS= read -r hit || [ -n "$hit" ]; do
    [ -n "$hit" ] || continue
    ln_in_text="${hit%%:*}"
    grep -qx -- "$ln_in_text" "$WORK/reported" && continue
    printf '%s\n' "$ln_in_text" >> "$WORK/reported"
    content="${hit#*:}"
    content="${content%$'\r'}"
    where="$(sed -n "${ln_in_text}p" "$WORK/meta")"
    fpath="${where%%$'\t'*}"
    fline="${where#*$'\t'}"
    allowed=0
    j=0
    while [ "$j" -lt "${#ALLOW_PATHS[@]}" ]; do
      if grep -qE -- "${ALLOW_PATHS[$j]}" <<< "$fpath" && grep -qE -- "${ALLOW_LINES[$j]}" <<< "$content"; then
        allowed=1; break
      fi
      j=$((j + 1))
    done
    if [ "$allowed" -eq 1 ]; then
      ALLOWED=$((ALLOWED + 1))
      continue
    fi
    FINDINGS=$((FINDINGS + 1))
    printf '%s:%s: %s: %s\n' "$fpath" "$fline" "$label" "${content:0:200}"
  done < "$WORK/hits"
done

printf 'check-inline-suppression: scanned %s file(s) (%s exempt), %s added line(s) against %s pattern(s) in %s; %s allowed by %s; %s finding(s).\n' \
  "$SCANNED_FILES" "$EXEMPT" "$LINES" "${#LABELS[@]}" "$DESC" "$ALLOWED" \
  "$([ -f "$ALLOW_FILE" ] && printf '%s (%s entr%s)' "$ALLOW_FILE" "${#ALLOW_PATHS[@]}" "$([ "${#ALLOW_PATHS[@]}" -eq 1 ] && printf y || printf ies)" || printf 'no allow file')" \
  "$FINDINGS"

if [ "$FINDINGS" -gt 0 ]; then
  {
    printf 'check-inline-suppression: Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression governs.\n'
    printf '  Tune the rule in the tool'"'"'s configuration, or satisfy it; do not silence it on the line.\n'
    printf '  A false positive configuration cannot scope: add <path ERE> TAB <line ERE> TAB <reason> to %s.\n' "$ALLOW_FILE"
  } >&2
  exit 1
fi

printf 'check-inline-suppression: clean\n'
exit 0
