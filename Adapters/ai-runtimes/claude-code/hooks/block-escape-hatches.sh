#!/usr/bin/env bash
# IA Engineering — Claude Code PreToolUse hook (matcher: Bash)
#
# Mechanically enforces Standards/GIT_STANDARD.md, Escape Hatches: refuses a
# shell command that would make a control stop applying with nothing recording
# that it did. The table in that Standard is the source; this file is its
# executable form.
#
# WHAT IS STRIPPED BEFORE MATCHING: single-quoted strings, double-quoted
# strings, and heredoc bodies. A commit message that *mentions* --no-verify
# (this framework's own Standards do) is not a use of it; matching the raw
# command text blocked exactly such commits in a sibling kit's first version.
#
# WHAT IS NOT HERE: --force-with-lease is treated as --force. The Risk Standard
# classifies force-pushing a protected branch as Critical even with the lease,
# and this hook cannot see which branch a bare `git push -f` targets — so it
# refuses all of them and the human runs the sanctioned one (the data-purge
# protocol) by hand.

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TOOL="$(iaeng_field '.tool_name')"
[ -z "$TOOL" ] || [ "$TOOL" = "Bash" ] || exit 0

CMD="$(iaeng_field '.tool_input.command')"
if [ -z "$CMD" ]; then
  # An empty command is either a malformed payload or an input this helper
  # could not read. Neither is a reason to allow.
  iaeng_block "cannot read tool_input.command from the hook payload (is jq installed?)" \
    "Adapters/ai-runtimes/claude-code/hooks/README.md — the hook fails closed rather than allowing what it could not inspect."
fi

# --- Strip quoted strings and heredoc bodies ----------------------------------
# strip-quotes.awk is a small shell lexer, not a regex pass: it walks the text
# once, tracking outside / single-quoted / double-quoted / heredoc-body, and
# prints only what the shell would parse as words. Two earlier regex versions
# were defeated by real commands from this repository's own history (see the
# awk file's header and Governance/TROUBLESHOOTING.md, entry R). It is a
# separate file so that no shell quoting applies to the program itself. Only
# text OUTSIDE quotes and heredoc bodies reaches the rules below.
LEXER="$(dirname "$0")/strip-quotes.awk"
if [ ! -f "$LEXER" ]; then
  iaeng_block "strip-quotes.awk is missing next to this hook — cannot separate quoted text from commands" \
    "Adapters/ai-runtimes/claude-code/hooks/README.md — the hook fails closed rather than matching raw text, which blocks every command that merely mentions a forbidden flag."
fi
STRIPPED="$(printf '%s\n' "$CMD" | awk -f "$LEXER")"

# --- Rules: pattern → reason ----------------------------------------------------
# Each is matched against the stripped command. [^|;&]* keeps a match inside one
# pipeline segment so `git push origin x && echo -f` is not misread.
#
# G  matches `git` plus any GLOBAL options before the subcommand — `git -C dir
#    push`, `git -c key=value commit`. Without this, prefixing a global option
#    walked straight past every rule below; `git -C . push --force` was allowed
#    until this was added.
# S  one whitespace character.
# E  what may END a flag: whitespace, a command separator, or end of text.
#    `git push --force;` was allowed while this was whitespace-or-end alone.
G='git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|--no-pager|-P))*[[:space:]]+'
S='[[:space:]]'
E='([[:space:]]|;|&|\||\)|$)'

check() { printf '%s\n' "$STRIPPED" | grep -qE -- "$1"; }

# --no-verify is scoped to a git command rather than matched anywhere, so that
# searching the documentation for the string — `grep -rn -- --no-verify
# Standards/` — is not refused. A hook that fires on reading about a rule is a
# hook that teaches people to work around it.
if check "${G}[a-z][a-z-]*[^|;&]*--no-verify"; then
  iaeng_block "--no-verify disables the commit-msg and pre-commit hooks — attribution and data protection in one motion" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Fix what the hook refuses; if the hook is wrong, that is a Work Unit against the hook."
fi
if check '--no-gpg-sign|commit\.gpgsign=false'; then
  iaeng_block "disabling commit signing" "Standards/GIT_STANDARD.md, Escape Hatches. Fix the signing setup."
fi
if check "${G}stash$E" && ! check "${G}stash${S}+(list|show)$E"; then
  iaeng_block "git stash sets work aside with no record; it is local, unlabelled, and lost with the clone" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Commit as work in progress on the feature branch, or open a second branch."
fi
if check "${G}(rebase|add|commit|checkout|reset)[^|;&]*${S}(-i|--interactive|-p|--patch)$E"; then
  iaeng_block "interactive git command in a non-interactive session — it hangs or does nothing, and the session assumes a result" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Use the non-interactive equivalent and verify with git log / git status."
fi
# `-n` is --no-verify for git commit and --dry-run for git push, so the rule is
# scoped to commit. Same escape hatch as the long form, one character wide.
if check "${G}commit[^|;&]*${S}-n$E"; then
  iaeng_block "git commit -n is --no-verify in short form — it disables the commit-msg and pre-commit hooks" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Fix what the hook refuses."
fi
if check "${G}push[^|;&]*${S}(-f|--force|--force-with-lease(=[^[:space:]]*)?|--mirror)$E"; then
  iaeng_block "force-push or mirror-push — rewrites history every collaborator has" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (Critical). The one sanctioned rewrite is the data-purge protocol, run by a human on a Director decision."
fi
# The remote may come before or after the flag — `push origin --delete X` and
# `push --delete origin X` are both valid — so the branch is matched anywhere
# after the flag rather than at a fixed position. It was matched at a fixed
# position, and `git push origin --delete release/v1` walked past. The branch
# name is anchored on whitespace so `feature-main` is not read as `main`.
if check "${G}push[^|;&]*${S}(-d|--delete)[^|;&]*${S}(main$E|develop$E|release/)"; then
  iaeng_block "deleting a protected branch on the remote" \
    "Standards/BRANCH_STANDARD.md; Standards/GIT_STANDARD.md, Escape Hatches. Release branches are never deleted."
fi
if check "${G}reset[^|;&]*${S}--hard$E"; then
  iaeng_block "git reset --hard discards uncommitted work and moves the branch without a record" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Inspect first; prefer a new branch or a single-path checkout."
fi
if check "${G}clean[^|;&]*${S}-[a-zA-Z]*f"; then
  iaeng_block "git clean -f deletes untracked files that may not be yours" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Surface unexpected files instead of deleting them."
fi
if check "${G}(checkout|restore)[^|;&]*${S}(--${S}+)?\.$E"; then
  iaeng_block "discarding every working-tree change at once (checkout -- . / restore .)" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Restore the one path you mean, by name."
fi
if check "${G}branch[^|;&]*${S}-D$E"; then
  iaeng_block "force-deleting a branch (-D) discards unmerged commits" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Use -d, which refuses when the branch is unmerged — that refusal is information."
fi
if check "${G}filter-(branch|repo)$E"; then
  iaeng_block "history rewrite" \
    "Standards/DATA_PROTECTION_STANDARD.md, purge protocol — a Director decision executed by a human, with a bundle backup first."
fi
if check "(^|${S}|;|&&|\|)rm${S}+-[a-zA-Z]*r[a-zA-Z]*${S}+(-[a-zA-Z]+${S}+)*(/|\.git|\.git/)$E"; then
  iaeng_block "recursive removal of the repository metadata or the filesystem root" \
    "Standards/RISK_STANDARD.md, operational catalog (Critical)."
fi

exit 0
