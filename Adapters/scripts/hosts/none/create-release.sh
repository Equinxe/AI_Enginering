#!/usr/bin/env bash
# IA Engineering — hosts/none/create-release.sh
#
# This host has no Releases page. See Adapters/scripts/hosts/README.md.
#
# EXIT 1, and it must. Workflows/RELEASE.md Step 7 is explicit that a bare
# annotated tag is not sufficient: "A tag with no corresponding release notes
# is an incomplete release, regardless of what version number it carries."
# Exiting 0 here would let a release report itself complete while the thing
# Step 7 exists to require does not exist.
#
# It prints the file to publish and where it came from, so the manual step is
# a copy rather than a reconstruction.

set -uo pipefail

TAG="${1:-<tag>}"
TITLE="${2:-<title>}"
NOTES_FILE="${3:-<notes-file>}"

echo "host 'none' cannot create a Release." >&2
echo >&2
echo "  The tag $TAG is pushed. Step 7 is NOT complete: a tag with no release" >&2
echo "  notes is an incomplete release (Workflows/RELEASE.md Step 7)." >&2
echo >&2
echo "  Publish this by hand on your forge:" >&2
echo "    title: $TITLE" >&2
echo "    body:  $NOTES_FILE" >&2
echo >&2
echo "  That file is this version's CHANGELOG.md section, extracted verbatim." >&2
exit 1
