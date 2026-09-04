# IA Engineering — strip-quotes.awk
#
# A small shell lexer used by block-escape-hatches.sh. Reads the whole command
# text as one record and prints only the text the shell would parse as words
# and options.
#
# Four earlier versions were defeated by real commands, each one a layer deeper
# than the last: a per-line regex strip missed a multi-line -m message; a
# whole-text regex strip mis-paired the idiom '"'"' and inverted every region
# after it; a quote-only state machine mis-paired "$(cmd "arg")"; and an
# ANSI-C branch bolted onto the single-quote state let `$'\''` close the region
# early, after which the rest of the line was swallowed and EVERY rule saw a
# command ending at `git commit`. That last one failed open and said nothing,
# which is the opposite of what these hooks promise.
#
# So: $'...' is its own state, not single-quoting with a decoder attached.
#
# THE GRAMMAR THIS MODELS
#
#   outside      \<newline>  line continuation, removed as the shell removes it
#                \x          the backslash is dropped and the character kept,
#                            because that is what the shell passes on —
#                            `--no-veri\fy` reaches git as `--no-verify`.
#                            \{ and \} are kept as LITERAL braces, marked so
#                            that brace expansion skips them, since the shell
#                            does not expand an escaped brace
#                '  "        opens a quoted region
#                $'  $"      ANSI-C and locale quoting: the $ is consumed by
#                            the shell, so it is dropped here too. Leaving it
#                            glued to the flag destroyed the whitespace
#                            boundary seven of the eight rules anchor on
#                $(  `       command substitution: the contents are COMMANDS,
#                            so they are scanned, not stripped
#                <<TAG       keeps the rest of the line, skips the body up to
#                            the line equal to TAG
#   single       everything literal until the closing '
#   ansic        $'...' — a backslash escapes the NEXT CHARACTER, so \' does
#                not close the region. Escapes are decoded on close: \xHH,
#                \NNN, \uHHHH, each capped at the shell's own digit count
#   double       \x escapes; $( and ` open substitutions; " closes
#
# A quoted region is dropped, with one exception: when its entire content is a
# single word with no whitespace — "--no-verify", "reset", '-f'. Quoting a lone
# word is not how anyone writes a message; it is how a token gets past a text
# filter, and the shell passes it on identically either way. Braces inside such
# a word are marked literal, because the shell does not expand a quoted brace.
#
# BRACE EXPANSION needs no quoting at all, so it is done here: comma groups and
# simple ranges are expanded and every alternative APPENDED to the text. The
# rules only need the token to appear somewhere, so appending suffices and can
# only over-match. When a bound is reached the lexer emits __IAENG_LEXER_LIMIT__
# instead of a partial expansion, and the hook blocks on that marker — a bound
# an attacker clears by typing one more comma is not a bound.
#
# WHAT THIS DELIBERATELY DOES NOT CATCH: a token assembled at runtime and never
# visible in the text — `F=--force; git push $F`, `eval "$CMD"`, a flag read
# from a file. Recovering those means evaluating the command, which is the
# thing this hook exists to happen *before*. The hook stops an escape hatch
# reached for by habit; it is not an adversary boundary, and
# Adapters/ai-runtimes/claude-code/hooks/README.md says so. What stops a
# determined bypass is the server side — the pre-push hook, branch protection,
# and the required CI checks — none of which a developer machine can skip.

BEGIN {
  RS = "\001"
  SQ = "\047"
  BL = "\002"          # a literal { the shell will not expand
  BR = "\003"          # a literal }
  LIMIT = " __IAENG_LEXER_LIMIT__ "
  MAX_ALTS = 32        # alternatives in one group
  MAX_GROUPS = 16      # groups expanded in one command
  MAX_SPAN = 64        # values in one {a..z} range
}

function is_bare_word(s) {
  return s != "" && s !~ /[ \t\n]/
}

function is_command_context(w) {
  # -c and any short bundle ending in c (`bash -lc`), eval, and an alias VALUE:
  # `git config alias.yolo "push --force"` writes a control-disabling command
  # into the clone's configuration, and unlike variable indirection the value
  # is literal text, so it is reachable.
  return w == "eval" || w == "--command" || w ~ /^-[A-Za-z]*c$/ || w ~ /^alias\./
}

# Braces that came from a quoted or escaped source are literal to the shell.
function mark_literal_braces(s) {
  gsub(/\{/, BL, s)
  gsub(/\}/, BR, s)
  return s
}

function decode_ansic(s,   res, i, n, c, d, hex, oct, v, j, k, maxlen) {
  res = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c != "\\") { res = res c; i++; continue }
    d = substr(s, i + 1, 1)
    if (d == "x" || d == "u" || d == "U") {
      # Each form has a maximum digit count in the shell. Reading greedily is
      # wrong in the direction that HIDES an attack: \x2d\x2dforce decoded as
      # 2df (735, out of range, dropped) and produced -orce.
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
        if (v > 0 && v < 256) res = res sprintf("%c", v)
        i = j; continue
      }
      res = res d; i += 2; continue
    }
    if (d ~ /[0-7]/) {
      oct = ""; j = i + 1
      while (j <= n && substr(s, j, 1) ~ /[0-7]/ && length(oct) < 3) {
        oct = oct substr(s, j, 1); j++
      }
      v = 0
      for (k = 1; k <= length(oct); k++) v = v * 8 + (substr(oct, k, 1) + 0)
      if (v > 0 && v < 256) res = res sprintf("%c", v)
      i = j; continue
    }
    # \n \t \r become a space so the word breaks the way the shell breaks it;
    # anything else, including \' and \\, yields the character itself.
    if (d == "n" || d == "t" || d == "r") { res = res " "; i += 2; continue }
    res = res d; i += 2
  }
  return res
}

