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
# WHAT THIS MODELS AT RUNTIME, and where the line is. The shell's own
# constructions are decoded: quoting, ANSI-C `$'\x2d'`, brace expansion, command
# substitution, and printf's backslash escapes (`printf '\x2d\x2dforce'` reaches
# git as `--force`, so printf in command position has its argument decoded — see
# is_decode_context). These are deterministic shell mechanics, readable without
# running anything.
#
# WHAT THIS DELIBERATELY DOES NOT CATCH: a token an EXTERNAL program builds or a
# name carries — `$(python -c ...)`, `$(base64 -d ...)`, `$(echo .. | tr . -)`,
# a flag read from a file, `F=--force; git push $F`, `eval "$CMD"`, or a token
# split across two variables. Recovering those means evaluating the command,
# which is the thing this hook exists to happen *before*, and each is trivially
# interchangeable with the next — closing one leaves the rest, so the honest
# boundary is "shell mechanics, yes; runtime values, no." The hook stops an
# escape hatch reached for by habit; it is not an adversary boundary, and
# Adapters/ai-runtimes/claude-code/hooks/README.md says so. What stops a
# determined bypass is the server side — branch protection and the required CI
# checks, which run where a developer machine cannot skip them (within the
# conditions stated in SECURITY.md, Where the boundary is). The pre-push hook
# is a second local guardrail, not part of that boundary — it is skipped by
# --no-verify or a core.hooksPath override — the escape hatches the runtime
# hook refuses.

BEGIN {
  RS = "\001"
  SQ = "\047"
  BL = "\002"          # a literal { the shell will not expand
  BR = "\003"          # a literal }
  PH = "\004"          # whitespace inside a quoted region, KEEPQ mode only
  LIMIT = " __IAENG_LEXER_LIMIT__ "
  MAX_ALTS = 32        # alternatives in one group
  MAX_GROUPS = 16      # groups expanded in one command
  MAX_SPAN = 64        # values in one {a..z} range
  CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  # awk has no ord(); this is it. Needed for \cX, where bash produces the
  # control character X & 0x1f.
  for (_i = 1; _i < 256; _i++) ORD[sprintf("%c", _i)] = _i
}

# THE ONE INVARIANT OF THIS FILE
#
# Whatever it cannot read, it says so — it never drops it. Every fail-open
# defect found in this lexer has been the same shape: a path that discarded
# input it could not model and returned as if it had read it, so the rules
# matched a command that was not the one being run and the hook exited 0.
# `LIMIT` is the answer to "I could not read this"; the hook refuses on it.
# A new branch here that returns without either emitting the text or emitting
# LIMIT is a bug of that kind, whatever else it does.

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

# printf DECODES the backslash escapes in its arguments at runtime, so a
# single-quoted `printf '\x2d\x2dforce'` reaches git as `--force` — the exact
# escape family this lexer already decodes for ANSI-C `$'...'`, spelled through a
# command instead of a quote. Leaving that gap was an inconsistency: `$'\x2d'`
# was caught, `printf '\x2d'` was not. When the word before a quote is printf,
# its string argument is decoded like an ANSI-C region instead of kept literal.
#
# THIS IS SHELL-MECHANIC MODELLING, NOT AN ADVERSARY BOUNDARY. It cannot, and
# does not, see a token an EXTERNAL program builds — `$(python -c ...)`,
# `$(base64 -d ...)`, `$(echo .. | tr . -)`, a flag read from a file, or a token
# split across two variables. Those remain out of scope by construction, exactly
# as README.md and the header of this file state; the server side (branch
# protection and the required CI checks — see README.md, Not an adversary
# boundary) is what stops a determined bypass.
function is_decode_context(w) {
  return w == "printf" || w ~ /\/printf$/
}

# Pulls the COMMANDS out of an unquoted heredoc body: the contents of every
# $( ) and every backtick pair, and nothing else. The surrounding text is data
# — it becomes the command's stdin — so it is dropped, which keeps the reason
# the body-skip exists in the first place.
function extract_subs(b,   res, i, n, c, d, depth, start) {
  res = ""; n = length(b); i = 1
  while (i <= n) {
    c = substr(b, i, 1); d = substr(b, i + 1, 1)
    if (c == "\\") { i += 2; continue }
    if (c == "$" && d == "(") {
      depth = 1; i += 2; start = i
      while (i <= n && depth > 0) {
        c = substr(b, i, 1)
        if (c == "$" && substr(b, i + 1, 1) == "(") { depth++; i += 2; continue }
        if (c == ")") { depth--; if (depth == 0) break }
        i++
      }
      res = res " " substr(b, start, i - start) " "
      i++; continue
    }
    if (c == "`") {
      i++; start = i
      while (i <= n && substr(b, i, 1) != "`") i++
      res = res " " substr(b, start, i - start) " "
      i++; continue
    }
    i++
  }
  return res
}

