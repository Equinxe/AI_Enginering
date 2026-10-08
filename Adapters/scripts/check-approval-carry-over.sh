#!/usr/bin/env bash
# IA Engineering — check-approval-carry-over.sh
#
# Decides, mechanically, whether the reviews given on a Pull Request's earlier
# head carry over to its new head after the branch only merged `develop` in,
# and prints the one-line record the Main Agent pastes on the Pull Request.
#
# THE RULE — Director decision, 7 October 2026. Core/MAIN_AGENT_CONDUCT.md,
# the Main Agent's merge into develop, condition 1, in the words of PR #225 at
# 9941d0b (rewrapped, not reworded). If that text changes, this quote and the
# checks below change with it, in the same review:
#
#   The carry-over holds only when the approved head is an ancestor of the new
#   head; every commit on the first-parent line from the approved head to the
#   new head is a merge with exactly two parents, whose second parent is an
#   ancestor of `origin/develop`; each of those merges is exactly the merge
#   git makes on its own from its two parents, everywhere except
#   `Registry/work-units.yml`; and in `Registry/work-units.yml` the new head
#   holds exactly the entries git's own merge would hold, each byte for byte
#   the same, in any order, with the Pull Request's own entry byte for byte
#   the same on both heads. A conflict resolution that only orders registry
#   entries therefore passes. Any other change made by hand in the merge
#   fails, even one that only moves a Pull Request line.
#
#   The Main Agent checks this with
#   `Adapters/scripts/check-approval-carry-over.sh <approved head> <new head>`,
#   run after `git fetch origin` and before the merge. Exit 0 means the
#   approvals carry over: the script prints a one-line record, and the Main
#   Agent pastes that line on the Pull Request as one comment before merging.
#   Any other result (1: no carry-over; 2: error), or a missing record, means
#   no approval carries over. If the script is missing or cannot run, no
#   approval carries over; the criteria above are never checked by hand.
#
# HOW EACH CLAUSE IS DECIDED
#
#   (a) "the approved head is an ancestor of the new head":
#       `git merge-base --is-ancestor <approved> <new>`.
#
#   (b) "every commit on the first-parent line from the approved head to the
#       new head is a merge with exactly two parents, whose second parent is an
#       ancestor of origin/develop": the commits `git rev-list --first-parent
#       <approved>..<new>` lists, oldest first. The oldest must have the
#       approved head as its FIRST parent, or the line does not start at the
#       approved head: a merge can reach it through its second parent instead.
#       Each must have exactly two parents, and its second parent must be an
#       ancestor of the base (`git merge-base --is-ancestor`; --base names a
#       ref other than origin/develop).
#
#   (c) "exactly the merge git makes on its own from its two parents,
#       everywhere except Registry/work-units.yml": git's own merge is
#       merge_classify_automatic in merge-classify.sh, the automatic merge
#       check-work-units.sh and check-employee-trailers.sh already classify
#       merges against: attributes pinned to the empty tree, merge settings
#       pinned to git's defaults. It must conflict nowhere but in the registry
#       (a conflict anywhere else was resolved by hand), and
#       `git diff-tree -r --no-renames --ignore-submodules=none --no-relative`
#       between its tree and the merge's must name no other path. Trees are
#       compared by object id, so no diff setting, attribute, line-ending
#       conversion, locale or shell can make two different files look equal.
#       --ignore-submodules=none is load-bearing: with `ignore = all` in
#       .gitmodules even the plumbing diff-tree hides a moved submodule pointer.
#
#   (d) "in Registry/work-units.yml the new head holds exactly the entries
#       git's own merge would hold, each byte for byte the same, in any order":
#       checked at each merge on the line, against git's own merge of that
#       merge's two parents (with one merge, the usual case, that merge is the
#       new head). A resolution that only orders entries passes; one that drops
#       or edits another Work Unit's entry, keeps a conflict marker, or adds a
#       line fails, as any other change made by hand in the merge does.
#       - An entry is a block, per the registry's parsing contract: a line
#         starting `  - id: ` and every line up to the next one. The lines
#         before the first entry are one more block, the header.
#       - Blank lines (empty, or a lone CR) that end a block are separators,
#         not content: moving an entry moves them.
#       - Where git's own merge conflicts in the registry, both sides of each
#         conflict are kept, as git writes them in the diff3 style (each
#         side's hunk whole), the markers and the base dropped. That is the
#         set a resolution that only orders entries reproduces.
#
#   (e) "with the Pull Request's own entry byte for byte the same on both heads":
#       its own entries are the ones the approved head adds, changes or
#       removes relative to its merge base with the base. Each must be the same
#       bytes at the new head, or absent from both.
#
#   The registry is read in bash, line by line: Git Bash's awk, sed and grep
#   drop the CR of a CRLF line, and a CR is a byte. A registry holding a NUL
#   or another control byte cannot be read that way, so it is refused.
#
# FAILS CLOSED. Exit 2, never 0, when it cannot decide: a revision that does
# not resolve, a shallow clone, git older than 2.40 (`merge-tree --write-tree`
# needs 2.38, --attr-source 2.40), merge-classify.sh missing, a git command
# failing. Exit 1, with the reason, when the history or the registry is not
# what the rule requires, including a registry this script cannot read
# without ambiguity.
#
# WHAT IT DOES NOT DECIDE: which commit an approval names (the Main Agent
# passes it as <approved-head>), whether the required checks are green on the
# new head (condition 3), and the Director's Core/ approval, which this test
# never carries over (condition 2).
#
# USAGE
#
#   check-approval-carry-over.sh <approved-head> <new-head> [--base <ref>]
#
#   <approved-head>  the commit the approval names (for a forge review, the
#                    commit it was submitted on)
#   <new-head>       the Pull Request's head now
#   --base <ref>     the branch merged in; default origin/develop. Run
#                    `git fetch origin` first: a stale origin/develop refuses
#                    a merge of a newer develop commit.
#
# OUTPUT AND EXIT STATUS
#
#   0  the approvals carry over. stdout is exactly one line, the record:
#        Approval carry-over: <approved> -> <new>; merges equal git's own merge outside Registry/work-units.yml; registry entry identical; checker: check-approval-carry-over.sh
#      with both heads as full commit ids. What was checked goes to stderr.
#   1  they do not: the reason is on stderr, and stdout is empty.
#   2  usage or environment error: stdout is empty. No approval carries over.
#
# THE RECORD IS 7-BIT ASCII, and must stay so. Exit 0 with a wrong record is
# worse than no record. QA ran this script from a stock PowerShell 5.1
# console on OEM code page 850: an arrow in the record printed as three
# mangled characters, and `>` wrote the file as UTF-16LE. An ASCII line reads
# the same in every console and code page, so the record has no non-ASCII
# byte; a test asserts it. The diagnostics on stderr may still quote paths
# that are not ASCII.
#
# Run it from Git Bash or another POSIX shell: its comparisons are bash code.
#
# This file is a control path (Adapters/scripts/): it decides whether a review
# still stands. A change to it is a change to that decision; review it as one.

