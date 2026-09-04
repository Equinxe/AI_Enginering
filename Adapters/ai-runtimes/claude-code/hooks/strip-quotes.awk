# IA Engineering — strip-quotes.awk
#
# A small shell lexer used by block-escape-hatches.sh. Reads the whole command
# text as one record and prints only the text the shell would parse as words
# and options — everything outside quoted strings and heredoc bodies.
#
# Three earlier versions were regex passes, and each was defeated by a real
# command from this repository's own history: a per-line strip left the inner
# lines of a multi-line -m "..." message unstripped; a whole-text strip
# mis-paired the shell idiom '"'"' and inverted every region after it; and a
# quote-only state machine mis-paired the quotes inside "$(cmd "arg")", which
# is ordinary shell, and refused a command that contained no escape hatch at
# all. Quoting is a grammar with nesting; it needs a stack.
#
# THE GRAMMAR THIS MODELS
#
#   outside      \<newline>  line continuation -> one space, so
#                            `git \<newline>push --force` reads as one command
#                \x          keeps both, so an escaped \--no-verify still
#                            reaches the rules — the shell passes it through
#                '  "        opens a quoted region
#                $(          opens a command substitution: its contents are
#                            COMMANDS, so they are scanned, not stripped.
#                            `git push $(echo --force)` is not a way past the
#                            rules
#                <<TAG       keeps the rest of the line, skips the body up to
#                            the line equal to TAG
#   single       everything literal until the closing ' — including $( , which
#                the shell does not expand there
#   double       \x escapes; $( opens a substitution (scanned); " closes
#
# A quoted region is dropped, with ONE exception: when its entire content is a
# single option word — "--no-verify", '-f'. Quoting a lone flag is not how
# anyone writes a message; it is how a flag gets past a text filter, and the
# shell passes it to the command identically either way. A region that
# contained a substitution is never treated as a lone option word.
#
# WHAT THIS DELIBERATELY DOES NOT CATCH: a flag assembled at runtime and not
# visible in the text — `F=--force; git push $F`, `eval "$CMD"`, a flag read
# from a file. Recovering those means evaluating the command, which is the
# thing this hook exists to happen *before*. The hook stops an escape hatch
# reached for by habit; it is not an adversary boundary. What stops a
# determined bypass is the server side — the pre-push hook, branch protection,
# and the required CI checks — none of which a developer machine can skip.
# Adapters/ai-runtimes/claude-code/hooks/README.md states the same boundary.
#
# Kept as its own file rather than a quoted string inside the shell script, so
# that no shell quoting applies to the program itself.

BEGIN { RS = "\001"; SQ = "\047" }

# A quoted region that holds ONE word with no whitespace is quoting for no
# effect: the shell hands `"reset"` to git exactly as it hands `reset`, and
# `"--no-verify"` exactly as `--no-verify`. Dropping those was how a quoted
# subcommand — `git "reset" --hard HEAD` — walked past every rule. A region
# holding a phrase is a message and is still dropped.
function is_bare_word(s) {
  return s != "" && s !~ /[ \t\n]/
}

