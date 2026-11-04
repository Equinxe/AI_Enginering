#!/usr/bin/env bash
# IA Engineering — Claude Code hooks: the context state directory
#
# WU-IAENG-394, issue #340. The statusLine writer (context-statusline.sh) and
# the context alert reader (context-alert.sh) must name the same directory,
# or the alert never fires. Each kept its own copy of the TMPDIR rule, and
# the copies drifted: the reader read a backslash as a plain character, so
# for TMPDIR=C:\x\..\y the writer fell back to /tmp while the reader looked
# under C:\x\..\y. The rule now lives here once, and both source this file.
#
# It defines one function and runs nothing. No stdin is read and no process
# is started. lib.sh is not the home for it: sourcing lib.sh reads all of
# stdin with cat, which the writer needs for itself and the reader's builtin
# fast path cannot afford.
#
# iaeng_ctx_dir <var> — sets the variable named <var> to
#     ${TMPDIR:-/tmp}/iaeng-ctx-<uid>
# TMPDIR counts only when it is absolute (/..., or a drive letter and a
# separator: C:\ or C:/) and has no . or .. component, with either separator
# (C:\a\..\b and C:/a/./b are refused too); otherwise /tmp. One trailing /
# is dropped. It returns 1 and leaves <var> alone when UID is not a whole
# number. The directory is only named: it is not created and not checked.
# Each caller applies its own guards (a directory, not a link, owned by the
# user, writable by no one else) before anything in it is opened.
#
# IAENG_CTX_TEST_FALLBACK, when set, names the directory used in place of
# /tmp. It is for the hook tests (WU-IAENG-401, issue #345): with it, a case
# whose TMPDIR the rule refuses writes into the suite's scratch tree, not
# into the user's real /tmp/iaeng-ctx-<uid>. The same rule judges it, and a
# value the rule refuses leaves /tmp. It gives nothing TMPDIR does not:
# whoever sets the hooks' environment can already name the directory
# through TMPDIR, and the callers' guards hold whatever is named.
iaeng_ctx_dir() {
  local _iaeng_b _iaeng_f=/tmp _iaeng_bs=$'\x5c'
  # The test fallback first, then TMPDIR, each judged by the same rule. A
  # value refused leaves the one before it: /tmp, or the test fallback.
  for _iaeng_b in "${IAENG_CTX_TEST_FALLBACK:-}" "${TMPDIR:-}"; do
    case "$_iaeng_b" in
      /*|[A-Za-z]:/*|[A-Za-z]:"$_iaeng_bs"*) ;;
      *) _iaeng_b="$_iaeng_f" ;;
    esac
    # Every backslash is read as a separator before the . and .. test. The
    # backslash is written once, in _iaeng_bs, by its code: $'\x5c' holds no
    # pair of backslashes for a copy to halve, as a copy can halve "\\"
    # (issue #340, #345). '\' would say the same, but shellcheck reads it as
    # a quote escaped by mistake (SC1003). That is all the spelling does. A
    # copy that mangled it all the same would name another directory for a
    # backslash TMPDIR (C:\tmp refused, /a\..\b accepted), and the rule's own
    # cases in tests/context-alert.sh, which name those, would fail.
    case "/${_iaeng_b//"$_iaeng_bs"//}/" in */../*|*/./*) _iaeng_b="$_iaeng_f" ;; esac
    _iaeng_f="$_iaeng_b"
  done
  _iaeng_b="${_iaeng_b%/}"
  [[ ${UID:-} =~ ^[0-9]+$ ]] || return 1
  printf -v "$1" '%s' "$_iaeng_b/iaeng-ctx-$UID"
}