set -uo pipefail
export LC_ALL=C

readonly PROG="check-approval-carry-over.sh"
readonly REGISTRY="Registry/work-units.yml"
readonly ENTRY_PREFIX="  - id: "
# Named once, so the block encoding below does not depend on how a literal
# control character or backslash survives an edit of this file.
readonly LF=$'\n' CR=$'\r' TAB=$'\t' BS=$'\\'

say() { printf '%s: %s\n' "$PROG" "$*" >&2; }
detail() { printf '  %s\n' "$*" >&2; }
usage() {
  say "$*"
  printf 'usage: %s <approved-head> <new-head> [--base <ref>]   (default base: origin/develop)\n' "$PROG" >&2
  exit 2
}
cannot_decide() {
  say "cannot decide: $*"
  say "exit 2: no approval carries over."
  exit 2
}
refuse() {
  say "no carry-over: $*"
  say "exit 1: the approvals do not carry over; the Pull Request needs a fresh review."
  exit 1
}
# Revisions and paths are printed with %q: a path is chosen by whoever wrote
# the commit, and may hold a newline or an escape sequence.
q() { printf '%q' "$1"; }
qlist() {
  local out="" p
  for p in "$@"; do out="$out${out:+, }$(q "$p")"; done
  printf '%s' "$out"
}
short() { printf '%.12s' "$1"; }
is_oid() {
  case "$1" in
    '' | *[!0-9a-f]*) return 1 ;;
  esac
  [ "${#1}" -eq 40 ] || [ "${#1}" -eq 64 ]
}

