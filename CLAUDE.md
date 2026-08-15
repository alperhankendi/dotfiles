# Working in this repository

Read `PLAN.md` before proposing structural changes. It records the decisions
and, more usefully, the rejected alternatives in section 3 and why each one
lost.

## Non-negotiables

- Everything in this repository is written in **English** — code, comments,
  documentation, commit messages.
- Every shell script targets macOS system **bash 3.2**. No associative
  arrays, no `mapfile`, no `${var^^}`.
- Executable action scripts (`bin/dot`, `bootstrap.sh`, `macos/defaults.sh`)
  start with `set -euo pipefail`. Files meant to be `source`d
  (`scripts/lib.sh`, `scripts/link.sh`) carry no `set` line of their own —
  they inherit whatever the caller has set.
- Anything that must keep evaluating independent checks after one of them
  fails — `scripts/doctor.sh`, `scripts/test-dot-cli.sh`,
  `scripts/test-link.sh` — starts with `set -uo pipefail`, deliberately
  without `-e`, so one failing check or assertion doesn't abort the rest.
- Every shell script passes `shellcheck` at zero warnings.
- `stow` is always called with `--no-folding`. Dropping it makes Claude Code
  write its session state into this repository. See `PLAN.md` section 9.4.
- No binaries. Fonts and applications come from Homebrew. One text file is
  vendored: `packages/delta/.config/delta/catppuccin.gitconfig`, because
  delta ships no Catppuccin theme of its own. Nothing else is vendored — bat
  and Ghostty both ship Catppuccin Mocha built in.
- Never commit personal data. Identity and keys live in
  `~/.config/git/local` and `~/.config/zsh/local.zsh`, both gitignored, with
  `.example` templates tracked in their place.

## Adding a tool

1. Add one line to `homebrew/Brewfile`, in the matching section, with a
   trailing comment.
2. If it has configuration, create `packages/<tool>/...` mirroring the
   target path in `$HOME`. Theme it Catppuccin Mocha if the tool supports
   theming.
3. Add a check to `scripts/doctor.sh`.
4. Run `dot link && dot brew && dot doctor`.

Never add the package name to a list — `dot` discovers `packages/*` itself.

## Definition of done

`dot doctor` exits 0. On a fresh machine, `dot bootstrap` itself exits
non-zero until `~/.config/git/local` and `~/.config/zsh/local.zsh` are
filled in with real values — that is expected, not a bug, and is not what
this rule is about. The rule is: after you finish a change, `dot doctor`
must be green on the machine you tested it on. If it is not, the work is
not finished.

## Editing configuration

Files under `~/.config` (and `~/.claude`) are symlinks into `packages/`.
Edit the file in this repository and run `dot link`; never edit through the
symlink target path.

## CI runs on Linux, not macOS

`.github/workflows/ci.yml` runs on `ubuntu-latest`. It checks shell syntax,
TOML/JSON validity, repository structure, the `dot` CLI's non-macOS paths,
and `stow --simulate` for every package — it does not and cannot exercise
Homebrew, Ghostty, tmux plugin installation, or `dot doctor` returning 0.
Passing CI is a necessary check, not a substitute for running `dot doctor`
on an actual Mac.
