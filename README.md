# dotfiles-next

Personal macOS dotfiles. One command provisions a fresh Mac; the Claude Code
environment is versioned alongside the terminal stack.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/alperhankendi/dotfiles/main/bootstrap.sh | bash
```

Or clone first and read it before running:

```bash
git clone https://github.com/alperhankendi/dotfiles.git ~/workspace/dotfiles-next
cd ~/workspace/dotfiles-next
./bin/dot bootstrap
```

On a genuinely fresh Mac this is really two commands, not one: if the Xcode
Command Line Tools are not installed yet, both `bootstrap.sh` and
`dot bootstrap` detect that, launch Apple's GUI installer, print instructions
to re-run, and exit 0 — run the same command again once that installer
finishes.

`dot bootstrap` asks for your administrator password up front (Homebrew needs
it to create `/opt/homebrew`), and asks once more, right beside it, whether to
apply macOS system defaults later in the run — `--yes` skips that second
prompt, `--skip-macos` skips the defaults entirely, `--skip-gui` skips casks
and fonts. Both prompts read the controlling terminal directly, so they still
appear even under `curl | bash` (where stdin is a pipe); they are skipped only
where no terminal exists at all, such as CI.

Afterwards, fill in `~/.config/git/local` and `~/.config/zsh/local.zsh` —
`dot bootstrap` creates both from their `.example` templates but leaves the
values as placeholders. **On a fresh machine `dot bootstrap` exits non-zero
because of this** — `dot doctor` fails until those two files hold real
values, and bootstrap reports whatever `dot doctor` reports. That is
expected, not a bug: fill in the two files, then run `dot doctor` again.

## The stack

| Layer | Tool |
|-------|------|
| Terminal | Ghostty |
| Multiplexer | tmux (resurrect + continuum) |
| Shell | zsh + sheldon |
| Prompt | starship |
| Editor | LazyVim |
| History | Atuin (local only, no sync) |
| Runtimes | mise |
| Theme | Catppuccin Mocha, everywhere |
| Font | Anka/Coder + Symbols Nerd Font |

Classics replaced: `ls`→eza, `cat`→bat, `diff`→delta, `cd`→zoxide,
`grep`→ripgrep, `find`→fd, `du`→dust, `df`→duf, `ps`→procs, `top`→btop,
`man`→tldr, `rm`→trash.

Containers run on **colima** with the plain `docker` and `docker compose`
clients — no Docker Desktop, no OrbStack, both of which need a paid licence
for commercial use. Run `colima start` once per boot before using docker.

## Commands

| Command | What it does |
|---------|--------------|
| `dot bootstrap` | Full install on a fresh machine |
| `dot link [pkg]` | Symlink packages into `$HOME` |
| `dot unlink [pkg]` | Remove those symlinks |
| `dot brew [--gui]` | Install Homebrew packages |
| `dot lang [--list \| <lang>]` | Pick and install language toolchains (dotnet, go, java, python, zig, C/C++); `dot bootstrap` asks the same question up front |
| `dot macos` | Apply macOS system defaults (no root needed) |
| `dot update` | Update everything, then leave the lock files for you to review and commit |
| `dot doctor` | Check that everything is in place |

## Shortcuts

| Key | Action |
|-----|--------|
| `cmd+backquote` | Toggle the Ghostty quick terminal, from anywhere |
| `cmd+shift+s` | Dump the pane to a file and paste its path |
| `cmd+shift+p` | Ghostty command palette |
| `ctrl+a` then `\|` / `-` | Split the tmux pane |
| `ctrl+r` | Atuin history search |
| `ctrl+t` | fzf file picker |

Splits live in tmux, not Ghostty: `cmd+d` and `cmd+shift+d` are explicitly
unbound in `packages/ghostty/.config/ghostty/config`, because a Ghostty split
dies with the window while a tmux pane survives a closed terminal and a
reboot.

## Adding a tool

1. One line in `homebrew/Brewfile`.
2. If it has a config, create `packages/<tool>/.config/<tool>/<file>`.
3. Add a check to `scripts/doctor.sh`.
4. `dot link && dot brew && dot doctor`.

There is no package list to update — `dot` reads `packages/*` directly.

## Layout

See [PLAN.md](PLAN.md) for the full design, the rejected alternatives, and
the traps worth knowing about.
