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
# A small shell lexer, not a regex pass. Two earlier versions were regex
# passes and both were defeated by real commands from this repository's own
# history: a per-line strip left the inner lines of a multi-line -m "..."
# message unstripped, and a whole-text strip mis-paired the quotes of the
# shell idiom '"'"' (a literal apostrophe inside single quotes), inverting
# every double-quoted region after it. Quoting is a state machine; only a
# state machine reads it correctly. This one walks the text once: outside
# quotes, a backslash escapes the next character and <<TAG opens a heredoc
# whose body is skipped up to the line equal to TAG; inside single quotes
# everything is skipped until the closing quote; inside double quotes a
# backslash escapes the next character and the region ends at the closing
# quote. Only text OUTSIDE quotes and heredoc bodies reaches the rules.
AWK_STRIP='
BEGIN { RS = "\001" }
{
  s = $0; n = length(s); i = 1; mode = 0; out = ""
  while (i <= n) {
    c = substr(s, i, 1)
    if (mode == 0) {
      if (c == "\\") { out = out c substr(s, i + 1, 1); i += 2; continue }
      if (c == "\047") { mode = 1; i++; continue }
      if (c == "\"")   { mode = 2; i++; continue }
      if (c == "<" && substr(s, i + 1, 1) == "<") {
        j = i + 2
        if (substr(s, j, 1) == "-") j++
        while (substr(s, j, 1) == " " || substr(s, j, 1) == "\t") j++
        q = substr(s, j, 1)
        if (q == "\047" || q == "\"") j++
        tag = ""
        while (j <= n && substr(s, j, 1) ~ /[A-Za-z0-9_]/) { tag = tag substr(s, j, 1); j++ }
        if (tag != "") {
          k = index(substr(s, j), "\n")
          if (k == 0) { out = out substr(s, i, j - i); i = j; continue }
          lineend = j + k - 1
          out = out substr(s, i, lineend - i + 1)
          pos = lineend + 1
          while (pos <= n) {
            k = index(substr(s, pos), "\n")
            if (k == 0) { line = substr(s, pos); pos = n + 1 } else { line = substr(s, pos, k - 1); pos += k }
            if (line == tag) break
          }
          i = pos; continue
        }
      }
      out = out c; i++; continue
    }
    if (mode == 1) { if (c == "\047") mode = 0; i++; continue }
    if (mode == 2) {
      if (c == "\\") { i += 2; continue }
      if (c == "\"") mode = 0
      i++; continue
    }
  }
  printf "%s", out
}'
STRIPPED="$(printf '%s\n' "$CMD" | awk "$AWK_STRIP")"

# --- Rules: pattern → reason ----------------------------------------------------
# Each is matched against the stripped command. [^|;&]* keeps a match inside one
# pipeline segment so `git push origin x && echo -f` is not misread.
G='git[[:space:]]+'
S='[[:space:]]'

check() { printf '%s\n' "$STRIPPED" | grep -qE -- "$1"; }

if check '--no-verify'; then
  iaeng_block "--no-verify disables the commit-msg and pre-commit hooks — attribution and data protection in one motion" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Fix what the hook refuses; if the hook is wrong, that is a Work Unit against the hook."
fi
if check '--no-gpg-sign|commit\.gpgsign=false'; then
  iaeng_block "disabling commit signing" "Standards/GIT_STANDARD.md, Escape Hatches. Fix the signing setup."
fi
if check "${G}stash(${S}|$)" && ! check "${G}stash${S}+(list|show)(${S}|$)"; then
  iaeng_block "git stash sets work aside with no record; it is local, unlabelled, and lost with the clone" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Commit as work in progress on the feature branch, or open a second branch."
fi
if check "${G}(rebase|add|commit|checkout|reset)[^|;&]*${S}(-i|--interactive|-p|--patch)(${S}|$)"; then
  iaeng_block "interactive git command in a non-interactive session — it hangs or does nothing, and the session assumes a result" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Use the non-interactive equivalent and verify with git log / git status."
fi
if check "${G}push[^|;&]*${S}(-f|--force|--force-with-lease(=[^[:space:]]*)?|--mirror)(${S}|$)"; then
  iaeng_block "force-push or mirror-push — rewrites history every collaborator has" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (Critical). The one sanctioned rewrite is the data-purge protocol, run by a human on a Director decision."
fi
if check "${G}push[^|;&]*${S}(-d|--delete)${S}+[^[:space:]]+${S}+(main|develop|release/)"; then
  iaeng_block "deleting a protected branch on the remote" \
    "Standards/BRANCH_STANDARD.md; Standards/GIT_STANDARD.md, Escape Hatches. Release branches are never deleted."
fi
if check "${G}reset[^|;&]*${S}--hard(${S}|$)"; then
  iaeng_block "git reset --hard discards uncommitted work and moves the branch without a record" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Inspect first; prefer a new branch or a single-path checkout."
fi
if check "${G}clean[^|;&]*${S}-[a-zA-Z]*f"; then
  iaeng_block "git clean -f deletes untracked files that may not be yours" \
    "Standards/GIT_STANDARD.md, Escape Hatches; Standards/RISK_STANDARD.md (High). Surface unexpected files instead of deleting them."
fi
if check "${G}(checkout|restore)[^|;&]*${S}(--${S}+)?\.(${S}|$)"; then
  iaeng_block "discarding every working-tree change at once (checkout -- . / restore .)" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Restore the one path you mean, by name."
fi
if check "${G}branch[^|;&]*${S}-D(${S}|$)"; then
  iaeng_block "force-deleting a branch (-D) discards unmerged commits" \
    "Standards/GIT_STANDARD.md, Escape Hatches. Use -d, which refuses when the branch is unmerged — that refusal is information."
fi
if check "${G}filter-(branch|repo)(${S}|$)"; then
  iaeng_block "history rewrite" \
    "Standards/DATA_PROTECTION_STANDARD.md, purge protocol — a Director decision executed by a human, with a bundle backup first."
fi
if check "(^|${S}|;|&&|\|)rm${S}+-[a-zA-Z]*r[a-zA-Z]*${S}+(-[a-zA-Z]+${S}+)*(/|\.git|\.git/)(${S}|$)"; then
  iaeng_block "recursive removal of the repository metadata or the filesystem root" \
    "Standards/RISK_STANDARD.md, operational catalog (Critical)."
fi

exit 0
