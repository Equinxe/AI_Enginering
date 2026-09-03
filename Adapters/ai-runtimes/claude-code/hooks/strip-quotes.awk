# IA Engineering — strip-quotes.awk
#
# A small shell lexer used by block-escape-hatches.sh. Reads the whole command
# text as one record and prints only the text that is OUTSIDE single quotes,
# double quotes, and heredoc bodies — the text the shell would actually parse
# as words and options.
#
# Two earlier versions of this were regex passes in sed and both were defeated
# by real commands from this repository's own history: a per-line strip left
# the inner lines of a multi-line -m "..." message unstripped, and a whole-text
# strip mis-paired the quotes of the shell idiom '"'"' (a literal apostrophe
# inside single quotes), inverting every double-quoted region after it.
# Quoting is a state machine; only a state machine reads it correctly.
#
# Rules, walking the text once:
#   outside quotes   a backslash keeps itself and the next character (so an
#                    escaped `\--no-verify` still reaches the rules — the shell
#                    passes it to git unchanged); an apostrophe enters single-
#                    quote mode; a double quote enters double-quote mode; <<TAG
#                    (with optional -, spaces, and quoting of TAG) keeps the rest
#                    of that line and skips the body up to the line equal to TAG
#   single quotes    everything is skipped until the closing apostrophe
#   double quotes    a backslash skips the next character; the region ends at
#                    the closing double quote
#
# Kept as its own file rather than a quoted string inside the shell script so
# that no shell quoting applies to it at all: the program's $0 and quote
# characters are read by awk directly, and shellcheck has nothing to misread.

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
}
