#!/usr/bin/env bash
# IA Engineering — Claude Code PreToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Mechanically enforces Standards/CODE_QUALITY_STANDARD.md, No Inline
# Suppression: refuses an edit that writes a linter / type-checker / test
# disable directive into code. A rule that is wrong for the project is tuned in
# the tool's configuration file, where the change is a reviewed diff; a skipped
# or focused test is a red signal turned green without changing what it
# measured.
#
# NAMED EXEMPTION: documentation files (.md, .rst, .txt, .adoc). This
# framework's own Standard quotes every pattern below in order to forbid it;
# a hook that blocked the Standard from being written would be the joke
# version of itself. Code is never exempt, and there is no environment
# override — the one admissible inline case (a tool false positive that
# configuration cannot scope) is applied by a human, with the forcing
# constraint written on the preceding line, as the Standard requires.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TOOL="$(iaeng_field '.tool_name')"
case "$TOOL" in ""|Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

FILE="$(iaeng_field '.tool_input.file_path')"

# NAMED EXEMPTIONS — two, both by path, neither a fall-through.
#
# 1. Documentation. Standards/CODE_QUALITY_STANDARD.md quotes every directive
#    below in order to forbid it; a hook that stopped the Standard from being
#    written would be the joke version of itself.
# 2. This hook's own test corpus, under a hooks/tests/ directory. A test that
#    proves a directive is refused has to contain that directive. Found by this
#    hook refusing the very file that tests it — the same shape as (1), one
#    level down. Scoped to hooks/tests/ rather than to any path containing the
#    word test, because a directory whose whole contents become exempt is how
#    the synthetic-fixture marker was defeated before it was anchored
#    (Standards/DATA_PROTECTION_STANDARD.md, Synthetic Fixtures).
#
# Code is never exempt, and there is no environment override. Note that this
# file is not exempt from itself: its own comments name the directives
# obliquely for that reason, and the rule they implement is stated in full in
# the Standard.
# `shopt -s nocasematch` rather than ${FILE,,}: the lowercasing expansion is
# bash 4.0+, and macOS still ships bash 3.2 as /bin/bash. There it is not a
# runtime error but a PARSE error, so bash exits 2 before running a line — and
# Claude Code reads exit 2 from a PreToolUse hook as *block*. Every Edit and
# Write would have been refused, with no reason text, on every macOS machine.
# It was the only bash-4 construct in any hook. (`mapfile` in
# Adapters/github-actions/pr-validation.yml is also bash 4, and stays: that
# one runs on ubuntu-latest, where the version is known.)
shopt -s nocasematch
case "$FILE" in
  *.md|*.rst|*.txt|*.adoc) exit 0 ;;
  */hooks/tests/*|*\\hooks\\tests\\*) exit 0 ;;
esac
shopt -u nocasematch

# Every string the edit would write. With jq: new_string, content, and each
# MultiEdit edit's new_string. Without jq: the raw payload — the patterns are
# distinctive enough that matching the whole JSON is a safe over-approximation
# (it can block, never allow, more than the exact text would).
if iaeng_have_jq; then
  TEXT="$(printf '%s' "$IAENG_INPUT" \
    | jq -r '.tool_input | [.new_string?, .content?, (.edits[]?.new_string?)] | .[] | select(. != null)' 2>/dev/null)"
else
  TEXT="$IAENG_INPUT"
fi
[ -n "$TEXT" ] || exit 0

check() { printf '%s\n' "$TEXT" | grep -qE -- "$1"; }

if check '#[[:space:]]*noqa|#[[:space:]]*type:[[:space:]]*ignore|#[[:space:]]*pylint:[[:space:]]*disable|#[[:space:]]*pyright:[[:space:]]*ignore|#[[:space:]]*mypy:[[:space:]]*ignore'; then
  iaeng_block "inline Python lint/type suppression (${FILE:-unknown file})" \
    "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression. Configure the rule for the project, or satisfy it."
fi
if check 'eslint-disable|@ts-ignore|@ts-nocheck|@ts-expect-error|biome-ignore|prettier-ignore'; then
  iaeng_block "inline JavaScript/TypeScript lint/type suppression (${FILE:-unknown file})" \
    "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression."
fi
if check '@SuppressWarnings|#pragma[[:space:]]+warning[[:space:]]+disable|#nosec|//[[:space:]]*nolint|#[[:space:]]*rubocop:disable|#[[:space:]]*shellcheck[[:space:]]+disable'; then
  iaeng_block "inline suppression directive (${FILE:-unknown file})" \
    "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression. A tool false positive that configuration cannot scope is applied by a human with the constraint named on the preceding line."
fi
if check '\.(skip|only)\(|^[[:space:]]*(xit|xdescribe|xtest|fit|fdescribe)\(|@pytest\.mark\.skip|pytest\.skip\(|@unittest\.skip|t\.Skip\('; then
  iaeng_block "skipped or focused test (${FILE:-unknown file}) — a red signal turned green without changing what it measured" \
    "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression; Standards/TESTING_STANDARD.md. Fix the test or delete it in its own reviewed Work Unit."
fi
if check '^[[:space:]]*except[[:space:]]*:[[:space:]]*$|except[[:space:]]*(Exception|BaseException)?[[:space:]]*:[[:space:]]*pass[[:space:]]*$|catch[[:space:]]*\([^)]*\)[[:space:]]*\{[[:space:]]*\}'; then
  iaeng_block "swallowed exception (${FILE:-unknown file}) — a failure reported as success" \
    "Standards/CODE_QUALITY_STANDARD.md, No Inline Suppression; Standards/RISK_STANDARD.md, product catalog (High)."
fi

exit 0