# Returns the alternatives of one range group, or the limit marker.
function expand_range(a, b,   res, i, lo, hi) {
  if (a ~ /^-?[0-9]+$/ && b ~ /^-?[0-9]+$/) {
    lo = a + 0; hi = b + 0
    if (hi < lo) { i = lo; lo = hi; hi = i }
    if (hi - lo > MAX_SPAN) return LIMIT
    res = ""
    for (i = lo; i <= hi; i++) res = res " " i
    return res
  }
  if (length(a) == 1 && length(b) == 1) {
    lo = index(CHARS, a); hi = index(CHARS, b)
    if (lo == 0 || hi == 0) return ""
    if (hi < lo) { i = lo; lo = hi; hi = i }
    if (hi - lo > MAX_SPAN) return LIMIT
    res = ""
    for (i = lo; i <= hi; i++) res = res " " substr(CHARS, i, 1)
    return res
  }
  return ""
}

function expand_braces(s,   extra, groups, grp, inner, alts, n, k, pre, post, a, b, r) {
  extra = ""
  groups = 0

  while (match(s, /\{[^{}]*(,|\.\.)[^{}]*\}/)) {
    groups++
    if (groups > MAX_GROUPS) return extra LIMIT
    grp = substr(s, RSTART, RLENGTH)
    pre = substr(s, 1, RSTART - 1)
    post = substr(s, RSTART + RLENGTH)
    inner = substr(grp, 2, length(grp) - 2)

    if (index(inner, "..") > 0) {
      a = substr(inner, 1, index(inner, "..") - 1)
      b = substr(inner, index(inner, "..") + 2)
      r = expand_range(a, b)
      if (r == LIMIT) return extra LIMIT
      n = split(r, alts, " ")
      # split() on a leading-space string yields an empty first field on some
      # awks; re-split without it.
      sub(/^ /, "", r)
      n = split(r, alts, " ")
    } else {
      n = split(inner, alts, ",")
    }

    if (n > MAX_ALTS) return extra LIMIT
    if (n == 0) { s = pre post; continue }
    for (k = 1; k <= n; k++) extra = extra " " pre alts[k] post
    s = pre alts[1] post
  }
  return extra
}

{
  s = $0; n = length(s); i = 1
  out = ""
  mode = "out"
  depth = 0
  buf = ""
  tainted = 0
  cmdctx = 0
  CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

  while (i <= n) {
    c = substr(s, i, 1)
    d = substr(s, i + 1, 1)

    if (mode == "out") {
      if (c == "\\") {
        if (d == "\n") { i += 2; continue }
        if (d == "{") { out = out BL; i += 2; continue }
        if (d == "}") { out = out BR; i += 2; continue }
        out = out d; i += 2; continue
      }
      if (c == "$" && d == "(") {
        stack[depth] = "out"; depth++
        out = out " "; i += 2; continue
      }
      if (c == "`") {
        # Backticks are command substitution too; their contents are commands.
        out = out " "; i++; continue
      }
      if (c == ")" && depth > 0) {
        depth--; mode = stack[depth]
        if (mode != "out") tainted = 1
        out = out " "; i++; continue
      }
      if (c == "$" && (d == SQ || d == "\"")) {
        # The shell consumes the $ in $'...' and $"...".
        mode = (d == SQ) ? "ansic" : "dq"
        buf = ""; tainted = 0
        prev = out; sub(/[ \t\n]+$/, "", prev)
        nw = split(prev, words, /[ \t\n]+/)
        cmdctx = (nw > 0) ? is_command_context(words[nw]) : 0
        i += 2; continue
      }
      if (c == SQ || c == "\"") {
        mode = (c == SQ) ? "sq" : "dq"
        buf = ""; tainted = 0
        prev = out; sub(/[ \t\n]+$/, "", prev)
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
        if (cmdctx) out = out " " buf " "
        else if (!tainted && is_bare_word(buf)) out = out mark_literal_braces(buf)
        mode = "out"; buf = ""; tainted = 0; cmdctx = 0
        i++; continue
      }
      buf = buf c; i++; continue
    }

    if (mode == "ansic") {
      # A backslash escapes the NEXT CHARACTER here, so \' does not close the
      # region. Getting this wrong let a four-character token desynchronise the
      # lexer and swallow the rest of the command.
      if (c == "\\" && i < n) { buf = buf c d; i += 2; continue }
      if (c == SQ) {
        buf = decode_ansic(buf)
        if (cmdctx) out = out " " buf " "
        else if (is_bare_word(buf)) out = out mark_literal_braces(buf)
        mode = "out"; buf = ""; tainted = 0; cmdctx = 0
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
    if (c == "`") { tainted = 1; buf = buf " "; i++; continue }
    if (c == "\"") {
      if (cmdctx) out = out " " buf " "
      else if (!tainted && is_bare_word(buf)) out = out mark_literal_braces(buf)
      mode = "out"; buf = ""; tainted = 0; cmdctx = 0
      i++; continue
    }
    buf = buf c; i++
  }

  # An unterminated quote ran to the end of the text and is dropped, as any
  # other quoted text would be.
  result = out expand_braces(out)
  gsub(BL, "{", result)
  gsub(BR, "}", result)
  printf "%s", result
}
