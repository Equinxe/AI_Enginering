#!/usr/bin/env bash
# IA Engineering — merge-classify.sh (SOURCED, not executed)
#
# The single definition of "does this merge commit AUTHOR content?", shared by
# check-employee-trailers.sh and check-work-units.sh. Before WU-IAENG-313 the
# classifier lived only in the first, so the second let an authored merge carry
# no Work Unit trailer (PT2-03). Two copies of a classifier is how a control
# ends up enforced on one trailer and not the other, so it is extracted rather
# than duplicated.
#
# A merge is CLEAN when its tree equals the automatic merge of its two parents
# (`git merge-tree --write-tree`, git >= 2.38): it contains nothing of its own.
# Anything else is AUTHORED: a tree that differs (conflict resolution, extra
# edits, `-s ours`), a conflicted automatic merge (exit 1), or more than two
# parents (octopus, never classified as clean).
#
# This file is a control path. The scripts that source it are the required
# checks, and they run from the PR's own tree, so changing this file is
# changing the check — review it as such. It deliberately holds NO exemption
# list: grandfathered shas live as `readonly` constants in the calling script
# (SEC-IAENG-307-01: a data file let a PR exempt itself).
#
# API (no global state: the answer is printed, so a caller reads it with $(...))
#
#   merge_classify_git_ok          returns 0 when git can classify (>= 2.38)
#   merge_classify <merge-sha>     prints one line and always returns 0:
#                                    clean
#                                    authored
#                                    error: <reason>

merge_classify_git_ok() {
  local ver gv_major gv_minor
  ver="$(git version | sed -E 's/^git version ([0-9]+)\.([0-9]+).*/\1 \2/')"
  read -r gv_major gv_minor <<< "$ver"
  if ! [[ "${gv_major:-}" =~ ^[0-9]+$ && "${gv_minor:-}" =~ ^[0-9]+$ ]] || [ $((gv_major * 1000 + gv_minor)) -lt 2038 ]; then
    return 1
  fi
  return 0
}

merge_classify() {
  local sha="$1" parents mt_rc mt_out m_tree
  local -a parr

  if ! parents="$(git rev-list --parents -n 1 "$sha")"; then
    echo "error: its parents could not be read"
    return 0
  fi
  parents="$(printf '%s' "$parents" | cut -d' ' -f2-)"
  read -ra parr <<< "$parents"
  if [ "${#parr[@]}" -ne 2 ]; then
    echo authored
    return 0
  fi

  mt_rc=0
  mt_out="$(git merge-tree --write-tree --no-messages "${parr[0]}" "${parr[1]}" 2>/dev/null)" || mt_rc=$?
  if [ "$mt_rc" -gt 1 ]; then
    echo "error: git merge-tree exited $mt_rc - shallow history or missing objects?"
    return 0
  fi
  if ! m_tree="$(git rev-parse "$sha^{tree}")"; then
    echo "error: its tree could not be read"
    return 0
  fi
  if [ "$mt_rc" -eq 0 ] && [ "$(printf '%s\n' "$mt_out" | head -1)" = "$m_tree" ]; then
    echo clean
  else
    echo authored
  fi
  return 0
}
