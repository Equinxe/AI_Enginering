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
iaeng_ctx_dir() {
  local _iaeng_b="${TMPDIR:-}" _iaeng_bs="\\"
  case "$_iaeng_b" in
    /*|[A-Za-z]:[/\\]*) ;;
    *) _iaeng_b=/tmp ;;
  esac
  # Every backslash is read as a separator before the . and .. test. The
  # backslash is held in a variable, so no copy of this line can lose it in
  # transport (issue #340, sec-320).
  case "/${_iaeng_b//"$_iaeng_bs"//}/" in */../*|*/./*) _iaeng_b=/tmp ;; esac
  _iaeng_b="${_iaeng_b%/}"
  [[ ${UID:-} =~ ^[0-9]+$ ]] || return 1
  printf -v "$1" '%s' "$_iaeng_b/iaeng-ctx-$UID"
}
