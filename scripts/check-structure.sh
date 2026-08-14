#!/usr/bin/env bash
# Verifies the repository layout matches PLAN.md section 4.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

require_dir() {
  if [ -d "$ROOT/$1" ]; then
    printf '  ok   dir  %s\n' "$1"
  else
    printf '  FAIL dir  %s (missing)\n' "$1"
    status=1
  fi
}

require_file() {
  if [ -f "$ROOT/$1" ]; then
    printf '  ok   file %s\n' "$1"
  else
    printf '  FAIL file %s (missing)\n' "$1"
    status=1
  fi
}

require_dir bin
require_dir scripts
require_dir homebrew
require_dir macos
require_dir packages
require_file .gitignore
require_file .editorconfig
require_file PLAN.md

# The reference project must never be tracked by git.
if git -C "$ROOT" ls-files --error-unmatch macos-dot-files-main >/dev/null 2>&1; then
  printf '  FAIL macos-dot-files-main is tracked by git\n'
  status=1
else
  printf '  ok   macos-dot-files-main is untracked\n'
fi

exit "$status"
