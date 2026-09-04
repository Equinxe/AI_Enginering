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

# Case-insensitive variant, for git CONFIG KEYS only. Git treats the section
# and key parts of a config name case-insensitively — `git -c
# commit.gpgSign=false` disables signing exactly as the lowercase spelling
# does, and was allowed while the lowercase one was blocked. Command names and
# flags stay case-sensitive, because git's are.
check_key() { printf '%s\n' "$STRIPPED" | grep -qiE -- "$1"; }

# --no-verify is scoped to a git command rather than matched anywhere, so that
# searching the documentation for the string — `grep -rn -- --no-verify
# Standards/` — is not refused. A hook that fires on reading about a rule is a
# hook that teaches people to work around it.
if check "${G}[a-z][a-z-]*[^|;&]*--no-verify"; then
  iaeng_block "--no-verify disables the commit-msg and pre-commit hooks — attribution and data protection in one motion" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Fix what the hook refuses; if the hook is wrong, that is a Work Unit against the hook."
fi
if check '--no-gpg-sign' \
   || check_key "commit\.gpgsign[[:space:]]*[= ][[:space:]]*(false|0|off|no)"; then
  iaeng_block "disabling commit signing" "Standards/GIT_STANDARD.md, Escape Hatches. Fix the signing setup."
fi
# core.hooksPath is --no-verify spelled as configuration: `git -c
# core.hooksPath=/dev/null commit` runs no hook at all, and `git config
# core.hooksPath …` does it for every later command in the clone. The rule
# fires on any write of the setting, including the empty value. install.sh is
# unaffected — this hook sees the script's invocation, not the git commands
# inside it — and pointing the setting at the framework's own hooks is what
# that script is for.
#
# SCOPED TO A GIT COMMAND, for the same reason --no-verify is. The first
# version of this rule matched the string anywhere and immediately refused a
# `sed` that merely mentioned the setting while editing a state file — the
# exact false positive review had just flagged for --no-verify, reintroduced
# one rule later by the same hand. `git[^|;&]*` keeps the match inside a
# pipeline segment that actually starts with git, so `grep core.hooksPath
# Standards/` and `git config --get core.editor` both pass.
if check "git[^|;&]*core\.hooksPath"; then
  iaeng_block "setting core.hooksPath disables every git hook — the same effect as --no-verify, written as configuration" \
    "Standards/GIT_STANDARD.md, Escape Hatches. The sanctioned write of this setting is ./ia-engineering/Adapters/scripts/install.sh, which points it at the framework's hooks."
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
# A refspec prefixed with + forces the update with no -f anywhere on the line:
# `git push origin +main`, `git push origin +HEAD:main`. Same effect, same rule.
if check "${G}push[^|;&]*${S}\+[^[:space:]]+"; then
  iaeng_block "a + prefix on a push refspec forces the update — a force-push written without --force" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (Critical). Push without the +, and if the remote refuses, that refusal is information."
fi
# The remote may come before or after the flag — `push origin --delete X` and
# `push --delete origin X` are both valid — so the branch is matched anywhere
# after the flag rather than at a fixed position. It was matched at a fixed
# position, and `git push origin --delete release/v1` walked past. The branch
# name is anchored on whitespace so `feature-main` is not read as `main`.
PROT="(refs/heads/)?(main$E|develop$E|release/)"
if check "${G}push[^|;&]*${S}(-d|--delete)[^|;&]*${S}$PROT"; then
  iaeng_block "deleting a protected branch on the remote" \
    "Standards/BRANCH_STANDARD.md; Standards/GIT_STANDARD.md, Escape Hatches. Release branches are never deleted."
fi
if check "${G}reset[^|;&]*${S}--hard$E"; then
  iaeng_block "git reset --hard discards uncommitted work and moves the branch without a record" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Inspect first; prefer a new branch or a single-path checkout."
fi
if check "${G}clean[^|;&]*${S}(-[a-zA-Z]*f|--force)"; then
  iaeng_block "git clean -f deletes untracked files that may not be yours" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Surface unexpected files instead of deleting them."
