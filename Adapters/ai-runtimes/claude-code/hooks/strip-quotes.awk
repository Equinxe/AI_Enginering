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
#   double       \x escapes; $( and ` open substitutions; " closes. The
#                contents of either substitution are COMMANDS and are
#                scanned, as outside; the closing ) or ` returns here
#
# A quoted region is dropped, with one exception: when its entire content is a
# single word with no whitespace — "--no-verify", "reset", '-f'. Quoting a lone
# word is not how anyone writes a message; it is how a token gets past a text
# filter, and the shell passes it on identically either way. Braces inside such
# a word are marked literal, because the shell does not expand a quoted brace.
#
# A DROPPED REGION KEEPS ITS LAST PATH COMPONENT (WU-IAENG-440). A quoted
# command path often holds a space, and the command it names is its last
# component. When the region holds a / or a \ and the text after the last one
# is a word with no whitespace, that word is printed with a / before it. The
# / keeps the word from reading as an option, a keyword or a name of its own.
# The word is kept only where it can be a command a rule reads (WU-IAENG-455,
# code review of PR #485, F3): when it names git, a dashed git-<subcommand>,
# gh, rm or printf, in any case and with any extension Windows runs, or when
# the region is glued to the text after it, which may complete such a name
# (`"/c/x y/gi"t`). Any other tail is dropped with its region, as a message's
# text is: `git commit -m "see docs/x--no-verify"` and `-m "see
# Standards/core.hooksPath"` reach the rules as `git commit -m`.
#
# WORDS AS THE SHELL FORMS THEM (WU-IAENG-450). A quoted or escaped ; & | is a
# character of a word, not the end of a command; a substitution's output may
# be empty, so the words on either side of it may join; and a dropped region
# after a git option that takes a value, or after `stash`, is still a word.
# The first two are read in a third reading (sepw, close_sub), the last in
# every reading (is_value_context). Each is described where it is done. In
# KEEPQ mode a substitution leaves a `$` (subopen).
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
  WB = "\005"          # a word byte: a quoted or escaped ; & |, or a dropped value
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

# A VALUE CONTEXT (WU-IAENG-450) is a word after which a rule reads the next
# word itself: a git option that takes its value as the next word or after
# its `=` (the read exemptions read that value, so the word after it is the
# subcommand), and `stash` (the stash rule reads the word after it). A quoted
# region there that is dropped and holds something other than whitespace
# leaves WB in its place: the shell passes it as a word, and without WB the
# next word would take its place. `git -C "/c/x y" config --get
# core.hooksPath` is a read, and `git stash "-m a b" list` is not. Whitespace
# alone leaves nothing, as before (SEC-IAENG-431-05). A region that held a
# substitution leaves WB only in the third reading, where the substitution is
# muted (hadsub); the first two print the substitution's commands there.
#
# --config-env is a value context of its own (2): its value is `<key>=<env
# var>`, and the rules read the key. A dropped value there keeps its key, so
# `git --config-env "core.hooksPath=V X" commit` reads as the unquoted
# `--config-env=core.hooksPath=V` does (dropped).
function is_value_context(w) {
  if (w ~ /^--config-env=?$/) return 2
  return w ~ /^(-C|--(git-dir|work-tree|namespace|exec-path|super-prefix|attr-source|file|blob|default)=?)$/ \
    || w ~ /(^|[\/\\-])stash(\.[A-Za-z]+)?$/
}

