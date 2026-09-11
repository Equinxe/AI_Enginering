#!/usr/bin/env bash
# IA Engineering — hosts/none/open-bugs.sh
#
# This host has no issue tracker to read. See Adapters/scripts/hosts/README.md.
#
# EXIT 3 — PARTIAL. Not 0, and the difference was a real defect: exiting 0 with
# nothing on stdout made release.sh report "no open issues labelled bug", which
# asserts an absence nobody established. A host that cannot see the tracker has
# not found zero bugs; it has found nothing.
#
# Not 1 either. Workflows/RELEASE.md Step 1 condition 3 is reported and not
# failed by design — the judgment was always the reviewer's, and a host that
# cannot list issues has taken nothing away from them. Failing would add a
# blocking condition the workflow never had.
#
# 3 is the code the contract already reserves for "some of the work could not
# be done", and it lets the caller say so instead of guessing.

set -uo pipefail

echo "host 'none' cannot list open defects." >&2
echo "  Step 1 condition 3 is a judgment call, not a gate: review your tracker" >&2
echo "  by hand for critical or high defects before proceeding." >&2
exit 3
