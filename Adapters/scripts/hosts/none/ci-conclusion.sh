#!/usr/bin/env bash
# IA Engineering — hosts/none/ci-conclusion.sh
#
# This host has no run history to read. See Adapters/scripts/hosts/README.md.
#
# It does not pretend, and it does not pass. Workflows/RELEASE.md Step 1
# condition 2 requires CI to be green on develop; a host that cannot see CI
# has established nothing, and an unevaluated condition is a failure rather
# than a pass (Adapters/README.md, The Check Convention, rule 1).
#
# What it does instead is say exactly what a human must confirm, so an adopter
# on an unsupported forge gets a checklist rather than a crash.

set -uo pipefail

BRANCH="${1:-<branch>}"

echo "host 'none' cannot read a CI conclusion." >&2
echo "  Confirm by hand that the latest CI run on '$BRANCH' succeeded, and" >&2
echo "  record that you did — Workflows/RELEASE.md Step 1, condition 2." >&2
echo "  If this project is on a supported forge, declare it:" >&2
echo "    echo github > .ia-engineering/host" >&2
exit 1