# THE LAST WORD OF out, which the contexts above are judged on when a quote or
# a substitution opens. Splitting the whole of out at every quote made a pass
# cost the square of the command's length (WU-IAENG-450), and so did walking
# back over a word, or splitting the text before it, every time a quote or a
# substitution followed one. So out is read once, and what was read is kept:
#
# - LWL is the length of out already read, LWW the last word in it, and LWC,
#   LWD and LWV its command, decode and value contexts, judged once, when the
#   word is found.
# - A call reads only the bytes added since, from their end: back over the
#   whitespace that ends them, then back over the word before it. A word that
#   begins in them is the new last word. One that reaches back to the text
#   read before goes on from the word that text ended in, when it ended in
#   one, and its new bytes are added to LWW. Bytes that are all whitespace
#   leave the word and its contexts as they were.
# - A line break that lex() read outside quotes ends the command before it,
#   so a quote or a substitution after it has no word before it: when out
#   holds a line break after the word and lex() noted such a line break since
#   the last call (NLP), the word and its contexts are cleared. lex() notes
#   the line breaks the shell reads as the end of a command: one printed
#   outside quotes (a \<newline> was removed before it reached out) and the
#   one that ends a heredoc's first line. Read across one, `--config-env` at
#   the end of a line made the next line's quoted command path a value of
#   its own, and the path was not read as the command it names.
# - A line break that a quoted region's text holds, printed in a command
#   context or after printf, ends no command around the region, so it
#   clears no word and no command or decode context. A quote glued after
#   the region is judged on the last word before it: the command word when
#   the text is only whitespace, as in `eval "<line break>""b c"`, which
#   passes eval one argument, and otherwise the text's own last word. A
#   region's text is printed after its opening called last_word, so it
#   comes first among the bytes a call reads, before any line break lex()
#   notes after it. The exception is the rest of a double-quoted region
#   after a substitution that the first two readings print: a line break in
#   that substitution still clears a word of the region's rest there, and
#   the third reading, which mutes the substitution, judges it.
# - The value context (LWV) is cleared at any line break after the word,
#   noted or not. A value is the next word of the same command, and the
#   shell that runs a region's text ends the command at a line break in it.
#   Kept, `eval "echo --config-env<line break>""X=1 /usr/bin/git" push`
#   read the second region as the value of --config-env, which keeps only
#   its key (dropped), and its command path was printed in no reading.
#
# The kept word belongs to the text it was found in. Every place that sets out
# to another text sets the kept word too: lex() clears it (kept_clear), a
# substitution the third reading mutes saves it with out and clears it
# (kept_save: open_dq_sub, and the $( and backtick of lex()), and the close
# that gives out back gives it back (kept_restore: close_sub, and the
# backtick's close). Each byte of out is then read once, and each word judged
# once, so the work grows linearly with the length of the command, however
# long its words. One shape is still read again: a word that goes on past a
# quote glued into it is judged again at each such quote, so its cost grows
# with the square of its length, as it did before WU-IAENG-450.
function last_word(   L, j, e) {
  L = length(out)
  j = L
  while (j > LWL && index(" \t\n", substr(out, j, 1))) j--
  e = j
  if (j > LWL) {
    while (j > LWL && !index(" \t\n", substr(out, j, 1))) j--
    if (j == LWL && substr(out, LWL, 1) ~ /[^ \t\n]/) LWW = LWW substr(out, j + 1, e - j)
    else LWW = substr(out, j + 1, e - j)
    LWC = is_command_context(LWW)
    LWD = is_decode_context(LWW)
    LWV = is_value_context(LWW)
  }
  if (index(substr(out, e + 1, L - e), "\n")) {
    LWV = 0
    if (NLP) { LWW = ""; LWC = 0; LWD = 0 }
  }
  LWL = L; NLP = 0
  return LWW
}
# Clearing NLP here changes no output: the first bytes a text's first call
# reads were all read outside quotes, so a line break there is one lex()
# noted. It keeps the note with the text it was read in, as the word is.
function kept_clear() {
  LWL = 0; LWW = ""; LWC = 0; LWD = 0; LWV = 0; NLP = 0
}
# k is a depth, for a $( or a substitution in double quotes, or "b" and a
# depth, for a backtick pair outside quotes: one slot for each opening that
# a close can give back. The note of a line break (NLP) is saved and given
# back with the word: one read in a muted substitution left out with it.
function kept_save(k) {
  KN[k] = LWL " " LWC " " LWD " " LWV " " NLP; KW[k] = LWW
  kept_clear()
}
function kept_restore(k,   f) {
  split(KN[k], f, " ")
  LWL = f[1] + 0; LWC = f[2] + 0; LWD = f[3] + 0; LWV = f[4] + 0; NLP = f[5] + 0
  LWW = KW[k]
}

# The third reading reads a substitution as empty (close_sub). One that stands
# for a whole word in a value context is still a word there, as a dropped
# quoted value is: `git -C $(pwd) config --get core.hooksPath` and `git -C
# "$(pwd)" config ...` keep -C's value, so the read is still read as one. A
# substitution glued to other text joins it instead. word_before is 1 when the
# text before a substitution ends a value-context word and a space (last_word).
# word_after is 1 when the byte after the substitution ends a word.
function word_before() {
  if (out == "" || substr(out, length(out), 1) !~ /[ \t\n]/) return 0
  last_word()
  return LWV ? 1 : 0
}
function word_after(ch) {
  return ch == "" || ch ~ /[ \t\n;&|)]/
}

