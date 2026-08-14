---
description: Add a CLI tool to the dotfiles repository
---

Add the tool `$ARGUMENTS` to the dotfiles repository at `$DOTFILES`.

Steps:
1. Confirm the formula exists: `brew info $ARGUMENTS`.
2. Add one line to `$DOTFILES/homebrew/Brewfile`, in the section that
   matches the tool's purpose, with a short trailing comment saying what it
   replaces or does. Keep the existing grouping and ordering.
3. If the tool needs a configuration file, create
   `$DOTFILES/packages/<tool>/.config/<tool>/<file>` mirroring the path it
   expects in `$HOME`. Theme it with Catppuccin Mocha if it supports theming.
4. If a configuration file was created, add a check for it to
   `$DOTFILES/scripts/doctor.sh`.
5. Run `dot brew` and, if a package was created, `dot link <tool>`.
6. Run `dot doctor` and confirm it is green.
7. Show me the diff. Do not commit.
