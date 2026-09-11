#!/usr/bin/env bash
# IA Engineering — resolve-host.sh
#
# Prints the project's forge on stdout, one word, and nothing else there.
# Everything explanatory goes to stderr, so a caller can use the result
# directly: `host="$(resolve-host.sh)"`.
#
# WHAT A HOST IS, HERE
#
# The framework's controls are almost all host-free: they read git, the
# Registry, and the files in the tree. Four things are not, because no amount
# of git can answer them:
#
#   creating a release          the forge owns the Releases page
#   branch protection           the forge owns who may push where
#   the CI conclusion           the forge owns the run history
#   open defects                the forge owns the issue tracker
#
# Those four live under Adapters/scripts/hosts/<host>/, one implementation per
# forge. This script decides which directory to call.
#
# A DECLARATION BEATS A GUESS, and here detection cannot stand alone at all.
# A self-hosted GitLab, Gitea or Forgejo lives at whatever domain its owner
# chose, and `git remote get-url` says nothing about which software answers
# there. Detection recognises the hosted domains and no more; anything else
# resolves to `none` rather than to a wrong guess about someone's server.
#
# `none` IS A REAL HOST, NOT A FAILURE. It is what an unsupported forge, an
# air-gapped mirror, or a plain bare repository gets. Its implementations do
# not pretend: each prints exactly what a human must do by hand, and exits
# non-zero so nothing downstream mistakes silence for success. That turns "your
# forge is unsupported" into a checklist, which is the difference between a
# framework that cannot be adopted and one that can be adopted with effort.
#
# USAGE
#
#   resolve-host.sh [project-root]      (default: the current directory)
#
# Exit 0 with the host on stdout; 1 when a declaration names something unknown.

set -uo pipefail

KNOWN_HOSTS="github none"

ROOT="${1:-.}"
if [ ! -d "$ROOT" ]; then
  echo "resolve-host: no such directory: $ROOT" >&2
  exit 1
fi

DECLARATION="$ROOT/.ia-engineering/host"

if [ -f "$DECLARATION" ]; then
  host="$(tr -d '[:space:]' < "$DECLARATION")"

  if [ -z "$host" ]; then
    echo "::error::$DECLARATION exists but is empty. Write one of ($KNOWN_HOSTS) into it, or delete the file to fall back to detection. An empty declaration is not a declaration, and treating it as one would pick a host nobody wrote down." >&2
    exit 1
  fi

  case " $KNOWN_HOSTS " in
    *" $host "*)
      echo "Host declared in $DECLARATION: $host" >&2
      printf '%s\n' "$host"
      exit 0
      ;;
    *)
      echo "::error::$DECLARATION declares '$host', which is not one of: $KNOWN_HOSTS. Fix it, or delete the file to fall back to detection. Guessing instead would call an implementation that does not exist, or worse, the wrong one." >&2
      exit 1
      ;;
  esac
fi

# No declaration: detect, conservatively.
#
# Only the hosted domain is recognised. A self-hosted instance is deliberately
# NOT guessed from the URL — github.example.com may be a GitHub Enterprise
# server, or a GitLab someone named unhelpfully, and calling the wrong API
# against a real server is worse than saying so. Such a project declares.
remote_url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"

if [ -z "$remote_url" ]; then
  echo "No $DECLARATION and no 'origin' remote; using: none" >&2
  printf 'none\n'
  exit 0
fi

case "$remote_url" in
  *github.com[:/]*)
    echo "No $DECLARATION; detected from origin ($remote_url): github" >&2
    printf 'github\n'
    ;;
  *)
    echo "No $DECLARATION, and origin ($remote_url) is not a recognised hosted forge; using: none" >&2
    echo "::notice::Host-dependent steps will report what to do by hand rather than doing it. If this is a self-hosted instance of a supported forge, declare it: write the host name into .ia-engineering/host. Detection deliberately does not guess a self-hosted domain, because calling the wrong API against a real server is worse than saying nothing." >&2
    printf 'none\n'
    ;;
esac