# ------------------------------------------------------------- arguments ---

POS=()
BASE_ARG="origin/develop"
while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      [ $# -ge 2 ] || usage "--base needs a ref"
      BASE_ARG="$2"
      shift 2
      ;;
    --base=*)
      BASE_ARG="${1#--base=}"
      shift
      ;;
    -h | --help)
      usage "decides whether approvals carry over an update merge of develop; see this file's header"
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        POS+=("$1")
        shift
      done
      ;;
    -*)
      usage "unknown option: $(q "$1")"
      ;;
    *)
      POS+=("$1")
      shift
      ;;
  esac
done
[ "${#POS[@]}" -eq 2 ] || usage "expected two revisions, the approved head and the new head; got ${#POS[@]}"
APPROVED_ARG="${POS[0]}"
NEW_ARG="${POS[1]}"
for arg in "$APPROVED_ARG" "$NEW_ARG" "$BASE_ARG"; do
  case "$arg" in
    '') usage "a revision is empty" ;;
    -*) usage "a revision cannot start with '-': $(q "$arg")" ;;
  esac
done

# ------------------------------------------------------------ environment ---

command -v git > /dev/null 2>&1 || cannot_decide "git is not on PATH"
git rev-parse --git-dir > /dev/null 2>&1 || cannot_decide "not inside a git repository"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" \
  || cannot_decide "cannot locate the directory of this script"
[ -f "$SCRIPT_DIR/merge-classify.sh" ] \
  || cannot_decide "merge-classify.sh not found beside this script ($(q "$SCRIPT_DIR")): git's own merge is defined there"
# shellcheck source=merge-classify.sh
. "$SCRIPT_DIR/merge-classify.sh"
declare -F merge_classify_automatic > /dev/null \
  || cannot_decide "merge-classify.sh beside this script defines no merge_classify_automatic: it is older than this script"
merge_classify_git_ok \
  || cannot_decide "$(git version) is too old: git's own merge needs 'git merge-tree --write-tree' (git 2.38) with --attr-source (git 2.40); use git 2.40 or newer"

# Every path git prints below is read from the top of the work tree. Run from
# a subdirectory, `git merge-tree --name-only` prints conflicted paths relative
# to it: the registry's own conflict reads ../Registry/work-units.yml and is
# refused as a conflict elsewhere, and from X/ a conflict in
# X/Registry/work-units.yml would read as the registry's and be exempted. A
# bare repository has no work tree and no prefix, so it stays where it is.
TOP="$(git rev-parse --show-toplevel 2> /dev/null)" || TOP=""
if [ -n "$TOP" ]; then
  cd "$TOP" || cannot_decide "cannot enter the top of the work tree ($(q "$TOP"))"
fi
[ -z "$(git rev-parse --show-prefix 2> /dev/null)" ] \
  || cannot_decide "git still reports a prefix at the top of the work tree"

SHALLOW="$(git rev-parse --is-shallow-repository 2> /dev/null)" \
  || cannot_decide "git rev-parse --is-shallow-repository failed"
[ "$SHALLOW" = false ] \
  || cannot_decide "this clone is shallow: ancestry and merge bases cannot be decided on truncated history (run: git fetch --unshallow origin)"

TMP="$(mktemp -d 2> /dev/null)" || cannot_decide "mktemp -d failed"
trap 'rm -rf "$TMP"' EXIT

commit_of() { git rev-parse --verify --quiet "$1^{commit}"; }
APPROVED="$(commit_of "$APPROVED_ARG")" \
  || cannot_decide "the approved head $(q "$APPROVED_ARG") is not a commit in this repository (run: git fetch origin)"
NEW="$(commit_of "$NEW_ARG")" \
  || cannot_decide "the new head $(q "$NEW_ARG") is not a commit in this repository (run: git fetch origin)"
BASE="$(commit_of "$BASE_ARG")" \
  || cannot_decide "the base $(q "$BASE_ARG") is not a commit in this repository (run: git fetch origin)"
if [ "$APPROVED" = "$NEW" ]; then
  say "nothing to decide: the approved head is the new head ($(short "$NEW")), so the approval is on the current head and needs no carry-over."
  say "exit 2: no record is printed."
  exit 2
