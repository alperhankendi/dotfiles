#!/usr/bin/env bash
# Entry point for a brand new machine:
#   curl -fsSL <raw url>/bootstrap.sh | bash
# All the real logic lives in bin/dot, so there is only one place to change.
set -euo pipefail

REPO="${DOTFILES_REPO:-https://github.com/alperhankendi/dotfiles.git}"
DEST="${DOTFILES:-$HOME/workspace/dotfiles-next}"

if ! xcode-select -p >/dev/null 2>&1; then
  printf 'Installing the Xcode Command Line Tools first.\n'
  printf 'Follow the GUI prompt, then re-run this script.\n'
  xcode-select --install
  exit 0
fi

if [ -d "$DEST/.git" ]; then
  printf 'Repository already present at %s — pulling.\n' "$DEST"
  git -C "$DEST" pull --ff-only
else
  mkdir -p "$(dirname "$DEST")"
  git clone "$REPO" "$DEST"
fi

exec "$DEST/bin/dot" bootstrap "$@"
