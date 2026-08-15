#!/usr/bin/env bash
# Shared helpers. Sourced by bin/dot and by the scripts under scripts/.
# Do not run this file directly.

# Resolved once, so callers can rely on it regardless of their cwd.
DOT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export DOT_ROOT

# `dot` must work the same from any shell, including ones that never sourced
# .zprofile — scripts, CI, cron. String test, no subprocess.
case ":$PATH:" in
  *":/opt/homebrew/bin:"*) ;;
  *) PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"; export PATH ;;
esac

# Colour is opt-out via NO_COLOR and automatically disabled when stdout
# is not a terminal, so piped output stays clean.
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_BOLD=$'\033[1m'
else
  C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD=''
fi

info()    { printf '%s[info]%s  %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()    { printf '%s[warn]%s  %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()     { printf '%s[error]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()     { err "$*"; exit 1; }
section() { printf '\n%s== %s ==%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"; }

# have <command> — true when the command is on PATH.
have() { command -v "$1" >/dev/null 2>&1; }

# dot_packages — one stow package name per line, alphabetically.
# The package list is derived from the filesystem, never hand-maintained.
dot_packages() {
  find "$DOT_ROOT/packages" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | sort
}
