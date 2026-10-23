# IA Engineering — changelog-fragment.awk
#
# The one parser of a changelog.d/ fragment. Two scripts read fragments and
# both call this file, so the rules cannot drift apart:
#
#   Adapters/scripts/validate-framework.sh  section 23 refuses a malformed
#                                           fragment on the Pull Request that
#                                           adds it;
#   Adapters/scripts/release.sh assemble    refuses to assemble one at the
#                                           version bump (Workflows/RELEASE.md
#                                           Step 2).
#
# The same arrangement as suppression-patterns.tsv, read by both suppression
# checks. changelog.d/README.md states the format for authors; this file is
# the format as code.
#
# USAGE
#
#   awk -v id=WU-IAENG-378 -f changelog-fragment.awk changelog.d/WU-IAENG-378.md
#   awk -v list=1 -f changelog-fragment.awk < /dev/null
#
# OUTPUT, one tab-separated record per line:
#
#   ENTRY <TAB> <Category> <TAB> <line>   a line to assemble under that heading
#   EXEMPT <TAB> <reason>                 the Work Unit has no changelog entry
#   ERROR <TAB> <line number> <TAB> <why> the fragment is refused
#
# When any ERROR is printed, nothing else is: a refused fragment yields no
# entries, so a caller cannot assemble half of one.
#
# With -v list=1 it prints the allowed categories, one per line, in the order
# a CHANGELOG.md section lists them, and reads nothing.
#
# THE FORMAT
#
# A fragment is one of two things.
#
#   An entry: one or more "### <Category>" headings, each followed by at least
#   one "- " bullet. A bullet may continue on lines that start with a space or
#   a tab. The categories are Keep a Changelog 1.1.0's six, nothing else.
#
#   An exemption: the single line "No changelog entry: <reason>", for a Work
#   Unit that changes nothing a reader of the changelog needs to know. The
#   reason is required, because "no entry" with no reason is the omission
#   release.sh condition 5 exists to catch.
#
# A bullet whose last line does not already end with a parenthesised group
# naming this Work Unit gets " (<id>)" appended. That is this repository's
# convention for every CHANGELOG.md line, and it is what lets release.sh
# condition 5 find the Work Unit in a section after the fragment is gone.
#
# Carriage returns are dropped on read: a fragment checked out CRLF on Windows
# is the same fragment.

BEGIN {
  NCAT = split("Added Changed Deprecated Removed Fixed Security", CATS, " ")
  for (i = 1; i <= NCAT; i++) ALLOWED[CATS[i]] = 1
  if (list) {
    for (i = 1; i <= NCAT; i++) print CATS[i]
    done = 1
    exit
  }
  if (id == "") {
    print "ERROR\t0\tno Work Unit id was given to the parser (-v id=...)"
    done = 1
    exit
  }
  cat = ""; nbuf = 0; nout = 0; nerr = 0; exempt = ""; headings = 0
}

function err(msg) {
  errs[++nerr] = "ERROR\t" FNR "\t" msg
}

# True when tok occurs in s as a whole id: not preceded by a letter, digit or
# dash, and not followed by a letter or digit. WU-IAENG-37 is not WU-IAENG-378.
function has_token(s, tok,    p, before, after) {
  while ((p = index(s, tok)) > 0) {
    before = (p == 1) ? "" : substr(s, p - 1, 1)
    after = substr(s, p + length(tok), 1)
    if (before !~ /[A-Za-z0-9-]/ && after !~ /[A-Za-z0-9]/) return 1
    s = substr(s, p + length(tok))
  }
  return 0
}

# True when the line ends with a parenthesised group that names this id.
function final_group_has_id(line,    i, open) {
  sub(/[ \t]+$/, "", line)
  if (substr(line, length(line), 1) != ")") return 0
  open = 0
  for (i = length(line); i > 0; i--) {
    if (substr(line, i, 1) == "(") { open = i; break }
  }
  if (!open) return 0
  return has_token(substr(line, open + 1, length(line) - open - 1), id)
}

function flush(    j) {
  if (nbuf == 0) return
  if (!final_group_has_id(buf[nbuf])) {
    sub(/[ \t]+$/, "", buf[nbuf])
    buf[nbuf] = buf[nbuf] " (" id ")"
  }
  for (j = 1; j <= nbuf; j++) out[++nout] = "ENTRY\t" cat "\t" buf[j]
  nbuf = 0
}

function close_heading() {
  flush()
  if (cat != "" && items[cat] == 0) err("'### " cat "' has no '- ' bullet under it")
}

{ gsub(/\015/, "") }

/^[ \t]*$/ { flush(); next }

/^### / {
  close_heading()
  h = substr($0, 5)
  sub(/[ \t]+$/, "", h)
  headings++
  if (!(h in ALLOWED)) {
    err("'### " h "' is not an allowed heading: Added, Changed, Deprecated, Removed, Fixed or Security")
    cat = ""
    skipping = 1
    next
  }
  if (h in seen) err("'### " h "' appears twice")
  seen[h] = 1
  cat = h
  skipping = 0
  next
}

/^#/ {
  err("only '### <Category>' headings are allowed; '" $0 "' would break the CHANGELOG.md section it is assembled into")
  next
}

/^No changelog entry:/ {
  if (exempt != "" || headings > 0 || nout > 0 || nbuf > 0) {
    err("'No changelog entry:' must be the fragment's only line")
    next
  }
  exempt = substr($0, length("No changelog entry:") + 1)
  sub(/^[ \t]+/, "", exempt)
  sub(/[ \t]+$/, "", exempt)
  if (exempt == "") { err("'No changelog entry:' gives no reason"); exempt = "-" }
  else if (index(exempt, "--") > 0) err("the exemption reason contains '--', which would end the HTML comment it is assembled into")
  next
}

skipping { next }

exempt != "" {
  err("'No changelog entry:' must be the fragment's only line")
  next
}

cat == "" {
  err("text before the first '### <Category>' heading")
  next
}

/^- / {
  flush()
  buf[++nbuf] = $0
  items[cat]++
  next
}

/^[ \t]/ {
  if (nbuf == 0) err("an indented line with no '- ' bullet above it")
  else buf[++nbuf] = $0
  next
}

{
  err("a line under '### " cat "' that is neither a '- ' bullet nor an indented continuation of one")
}

END {
  if (done) exit
  close_heading()
  if (exempt != "" && headings > 0) {
    errs[++nerr] = "ERROR\t0\t'No changelog entry:' must be the fragment's only line"
  }
  if (exempt == ""&& headings == 0 && nerr == 0) {
    errs[++nerr] = "ERROR\t0\tthe fragment is empty: give it a '### <Category>' heading with a bullet, or the line 'No changelog entry: <reason>'"
  }
  if (nerr > 0) {
    for (i = 1; i <= nerr; i++) print errs[i]
    exit
  }
  if (exempt != "") { print "EXEMPT\t" exempt; exit }
  for (i = 1; i <= nout; i++) print out[i]
}
