# dotfiles-next — Design Document

> **Handoff document.** Readable and actionable with zero prior context.
> Date: 2026-08-14 · Owner: Alper Hankendi · Status: **design under review, implementation not started**
> Reference project: [`macos-dot-files-main/`](macos-dot-files-main/) — [seifscape/macos-dot-files](https://github.com/seifscape/macos-dot-files)

---

## 0. What this project is

A personal dotfiles repository for macOS. It carries two goals of equal weight:

1. **Bring a new Mac to a working state with one command.** Terminal, shell, CLI tools, editor, system settings.
2. **Version the environment the AI agent lives in.** The `~/.claude` configuration is a first-class package, and the repository itself is designed to be managed by Claude Code.

This is not a product meant to be shared. Nobody else is expected to clone it, so simplicity wins over generality. In exchange, **personal data is never committed** — everything machine-specific lives in gitignored `*.local` files.

**Language rule:** every artifact in this repository — documentation, code, inline comments, commit messages, slash commands — is written in **English**. Conversation about the project may happen in any language; the repository does not.

---

## 1. Design Principles

These arbitrate every later decision. When a choice is close, check it against the principles.

1. **Declarative over imperative.** Configuration is a TOML/INI/conf file, not a chain of `if [[ $? != 0 ]]`. Adding a tool should mean writing three lines of text, not reading a script.
2. **No binaries in the repo.** Fonts, themes, icons, plists come from the package manager. One text file is vendored — delta's Catppuccin theme (§6.9) — because delta ships no Catppuccin of its own. bat needs no such file: it ships all four Catppuccin flavours built in.
3. **One tool, one file.** If a tool's settings are scattered across two places, the design is wrong.
4. **Reproducibility, honestly scoped.** Pin what can be pinned: `lazy-lock.json` for Neovim plugins, explicit versions in `mise` for language runtimes, a git tag for the Catppuccin tmux theme. Homebrew is the deliberate exception — as of Homebrew 6 there is no `Brewfile.lock.json` and no lockfile concept at all, so the Brewfile guarantees the same *set* of tools on every machine, at whatever version Homebrew currently ships. For a personal CLI toolchain that is the right trade; anything stronger would mean pinning formula revisions by hand and re-pinning them forever.
5. **Must run unattended.** `dot bootstrap` has to work in CI and on a fresh machine without a human. Two things genuinely need a person, and both are asked **once, at the very start**, never mid-run: the administrator password, needed once so Homebrew can create `/opt/homebrew`, and the confirmation before the macOS defaults are applied. The defaults themselves need no root — every domain they write (`NSGlobalDomain`, `com.apple.finder`, `com.apple.dock`, `com.apple.screencapture`, `com.apple.desktopservices`) is per-user, verified during implementation. `--yes` silences the confirmation, `--skip-macos` skips the defaults entirely, and neither prompt appears when stdin is not a TTY, so CI is unaffected. Everything after that first prompt runs to completion without attention.
6. **Idempotent.** A second run produces the same result as the first. Never write into tracked files.
7. **Fast shell startup.** The Ghostty quick terminal is bound to a hotkey; dozens of shells open per day. Target: `time zsh -i -c exit` under **150 ms**. No network calls, no version checks, no banner at startup.
8. **Sources, not derived files.** If a file can be hand-edited, it is a source and must not be generator output. (This principle killed the `tools.toml` manifest idea — §3.)

---

## 2. Decisions

All made in this session. They can change, but only with a stated reason.

| # | Topic | Decision | Rationale |
|---|-------|----------|-----------|
| 2.1 | Purpose | Personal dotfiles **and** AI environment, equal weight | §0 |
| 2.2 | Engine | **GNU Stow** | Directory layout equals target layout. No abstraction to learn, no vendor lock-in. One dependency: `brew install stow` |
| 2.3 | Topology | **`packages/` plus a single `dot` CLI** | Keeps the root clean; the package list is never maintained by hand (§4) |
| 2.4 | Scope | **Single profile, macOS only** | No work/personal split, no Linux. Can be added later if needed |
| 2.5 | Terminal | **Ghostty** | iTerm2 retired. `~/.config/ghostty/config`, plain `key = value` |
| 2.6 | Multiplexer | **tmux**, five plugins | Agent session persistence (§6.5) |
| 2.7 | Shell | **zsh** with **sheldon** | sheldon is Rust, TOML-driven, lockable; `apply`/`hooks` give precise control over load order |
| 2.8 | Prompt | **starship** | ~120 lines of TOML instead of an 84 KB `.p10k.zsh`. It also provides the Claude status line (§6.7) |
| 2.9 | Font | **Anka/Coder** with a `Symbols Nerd Font Mono` fallback | Anka is not a Nerd Font (§9.1); the fallback is one line |
| 2.10 | Theme | **Catppuccin Mocha**, everywhere | Ghostty · tmux · starship · bat · delta · fzf · nvim · eza |
| 2.11 | History | **Atuin, sync disabled** | Nothing leaves the machine. Replaces Ctrl+R |
| 2.12 | Runtimes | **mise** | node/python/go pinned in a single binary. None of the ~300 ms nvm adds to shell startup |
| 2.13 | Splits | **In tmux** | No split keybinds defined in Ghostty — no shortcut collisions across two layers |
| 2.14 | Editor | **LazyVim** | The reference setup, minus the iOS-specific pieces |
| 2.15 | Secrets | **Gitignored `*.local` files** | `~/.config/git/local` and `~/.config/zsh/local.zsh`, with `.example` templates in the repo |
| 2.16 | Brewfile | **Core plus CLI**, GUI in a separate file | A curated list, not a `brew bundle dump` inventory |
| 2.17 | macOS defaults | **~25 settings, prompted during install** | `dot bootstrap` asks for confirmation; `--yes` / `--skip-macos` bypass it |
| 2.18 | AI layer | `~/.claude` package, repo-management commands, starship status line | Other AI CLIs (Codex/Gemini) are out of scope |

---

## 3. Rejected Options

Recorded with reasons so the same debate does not reopen:

| Option | Why it was rejected |
|--------|---------------------|
| **chezmoi** | Its template/secret/profile machinery earns nothing in a single-profile setup. Editing and saving a file is not enough — `chezmoi apply` is required, which contradicts principle 1 |
| **nix-darwin** | The learning curve and Homebrew conflict management cost more than the determinism buys |
| **Bare git repo** | No symlinks, but `$HOME` becomes the working tree; the risk of accidental commits is high |
| **Hand-written symlink script** | Means reimplementing Stow's folding and conflict behavior. Stow has had thirty years to get it right |
| **`tools.toml` manifest generating the Brewfile** | Turns the Brewfile from a source into a derived file, violating principle 8. The Brewfile already is a declarative manifest |
| **`brew bundle dump` inventory** | Every app you try leaks into the repo and reproducibility degrades (the reference has 100+ MAS apps and 100+ VS Code extensions) |
| **The reference's `~/.gitconfig.local` plus `read` prompt** | The prompt breaks unattended installation, and it leaves no home for API keys |
| **`fastfetch` and `dev-updates.sh` on every shell startup** | Directly contradicts principle 7. The reference `.zshrc` does exactly this |
| **`omerxx/catppuccin-tmux`** (the reference's theme) | An outdated fork. The official `catppuccin/tmux` v2 exists (§9.6) |
| **`git-credential-manager` cask** | macOS's built-in `osxkeychain` helper does the same job with no extra dependency |

---

## 4. Repository Topology

```
dotfiles-next/
├── README.md                  # what gets installed, how, and a shortcut table
├── PLAN.md                    # this document
├── CLAUDE.md                  # rules for AI-driven maintenance of this repo
├── bootstrap.sh               # curl | zsh entry point → bin/dot bootstrap
├── .gitignore
├── .editorconfig
│
├── bin/
│   └── dot                    # THE single entry point (§5)
│
├── homebrew/
│   ├── Brewfile               # core plus CLI (headless-safe)
│   └── Brewfile.gui           # casks: ghostty, fonts, GUI apps
│
├── macos/
│   └── defaults.sh            # ~25 settings, every line commented (§6.12)
│
├── packages/                  # ← stow packages; ONLY these are stowed
│   ├── zsh/  sheldon/  starship/  ghostty/  tmux/
│   ├── git/  bat/  delta/  atuin/  mise/  nvim/
│   └── claude/                # the AI layer (§6.11)
│
├── scripts/
│   ├── lib.sh                 # logging/color/helpers — sourced by `dot`
│   ├── doctor.sh              # health check (§8)
│   └── test-*.sh              # behavioural tests, also run in CI
│
├── docs/
│   └── superpowers/plans/     # implementation plans derived from this spec
│
├── .github/workflows/ci.yml   # shellcheck plus stow --simulate
└── macos-dot-files-main/      # reference project — gitignored, never committed
```

**Nine entries at the root.** The rule: every directory under `packages/` is a stow package, and nothing outside it is. That is why the package list is **never maintained by hand** — `dot` enumerates `packages/*`. There is no second source of truth to fall out of date, unlike the `PACKAGES=(...)` array in the reference's `install.sh`.

Inside a package, the layout mirrors the destination path exactly:

```
packages/ghostty/.config/ghostty/config   →   ~/.config/ghostty/config
packages/zsh/.zshenv                      →   ~/.zshenv
packages/claude/.claude/settings.json     →   ~/.claude/settings.json
```

---

## 5. The Engine: `bin/dot` Contract

One entry point. Humans and agents use the same interface.

| Command | What it does |
|---------|--------------|
| `dot bootstrap [--yes] [--skip-macos] [--skip-gui]` | Full install: Xcode CLT → Homebrew → `brew bundle` → `sheldon lock` → `dot link` → TPM and tmux plugins → `mise install` → macOS defaults (prompted) → `dot doctor` |
| `dot link [package...]` | `stow --no-folding --restow`. With no arguments: every package |
| `dot unlink [package...]` | `stow -D` |
| `dot brew [--gui]` | `brew bundle --file=homebrew/Brewfile` (plus `.gui`) |
| `dot macos` | Runs `macos/defaults.sh` |
| `dot update` | `brew update && brew upgrade && brew bundle` · `sheldon lock --update` · `mise upgrade` · TPM update · `nvim --headless "+Lazy! sync" +qa`, then leaves the lock files staged for review |
| `dot doctor` | §8 |

**Behavioral rules:**

- `set -euo pipefail`. Error messages name the step that failed.
- **Conflict policy:** if `dot link` finds a real (non-symlink) file at the destination, it never overwrites. It backs the file up as `file.bak-YYYYMMDD-HHMMSS`, reports what it did, and continues. On this machine `~/.zshrc` and `~/.claude/settings.json` already exist and will both take this path.
- **`--no-folding` is mandatory.** See §9.4 — without it, `~/.claude` becomes a single symlink and Claude Code cannot write its state.
- Colored output that respects `NO_COLOR` and non-TTY contexts.
- `bootstrap.sh` only clones the repo and delegates to `bin/dot bootstrap`, so the logic lives in exactly one place.

---

## 6. Layer-by-Layer Specification

### 6.1 Homebrew

**`homebrew/Brewfile`** — headless-safe, no casks. About 35 lines; every line must earn its place in daily use:

```ruby
# Engine
brew "stow"

# Shell
brew "zsh"; brew "sheldon"; brew "starship"; brew "tmux"

# Modern CLI  (old → new)
brew "eza"        # ls
brew "bat"        # cat
brew "git-delta"  # diff
brew "zoxide"     # cd
brew "fzf"        # fuzzy finder
brew "atuin"      # Ctrl+R
brew "ripgrep"    # grep
brew "fd"         # find
brew "dust"       # du
brew "duf"        # df
brew "procs"      # ps
brew "btop"       # top
brew "tealdeer"   # man → tldr
brew "yazi"       # file manager
brew "jq"; brew "yq"

# Git and dev
brew "git"; brew "gh"; brew "lazygit"; brew "neovim"; brew "mise"; brew "trash"
```

**`homebrew/Brewfile.gui`** — `ghostty`, `font-anka-coder`, `font-symbols-only-nerd-font`, and whatever GUI apps get added over time. Skipped in CI and headless installs via `--skip-gui`.

There is no `Brewfile.lock.json` — Homebrew 6 removed the lockfile concept entirely, so the Brewfile pins the tool set rather than the versions (principle 4). The `mas`, `vscode`, `go`, and `npm` blocks are **not used**.

Adding a tool → §7.

### 6.2 zsh

XDG-clean layout. Exactly one file remains in `$HOME`:

```
packages/zsh/.zshenv                          → ~/.zshenv    # ZDOTDIR and XDG vars, nothing else
packages/zsh/.config/zsh/.zprofile            # login shell: brew shellenv (PATH set once)
packages/zsh/.config/zsh/.zshrc               # main file, target ~30 lines
packages/zsh/.config/zsh/aliases.zsh
packages/zsh/.config/zsh/functions.zsh
packages/zsh/.config/zsh/exports.zsh
packages/zsh/.config/zsh/keybindings.zsh
packages/zsh/.config/zsh/local.zsh.example    # copied on install; the real one is gitignored
```

**Startup speed strategy** (principle 7; published cases report 1.4 s → 53 ms). Three techniques:

1. **`compinit` runs in full once a day**, and reads the cache with `-C` otherwise:
   ```zsh
   autoload -Uz compinit
   if [[ -n $ZDOTDIR/.zcompdump(#qN.mh+24) ]]; then compinit; else compinit -C; fi
   ```
2. **`.zcompdump` is compiled to bytecode** (`zcompile`) in the background. Saves 30–80 ms.
3. **Heavy initializations are deferred with `zsh-defer`** — autosuggestions and syntax highlighting. `starship` is **not** deferred; a prompt that arrives late is pointless.

`compinit` is called **exactly once**, and every `fpath` addition happens before it (§9.5). No `fastfetch`, no version check, no network at startup.

`local.zsh` is sourced **last** so it can override anything.

**Measurement commitment:** `dot doctor` runs `time zsh -i -c exit` and warns above 150 ms.

### 6.3 sheldon

`packages/sheldon/.config/sheldon/plugins.toml`. The real difficulty of this layer is **ordering**: syntax highlighting must come last, fzf-tab after compinit, atuin after the fzf keybindings.

```toml
shell = "zsh"

[templates]
defer = "{{ hooks?.pre | nl }}{% for file in files %}zsh-defer source \"{{ file }}\"\n{% endfor %}{{ hooks?.post | nl }}"

[plugins.zsh-defer]            # must load before anything deferred
github = "romkatv/zsh-defer"

[plugins.fzf-tab]
github = "Aloxaf/fzf-tab"

[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"
apply  = ["defer"]

[plugins.tooling]              # init lines for brew binaries — order guaranteed here
inline = '''
eval "$(starship init zsh)"
eval "$(zoxide init zsh --cmd cd)"
eval "$(mise activate zsh)"
eval "$(atuin init zsh --disable-up-arrow)"
source <(fzf --zsh)
'''

[plugins.zsh-syntax-highlighting]   # ALWAYS last
github = "zsh-users/zsh-syntax-highlighting"
apply  = ["defer"]
```

**Design choice:** starship, zoxide, atuin, fzf, and mise are brew binaries, not sheldon plugins. But their `eval` lines are not scattered through `.zshrc` — they sit here as an `inline` plugin. One file, one ordering authority.

### 6.4 Ghostty

`packages/ghostty/.config/ghostty/config`. Plain `key = value`.

```conf
# ── Appearance ──
theme = Catppuccin Mocha            # exact name from `ghostty +list-themes`
font-family = Anka/Coder
font-family = Symbols Nerd Font Mono     # fallback — Anka is not a Nerd Font (§9.1)
font-size = 14
adjust-cell-width = -3%                  # approximates the Condensed variant (§9.2)
cursor-style = block
cursor-style-blink = false
mouse-hide-while-typing = true
window-padding-x = 8
window-padding-y = 6
background-opacity = 0.97
background-blur = 20

# ── Shell / TUI ──
shell-integration = zsh
shell-integration-features = cursor,sudo,title,ssh-env,ssh-terminfo
macos-option-as-alt = true               # alt+b / alt+f word jumps at the prompt
confirm-close-surface = true             # prevents killing a running agent by accident
scrollback-limit = 104857600             # 100 MB — long agent output
clipboard-paste-protection = true

# ── Quick terminal — the drop-down agent session ──
quick-terminal-position = top
quick-terminal-size = 40%
quick-terminal-autohide = false          # must not vanish on focus loss while an agent runs

# ── Notifications ──
notify-on-command-finish = unfocused
notify-on-command-finish-after = 30s     # macOS notification when a long build/test/agent finishes

# ── Keybinds: ONLY what tmux cannot do ──
keybind = global:cmd+backquote=toggle_quick_terminal
keybind = super+d=unbind                 # Ghostty ships split binds; see below
keybind = super+shift+d=unbind
keybind = cmd+shift+s=write_scrollback_file:paste
keybind = cmd+shift+r=reload_config
keybind = shift+enter=text:\n            # multi-line input in Claude Code

# ── Machine-local override (gitignored) ──
config-file = ?local.conf
```

**The three most valuable Ghostty features for this stack:**

1. **`write_scrollback_file:paste`** — writes the entire pane output to a file and **pastes its path into the prompt**:
   ```
   cmd+shift+s   →   /var/folders/.../scrollback.txt lands in the prompt
   claude "what broke in this log: <pasted path>"
   ```
   No more selecting forty minutes of build output with the mouse. The most expensive step of giving an agent context collapses into one shortcut.
2. **Command palette** — `cmd+shift+p`, fuzzy search over every action. Because it removes the need to memorize shortcuts, this repo defines very few keybinds.
3. **`global:cmd+backquote` quick terminal** — the successor to the old iTerm backtick reflex. Same muscle memory, now as a drop-down agent session.

Alongside those: the Kitty Graphics Protocol (images in the terminal), `cmd+F` scrollback search, OSC 133 prompt detection, and a genuine AppKit application (Zig plus Metal).

**Split keybinds are deliberately undefined, and Ghostty's own defaults are unbound** — splits live in tmux (decision 2.13). Defining none is not enough: Ghostty ships `super+d` and `super+shift+d` bound to `new_split`, and a split created that way dies with the terminal. That defeats the entire reason tmux was chosen (§6.5), so both are explicitly unbound. Delete the two `unbind` lines to get them back.

**Custom shaders** (cursor smear, CRT, glow) are supported but **out of scope**: they require downloading GLSL from an external repo, which sits close to principle 2. Add one line to `local.conf` if wanted.

**Validation:** `ghostty +validate-config`, `+list-fonts`, `+list-themes`, `+list-keybinds`. `dot doctor` runs the first.

⚠️ Two things to verify during implementation: (a) that `font-family` may be repeated to declare a fallback, and (b) that `quick-terminal-size` and `notify-on-command-finish-after` exist in the installed Ghostty version. Both show up immediately under `+validate-config`; if unsupported, the line is dropped and the design is unaffected.

### 6.5 tmux

`packages/tmux/.config/tmux/tmux.conf`. XDG path, not `~/.tmux.conf`.

```conf
# ── The critical pair (§9.3) ──
set -sg escape-time 0            # zero ESC delay → REQUIRED for esc-esc in Claude Code and for nvim
set -g  allow-passthrough on     # let OSC sequences (Kitty graphics, OSC 52) pass through tmux

set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-ghostty:RGB"
set -g prefix C-a                # instead of C-b
set -g mouse on
set -g history-limit 200000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g set-clipboard on
set -g detach-on-destroy off     # closing the last window should not eject you from tmux
set -g status-position top
setw -g mode-keys vi

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"
```

**Plugins — five, no more:**

| Plugin | Why |
|--------|-----|
| `tpm` | plugin manager |
| `tmux-sensible` | defaults everyone can agree on |
| `tmux-resurrect` | saves sessions, windows, panes, layouts, and working directories |
| `tmux-continuum` | automatic save every 15 minutes, automatic restore on server start |
| `catppuccin/tmux` v2 | theme — **not via TPM**, but a tag-pinned clone (§9.6) |

```conf
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-nvim 'session'
```

**Why tmux (the agentic argument):** a long-running `claude` session survives closing the terminal, survives a dropped SSH connection, comes back after a reboot, and its panes can be driven by script.

**The cost:** Ghostty's OSC 133-based `jump_to_prompt` may not work reliably under tmux. This gets tested during installation; if it fails, the only loss is that comfort feature, which is acceptable next to the persistence gain.

The reference's `sessionx`, `floax`, `thumbs`, and `fzf-url` plugins are **not adopted** — each adds keybinds and maintenance for too little return.

### 6.6 starship

`packages/starship/.config/starship.toml`. Catppuccin Mocha palette; directory and git on the left, language versions, command duration, and clock on the right.

The reference's 300-plus-line config gets pruned: unused modules such as `azfunc`, `custom.dir_end`, `memory_usage`, `conda`, `haskell`, and `php` come out. Target: about 120 lines.

### 6.7 Claude Status Line (via starship)

**A research finding that was absent from the old plan.** As of starship **1.25.0** there is a `starship statusline claude-code` subcommand and three modules: `claude_model`, `claude_context`, and `claude_cost` ([PR #7234](https://github.com/starship/starship/pull/7234)).

- `claude_model` — the active model, with an alias table (`claude-opus-5` → `opus 5`)
- `claude_context` — context window usage as a percentage plus a visual gauge; yellow at 60%, red at 80%
- `claude_cost` — session cost, hidden entirely below a threshold

The prompt and the AI layer converge on **one config file**; no separate status line script is needed.

Wired up through `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "command": "starship statusline claude-code" } }
```

⚠️ The spelling of the profile key needs verification: the PR description says `profiles.claude_code`, while the reference project's working config uses `[profiles] claude-code`. Implementation will check `starship --version` is at least 1.25 and try both.

### 6.8 Git

`packages/git/.config/git/config` (XDG, not `~/.gitconfig`).

```ini
[include] path = ~/.config/git/local                          # identity — gitignored
[include] path = ~/.config/delta/catppuccin.gitconfig         # vendored theme (§6.9)
[init] defaultBranch = main
[push] autoSetupRemote = true
[pull] rebase = true
[rebase] autoStash = true
[credential] helper = osxkeychain
[core] pager = delta
[interactive] diffFilter = delta --color-only
[delta] features = catppuccin-mocha; navigate = true; line-numbers = true; side-by-side = true
```

Plus `packages/git/.config/git/ignore` for the global ignore list (`.DS_Store`, `*.swp`, `.idea/`, …).

### 6.9 CLI Tool Configs

| Tool | File | Note |
|------|------|------|
| **delta** | `packages/delta/.config/delta/catppuccin.gitconfig` | **Divergence from the reference:** it clones the `catppuccin/delta` repo during bootstrap, a hidden external dependency. We **vendor** the ~30-line theme instead |
| **bat** | `packages/bat/.config/bat/config` | **Corrected during implementation:** bat 0.26.1 ships Catppuccin Latte, Frappe, Macchiato and Mocha built in, verified against an empty config directory. No theme file is vendored and no `bat cache --build` is needed — both were in the original plan and both were unnecessary |
| **atuin** | `packages/atuin/.config/atuin/config.toml` | ~20 lines: `auto_sync = false`, `update_check = false`, `enter_accept = true`, `style = compact`. The reference's 300 lines of commented-out defaults are not carried over |
| **mise** | `packages/mise/.config/mise/config.toml` | node and python pinned; others added when needed |
| **eza / fzf / zoxide** | `exports.zsh` and `aliases.zsh` | No separate config file; Catppuccin fzf colors live in `FZF_DEFAULT_OPTS` |

**Alias migration table** (old repo → new):

| Old | New |
|-----|-----|
| `ls` / `lsd` plus `dircolor.zsh` | `eza --icons --group-directories-first` |
| `cat` | `bat` |
| `cd` / autojump | `zoxide --cmd cd` |
| Ctrl+R | Atuin |
| `alias git='hub'` | — (hub is archived; `gh` replaces it) |
| 15 aliases depending on `_git_dbg` | rewritten from scratch (all of them were already broken) |
| `iterm2_print_user_vars()` k8s context | starship `kubernetes` module |

### 6.10 Neovim

`packages/nvim/.config/nvim/` — LazyVim, following the reference setup:

- `init.lua`, `lua/config/{lazy,options,keymaps,autocmds}.lua`, `lua/plugins/*.lua`
- Catppuccin **Mocha** (the reference uses Frappe; decision 2.10 says Mocha)
- `lazy-lock.json` is **committed** (principle 4)
- **Not adopted:** `xcodebuild.lua` (iOS/Xcode-specific), `example.lua` (LazyVim template leftover)
- Adopted: telescope, gitsigns, hop, lazydocker, catppuccin

### 6.11 The AI Layer — `packages/claude`

```
packages/claude/.claude/
├── CLAUDE.md              # global working rules (language, tone, preferred tools)
├── settings.json          # statusLine, permissions, env
├── commands/
│   ├── add-tool.md        # automates §7
│   ├── dot-doctor.md      # runs dot doctor and interprets the output
│   └── dot-sync.md        # runs dot update and stages the lock files
└── agents/                # starts empty
```

**Never versioned** (they stay under `~/.claude` and are not symlinked): `projects/`, `sessions/`, `history.jsonl`, `cache/`, `shell-snapshots/`, `plugins/`, `telemetry/`, `ide/`, `backups/`, `settings.local.json`.

⚠️ This package is dangerous without `--no-folding` — see §9.4.

The existing `~/.claude/settings.json` (`{"theme":"dark","tui":"fullscreen"}`) will be backed up during `dot link`, and its contents folded into the repo's version.

The root **`CLAUDE.md`** is repo-specific: "adding a tool takes these three steps", "never put files outside `packages/`", "commit the lock files", "nothing is done until `dot doctor` is green".

### 6.12 macOS Defaults

`macos/defaults.sh` — about 25 settings, each preceded by a comment explaining what it does. `dot bootstrap` **asks for confirmation** (bypassed with `--yes`, never prompted in CI).

Scope: key repeat rate and delay · `ApplePressAndHoldEnabled false` · Finder (show extensions, path and status bars, hidden files, list view, no `.DS_Store` on network volumes) · Dock (autohide, no delay, no recents, size) · screenshots (saved to `~/Desktop/Screenshots`, PNG, no shadow). Sleep and energy settings are left alone.

The script ends by `killall`-ing the affected apps and printing which changes need a logout.

---

## 7. Recipe for Adding a Tool

The concrete form of this project's "three lines to add a feature" promise.

**A CLI tool with no config** (e.g. `httpie`):
1. One line in `homebrew/Brewfile`: `brew "httpie"`
2. `dot brew`

**A tool with a config** (e.g. `lazydocker`):
1. In `homebrew/Brewfile`: `brew "lazydocker"`
2. Create `packages/lazydocker/.config/lazydocker/config.yml`
3. `dot link && dot brew`

No package list to update, no `install.sh` to edit, no generator to run. The `/add-tool` slash command performs these steps and verifies the result with `dot doctor`.

---

## 8. Verification

**`dot doctor`** — "is everything where it should be". Built to catch the kind of silent breakage the old repo's `_git_dbg` had:

- Is Homebrew present, is `brew bundle check` clean
- Is every `packages/*` package actually symlinked, are there broken symlinks
- Are the expected binaries on `PATH` (`eza bat fzf zoxide atuin starship sheldon tmux mise nvim`)
- Is `ghostty +validate-config` clean
- Is the font installed: `ghostty +list-fonts | grep -i anka`
- Is `starship --version` at least 1.25 (required for the Claude status line)
- Are the tmux plugin directories populated
- Is `time zsh -i -c exit` under 150 ms (principle 7)
- Do `~/.config/git/local` and `~/.config/zsh/local.zsh` exist and contain real values
- Are the lock files current

Output: one ✓/⚠/✗ per line, each with **how to fix it**. Exit code 1 if any ✗.

**CI** (`.github/workflows/ci.yml`, ubuntu runner — free):
- `shellcheck bin/dot scripts/*.sh macos/defaults.sh bootstrap.sh`
- `stow --simulate --no-folding` for every package, so conflicts surface early
- TOML and JSON syntax validation

A full install test on a macOS runner is **deliberately absent for now** — the minutes are expensive. It can be added later as a manually triggered workflow.

---

## 9. Verified Technical Facts and Traps

Researched and confirmed; no need to investigate again.

### 9.1 Anka/Coder is NOT a Nerd Font
The `patched-fonts/` directory of `ryanoasis/nerd-fonts` was checked family by family (70 of them). **Anka is not there.**

This is fine, because Ghostty ships its own built-in Nerd Font symbol set and **draws box-drawing characters itself** rather than asking the font, aligning them exactly to the cell. Since the Claude Code TUI is built on box drawing, that works directly in our favor. If a glyph still comes up missing, the fix is one line: a second `font-family = Symbols Nerd Font Mono`. No fontforge patching required.

### 9.2 Anka/Coder Condensed is not in Homebrew
`font-anka-coder` exists (v1.100, four styles). `font-anka-coder-condensed` returns **404**. Getting Condensed would mean committing a binary font, which violates principle 2. We use the base family; the roughly 12.5% horizontal compression Condensed provides is approximated with `adjust-cell-width = -3%`.

### 9.3 The two critical tmux lines
Without `escape-time 0` and `allow-passthrough on`, the Claude Code TUI stumbles inside tmux. The first zeroes the ESC delay (required for esc-esc and for nvim); the second lets OSC sequences pass through tmux.

### 9.4 The Stow folding trap — `--no-folding` is mandatory
By default Stow "folds" directories: when the destination directory does not exist, it symlinks **the directory itself**. For `~/.claude` that is catastrophic — Claude Code then writes `sessions/` and `history.jsonl` straight into the repository. `--no-folding` always creates real directories and symlinks only leaf files. The same risk applies to `~/.config/nvim`. **`dot link` never drops this flag under any circumstances.**

### 9.5 The double-compinit trap
The most common cause of slow zsh startup: calling `compinit` twice with `fpath` changing in between, which regenerates the dump file every time. Every `fpath` addition must complete before a single `compinit` call.

### 9.6 catppuccin/tmux must not be loaded through TPM
Because of a name collision, the official repository recommends a tag-pinned direct clone instead of TPM:
```bash
git clone -b v2.3.0 https://github.com/catppuccin/tmux.git ~/.config/tmux/plugins/catppuccin/tmux
```
then `run ~/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux`. The `omerxx/catppuccin-tmux` fork the reference uses is outdated.

### 9.7 The sheldon lock file is not in the config directory
It lands in sheldon's data directory, so it never enters the repository. To pin versions, use the `tag`/`branch`/`rev` fields in the TOML.

### 9.8 Ghostty validation commands
`+validate-config`, `+list-fonts`, `+list-themes`, `+list-keybinds`, `+show-config`. Validate with the first whenever a new key is added — a wrong key is not silently swallowed.

---

## 10. Installing on a New Machine

```bash
# One command
curl -fsSL https://raw.githubusercontent.com/alperhankendi/dotfiles/main/bootstrap.sh | bash

# Or clone first if you want to read it before running it
git clone https://github.com/alperhankendi/dotfiles.git ~/workspace/dotfiles-next \
  && cd ~/workspace/dotfiles-next && ./bin/dot bootstrap
```

What remains manual afterward:
1. Fill in `~/.config/git/local` and `~/.config/zsh/local.zsh` (`dot doctor` reminds you)
2. Open Ghostty and confirm the font name with `ghostty +list-fonts | grep -i anka`
3. Install the tmux plugins with `prefix + I`
4. Test `jump_to_prompt` inside tmux (the cost noted in §6.5)

---

## 11. Out of Scope (YAGNI)

Deliberately not built. Any of these can be added later as its own decision:

work/personal profiles · Linux and devcontainer support · chezmoi or nix · `mas`/`vscode`/`npm` inventories · Codex and Gemini CLI configs · 1Password, age, or sops · Ghostty custom shaders · a full-install CI job on a macOS runner · embedded fonts or binaries in the repo · system info or update checks on every shell startup.

---

## 12. Small Points Still Open

Details that do not block implementation and can be settled along the way:

1. **tmux prefix** — the plan says `C-a` (as does the reference). Staying on `C-b` is a one-line change.
2. **bat theme** — vendor the `.tmTheme` (better highlighting, a few hundred lines of text) or use `--theme=ansi` (zero files, duller output).
3. **Ghostty transparency** — `background-opacity` and `background-blur` are in the plan; drop both if you want it plainer.
4. **starship profile key** — resolved: `claude-code` (hyphen). Confirmed empirically on starship 1.26.0: `echo '{}' | starship statusline claude-code` renders the intended profile only when `[profiles]` has the hyphenated key; with only `claude_code` (underscore) present the same command falls back to a mixed/default rendering instead. `claude_code` was removed from `packages/starship/.config/starship.toml`.
5. **Remote** — resolved: `https://github.com/alperhankendi/dotfiles`, created empty. `git init` runs as the first implementation step; nothing is pushed until the whole build is finished and reviewed.
