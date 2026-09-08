#!/usr/bin/env bash
# IA Engineering — hosts/github/fetch-review-comments.sh
#
# The GitHub half of the Review Recorded check. It FETCHES ONLY. Every decision
# — what counts as a recorded decision, which authors count, and whether an
# absent decision is a finding or an unread source — belongs to
# Adapters/scripts/check-review-recorded.sh, which is host-neutral and tested.
#
# WHY THIS FILE IS SEPARATE
#
# It is the first concrete implementation of the host seam. A second forge
# writes its own fetcher — GitLab notes, Gitea, whatever — and reuses the
# decision unchanged. If instead each forge carried its own copy of the
# matching rule and the author filter, the "seam" would be a fork with a shared
# name, and the two would drift on the first fix applied to one of them.
#
# It deliberately does NOT filter by author. That is the check's rule, and a
# fetcher that filtered would let a future fetcher forget to, leaving the check
# announcing a mode it is not enforcing.
#
# OUTPUT
#
# One file per comment in <out-dir>:
#
#   line 1:  author: <login>
#   line 2+: the comment body, verbatim
#
# GitHub keeps a Pull Request's prose in three places, and all three are read
# because a reviewer may record a decision in any of them:
#
#   issues/<n>/comments   the conversation timeline
#   pulls/<n>/reviews     the body of a submitted review
#   pulls/<n>/comments    inline comments on the diff
#
# EXIT CODES
#
#   0  every source read
#   3  PARTIAL — at least one source could not be read; what was read has been
#      written. The caller passes --fetch-incomplete so the check reports
#      "nothing established either way" rather than "no decision recorded".
#      A distinct code rather than a failure, because a partial fetch is a
#      real state with its own required behaviour, and collapsing it into
#      either success or failure loses exactly the distinction the check
#      exists to make.
#   1  usage error, or the output directory could not be created
#
# USAGE
#
#   fetch-review-comments.sh <owner/repo> <pr-number> <out-dir>
#
#   GH_TOKEN must be set, as for any `gh` invocation.

set -uo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <owner/repo> <pr-number> <out-dir>" >&2
  exit 1
fi

REPO="$1"
PR_NUMBER="$2"
OUT_DIR="$3"

if ! command -v gh >/dev/null 2>&1; then
  echo "::error::gh is not installed. This fetcher is the GitHub host adapter and needs it; a different forge uses its own fetcher." >&2
  exit 1
fi

if ! mkdir -p "$OUT_DIR"; then
  echo "::error::Could not create $OUT_DIR." >&2
  exit 1
fi

# The directory is created even when there are no comments at all. An EMPTY
# directory means "read, nothing there"; an ABSENT one means the fetch never
# ran. check-review-recorded.sh treats those differently on purpose, and that
# only works if this script always leaves one behind.

INCOMPLETE=0
INDEX=0

fetch_source() {
  local url="$1" label="$2" payload
  # --paginate because a long-running Pull Request exceeds one page, and a
  # decision recorded early would then be invisible to a check reading only
  # the most recent page.
  #
  # @json puts each comment on a single line, so a body containing newlines
  # survives the loop below intact.
  if ! payload="$(gh api "$url" --paginate -q '.[] | @json' 2>&1)"; then
    echo "::warning::Could not read $label ($url) — $payload" >&2
    INCOMPLETE=1
    return
  fi

  local count=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local login body
    login="$(printf '%s' "$line" | jq -r '.user.login // "unknown"')"
    body="$(printf '%s' "$line" | jq -r '.body // ""')"
    INDEX=$((INDEX + 1))
    count=$((count + 1))
    {
      printf 'author: %s\n' "$login"
      printf '%s\n' "$body"
    } > "$OUT_DIR/$(printf '%04d' "$INDEX").txt"
  done <<EOF
$payload
EOF
  echo "  $label: $count comment(s)"
}

echo "Fetching review prose for $REPO#$PR_NUMBER into $OUT_DIR"
fetch_source "repos/$REPO/issues/$PR_NUMBER/comments" "conversation comments"
fetch_source "repos/$REPO/pulls/$PR_NUMBER/reviews"   "review bodies"
fetch_source "repos/$REPO/pulls/$PR_NUMBER/comments"  "inline review comments"

echo "Total written: $INDEX"

if [ "$INCOMPLETE" -eq 1 ]; then
  echo "At least one source could not be read; the caller must pass --fetch-incomplete." >&2
  exit 3
fi
exit 0
