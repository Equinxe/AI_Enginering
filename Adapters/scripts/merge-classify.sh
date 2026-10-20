#!/usr/bin/env bash
# IA Engineering — merge-classify.sh (SOURCED, not executed)
#
# The single definition, for the CI checks, of "does this merge commit AUTHOR
# content?", shared by check-employee-trailers.sh and check-work-units.sh, and
# of git's own merge of two commits, which check-approval-carry-over.sh compares
# each update merge of develop against.
# Before WU-IAENG-313 the classifier lived only in the first, so the second let
# an authored merge carry no Work Unit trailer (PT2-03). Two copies of a
# classifier is how a control ends up enforced on one trailer and not the
# other, so it is extracted rather than duplicated.
#
# It is not the only classifier. The local commit-msg hook
# (Adapters/git-hooks/commit-msg) classifies BEFORE the merge commit exists —
# HEAD against MERGE_HEAD, not a commit's two parents — so it keeps its own
# copy. That copy does not carry the attribute pin described below; aligning
# it is a follow-up, not part of this file.
#
# A merge is CLEAN when its tree equals the automatic merge of its two parents
# (`git merge-tree --write-tree`): it contains nothing of its own. Anything
# else is AUTHORED: a tree that differs (conflict resolution, extra edits,
# `-s ours`), a conflicted automatic merge (exit 1), or more than two parents
# (octopus, never classified as clean).
#
# THE AUTOMATIC MERGE IGNORES THE TREE'S OWN ATTRIBUTES (SEC-IAENG-313-01).
# `git merge-tree` reads `merge=` drivers from .gitattributes in the working
# tree, which in CI is the Pull Request's own tree. A PR adding `* merge=union`
# would make a union-shaped hand resolution equal the "automatic" merge, and
# classify clean. The merge is therefore computed with --attr-source pinned to
# the empty tree (4b825dc6...), so no attribute the PR controls changes the
# answer. --attr-source needs git >= 2.40, which is the floor below.
#
# THE AUTOMATIC MERGE IGNORES THE MACHINE'S MERGE SETTINGS TOO (WU-IAENG-344).
# A user's or a repository's config can change what `git merge-tree` produces:
# merge.conflictStyle=diff3 or zdiff3 makes git less eager to resolve
# overlapping changes, so a merge that is clean by default conflicts;
# merge.renames=false and merge.directoryRenames change how renames merge;
# a low merge.renameLimit, or the diff.renameLimit it falls back to, skips
# rename detection, so an edit to a renamed file conflicts (issue #237);
# merge.renormalize rewrites line endings before merging; merge.default names
# the driver for every path whose `merge` attribute is unset, which with the
# attributes pinned to the empty tree is every path: `union` made a
# union-shaped hand resolution "clean", and a custom driver's command ran
# (Security Engineer on PR #249, SEC-IAENG-351-F1). Each is pinned to
# git's documented default, so two machines compute the same merge from the
# same two commits — the record check-approval-carry-over.sh prints has to be
# reproducible by whoever audits it, and a classification must not depend on
# the config of the machine that runs it.
#
# NOR THE MACHINE'S OWN ATTRIBUTE FILES AND REPLACE REFS (WU-IAENG-344,
# Security Engineer on PR #232). --attr-source replaces only the in-tree
# .gitattributes: a `merge=union` in core.attributesFile or the system
# attributes file still turned a union-shaped hand resolution into the
# "automatic" merge, and a local refs/replace entry made git read one merge
# as another. core.attributesFile=/dev/null (Git for Windows maps it too),
# GIT_ATTR_NOSYSTEM=1 and GIT_NO_REPLACE_OBJECTS=1 close those. A non-empty
# $GIT_DIR/info/attributes cannot be switched off by an option, nor can
# grafts ($GIT_DIR/info/grafts or $GIT_GRAFT_FILE), which rewrite a commit's
# parents and survive GIT_NO_REPLACE_OBJECTS (SEC-IAENG-351-F2); the
# carry-over check refuses to run with either. In CI none of these exist, so the
# required checks classify exactly as before.
#
# ONE AUTOMATIC MERGE. merge_classify_automatic is the only place the automatic
# merge is computed: merge_classify below and check-approval-carry-over.sh both
# call it, so the pins above cannot drift between the checks that read merges.
#
# This file is a control path. The scripts that source it are the required
# checks, and they run from the PR's own tree, so changing this file is
# changing the check — review it as such. It deliberately holds NO exemption
# list: grandfathered shas live as `readonly` constants in the calling script
# (SEC-IAENG-307-01: a data file let a PR exempt itself).
#
# API (no global state: the answer is printed, so a caller reads it with $(...))
#
#   merge_classify_git_ok          returns 0 when git can classify (>= 2.40)
#   merge_classify <merge-sha>     prints one line and always returns 0:
#                                    clean
#                                    authored
#                                    error: <reason>
#   merge_classify_automatic [--diff3] <parent1> <parent2> [<merge-tree option>...]
#                                  git's own merge of two commits: prints what
#                                  `git merge-tree --write-tree --no-messages`
#                                  prints, and returns its exit status (0 clean,
#                                  1 conflicted, anything else an error). Options
#                                  such as -z or --name-only go to merge-tree.
#                                  --diff3 writes conflicted hunks in the diff3
#                                  style, each side's hunk whole; it presents a
#                                  merge that already conflicts and never
#                                  classifies one, since diff3 can turn a clean
#                                  merge into a conflicted one.

# The empty tree: a well-known object every git resolves without it being
# stored, so it is a valid --attr-source in any repository.
readonly MERGE_CLASSIFY_EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904

merge_classify_git_ok() {
  local ver gv_major gv_minor
  ver="$(git version | sed -E 's/^git version ([0-9]+)\.([0-9]+).*/\1 \2/')"
  read -r gv_major gv_minor <<< "$ver"
  if ! [[ "${gv_major:-}" =~ ^[0-9]+$ && "${gv_minor:-}" =~ ^[0-9]+$ ]] || [ $((gv_major * 1000 + gv_minor)) -lt 2040 ]; then
    return 1
  fi
  return 0
}

merge_classify_automatic() {
  local style=merge p1 p2
  if [ "${1:-}" = "--diff3" ]; then
    style=diff3
    shift
  fi
  p1="$1"
  p2="$2"
  shift 2
  GIT_NO_REPLACE_OBJECTS=1 GIT_ATTR_NOSYSTEM=1 \
    git -c core.attributesFile=/dev/null \
      -c merge.conflictStyle="$style" \
      -c merge.renames=true \
      -c merge.renameLimit=7000 \
      -c merge.directoryRenames=conflict \
      -c merge.renormalize=false \
      -c merge.default=text \
      --attr-source="$MERGE_CLASSIFY_EMPTY_TREE" \
      merge-tree --write-tree --no-messages "$@" "$p1" "$p2"
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
  mt_out="$(merge_classify_automatic "${parr[0]}" "${parr[1]}" 2>/dev/null)" || mt_rc=$?
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