# KEEPQ MODE (`awk -v KEEPQ=1`, used only by the approval-label rule in
# block-escape-hatches.sh). Keeps every top-level quoted region, with each
# whitespace character, `;`, `&` and `|` inside it replaced by PH (a control
# character that is not whitespace to a regex), so a quoted separator cannot
# split the command either. A quoted value `"help wanted,size/approved"` survives
# as ONE word, while a flag or a command that only appears INSIDE quoted text
# (`--body "run gh pr edit --add-label x"`) loses the whitespace boundary every
# rule anchors on, so quoted prose never reads as a command. Heredoc bodies are
# still skipped. Unset, this mode does nothing: the default output is unchanged.
function keepq(s) {
  gsub(/[ \t\n;&|]/, PH, s)
  return mark_literal_braces(s)
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
      # NUL TRUNCATES, as it does in the shell: bash discards the remainder of
      # the $'...' string. Continuing to decode past it produced a word that
      # the shell never forms — `$'--force\c@DECOY'` reached git as `--force`
      # while the rules saw `--forcec@DECOY` and matched nothing.
      if (v == 0) return res
      if (v < 256) res = res sprintf("%c", v)
      i = j; continue
    }
    # \cX is control-X: it CONSUMES the next character, and X & 0x1f is the
    # code. \c@ is NUL, so it truncates. Falling through to the catch-all gave
    # `\c` -> `c` and left the decoy text in place, which is the bypass above.
    if (d == "c") {
      e = substr(s, i + 2, 1)
      if (e == "") return res
      v = ORD[e] % 32
      if (v == 0) return res
      res = res sprintf("%c", v)
      i += 3; continue
    }
    # The single-character escapes, as their actual control characters rather
    # than as their letter. Decoding \f to "f" made `--forc\fe` read as
    # `--forcfe`, which is neither what the shell forms nor a match.
    if (d == "a") { res = res sprintf("%c", 7);  i += 2; continue }
    if (d == "b") { res = res sprintf("%c", 8);  i += 2; continue }
    if (d == "e" || d == "E") { res = res sprintf("%c", 27); i += 2; continue }
    if (d == "f") { res = res sprintf("%c", 12); i += 2; continue }
    if (d == "v") { res = res sprintf("%c", 11); i += 2; continue }
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