# ANSI-C quoting decodes escapes before the shell ever sees the word:
# `git push $'\x2d\x2dforce'` passes --force. Without this, dropping the `$`
# alone still left `\x2d\x2dforce`, which matches nothing. Hex, octal and
# \u are decoded; the common single-character escapes are folded to their
# character so that a `\t` inside the word does not read as a word break.
function decode_ansic(s,   out, i, n, c, d, hex, oct, v, j) {
  out = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c != "\\") { out = out c; i++; continue }
    d = substr(s, i + 1, 1)
    if (d == "x" || d == "u" || d == "U") {
      # Each form has a MAXIMUM digit count in the shell — \x takes two, \u
      # four, \U eight — and reading greedily past it is wrong in a way that
      # hides the attack rather than revealing it: `\x2d\x2dforce` decoded as
      # `2df` (735, out of range, dropped) and produced `-orce`, so the flag
      # vanished and the rules matched nothing.
      maxlen = (d == "x") ? 2 : ((d == "u") ? 4 : 8)
      hex = ""; j = i + 2
      while (j <= n && substr(s, j, 1) ~ /[0-9A-Fa-f]/ && length(hex) < maxlen) {
        hex = hex substr(s, j, 1); j++
      }
      if (hex != "") {
        v = 0
        for (k = 1; k <= length(hex); k++) {
          v = v * 16 + index("0123456789abcdef", tolower(substr(hex, k, 1))) - 1
        }
        if (v > 0 && v < 256) out = out sprintf("%c", v)
        i = j; continue
      }
      out = out d; i += 2; continue
    }
    if (d ~ /[0-7]/) {
      oct = ""; j = i + 1
      while (j <= n && substr(s, j, 1) ~ /[0-7]/ && length(oct) < 3) {
        oct = oct substr(s, j, 1); j++
      }
      v = 0
      for (k = 1; k <= length(oct); k++) v = v * 8 + (substr(oct, k, 1) + 0)
      if (v > 0 && v < 256) out = out sprintf("%c", v)
      i = j; continue
    }
    if (d == "n" || d == "t" || d == "r") { out = out " "; i += 2; continue }
    out = out d; i += 2
  }
  return out
}

# Brace expansion needs no quoting at all, so it reached the rules verbatim:
# `git push --{f,f}orce` is `git push --force` to the shell. Rather than
# implementing the shell's expander, each simple comma group is expanded in
# place and every alternative APPENDED to the text. The rules only need the
# flag to appear somewhere, so appending is enough, and it can only ever
# over-match. Bounded, because an unbounded expander on hostile input is its
# own problem.
function expand_braces(s,   extra, guard, grp, inner, alts, n, k, pre, post) {
  extra = ""
  guard = 0
  while (match(s, /\{[^{}]*,[^{}]*\}/) && guard < 8) {
    guard++
    grp = substr(s, RSTART, RLENGTH)
    pre = substr(s, 1, RSTART - 1)
    post = substr(s, RSTART + RLENGTH)
    inner = substr(grp, 2, length(grp) - 2)
    n = split(inner, alts, ",")
    for (k = 1; k <= n && k <= 8; k++) extra = extra " " pre alts[k] post
    s = pre alts[1] post
  }
  return extra
}

# The word before a quoted region decides whether that region is DATA or
# CODE. After `eval`, or after a `-c` (as in `bash -c`, `sh -c`), the shell
# runs the contents as commands, so they are scanned as commands. Before this,
# `bash -c 'git commit --no-verify -m x'` and `eval "git push --force"` were
# both allowed: a four-character prefix disabled every rule in the hook.
# Scanning too much here can only over-block, never under-block.
function is_command_context(w) {
  # -c, and any short-option bundle ending in c: `bash -lc "..."` runs its
  # argument exactly as `bash -c` does, and was allowed while `bash -c`,
  # `sh -c` and `eval` were all blocked.
  #
  # An alias VALUE is command text too: `git config alias.yolo "push --force"`
  # writes a control-disabling command into the clone's configuration, which is
  # the category core.hooksPath sits in. Surfacing the value is what lets the
  # alias rule in block-escape-hatches.sh see it.
  return w == "eval" || w == "--command" || w ~ /^-[A-Za-z]*c$/ || w ~ /^alias\./
}