# A QUOTED OR ESCAPED ; & | IS PART OF A WORD (WU-IAENG-450). The shell does
# not end a command there, so the third reading prints each as WB and the
# hook, which cuts segments at ; & | and line breaks, keeps the word in its
# command: `git -C "a;b" config core.hooksPath x` is one command. The first
# and second readings print the character as before, and note that the third
# differs.
function sepw(s) {
  if (s ~ /[;&|]/) {
    if (V3) gsub(/[;&|]/, WB, s)
    else CH3 = 1
  }
  return s
}

# In KEEPQ mode a substitution leaves `$` where it opens, glued to the text
# before it (WU-IAENG-450). The approval-label rule reads a label value that
# holds a `$` as not a static literal: a substitution, like a variable, can
# expand to either approval label.
function subopen() {
  return (KEEPQ == 1) ? "$ " : " "
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

# The last path component of a dropped quoted region, with a / before it, or
# nothing (see the header, A DROPPED REGION KEEPS ITS LAST PATH COMPONENT). A
# backslash counts as a separator, as it does in a Windows path. The search
# runs once from the end of the region, so it is linear in its length. nx is
# the byte after the region's closing quote: a byte that does not end a word
# (word_after) glues the region to the text after it.
function path_tail(s, nx,   k, ch) {
  for (k = length(s); k > 0; k--) {
    ch = substr(s, k, 1)
    if (ch == "/" || ch == "\\") break
  }
  if (k == 0) return ""
  s = substr(s, k + 1)
  if (s == "" || s ~ /[ \t\n]/ || s ~ /^-/) return ""
  if (word_after(nx) && !is_rule_command(s)) return ""
  return "/" sepw(mark_literal_braces(s))
}

# A command name a rule reads (path_tail): git, a dashed git-<subcommand>, gh,
# rm or printf, in any case, with any extension Windows runs a command by.
function is_rule_command(s) {
  return tolower(s) ~ /^(git(-[^\/\\]*)?|gh|rm|printf)(\.(exe|cmd|com|bat))?$/
}

# A SUBSTITUTION OPENED INSIDE DOUBLE QUOTES, by $( or by a backtick
# (WU-IAENG-440). Its contents are commands, so they are scanned as outside
# until the matching ) or backtick, which returns to the quoted region. The
# quoted text read so far is printed first, as the region's close would print
# it, wherever that close prints the region whatever it holds (a command
# context, printf, the KEEPQ view). The contexts are saved with the region and
# restored on return, since a quote opened inside the substitution clears them.
#
# In the third reading (V3, WU-IAENG-450) a substitution in double quotes is
# muted instead (close_sub): the text of its region is kept, and the region
# closes as if it held none. In a command context or printf's argument that
# text is then printed whole, so `bash -c "git push --fo$(true)rce"` reads
# `git push --force` there; the first two readings print the substitution's
# commands.
function open_dq_sub(kind) {
  mstack[depth] = V3
  if (V3) note_nested(depth > 0 || obt[depth])
  if (mstack[depth]) {
    bstack[depth] = buf; tstack[depth] = tainted; ostack[depth] = out
    out = ""; kept_save(depth)
  } else {
    if (decodectx) out = out " " decode_ansic(buf) " "
    else if (cmdctx) out = out " " buf " "
    else if (KEEPQ == 1) out = out keepq(buf)
    out = out subopen()
  }
  stack[depth] = kind; cstack[depth] = cmdctx; dstack[depth] = decodectx
  vstack[depth] = valctx
  depth++
  mode = "out"; tainted = 1; buf = ""
}

# SUBSTITUTIONS READ AS EMPTY (WU-IAENG-450). In the third reading a
# substitution prints nothing, as if its output were empty: the text it
# printed is discarded when it closes, and a region it was opened in gets its
# text and its state back. The words on either side of it then join as the
# shell joins them, so `git push "--force$(true)"`, `--fo$(true)rce` and
# their backtick forms read as `--force`, and a ; inside it no longer cuts the
# command around it in two: `git -C "$(true; true)" push --force`. The first
# two readings print its commands, so they are still read. close_sub is
# called after depth has been decremented; it returns 1 when the substitution
# was muted.
#
# The saved texts are released once restored, so that the next append to out
# or buf extends it rather than copying it: a command of many substitutions
# stays linear in its length.
#
# A region that gets its text back notes that it held a substitution
# (hadsub), so that, in a value context, it is a word even when its text is
# empty (dropped). One opened outside quotes, in a value context, standing
# for a whole word (mvs, word_after), leaves WB.
function close_sub(nextc) {
  if (!mstack[depth]) return 0
  out = ostack[depth]; ostack[depth] = ""
  kept_restore(depth)
  if (stack[depth] != "out") {
    buf = bstack[depth]; bstack[depth] = ""
    tainted = tstack[depth]
    hadsub = 1
  } else if (mvs[depth] && word_after(nextc)) out = out WB
  mstack[depth] = 0
  return 1
}

# A SUBSTITUTION INSIDE ANOTHER (WU-IAENG-455, review of PR #529). The third
# reading tracks every substitution it mutes: a $( and a substitution in
# double quotes by depth, a backtick pair outside quotes by obt at its depth.
# A substitution it opens while one of those is open, at a depth above 0 or
# inside a backtick pair, is nested, and NESTED is set. The first two readings
# print a nested substitution's commands as words of the one around it, so a
# word there may be one the shell never passes: in `$(git config $(--get)
# core.hooksPath x)`, --get is a command whose output is empty, and the outer
# command is a write. The hook reads NESTED (NESTMARK, below) and grants no
# exemption that reads a substitution's words as a command's arguments when
# one is set. An escaped backtick inside a backtick pair is printed as a
# backtick, not read as a substitution; the rule that reads the words keeps
# that byte out of them.
function note_nested(inside) {
  if (inside) NESTED = 1
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

# lex(s) returns the words of s, read as described in the header. With V2 = 0
# it is the reading this file gave before WU-IAENG-440, but for the value
# context of WU-IAENG-450 (dropped); with V2 = 1 it is the second reading
# (TWO READINGS, below), and with V3 = 1 as well, the third. Pass 1 sets
# CHANGED where the second would differ, and CH3 where only the third would.
function lex(s,   n, i) {
  n = length(s); i = 1
  out = ""; kept_clear()
  mode = "out"
  depth = 0
  buf = ""
  tainted = 0
  cmdctx = 0
  decodectx = 0
  valctx = 0
  hadsub = 0
  split("", obt)

  while (i <= n) {
    c = substr(s, i, 1)
    d = substr(s, i + 1, 1)

    if (mode == "out") {
      if (c == "\\") {
        if (d == "\n") { i += 2; continue }
        if (d == "{") { out = out BL; i += 2; continue }
        if (d == "}") { out = out BR; i += 2; continue }
        # An escaped ; & | is part of a word (sepw). KEEPQ mode keeps each
        # word whole in every reading, as it does a quoted separator.
        if (d ~ /[;&|]/) {
          if (V3 || KEEPQ == 1) out = out WB
          else { out = out d; CH3 = 1 }
          i += 2; continue
        }
        out = out d; i += 2; continue
      }
      if (c == "$" && d == "(") {
        if (!V2) CH3 = 1
        mstack[depth] = V3
        if (V3) {
          note_nested(depth > 0 || obt[depth])
          mvs[depth] = word_before(); ostack[depth] = out; out = ""
          kept_save(depth)
        }
        else out = out subopen()
        stack[depth] = "out"; depth++
        i += 2; continue
      }
      if (c == "`") {
        # Backticks are command substitution too; their contents are commands.
        # One that closes a substitution opened inside double quotes returns
        # to that region (open_dq_sub).
        if (depth > 0 && stack[depth - 1] == "dqbt") {
          depth--; mode = "dq"; tainted = 1
          cmdctx = cstack[depth]; decodectx = dstack[depth]; valctx = vstack[depth]
          if (!close_sub(d)) out = out " "
          i++; continue
        }
        # In the third reading a backtick pair outside quotes is muted, as
        # $( is (close_sub). Such a pair does not nest, so one flag for each
        # depth tells its opening backtick from its closing one.
        if (V3) {
          if (obt[depth]) {
            out = obs[depth]; obs[depth] = ""; obt[depth] = 0
            kept_restore("b" depth)
            if (obv[depth] && word_after(d)) out = out WB
          } else {
            note_nested(depth > 0)
            obv[depth] = word_before(); obs[depth] = out; obt[depth] = 1; out = ""
            kept_save("b" depth)
          }
          i++; continue
        }
        if (!V2) CH3 = 1
        out = out subopen(); i++; continue
      }
      # A ) closes a $( substitution, never a backtick one.
      if (c == ")" && depth > 0 && stack[depth - 1] != "dqbt") {
        depth--; mode = stack[depth]
        if (mode != "out") {
          tainted = 1
          if (V2) { cmdctx = cstack[depth]; decodectx = dstack[depth]; valctx = vstack[depth] }
        }
        if (!close_sub(d)) out = out " "
        i++; continue
      }
      if (c == "$" && (d == SQ || d == "\"")) {
        # The shell consumes the $ in $'...' and $"...".
        mode = (d == SQ) ? "ansic" : "dq"
        buf = ""; tainted = 0; hadsub = 0
        last_word(); cmdctx = LWC; decodectx = LWD; valctx = LWV
        i += 2; continue
      }
      if (c == SQ || c == "\"") {
        mode = (c == SQ) ? "sq" : "dq"
        buf = ""; tainted = 0; hadsub = 0
        last_word(); cmdctx = LWC; decodectx = LWD; valctx = LWV
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
          NLP = 1
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
      # A line break read here ends a command (last_word).
      if (c == "\n") NLP = 1
      out = out c; i++; continue
    }

    if (mode == "sq") {
      if (c == SQ) {
        if (decodectx) out = out " " decode_ansic(buf) " "
        else if (cmdctx) out = out " " buf " "
        else if (KEEPQ == 1) out = out keepq(buf)
        else if (!tainted && is_bare_word(buf)) out = out sepw(mark_literal_braces(buf))
        else dropped(buf, d)
        mode = "out"; buf = ""; tainted = 0; cmdctx = 0; decodectx = 0; valctx = 0; hadsub = 0
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
        else if (is_bare_word(buf)) out = out sepw(mark_literal_braces(buf))
        else dropped(buf, d)
        mode = "out"; buf = ""; tainted = 0; cmdctx = 0; decodectx = 0; valctx = 0; hadsub = 0
        i++; continue
      }
      buf = buf c; i++; continue
    }

    # mode == "dq"
    if (c == "\\") { buf = buf c d; i += 2; continue }
    if (c == "$" && d == "(") {
      if (V2) { open_dq_sub("dq"); i += 2; continue }
      # The third reading reads every such substitution as empty (CH3). The
      # second differs only in a command context or printf, where the third
      # is made too, since a second reading always is. In KEEPQ mode the
      # region's text before the substitution is printed first, as the second
      # reading prints it (open_dq_sub), so that the `$` is glued to it:
      # `-f "body=$(cat c.md)"` reads `-f body=$ cat c.md`, a field whose key
      # is `body`, in every reading (WU-IAENG-450).
      if (cmdctx || decodectx) CHANGED = 1
      else {
        CH3 = 1
        if (KEEPQ == 1) out = out keepq(buf)
      }
      mstack[depth] = 0
      stack[depth] = "dq"; vstack[depth] = valctx; depth++
      mode = "out"; tainted = 1; buf = ""
      out = out subopen(); i += 2; continue
    }
    if (c == "`") {
      if (V2) { open_dq_sub("dqbt"); i++; continue }
      CHANGED = 1
      tainted = 1; buf = buf subopen(); i++; continue
    }
    if (c == "\"") {
      if (decodectx) out = out " " decode_ansic(buf) " "
      else if (cmdctx) out = out " " buf " "
      else if (KEEPQ == 1) out = out keepq(buf)
      else if (!tainted && is_bare_word(buf)) out = out sepw(mark_literal_braces(buf))
      else dropped(buf, d)
      mode = "out"; buf = ""; tainted = 0; cmdctx = 0; decodectx = 0; valctx = 0; hadsub = 0
      i++; continue
    }
    buf = buf c; i++
  }

  # An unterminated quote ran to the end of the text and is dropped, as any
  # other quoted text would be.
  #
  # A substitution or backtick pair the third reading muted and the text never
  # closed is printed after the text before it, so nothing read is dropped:
  # the innermost first, then each one around it.
  while (V3) {
    if (obt[depth]) { out = obs[depth] " " out; obt[depth] = 0 }
    if (depth == 0) break
    depth--
    if (mstack[depth]) { out = ostack[depth] " " out; mstack[depth] = 0 }
  }
  return out
}

# A quoted region the reading drops: nothing in pass 1, its path_tail in the
# second and third readings, judged with nx, the byte after its closing quote.
# Pass 1 notes that they differ. In a value context
# (is_value_context), a region with no path tail to print leaves WB, in every
# reading, when it holds something other than whitespace or held a
# substitution the third reading muted (hadsub), and held none whose commands
# the reading printed (tainted).
#
# After --config-env (valctx 2) a region whose text begins `<key>=` keeps that
# key and its `=`, in every reading. The rest of its value, the name of a
# variable, is not printed: the key and its `=` are already a word, and G and
# GX read the word after the option as its value whatever follows the `=`.
#
# THE DROP MARK (`awk -v DROPMARK=...`, set by block-escape-hatches.sh for its
# marked view; review of PR #529, round 2, B1). A region this function prints
# nothing for is still a word the shell passes: in
#   git config "core.hooksPath${E:+ }" get core.hooksPath
# git receives the key before `get`. With DROPMARK set, such a region prints
# DROPMARK in every reading, so the core.hooksPath rule sees that a word stood
# there. Unset, nothing is printed, as before.
function dropped(b, nx,   t) {
  if (valctx == 2 && !tainted && match(b, /^[^ \t\n=]+=/)) {
    out = out sepw(substr(b, 1, RLENGTH))
    return
  }
  t = path_tail(b, nx)
  if (V2 && t != "") { out = out t; return }
  if (t != "") CHANGED = 1
  if (valctx && !tainted && (b ~ /[^ \t\n]/ || hadsub)) out = out WB
  else if (DROPMARK != "") out = out DROPMARK
}

# TWO READINGS (WU-IAENG-440). The text is printed as this file read it before
# WU-IAENG-440 (pass 1), every record as before. When the second reading of
# some record differs, the whole text follows again on a line of its own, read
# the second way: a substitution in double quotes opened by a backtick as by
# $(, the quoted text before a substitution printed where its region's close
# prints it, and a dropped region's last path component kept. The rules refuse
# on a match in any line or segment, so the second reading can only add a
# refusal: the first is printed whole, so the rules that read words side by
# side still find every pair they found. Brace alternatives are appended to
# each reading of each record.
#
# A THIRD READING (WU-IAENG-450) is the second with every substitution read as
# empty (close_sub) and every quoted or escaped ; & | printed as WB (sepw). It
# follows the others on a line of its own when some record's third reading
# differs from both of its others, and, like the second, can only add a
# refusal. It is not made in KEEPQ mode, where a substitution leaves its `$`
# (subopen) and a separator is already kept in its word. Three changes reach
# every reading, pass 1 included: a dropped region in a value context leaves
# WB (dropped); in KEEPQ mode, an escaped ; & | is WB; and in KEEPQ mode, the
# quoted text before a substitution opened in double quotes is printed before
# its `$`, as the second reading prints it.
#
# Pass 1 sets CHANGED where the second reading would differ and CH3 where only
# the third would. A record that sets CH3 alone is lexed twice, not three
# times: its second reading is its first (WU-IAENG-450).
{
  V2 = 0; V3 = 0; CHANGED = 0; CH3 = 0
  r1 = lex($0)
  one = r1 expand_braces(r1)
  two = one
  three = one
  if (CHANGED || CH3) {
    V2 = 1
    r2 = r1
    if (CHANGED) {
      r2 = lex($0)
      if (r2 != r1) { two = r2 expand_braces(r2); ANY2 = 1 }
    }
    three = two
    if (KEEPQ != 1) {
      V3 = 1
      r3 = lex($0)
      V3 = 0
      if (r3 != r1 && r3 != r2) { three = r3 expand_braces(r3); ANY3 = 1 }
    }
    V2 = 0
  }
  ALL1 = ALL1 one
  ALL2 = ALL2 two
  ALL3 = ALL3 three
}

END {
  result = ALL1
  if (ANY2) result = result "\n" ALL2
  if (ANY3) result = result "\n" ALL3
  gsub(BL, "{", result)
  gsub(BR, "}", result)
  printf "%s", result
}

# THE NESTING MARK (`awk -v NESTMARK=...`, set by block-escape-hatches.sh).
# Printed after the output, before the end mark, when the third reading found
# a substitution inside another (note_nested). Unset, nothing is printed.
END { if (NESTMARK != "" && NESTED) printf "%s", NESTMARK }

# THE END MARK (`awk -v MARK=...`, set by block-escape-hatches.sh). Printed
# once, after the whole output, so the hook can tell a command that lexes to
# nothing but a line break (a lone quoted path) from a lexer that printed
# nothing. Unset, nothing is printed.
END { if (MARK != "") printf "%s", MARK }