fi

say "approved head $(short "$APPROVED"), new head $(short "$NEW"), base $(q "$BASE_ARG") at $(short "$BASE")"

# ---------------------------------------------------- registry, as blocks ---

# enc <text> — sets ENC to <text> on one line: backslash, LF, CR and TAB
# escaped, so a block can go through sort and comm, which read lines, and a
# TAB can separate fields. Assignments, not $(...): a subshell per block
# costs seconds on Windows.
ENC=""
enc() {
  local s="$1"
  s=${s//"$BS"/"$BS$BS"}
  s=${s//"$LF"/"${BS}n"}
  s=${s//"$CR"/"${BS}r"}
  s=${s//"$TAB"/"${BS}t"}
  ENC="$s"
}

# emit_block <bytes> <kind> <id> — prints one block as a line:
# <encoded block> TAB <kind>:<encoded id>, kind H for the header, E for an
# entry. Blank lines ending the block are dropped: they separate entries.
emit_block() {
  local b="$LF$1" k="$2" id="$3" eb
  while :; do
    case "$b" in
      *"$LF$LF") b="${b%"$LF"}" ;;
      *"$LF$CR$LF") b="${b%"$CR$LF"}" ;;
      *) break ;;
    esac
  done
  b="${b#"$LF"}"
  enc "$b"
  eb="$ENC"
  enc "$id"
  printf '%s\t%s:%s\n' "$eb" "$k" "$ENC"
}

# blocks <file> <out> — the file's blocks, one per line, in file order. Read
# with bash's read, which keeps a CR; each line keeps its own terminator, so a
# last line without one stays different from the same line with one.
blocks() {
  local line term blk="" kind=H id=""
  {
    while :; do
      if IFS= read -r line; then
        term="$LF"
      elif [ -n "$line" ]; then
        term=""
      else
        break
      fi
      case "$line" in
        "$ENTRY_PREFIX"*)
          emit_block "$blk" "$kind" "$id"
          blk=""
          kind=E
          id="${line#"$ENTRY_PREFIX"}"
          ;;
      esac
      blk="$blk$line$term"
      [ -n "$term" ] || break
    done < "$1"
    emit_block "$blk" "$kind" "$id"
  } > "$2"
}

# is_marker <marker> <line> — the line is that conflict marker as git writes
# it: alone, before a CR, or followed by a space and a label.
is_marker() {
  case "$2" in
    "$1" | "$1$CR" | "$1 "*) return 0 ;;
  esac
  return 1
}
is_any_marker() {
  is_marker '<<<<<<<' "$1" || is_marker '|||||||' "$1" || is_marker '=======' "$1" || is_marker '>>>>>>>' "$1"
}

# has_marker_like <file> — 0 when a line STARTS with seven of < | = >. Such a
# line in a merge's input would make git's own markers ambiguous.
has_marker_like() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '<<<<<<<'* | '|||||||'* | '======='* | '>>>>>>>'*) return 0 ;;
    esac
  done < "$1"
  return 1
}

# carry_both <file> <out> — a registry as git's own merge writes it in the
# diff3 style, with both sides of every conflict kept and the markers and the
# base dropped. Returns 1 when the markers are not in git's order.
carry_both() {
  local line term state=out
  {
    while :; do
      if IFS= read -r line; then
        term="$LF"
      elif [ -n "$line" ]; then
        term=""
      else
        break
      fi
      case "$state" in
        out)
          if is_marker '<<<<<<<' "$line"; then
            state=ours
          elif is_any_marker "$line"; then
            return 1
          else
            printf '%s' "$line$term"
          fi
          ;;
        ours)
          if is_marker '|||||||' "$line"; then
            state=base
          elif is_marker '=======' "$line"; then
            state=theirs
          elif is_any_marker "$line"; then
            return 1
          else
            printf '%s' "$line$term"
          fi
          ;;
        base)
          if is_marker '=======' "$line"; then
            state=theirs
          elif is_any_marker "$line"; then
            return 1
          fi
          ;;
        theirs)
          if is_marker '>>>>>>>' "$line"; then
            state=out
          elif is_any_marker "$line"; then
            return 1
          else
            printf '%s' "$line$term"
          fi
          ;;
      esac
      [ -n "$term" ] || break
    done < "$1"
    [ "$state" = out ]
  } > "$2"
}

