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

function is_option_word(s) {
  return s ~ /^-{1,2}[A-Za-z][A-Za-z0-9=_-]*$/
}

{
  s = $0; n = length(s); i = 1
  out = ""          # text that reaches the rules
  mode = "out"      # out | sq | dq
  depth = 0         # open $( substitutions
  buf = ""          # current quoted region's content
  tainted = 0       # the current region contained a substitution

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
        out = out c d; i += 2; continue
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
        if (!tainted && is_option_word(buf)) out = out buf
        mode = "out"; buf = ""; tainted = 0
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
      if (!tainted && is_option_word(buf)) out = out buf
      mode = "out"; buf = ""; tainted = 0
      i++; continue
    }
    buf = buf c; i++
  }

  # An unterminated quote ran to the end of the text. Its content was never
  # closed, so it is not a lone option word and is dropped, as any other
  # quoted text would be.
  printf "%s", out
}
