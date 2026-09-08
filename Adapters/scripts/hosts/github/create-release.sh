#!/usr/bin/env bash
# IA Engineering — hosts/github/create-release.sh
#
# Creates the forge's Release object for a tag that already exists.
# See Adapters/scripts/hosts/README.md for the contract: this ACTS ONLY.
#
# It does not create the tag, does not decide the notes, and does not check
# that the release was approved. release.sh owns all three, and they are the
# same on every forge: Workflows/RELEASE.md Step 7 builds the notes from the
# version's CHANGELOG.md section, and Step 5 is the Director's gate.
#
# WHY THE NOTES ARRIVE AS A FILE, not a string. They are the whole CHANGELOG
# section — 95 lines for v0.0.12 — with backticks, quotes and em dashes in it.
# Passing that through an argument means passing it through a shell, and this
# repository has already lost content from two pushed commit messages to
# command substitution in exactly that way.
#
# USAGE
#
#   create-release.sh <tag> <title> <notes-file>
#
# Exit 0 on success, 1 otherwise.

set -uo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <tag> <title> <notes-file>" >&2
  exit 1
fi

TAG="$1"
TITLE="$2"
NOTES_FILE="$3"

if ! command -v gh > /dev/null 2>&1; then
  echo "gh is not installed, so no Release was created. The tag may already be pushed — a tag without release notes is an incomplete release (Workflows/RELEASE.md Step 7). Create it by hand from $NOTES_FILE." >&2
  exit 1
fi

if [ ! -s "$NOTES_FILE" ]; then
  echo "The notes file $NOTES_FILE is missing or empty. A Release whose body is empty is the bare tag Step 7 forbids; refusing rather than publishing one." >&2
  exit 1
fi

if ! out="$(gh release create "$TAG" --title "$TITLE" --notes-file "$NOTES_FILE" 2>&1)"; then
  echo "Could not create the Release for $TAG — $out" >&2
  echo "The tag may already be pushed. Step 7 is incomplete until a Release exists; create it by hand from $NOTES_FILE." >&2
  exit 1
fi

printf '%s\n' "$out"