# registry_entry <tree-ish> — prints "<mode> <type> <oid>" for the registry in
# that tree, or nothing when it has none. The name is compared byte for byte:
# a case-insensitive checkout must not stand in another file for it.
registry_entry() {
  local rec
  git ls-tree -z --full-tree "$1" "$REGISTRY" > "$TMP/ls" || return 1
  while IFS= read -r -d '' rec; do
    if [ "${rec#*"$TAB"}" = "$REGISTRY" ]; then
      printf '%s\n' "${rec%%"$TAB"*}"
    fi
  done < "$TMP/ls"
  return 0
}

# registry_blob <oid> <file> <where> — writes the blob to <file>, refusing a
# registry holding a NUL or another control byte: bash's read cannot keep a
# NUL, so two different files would read the same.
registry_blob() {
  local n
  git cat-file blob "$1" > "$2" || cannot_decide "git cat-file failed on $REGISTRY in $3"
  n="$(tr -d '\011\012\015\040-\377' < "$2" | wc -c)" || cannot_decide "tr failed on $REGISTRY in $3"
  [ "$((n))" -eq 0 ] \
    || refuse "$REGISTRY in $3 holds a NUL or another control byte ($((n)) of them): it cannot be compared line by line"
}

# registry_list <tree-ish> <where> <out> — the registry's blocks, sorted; an
# empty list when the tree has no registry.
registry_list() {
  local entry mode type oid
  entry="$(registry_entry "$1")" || cannot_decide "git ls-tree failed on $2"
  : > "$3"
  [ -n "$entry" ] || return 0
  read -r mode type oid <<< "$entry"
  { [ "$type" = blob ] && [ "$mode" != 120000 ]; } \
    || refuse "$REGISTRY in $2 is not a regular file ($mode $type)"
  registry_blob "$oid" "$TMP/list.yml" "$2"
  blocks "$TMP/list.yml" "$TMP/list.blocks"
  sort "$TMP/list.blocks" > "$3"
}

# show_ids <file> — the ids of the block lines in <file>, for a message.
show_ids() {
  local l k out=""
  while IFS= read -r l; do
    k="${l##*"$TAB"}"
    case "$k" in
      H:*) k="the header (before the first entry)" ;;
      E:*) k="$(q "${k#E:}")" ;;
    esac
    out="$out${out:+, }$k"
  done < "$1"
  printf '%s' "$out"
}

# ----------------------------------------------- (a) the approved head ---

rc=0
git merge-base --is-ancestor "$APPROVED" "$NEW" || rc=$?
case "$rc" in
  0) ;;
  1) refuse "the approved head $(short "$APPROVED") is not an ancestor of the new head $(short "$NEW"): the branch was rebased, reset or force-pushed after the approval" ;;
  *) cannot_decide "git merge-base --is-ancestor exited $rc" ;;
esac
detail "(a) the approved head is an ancestor of the new head"

# ------------------------------------------ (b) the first-parent line ---

LINE="$(git rev-list --first-parent --reverse "$APPROVED..$NEW")" \
  || cannot_decide "git rev-list failed on $(short "$APPROVED")..$(short "$NEW")"
MERGES=()
OURS=()
THEIRS=()
prev="$APPROVED"
while IFS= read -r c; do
  [ -n "$c" ] || continue
  parents="$(git rev-list --parents -n 1 "$c")" || cannot_decide "cannot read the parents of $(short "$c")"
  read -r -a P <<< "$parents"
  n=$((${#P[@]} - 1))
  if [ "$n" -lt 2 ]; then
    refuse "$(short "$c") is not a merge (it has $n parent): a commit pushed after the approval voids it, and only merges of $(q "$BASE_ARG") carry it over"
  fi
  if [ "$n" -gt 2 ]; then
    refuse "$(short "$c") is a merge of $n parents: only a merge with exactly two parents carries an approval over"
  fi
  [ "${P[1]}" = "$prev" ] \
    || refuse "the first-parent line from the new head does not start at the approved head: the first parent of $(short "$c") is $(short "${P[1]}"), not $(short "$prev")"
  rc=0
  git merge-base --is-ancestor "${P[2]}" "$BASE" || rc=$?
  case "$rc" in
    0) ;;
    1) refuse "the second parent of $(short "$c"), $(short "${P[2]}"), is not on $(q "$BASE_ARG") ($(short "$BASE")): only a merge of $(q "$BASE_ARG") carries an approval over (if it is newer than your copy: git fetch origin)" ;;
    *) cannot_decide "git merge-base --is-ancestor exited $rc" ;;
  esac
  MERGES+=("$c")
  OURS+=("${P[1]}")
  THEIRS+=("${P[2]}")
  prev="$c"
