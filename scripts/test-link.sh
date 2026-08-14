#!/usr/bin/env bash
# Tests dot link against a throwaway HOME so the real one is never touched.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
status=0
FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT

report() {
  if [ "$1" -eq 0 ]; then
    printf '  ok   %s\n' "$2"
  else
    printf '  FAIL %s\n' "$2"
    status=1
  fi
}

# 1. Linking creates a symlink at the mirrored path.
HOME="$FAKE_HOME" "$ROOT/bin/dot" link git >/dev/null 2>&1
if [ -L "$FAKE_HOME/.config/git/config" ]; then rc=0; else rc=1; fi
report "$rc" "dot link git creates ~/.config/git/config as a symlink"

# 2. .config/git itself must be a real directory, not a symlink (--no-folding).
if [ -d "$FAKE_HOME/.config/git" ] && [ ! -L "$FAKE_HOME/.config/git" ]; then rc=0; else rc=1; fi
report "$rc" "--no-folding keeps ~/.config/git a real directory"

# 3. Re-running is idempotent.
HOME="$FAKE_HOME" "$ROOT/bin/dot" link git >/dev/null 2>&1
if [ -L "$FAKE_HOME/.config/git/config" ]; then rc=0; else rc=1; fi
report "$rc" "dot link git is idempotent"

# 4. An existing real file is backed up, never overwritten.
HOME="$FAKE_HOME" "$ROOT/bin/dot" unlink git >/dev/null 2>&1
mkdir -p "$FAKE_HOME/.config/git"
printf 'pre-existing\n' > "$FAKE_HOME/.config/git/config"
HOME="$FAKE_HOME" "$ROOT/bin/dot" link git >/dev/null 2>&1
backup_count="$(find "$FAKE_HOME/.config/git" -name 'config.bak-*' | wc -l | tr -d ' ')"
if [ "$backup_count" = "1" ] && [ -L "$FAKE_HOME/.config/git/config" ]; then rc=0; else rc=1; fi
report "$rc" "an existing real file is backed up and replaced by the symlink"

# 5. The backup still holds the original content.
if grep -q 'pre-existing' "$FAKE_HOME"/.config/git/config.bak-* 2>/dev/null; then rc=0; else rc=1; fi
report "$rc" "the backup preserves the original content"

# 6. Unlinking removes the symlink.
HOME="$FAKE_HOME" "$ROOT/bin/dot" unlink git >/dev/null 2>&1
if [ ! -L "$FAKE_HOME/.config/git/config" ]; then rc=0; else rc=1; fi
report "$rc" "dot unlink git removes the symlink"

exit "$status"
