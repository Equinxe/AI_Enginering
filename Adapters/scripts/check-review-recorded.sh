#!/usr/bin/env bash
# IA Engineering — check-review-recorded.sh
#
# A Code Reviewer decision was actually recorded on the change set: a
# `Decision: approved` block, per Employees/Specialized/CODE_REVIEWER.md's
# Review Decision section and Workflows/CODE_REVIEW.md.
#
# THIS CHECK IS ADVISORY BY DESIGN
#
# It matches comment TEXT, and text can be satisfied by pasting the block.
# Requiring it would therefore buy false confidence rather than review, which
# is why it is deliberately absent from the required checks. Advisory here
# means "red does not block" — it does NOT mean "green means nothing", and the
# check exits non-zero when no decision is found rather than exiting 0 either
# way. An advisory check that always succeeds is indistinguishable from a
# passing gate, which is worse than having no check at all.
#
# THE HOST SEAM
#
# This is the only one of the four extracted checks that cannot be answered
# from git alone: it needs whatever the forge stores as comments. So the work
# is split, and the split is the point:
#
#   The HOST fetches. It knows its own API — GitHub issue comments, reviews and
#   inline review comments; GitLab notes; nothing at all on a forge with no
#   comment concept.
#
#   THIS SCRIPT DECIDES. It owns the matching rule, the author filter, and the
#   distinction between "no decision was recorded" and "the comments could not
#   be read". Those three are the check's actual content, and leaving any of
#   them to the host would mean each host reimplementing them slightly
#   differently.
#
# In particular the author filter lives HERE, not in the fetcher. If the host
# filtered, a host that forgot to would leave this script reporting that only
# the review identity's decisions count while in fact any author's did — a
# check describing a rule it is not applying.
#
# INPUT FORMAT: A DIRECTORY OF FILES, ONE PER COMMENT
#
#   <dir>/<anything>
#     line 1:  author: <login>
#     line 2+: the comment body, verbatim
#
# A directory rather than a delimited stream, because a delimited stream lets a
# comment BODY contain the delimiter and so declare its own author. Here the
# body begins at line 2 and cannot supply line 1, so a comment cannot claim to
# come from someone else. The check gates review; a forgeable author field in
# it would be worth less than no field.
#
# USAGE
#
#   check-review-recorded.sh <comments-dir> [--fetch-incomplete]
#
#   --fetch-incomplete   the host could not read every source. Absence of a
#                        decision is then unproven, and the script says so
#                        instead of reporting the change set unreviewed.
#
#   IAENG_REVIEW_BOT_LOGIN   when set, only decisions authored by that login
#                            count. When unset, any author's decision counts,
#                            including the author of the change itself.
#
# Exit 0 when a decision is found, 1 otherwise, 2 on a usage error.

set -uo pipefail

err() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error::%s\n' "$1" >&2
  else
    printf 'check-review-recorded: ERROR: %s\n' "$1" >&2
  fi
}

note() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::notice::%s\n' "$1"
  else
    printf 'check-review-recorded: %s\n' "$1"
  fi
}

COMMENTS_DIR=""
FETCH_INCOMPLETE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --fetch-incomplete) FETCH_INCOMPLETE=1; shift ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 <comments-dir> [--fetch-incomplete]" >&2
      exit 2
      ;;
    *)
      if [ -n "$COMMENTS_DIR" ]; then
        echo "Unexpected extra argument: $1" >&2
        exit 2
      fi
      COMMENTS_DIR="$1"; shift
      ;;
  esac
done

if [ -z "$COMMENTS_DIR" ]; then
  echo "Usage: $0 <comments-dir> [--fetch-incomplete]" >&2
  echo "  Each file: line 1 'author: <login>', line 2+ the comment body." >&2
  exit 2
fi

# A directory the host never created is not an empty comment list. It means the
# fetch step did not run, and reporting "no decision recorded" would blame the
# change set for a broken pipeline.
if [ ! -d "$COMMENTS_DIR" ]; then
  err "No such directory: $COMMENTS_DIR. The host's fetch step is expected to create it, empty if the change set has no comments. Its absence means the fetch did not run, which is not the same as an unreviewed change set."
  exit 1
fi

REQUIRED_LOGIN="${IAENG_REVIEW_BOT_LOGIN:-}"
if [ -n "$REQUIRED_LOGIN" ]; then
  echo "Mode: independent — only decisions posted by '$REQUIRED_LOGIN' count (IAENG_REVIEW_BOT_LOGIN)."
  echo "Note: this raises the cost of an author satisfying the check themselves. It does not prevent it when that login is a generic CI identity the author can post as; point IAENG_REVIEW_BOT_LOGIN at a separate account or an App for that."
else
  echo "Mode: any author — IAENG_REVIEW_BOT_LOGIN is not set, so a decision block from any account counts, including the author's own."
fi

EXAMINED=0
MATCHED=0
SKIPPED_AUTHOR=0

for f in "$COMMENTS_DIR"/*; do
  [ -f "$f" ] || continue
  EXAMINED=$((EXAMINED + 1))

  header="$(head -n 1 "$f" | tr -d '\r')"
  case "$header" in
    "author: "*) author="${header#author: }" ;;
    *)
      err "$f does not begin with an 'author: <login>' line. The host's fetch step writes it; a file without one cannot be attributed, and attributing it to nobody would let an unattributable comment satisfy an author-filtered check."
      exit 1
      ;;
  esac

  if [ -n "$REQUIRED_LOGIN" ] && [ "$author" != "$REQUIRED_LOGIN" ]; then
    SKIPPED_AUTHOR=$((SKIPPED_AUTHOR + 1))
    continue
  fi

  # The body starts at line 2. Reading from line 1 would let the author header
  # itself be matched, which no rule wants but which a future edit could make
  # true by accident.
  # Captured, then matched with a here-string. A pasted log can make a comment
  # exceed the pipe buffer, and a Decision: line near its top would make grep -q
  # short-circuit `tail` — SIGPIPE, which pipefail returns as failure, and a
  # recorded decision reads as absent. TROUBLESHOOTING X.
  body="$(tail -n +2 "$f")"
  if grep -qiE '^[[:space:]]*Decision:[[:space:]]*approved' <<< "$body"; then
    MATCHED=$((MATCHED + 1))
    echo "  decision found in $(basename "$f") (author: $author)"
  fi
done

# The denominator, always. A check that iterates a set reports how big the set
# was, or "none found" cannot be told from "nothing was looked at"
# (Adapters/README.md, The Check Convention, rule 3).
echo "Comments examined: $EXAMINED (skipped for author: $SKIPPED_AUTHOR, matched: $MATCHED)"

if [ "$MATCHED" -gt 0 ]; then
  echo "A recorded Code Reviewer decision ('Decision: approved') was found."
  exit 0
fi

if [ "$FETCH_INCOMPLETE" -eq 1 ]; then
  err "The host reported that at least one comment source could not be read, and no decision was found in what it did read. This is NOT the same as an unreviewed change set: nothing was established either way. See the host's warnings."
  exit 1
fi

err "No recorded Code Reviewer decision ('Decision: approved', per Employees/Specialized/CODE_REVIEWER.md's Review Decision block) was found among the $EXAMINED comment(s) on this change set. Per Workflows/CODE_REVIEW.md a Code Reviewer decision must be recorded before merge."
note "This check is ADVISORY where it is configured as such: red does not block the merge. It goes red rather than green so its result is legible — an advisory check that exits 0 either way is indistinguishable from a passing gate."
exit 1