done <<< "$LINE"
[ "${#MERGES[@]}" -gt 0 ] || cannot_decide "git rev-list listed no commit between the approved head and the new head"
detail "(b) ${#MERGES[@]} commit(s) on the first-parent line, each a two-parent merge of $(q "$BASE_ARG"): $(for c in "${MERGES[@]}"; do printf '%s ' "$(short "$c")"; done)"

# ------------------------- (c) and (d) each merge against git's own merge ---

REGISTRY_NOTES=()
check_merge() {
  local c="$1" p1="$2" p2="$3" rc auto path meta reg_conflict=0
  local want got want_mode want_type want_oid got_mode got_type got_oid
  local bases nb rev e o auto3 note
  local -a elsewhere differ
  elsewhere=()
  differ=()

  # (c) git's own merge: a conflict anywhere but the registry was resolved by hand.
  rc=0
  merge_classify_automatic "$p1" "$p2" -z --name-only > "$TMP/merge" 2> "$TMP/merge.err" || rc=$?
  [ "$rc" -le 1 ] \
    || cannot_decide "git merge-tree exited $rc on the parents of $(short "$c") (missing objects?): $(head -c 300 "$TMP/merge.err")"
  auto=""
  {
    IFS= read -r -d '' auto || true
    while IFS= read -r -d '' path; do
      if [ "$path" = "$REGISTRY" ]; then
        reg_conflict=1
      else
        elsewhere+=("$path")
      fi
    done
  } < "$TMP/merge"
  is_oid "$auto" || cannot_decide "git merge-tree printed no tree for the parents of $(short "$c")"
  if [ "$rc" -eq 1 ] && [ "$reg_conflict" -eq 0 ] && [ "${#elsewhere[@]}" -eq 0 ]; then
    cannot_decide "git merge-tree reported a conflict for the parents of $(short "$c") and named no path"
  fi
  if [ "$rc" -eq 0 ] && { [ "$reg_conflict" -eq 1 ] || [ "${#elsewhere[@]}" -gt 0 ]; }; then
    cannot_decide "git merge-tree reported a clean merge for the parents of $(short "$c") and named conflicted paths"
  fi
  [ "${#elsewhere[@]}" -eq 0 ] \
    || refuse "git's own merge of the parents of $(short "$c") conflicts outside $REGISTRY, in $(qlist "${elsewhere[@]}"): that conflict was resolved by hand"

  # (c) the merge's tree against git's own, by object id, every path but the registry.
  rc=0
  git diff-tree -r -z --no-renames --ignore-submodules=none --no-relative "$auto" "$c" > "$TMP/diff" 2> "$TMP/diff.err" || rc=$?
  [ "$rc" -eq 0 ] || cannot_decide "git diff-tree exited $rc comparing $(short "$c") with git's own merge: $(head -c 300 "$TMP/diff.err")"
  while IFS= read -r -d '' meta; do
    case "$meta" in
      :*) ;;
      *) cannot_decide "unexpected git diff-tree output comparing $(short "$c") with git's own merge" ;;
    esac
    IFS= read -r -d '' path || cannot_decide "truncated git diff-tree output comparing $(short "$c") with git's own merge"
    [ "$path" = "$REGISTRY" ] || differ+=("$path")
  done < "$TMP/diff"
  [ "${#differ[@]}" -eq 0 ] \
    || refuse "$(short "$c") differs from git's own merge of its parents outside $REGISTRY, in $(qlist "${differ[@]}"): a change made by hand in the merge"

  # (d) the registry holds exactly the entries git's own merge holds.
  want="$(registry_entry "$auto")" || cannot_decide "git ls-tree failed on git's own merge of the parents of $(short "$c")"
  got="$(registry_entry "$c")" || cannot_decide "git ls-tree failed on $(short "$c")"
  if [ -z "$want" ] && [ -z "$got" ]; then
    REGISTRY_NOTES+=("$(short "$c"): no registry, in git's own merge or in the merge")
    return 0
  fi
  [ -n "$want" ] || refuse "$(short "$c") has a $REGISTRY that git's own merge of its parents does not have"
  [ -n "$got" ] || refuse "$(short "$c") has no $REGISTRY, while git's own merge of its parents has one"
  read -r want_mode want_type want_oid <<< "$want"
  read -r got_mode got_type got_oid <<< "$got"
  { [ "$got_type" = blob ] && [ "$got_mode" != 120000 ]; } \
    || refuse "$REGISTRY in $(short "$c") is not a regular file ($got_mode $got_type)"
  { [ "$want_type" = blob ] && [ "$want_mode" != 120000 ]; } \
    || refuse "$REGISTRY in git's own merge of the parents of $(short "$c") is not a regular file ($want_mode $want_type)"
  [ "$want_mode" = "$got_mode" ] \
    || refuse "$(short "$c") changes the mode of $REGISTRY: $want_mode in git's own merge, $got_mode in the merge"

  if [ "$reg_conflict" -eq 0 ]; then
    if [ "$want_oid" = "$got_oid" ]; then
      REGISTRY_NOTES+=("$(short "$c"): the registry is git's own merge, byte for byte")
      return 0
    fi
    registry_blob "$want_oid" "$TMP/want.yml" "git's own merge of the parents of $(short "$c")"
    note="git's own merge is clean there; the entries are the same, reordered"
  else
    # Both sides of each conflict, as git writes them in the diff3 style. Read
    # only when git's own merge is unambiguous: one merge base (several make
    # git merge a virtual base, whose own conflicts would sit inside the base
    # section) and no input line that looks like one of git's markers.
    bases="$(git merge-base --all "$p1" "$p2")" || cannot_decide "git merge-base --all failed on the parents of $(short "$c")"
    nb="$(printf '%s\n' "$bases" | grep -c .)"
    [ "$nb" -eq 1 ] \
      || refuse "$REGISTRY conflicts in git's own merge of the parents of $(short "$c"), which have $nb merge bases: the conflict's two sides cannot be read without ambiguity"
    for rev in "$p1" "$p2" "$bases"; do
      e="$(registry_entry "$rev")" || cannot_decide "git ls-tree failed on $(short "$rev")"
      [ -n "$e" ] || continue
      read -r _ _ o <<< "$e"
      registry_blob "$o" "$TMP/side.yml" "$(short "$rev")"
      if has_marker_like "$TMP/side.yml"; then
        refuse "$REGISTRY in $(short "$rev") has a line that looks like a conflict marker, so the conflict git writes in the merge of $(short "$c") cannot be read without ambiguity"
      fi
    done
    rc=0
    merge_classify_automatic --diff3 "$p1" "$p2" -z --name-only > "$TMP/merge3" 2> "$TMP/merge3.err" || rc=$?
    [ "$rc" -le 1 ] \
      || cannot_decide "git merge-tree (diff3) exited $rc on the parents of $(short "$c"): $(head -c 300 "$TMP/merge3.err")"
    auto3=""
    IFS= read -r -d '' auto3 < "$TMP/merge3" || true
    is_oid "$auto3" || cannot_decide "git merge-tree (diff3) printed no tree for the parents of $(short "$c")"
    e="$(registry_entry "$auto3")" || cannot_decide "git ls-tree failed on git's own merge (diff3) of $(short "$c")"
    [ -n "$e" ] || cannot_decide "git's own merge (diff3) of the parents of $(short "$c") has no $REGISTRY"
    read -r _ _ o <<< "$e"
    registry_blob "$o" "$TMP/merged3.yml" "git's own merge (diff3) of the parents of $(short "$c")"
    carry_both "$TMP/merged3.yml" "$TMP/want.yml" \
      || refuse "the conflict git writes in $REGISTRY for the merge of $(short "$c") does not read as two sides"
    note="git's own merge conflicts there; both sides kept, in the order the merge chose"
  fi

  registry_blob "$got_oid" "$TMP/got.yml" "$(short "$c")"
  blocks "$TMP/want.yml" "$TMP/want.blocks"
  blocks "$TMP/got.yml" "$TMP/got.blocks"
  sort "$TMP/want.blocks" > "$TMP/want.sorted"
  sort "$TMP/got.blocks" > "$TMP/got.sorted"
  comm -23 "$TMP/want.sorted" "$TMP/got.sorted" > "$TMP/missing"
  comm -13 "$TMP/want.sorted" "$TMP/got.sorted" > "$TMP/extra"
  if [ -s "$TMP/missing" ] || [ -s "$TMP/extra" ]; then
    local why=""
    [ -s "$TMP/missing" ] && why="git's own merge holds, and the merge does not hold byte for byte: $(show_ids "$TMP/missing")"
    [ -s "$TMP/extra" ] && why="$why${why:+; }the merge holds, and git's own merge does not: $(show_ids "$TMP/extra")"
    refuse "$REGISTRY in $(short "$c") does not hold exactly the entries git's own merge of its parents holds. $why"
  fi
  REGISTRY_NOTES+=("$(short "$c"): $note")
  return 0
}