{
  s = $0; n = length(s); i = 1
  out = ""          # text that reaches the rules
  mode = "out"      # out | sq | dq
  depth = 0         # open $( substitutions
  buf = ""          # current quoted region's content
  tainted = 0       # the current region contained a substitution
  cmdctx = 0        # the current region is command text, not data
  ansic = 0         # the current region is $'...' and decodes escapes
  nw = 0

  while (i <= n) {
    c = substr(s, i, 1)
    d = substr(s, i + 1, 1)

    if (mode == "out") {
      if (c == "\\") {
        # A line continuation is REMOVED by the shell, not replaced by a
        # space: `git \<newline>push` is `gitpush`, and `git \<newline>push`
        # with the space before the backslash is `git push`. Emitting a space
        # here produced a double space, which the rules tolerated but which
        # made the lexer's output stop being what the shell would read.
        if (d == "\n") { i += 2; continue }
        # OUTSIDE QUOTES THE BACKSLASH IS DROPPED AND THE CHARACTER KEPT —
        # which is what the shell does. Keeping both let a backslash INSIDE a
        # flag defeat every rule: `git commit --no-veri\fy -m x` reaches git as
        # `--no-verify` (confirmed: printf "[%s]" --no-veri\fy prints
        # [--no-verify]) while the rules saw `--no-veri\fy` and matched
        # nothing. The same shape as the quoted-flag bypass, one layer down.
        # `\--no-verify` still matches, because dropping the backslash leaves
        # exactly `--no-verify`.
        out = out d; i += 2; continue
      }
      if (c == "$" && d == "(") {
        stack[depth] = "out"; depth++
        out = out " "; i += 2; continue
      }
      if (c == ")" && depth > 0) {
        depth--; mode = stack[depth]
        if (mode != "out") { tainted = 1 }
        out = out " "; i++; continue
      }
      if (c == SQ || c == "\"") {
        mode = (c == SQ) ? "sq" : "dq"
        buf = ""; tainted = 0

        # A `$` immediately before the quote is ANSI-C ($'...') or locale
        # ($"...") quoting, and the shell CONSUMES it: `git push $'--force'`
        # passes `--force`. Emitting the `$` left `$--force` in the text, which
        # kept the flag but destroyed the whitespace boundary every rule
        # anchors on — seven of the eight rules stopped matching from this one
        # character. The `$` is dropped here and, for the $'...' form, the
        # region's ANSI-C escapes are decoded below.
        ansic = 0
        if (out != "" && substr(out, length(out), 1) == "$") {
          out = substr(out, 1, length(out) - 1)
          if (mode == "sq") ansic = 1
        }
        # The last whitespace-delimited word already emitted decides whether
        # what follows is data or code. The trailing separator is trimmed
        # first: splitting "eval " yields an empty final field, which read as
        # "not a command context" and left eval's argument dropped.
        prev = out
        sub(/[ \t\n]+$/, "", prev)
        nw = split(prev, words, /[ \t\n]+/)
        cmdctx = (nw > 0) ? is_command_context(words[nw]) : 0
        i++; continue
      }
      if (c == "<" && d == "<") {
        j = i + 2
        if (substr(s, j, 1) == "-") j++
        while (substr(s, j, 1) == " " || substr(s, j, 1) == "\t") j++
        q = substr(s, j, 1)
        if (q == SQ || q == "\"") j++
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
            if (k == 0) { line = substr(s, pos); pos = n + 1 }
            else { line = substr(s, pos, k - 1); pos += k }
            if (line == tag) break
          }
          i = pos; continue
        }
      }
      out = out c; i++; continue
    }

    if (mode == "sq") {
      if (c == SQ) {
        if (ansic) buf = decode_ansic(buf)
        if (cmdctx) out = out " " buf " "
        else if (!tainted && is_bare_word(buf)) out = out buf
        mode = "out"; buf = ""; tainted = 0; cmdctx = 0; ansic = 0
        i++; continue
      }
      buf = buf c; i++; continue
    }

    # mode == "dq"
    if (c == "\\") { buf = buf c d; i += 2; continue }
    if (c == "$" && d == "(") {
      stack[depth] = "dq"; depth++
      mode = "out"; tainted = 1; buf = ""
      out = out " "; i += 2; continue
    }
    if (c == "\"") {
      if (cmdctx) out = out " " buf " "
      else if (!tainted && is_bare_word(buf)) out = out buf
      mode = "out"; buf = ""; tainted = 0; cmdctx = 0
      i++; continue
    }
    buf = buf c; i++
  }

  # An unterminated quote ran to the end of the text. Its content was never
  # closed, so it is not a lone option word and is dropped, as any other
  # quoted text would be.
  printf "%s%s", out, expand_braces(out)
}