fi
# `:/` is the magic pathspec for the repository root, so `git restore :/` from
# any subdirectory discards every working-tree change — the same act as
# `restore .` at the top, spelled so the `.` pattern cannot see it.
if check "${G}(checkout|restore)[^|;&]*${S}(--${S}+)?(\.|:/)$E"; then
  iaeng_block "discarding every working-tree change at once (checkout -- . / restore . / restore :/)" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Restore the one path you mean, by name."
fi
# -d and --force in either order is -D. `git branch -d --force x` deletes an
# unmerged branch that plain -d refuses, which is the whole point of the rule.
if check "${G}branch[^|;&]*${S}(-D$E|(-d|--delete)[^|;&]*${S}(-f|--force)$E|(-f|--force)[^|;&]*${S}(-d|--delete)$E)"; then
  iaeng_block "force-deleting a branch discards unmerged commits" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Use -d, which refuses when the branch is unmerged — that refusal is information."
fi
# `git push origin :main` is the old spelling of a remote branch deletion, and
# Standards/GIT_STANDARD.md names remote deletion of a protected branch. It
# carries no -d and no --delete, so the rule above cannot see it.
if check "${G}push[^|;&]*${S}:(refs/heads/)?(main|develop|release/)"; then
  iaeng_block "an empty source in a refspec deletes the remote branch — the old spelling of --delete, on a protected branch" \
    "Standards/BRANCH_STANDARD.md; Standards/GIT_STANDARD.md, Escape Hatches. Release branches are never deleted."
fi
# `git checkout --force <branch>` throws away uncommitted work to switch, and
# `git update-ref -d` deletes a ref with no reflog entry for the deletion.
# Both are the operational catalog's "discarding work that is not yours" and
# "history rewrite" rows in a spelling the other rules do not reach.
if check "${G}(checkout|switch)[^|;&]*${S}(-f|--force)$E"; then
  iaeng_block "checkout --force discards every uncommitted change to switch" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Commit or report the changes first — losing someone else's work is not recoverable."
fi
# An ALIAS is persistent configuration that disables a control — the category
# core.hooksPath sits in — and unlike variable indirection it is reachable,
# because the alias value is literal text in the command. The lexer surfaces
# that value as command text (is_command_context matches `alias.`), so the
# forbidden flag appears here and the two conditions together identify it
# without blocking ordinary aliases.
if check "${G}config[^|;&]*${S}alias\." \
   && check '(--force|--no-verify|--no-gpg-sign|--hard|--mirror|-D|filter-repo|filter-branch|core\.hooksPath)'; then
  iaeng_block "writing a git alias whose value is an escape hatch — the alias outlives the command and disables the control for every later use" \
    "Standards/GIT_STANDARD.md, Escape Hatches. An alias for a forbidden command is the forbidden command with a shorter name."
fi
if check "${G}update-ref[^|;&]*${S}(-d|--delete)$E"; then
  iaeng_block "update-ref -d deletes a ref outright" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Branch deletion goes through the branch commands, which refuse when the branch is unmerged."
fi
if check "${G}filter-(branch|repo)$E"; then
  iaeng_block "history rewrite" \
    "Standards/DATA_PROTECTION_STANDARD.md, purge protocol — a Director decision executed by a human, with a bundle backup first."
fi
# Long spellings and a trailing glob are the same command: `rm --recursive
# --force /` and `rm -rf /*` were both allowed while this matched only the
# bundled short form followed by an exact path.
RMFLAG="(-[a-zA-Z]*r[a-zA-Z]*|--recursive|--force|-[a-zA-Z]*f[a-zA-Z]*)"
if check "(^|${S}|;|&&|\|)rm(${S}+${RMFLAG})*${S}+(/|\.git)(/|\*|${S}|$)"; then
  iaeng_block "recursive removal of the repository metadata or the filesystem root" \
    "Standards/RISK_STANDARD.md, operational catalog (Critical)."
fi

exit 0