i=0
while [ "$i" -lt "${#MERGES[@]}" ]; do
  check_merge "${MERGES[$i]}" "${OURS[$i]}" "${THEIRS[$i]}"
  i=$((i + 1))
done
detail "(c) each merge is git's own merge of its two parents outside $REGISTRY (no conflict elsewhere, no other path differs)"
for note in "${REGISTRY_NOTES[@]}"; do
  detail "(d) $REGISTRY in $note"
done

# ------------------------------- (e) the Pull Request's own registry entry ---

BASE_A="$(git merge-base --all "$APPROVED" "$BASE")" \
  || refuse "the approved head shares no history with $(q "$BASE_ARG"), so its own registry entry cannot be told apart"
nb="$(printf '%s\n' "$BASE_A" | grep -c .)"
[ "$nb" -eq 1 ] \
  || refuse "the approved head has $nb merge bases with $(q "$BASE_ARG"), so its own registry entry cannot be told apart"
registry_list "$BASE_A" "the merge base $(short "$BASE_A") of the approved head" "$TMP/fork.sorted"
registry_list "$APPROVED" "the approved head $(short "$APPROVED")" "$TMP/approved.sorted"
registry_list "$NEW" "the new head $(short "$NEW")" "$TMP/new.sorted"

# The approved head's own entries: those it adds, changes or removes.
OWN=()
while IFS= read -r l; do
  k="${l##*"$TAB"}"
  case "$k" in
    E:*) ;;
    *) continue ;;
  esac
  seen=0
  for x in ${OWN[@]+"${OWN[@]}"}; do
    [ "$x" = "$k" ] && seen=1
  done
  [ "$seen" -eq 1 ] || OWN+=("$k")
