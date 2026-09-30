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

# The lexer emits this marker instead of a partial result when it reaches one
# of its expansion bounds. A bound that silently truncates is a bound an
# attacker clears by typing one more comma — measured: eight alternatives
# blocked and nine were allowed, while the shell produced the flag in both.
# Reaching a bound means the command was not fully read, and unread input is
# refused, which is the contract every other path in these hooks follows.
if grep -qF '__IAENG_LEXER_LIMIT__' <<< "$STRIPPED"; then
  iaeng_block "this command expands to more alternatives than the hook will enumerate, so it could not be read in full" \
    "Adapters/ai-runtimes/claude-code/hooks/README.md — unread input is refused rather than allowed. Write the command without the brace expansion."
fi

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
# WIDENED under Purple exercise #112, PT-05: the previous G recognised only
# -C, -c, --git-dir=, --work-tree=, --no-pager and -P as global options, so
# any OTHER real git global option prefixing the subcommand — --no-replace-
# objects, --literal-pathspecs, -p (the short spelling of --paginate),
# --no-optional-locks, the space form of --git-dir, --namespace=,
# --config-env= — walked straight past every rule below, exactly as a bare
# `-C` once did. `--[a-z][a-z-]*` covers every no-argument long option by
# shape rather than by name, so a future git release's global option needs no
# hook change; `-[pP]` covers -p/-P (paginate); the explicit alternation
# covers the options that take a value, in both `=value` and `SPACE value`
# form. Verified not to over-match: `git --version` has nothing after the
# option for G's own mandatory trailing whitespace to consume, so it never
# satisfies `${G}<subcommand>` for any rule; `git -p add` reads as `git
# --paginate add` (the -p consumed as global, not as add's -p/--patch
# argument), which is correctly NOT the interactive-add rule below, because
# that rule's own -p match sits strictly after the subcommand.
G='git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|exec-path|config-env|super-prefix|attr-source)(=|[[:space:]]+)[^[:space:]]+|--[a-z][a-z-]*|-[pP]))*[[:space:]]+'
S='[[:space:]]'
E='([[:space:]]|;|&|\||\)|$)'

# here-strings, not `printf | grep -q`: under pipefail, grep -q closing the
# pipe on an early match SIGPIPEs printf and pipefail returns that as failure,
# so a forbidden token early in a command larger than the pipe buffer would
# read as absent. Masked today by the lexer LIMIT for very large inputs, but
# the pattern is unsafe and shared with block-inline-suppression, where it was
# a live bypass. Same class as the check-*.sh fix. TROUBLESHOOTING X.
check() { grep -qE -- "$1" <<< "$STRIPPED"; }

# Case-insensitive variant, for git CONFIG KEYS only. Git treats the section
# and key parts of a config name case-insensitively — `git -c
# commit.gpgSign=false` disables signing exactly as the lowercase spelling
# does, and was allowed while the lowercase one was blocked. Command names and
# flags stay case-sensitive, because git's are.
check_key() { grep -qiE -- "$1" <<< "$STRIPPED"; }

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
#
# READS ARE NOT WRITES. The first version of this rule matched the setting
# anywhere in a git command, so `git config --local core.hooksPath` — which
# prints the value and changes nothing — was refused, and refused the very
# diagnostic someone runs to check whether the hooks are installed. The read
# forms are a named allow-list, not a fall-through: --get, --get-all,
# --get-regexp, --list, -l, and the dashless `get`/`list` subcommands git now
# also accepts. Everything else touching the key is treated as a write,
# including --unset, which removes the setting and so disables the
# framework's hooks just as surely as pointing it elsewhere.
#
# CASE-INSENSITIVE (Purple #112, PT-03). git treats a config section and key
# case-insensitively — core.hooksPath, core.HooksPath and CORE.HOOKSPATH all
# disable the same hook — and the previous `check` (case-sensitive) missed
# every spelling but the lowercase one; `check_key` closes that the same way
# it already does for commit.gpgsign, below.
#
# ANCHORED READ EXEMPTION (Purple #112, PT-06). The previous exemption
# matched a read flag and `core\.hooksPath` ANYWHERE in the command, in either
# order, with nothing tying the two together, so a read flag that was only
# another key's VALUE exempted a commit that separately carried a hooksPath
# override. The exemption is now a positive match on one segment: the
# segment's own `git ... config` invocation, then only options from a closed
# list, then a read keyword (--get, --get-all, --get-regexp, --list, -l, get,
# list), then only options from the same list, then core.hooksPath. The
# closed list is deliberate: an option that takes a free-form value (such as
# --comment) is not in it, so its value can never be mistaken for the read
# keyword and the segment falls through to the block.
#
# PER SEGMENT (review of WU-IAENG-306). The stripped command is split on
# `;`, `&`, `|` and newline and each segment is judged alone, so a read in one
# segment cannot exempt a write to the same key in another. A segment is
# blocked when it names core.hooksPath in a git command and either fails the
# read match or carries a `-c` / `--config-env` that names hooksPath (a write
# layered under a read, never exempted).
READ_OPT="(--(global|system|local|worktree|show-origin|show-scope|includes|no-includes|null|name-only)|-z|--(file|blob|type|default)(=|${S}+)[^[:space:]]+)"
READ_HOOKSPATH="^[[:space:](\`{]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*${S}+)*${G}config${S}+(${READ_OPT}${S}+)*(--get(-all|-regexp)?|--list|-l|get|list)${S}+(${READ_OPT}${S}+)*core\.hooksPath"
WRITE_HOOKSPATH_VIA_C="git[^|;&]*(-c${S}+|--config-env(=|${S}+))core\.hooksPath"
HOOKSPATH_WRITE=0
while IFS= read -r SEG; do
  grep -qiE -- "git[^|;&]*core\.hooksPath" <<< "$SEG" || continue
  if ! grep -qiE -- "$READ_HOOKSPATH" <<< "$SEG" \
     || grep -qiE -- "$WRITE_HOOKSPATH_VIA_C" <<< "$SEG"; then
    HOOKSPATH_WRITE=1
  fi
