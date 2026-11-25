#!/usr/bin/env bash
# IA Engineering — Claude Code hooks: the context thresholds
#
# WU-IAENG-421, issue #390. The context alert (context-alert.sh) speaks at two
# steps, and the status line (context-statusline.sh) changes colour at the
# same two: yellow from the alert, bold red from the last call. The rule that
# sets the two steps lives here once, and both source this file, so the line
# and the alert cannot disagree on them. The rule is the one context-alert.sh
# held since WU-IAENG-380, moved here without a change.
#
# It defines one function and runs nothing, as context-dir.sh does, for the
# same reasons: no stdin is read and no process is started, so the alert's
# builtin fast path and the status line's per-render budget are kept.
#
# iaeng_ctx_thresholds <prefix> — sets four variables, each name <prefix>
# followed by the one below, from the environment alone, and returns 0. It
# returns 1 and sets nothing when <prefix> is neither empty nor a plain shell
# name. The caller names them, as with iaeng_ctx_dir, so each consumer reads
# variables of its own:
#   DEFAULT_ALERT  60, the Director's provisional default of 23 Oct 2026
#                  (issue #304);
#   ALERT          IAENG_CTX_ALERT_PCT when it is a whole number from 1 to
#                  100, else DEFAULT_ALERT;
#   ALERT_BAD      1 when IAENG_CTX_ALERT_PCT is set and refused, else 0;
#   LAST           the last call: IAENG_CTX_LAST_CALL_PCT when it is a whole
#                  number above ALERT and at most 100, else ALERT + 10 when
#                  that is at most 100, else empty (there is no last call).
iaeng_ctx_thresholds() {
  local _iaeng_p="${1-}" _iaeng_raw _iaeng_alert _iaeng_bad=0 _iaeng_last=""
  # A plain name or nothing, so each name below is a variable's. With any
  # other prefix the four printf -v would each fail on stderr, and the
  # function would return 0 with nothing set. (No subscript is evaluated
  # either way: every name ends in a letter, not in "]".)
  [[ $_iaeng_p =~ ^([A-Za-z_][A-Za-z0-9_]*)?$ ]] || return 1

  _iaeng_raw="${IAENG_CTX_ALERT_PCT:-}"
  if [ -z "$_iaeng_raw" ]; then
    _iaeng_alert=60
  elif [[ $_iaeng_raw =~ ^[0-9]{1,3}$ ]] && [ "$((10#$_iaeng_raw))" -ge 1 ] && [ "$((10#$_iaeng_raw))" -le 100 ]; then
    _iaeng_alert=$((10#$_iaeng_raw))
  else
    _iaeng_alert=60
    _iaeng_bad=1
  fi
  _iaeng_raw="${IAENG_CTX_LAST_CALL_PCT:-}"
  if [[ $_iaeng_raw =~ ^[0-9]{1,3}$ ]] && [ "$((10#$_iaeng_raw))" -gt "$_iaeng_alert" ] && [ "$((10#$_iaeng_raw))" -le 100 ]; then
    _iaeng_last=$((10#$_iaeng_raw))
  elif [ $((_iaeng_alert + 10)) -le 100 ]; then
    _iaeng_last=$((_iaeng_alert + 10))
  fi

  printf -v "${_iaeng_p}DEFAULT_ALERT" '%s' 60
  printf -v "${_iaeng_p}ALERT" '%s' "$_iaeng_alert"
  printf -v "${_iaeng_p}ALERT_BAD" '%s' "$_iaeng_bad"
  printf -v "${_iaeng_p}LAST" '%s' "$_iaeng_last"
  return 0
}