done < <(comm -3 "$TMP/fork.sorted" "$TMP/approved.sorted")

# lines_of <sorted-file> <kind:id> — the block lines carrying that id.
lines_of() {
  local l
  while IFS= read -r l; do
    if [ "${l##*"$TAB"}" = "$2" ]; then
      printf '%s\n' "$l"
    fi
  done < "$1"
  return 0
}
OWN_SHOWN=""
for k in ${OWN[@]+"${OWN[@]}"}; do
  at_approved="$(lines_of "$TMP/approved.sorted" "$k")"
  at_new="$(lines_of "$TMP/new.sorted" "$k")"
  [ "$at_approved" = "$at_new" ] \
    || refuse "the Pull Request's own $REGISTRY entry $(q "${k#E:}") is not byte for byte the same on both heads"
  OWN_SHOWN="$OWN_SHOWN${OWN_SHOWN:+, }$(q "${k#E:}")"
done
if [ -n "$OWN_SHOWN" ]; then
  detail "(e) the Pull Request's own $REGISTRY entries are byte for byte the same on both heads: $OWN_SHOWN"
else
  detail "(e) the approved head adds, changes and removes no $REGISTRY entry of its own"
fi

say "the approvals carry over. The record to paste on the Pull Request is on stdout:"
printf "Approval carry-over: %s -> %s; merges equal git's own merge outside %s; registry entry identical; checker: %s\n" \
  "$APPROVED" "$NEW" "$REGISTRY" "$PROG"
exit 0