function expand_braces(s,   extra, groups, grp, inner, alts, n, k, pre, post, r, ends, m) {
  extra = ""
  groups = 0

  while (match(s, /\{[^{}]*(,|\.\.)[^{}]*\}/)) {
    groups++
    if (groups > MAX_GROUPS) return extra LIMIT
    grp = substr(s, RSTART, RLENGTH)
    pre = substr(s, 1, RSTART - 1)
    post = substr(s, RSTART + RLENGTH)
    inner = substr(grp, 2, length(grp) - 2)

    # COMMA FIRST, because bash splits top-level commas before it looks for a
    # range. Testing for ".." first read `{+..,}` as a range, failed to expand
    # it, and deleted the group — while bash produced `+..main` and `main`.
    if (index(inner, ",") > 0) {
      n = split(inner, alts, ",")
    } else {
      # {a..b} and the increment form {a..b..incr}. The increment is ignored
      # and the whole endpoint range emitted, which is a SUPERSET of what the
      # shell produces — the safe direction, since a superset can only
      # over-match. Reading `{o..o..1}` as endpoints `o` and `o..1` made
      # expand_range fail, and the group was then deleted: `--f{o..o..1}rce`
      # reached git as `--force` and the rules saw the braces intact.
      m = split(inner, ends, /\.\./)
      if (m < 2 || m > 3) return extra LIMIT
      r = expand_range(ends[1], ends[2])
      if (r == LIMIT || r == "") return extra LIMIT
      sub(/^ /, "", r)
      n = split(r, alts, " ")
    }

    # Both of these mean the group was not read. That is what LIMIT is for;
    # deleting the group instead is how every rule in the table fell to three
    # characters.
    if (n == 0) return extra LIMIT
    if (n > MAX_ALTS) return extra LIMIT
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
  decodectx = 0

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
        decodectx = (nw > 0) ? is_decode_context(words[nw]) : 0
        i += 2; continue
      }
      if (c == SQ || c == "\"") {
        mode = (c == SQ) ? "sq" : "dq"
        buf = ""; tainted = 0
        prev = out; sub(/[ \t\n]+$/, "", prev)
        nw = split(prev, words, /[ \t\n]+/)
        cmdctx = (nw > 0) ? is_command_context(words[nw]) : 0
        decodectx = (nw > 0) ? is_decode_context(words[nw]) : 0
        i++; continue
      }
      # `<<<` IS A HERE-STRING, NOT A HEREDOC. It consumes one word on the
      # same line and no following lines at all. Testing `<<` first read the
      # first two characters as a heredoc whose tag came from after the third
      # `<`, which found no terminator — so the previous Work Unit's
      # fail-closed change turned that into a refusal of an ordinary
      # `cat <<<hello`. Emitted as an operator; its word then lexes normally,
      # which is right, because an unquoted here-string word is expanded.
      if (c == "<" && d == "<" && substr(s, i + 2, 1) == "<") {
        out = out "<<<"; i += 3; continue
      }
      if (c == "<" && d == "<") {
        j = i + 2
        # `<<-` strips leading TABS from the body *and from the terminator
        # line*, so the terminator must be compared with its tabs removed.
        # Comparing the raw line meant `<<-EOF` with an indented `EOF` never
        # matched, the search ran to the end, and a perfectly ordinary
        # command was refused as unreadable.
        dash = 0
        if (substr(s, j, 1) == "-") { dash = 1; j++ }
        while (substr(s, j, 1) == " " || substr(s, j, 1) == "\t") j++
        # THE TAG IS A WORD WHOSE QUOTES ARE REMOVED, which is how bash reads
        # it: `<<E"O"F`, `<<E'O'F` and `<<\EOF` all delimit on EOF. Reading one
        # leading quote and then only [A-Za-z0-9_] gave the tag `E`, which
        # never appeared on a line of its own — the terminator search then ran
        # off the end and the whole rest of the command was dropped at exit 0.
        tag = ""
        tagquoted = 0
        while (j <= n) {
          ch = substr(s, j, 1)
          if (ch == "\n" || ch == " " || ch == "\t" || ch == ";" || ch == "&" \
              || ch == "|" || ch == ")" || ch == "<" || ch == ">") break
          # A quote or a backslash anywhere in the delimiter removes itself AND
          # tells bash not to expand the body. Which of the two it is decides
          # whether the body is inert text or partly commands.
          if (ch == SQ || ch == "\"" || ch == "\\") { tagquoted = 1; j++; continue }
          tag = tag ch; j++
        }
        if (tag != "") {
          k = index(substr(s, j), "\n")
          # No newline after the redirection: the body never starts, so
          # nothing was read.
          if (k == 0) { out = out substr(s, i, j - i) LIMIT; i = n + 1; continue }
          lineend = j + k - 1
          out = out substr(s, i, lineend - i + 1)
          pos = lineend + 1
          bodystart = pos
          found = 0
          while (pos <= n) {
            k = index(substr(s, pos), "\n")
            if (k == 0) { line = substr(s, pos); bodyend = n; pos = n + 1 }
            else { line = substr(s, pos, k - 1); bodyend = pos - 1; pos += k }
            if (dash) sub(/^\t+/, "", line)
            if (line == tag) { found = 1; break }
          }
          # THE BODY IS ONLY INERT IF THE DELIMITER WAS QUOTED. With an
          # unquoted delimiter bash performs parameter and command
          # substitution inside the body, so part of it is commands — and
          # skipping it unconditionally let `cat <<EOF` / `$(git push
          # --force)` / `EOF` through while bash really ran the push. Verified
          # both directions: quoted delimiter prints the text literally.
          if (found && !tagquoted && bodyend >= bodystart) {
            out = out extract_subs(substr(s, bodystart, bodyend - bodystart + 1))
          }
          # A terminator that never appears means the body ran to the end of
          # the text and this lexer cannot say where the command resumed.
          # Refused rather than guessed.
          if (!found) out = out LIMIT
          i = pos; continue
        }
      }
      out = out c; i++; continue
    }

    if (mode == "sq") {
      if (c == SQ) {
        if (decodectx) out = out " " decode_ansic(buf) " "
        else if (cmdctx) out = out " " buf " "
        else if (KEEPQ == 1) out = out keepq(buf)
        else if (!tainted && is_bare_word(buf)) out = out mark_literal_braces(buf)
        mode = "out"; buf = ""; tainted = 0; cmdctx = 0; decodectx = 0
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
        else if (KEEPQ == 1) out = out keepq(buf)
        else if (is_bare_word(buf)) out = out mark_literal_braces(buf)
        mode = "out"; buf = ""; tainted = 0; cmdctx = 0; decodectx = 0
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
      if (decodectx) out = out " " decode_ansic(buf) " "
      else if (cmdctx) out = out " " buf " "
      else if (KEEPQ == 1) out = out keepq(buf)
      else if (!tainted && is_bare_word(buf)) out = out mark_literal_braces(buf)
      mode = "out"; buf = ""; tainted = 0; cmdctx = 0; decodectx = 0
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