done < <(printf '%s\n' "$STRIPPED" | tr ';&|' '\n')
if [ "$HOOKSPATH_WRITE" -eq 1 ]; then
  iaeng_block "setting core.hooksPath disables every git hook — the same effect as --no-verify, written as configuration" \
    "Standards/GIT_STANDARD.md, Escape Hatches. The sanctioned write of this setting is ./ia-engineering/Adapters/scripts/install.sh, which points it at the framework's hooks."
fi
# GIT_CONFIG_PARAMETERS encodes an arbitrary number of git config pairs —
# `GIT_CONFIG_PARAMETERS="'core.hooksPath' '/dev/null'"` disables hooks for
# every git command that inherits the variable — in a counted, escaped format
# this hook has no reliable way to decode from stripped command text (Purple
# #112, PT-03). Rather than parse that encoding and risk the same silent
# under-read every earlier lexer version fell to, the variable is refused as
# a token: unread input is refused, not assumed safe, same contract as the
# lexer's own LIMIT marker above.
if check "(^|[[:space:];&|(])GIT_CONFIG_PARAMETERS="; then
  iaeng_block "GIT_CONFIG_PARAMETERS sets arbitrary git config for every git command in scope, in an encoding this hook cannot verify is safe from stripped command text" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Set the value some other way and describe why in the commit, or ask a human to run it."
fi
# GIT_CONFIG_KEY_<n> (paired with GIT_CONFIG_VALUE_<n>) names one git config
# key per pair of variables, the indexed alternative to GIT_CONFIG_PARAMETERS.
# A key written as literal text is judged by the case-insensitive hooksPath
# rule above. This rule refuses the assignment when the key is not fully
# literal in the stripped command: the value is empty or ends at a separator,
# or it contains a `$` (a variable or command substitution, whole or as part
# of the key). A fully literal, non-hooksPath key such as safe.directory is
# unaffected.
if check 'GIT_CONFIG_KEY_[0-9]+=([[:space:];&|]|$|[^[:space:];&|]*\$)'; then
  iaeng_block "GIT_CONFIG_KEY_<n> names a git config key this hook cannot read after quote-stripping — refused rather than assumed to be something other than core.hooksPath" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Write the key literally in the command so it can be reviewed, or ask a human to run it."
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
# without blocking ordinary aliases. The hooksPath alternative is matched
# case-insensitively (check_key), same reason as the standalone hooksPath
# rule above (Purple #112, PT-03) — this branch is a second path to the same
# text, redundant with that rule for most inputs, and kept exact-match for
# the case-sensitive flags because git's own flag spellings are.
if check "${G}config[^|;&]*${S}alias\." \
   && { check '(--force|--no-verify|--no-gpg-sign|--hard|--mirror|-D|filter-repo|filter-branch)' \
        || check_key 'core\.hooksPath'; }; then
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
