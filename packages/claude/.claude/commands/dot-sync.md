---
description: Update every managed tool and stage the resulting lock files
---

Run `dot update` in `$DOTFILES`.

Then:
1. Run `dot doctor` and confirm nothing regressed.
2. Show me `git status` and `git diff` for the lock files. Homebrew has no
   lockfile, so the only one is `packages/nvim/.config/nvim/lazy-lock.json`.
3. Stage only those lock files. Do not commit.
4. If any tool moved to a new major version, tell me which and what changed.
