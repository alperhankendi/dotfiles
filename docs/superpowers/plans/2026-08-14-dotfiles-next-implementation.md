# dotfiles-next Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal macOS dotfiles repository that provisions a fresh Mac with one command and versions the Claude Code environment alongside the terminal stack.

**Architecture:** GNU Stow links `packages/<name>/...` into `$HOME`, mirroring destination paths exactly. A single `bin/dot` bash script is the only entry point (`bootstrap`, `link`, `unlink`, `brew`, `macos`, `update`, `doctor`). `scripts/doctor.sh` is the project's test harness: every layer added must register a check there, so the check is written first, observed failing, then made to pass.

**Tech Stack:** bash 3.2 (macOS system bash), GNU Stow, Homebrew, zsh, sheldon, starship, Ghostty, tmux, LazyVim, mise, Atuin, shellcheck, GitHub Actions.

**Spec:** [`PLAN.md`](../../../PLAN.md)

## Global Constraints

Copied verbatim from the spec. Every task's requirements implicitly include this section.

- **Language:** every artifact in the repository — documentation, code, inline comments, commit messages, slash commands — is written in **English** (spec §0).
- **Shell dialect:** all scripts are `#!/usr/bin/env bash` and must run on macOS system bash **3.2**. No `declare -A`, no `mapfile`, no `${var^^}`, no `readarray`.
- **Every shell script starts with `set -euo pipefail`** and must pass `shellcheck` with zero warnings.
- **`stow` is always invoked with `--no-folding`.** `dot link` never drops this flag under any circumstances (spec §9.4).
- **No binaries in the repo.** Fonts, icons, and plists come from Homebrew. The only exceptions are text-format theme files: `packages/bat/.config/bat/themes/Catppuccin Mocha.tmTheme` and `packages/delta/.config/delta/catppuccin.gitconfig` (spec §1.2, §6.9).
- **Idempotent:** a second run of any command produces the same result as the first, and never writes into tracked files (spec §1.6).
- **Unattended:** `dot bootstrap` must complete without a human present. The only interactive step is the macOS defaults confirmation, bypassed by `--yes` and never shown when stdin is not a TTY (spec §1.5).
- **Startup budget:** `time zsh -i -c exit` must stay under **150 ms** (spec §1.7).
- **Theme:** Catppuccin **Mocha** in every layer (spec §2.10).
- **Repository root path during development:** `/Users/ahankendi/workspace/dotfiles-next`.
- **Reference project** lives at `macos-dot-files-main/` and is gitignored — read from it, never link to it.
- **Never commit personal data.** Git identity and API keys live only in `~/.config/git/local` and `~/.config/zsh/local.zsh`, both gitignored, both shipped as `.example` templates.

---

### Task 1: Repository Skeleton

**Files:**
- Create: `.gitignore`
- Create: `.editorconfig`
- Create: `.github/workflows/ci.yml`
- Test: `scripts/check-structure.sh`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: the directory layout `bin/`, `scripts/`, `homebrew/`, `macos/`, `packages/`, `docs/`; a git repository on branch `main`; `scripts/check-structure.sh` which exits 0 when the layout is correct and 1 otherwise.

- [ ] **Step 1: Write the failing structure test**

Create `scripts/check-structure.sh`:

```bash
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/check-structure.sh`
Expected: FAIL lines for `bin`, `homebrew`, `macos`, `packages`, `.gitignore`, `.editorconfig`, and a non-zero exit code.

- [ ] **Step 3: Create the directories and root files**

```bash
cd /Users/ahankendi/workspace/dotfiles-next
mkdir -p bin scripts homebrew macos .github/workflows
mkdir -p packages/zsh packages/sheldon packages/starship packages/ghostty \
         packages/tmux packages/git packages/bat packages/delta \
         packages/atuin packages/mise packages/nvim packages/claude
```

Create `.gitignore`:

```gitignore
# Reference project — read-only, never tracked
macos-dot-files-main/

# macOS noise
.DS_Store

# Machine-local secrets and identity (see PLAN.md section 2.15)
packages/git/.config/git/local
packages/zsh/.config/zsh/local.zsh
packages/ghostty/.config/ghostty/local.conf

# Backups produced by `dot link`
*.bak-*
```

Create `.editorconfig`:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

- [ ] **Step 4: Initialise the git repository**

```bash
cd /Users/ahankendi/workspace/dotfiles-next
git init -b main
```

- [ ] **Step 5: Run the structure test to verify it passes**

Run: `bash scripts/check-structure.sh`
Expected: every line `ok`, exit code 0.

- [ ] **Step 6: Add the CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install shellcheck and stow
        run: sudo apt-get update && sudo apt-get install -y shellcheck stow

      - name: Check repository structure
        run: bash scripts/check-structure.sh

      - name: shellcheck
        run: |
          shopt -s nullglob
          files=(bin/dot bootstrap.sh scripts/*.sh macos/*.sh)
          if [ ${#files[@]} -eq 0 ]; then
            echo "no shell files to check yet"
            exit 0
          fi
          shellcheck "${files[@]}"

      - name: stow dry run
        run: |
          shopt -s nullglob
          mkdir -p "$HOME/stow-target"
          for pkg in packages/*/; do
            name="$(basename "$pkg")"
            stow --dir=packages --target="$HOME/stow-target" \
                 --no-folding --simulate --verbose=1 "$name"
          done
```

- [ ] **Step 7: Verify shellcheck passes locally**

Run: `shellcheck scripts/check-structure.sh`
Expected: no output, exit code 0. If `shellcheck` is not installed yet, run `brew install shellcheck` first — it is also added to the Brewfile in Task 5.

- [ ] **Step 8: Commit**

```bash
git add .gitignore .editorconfig .github/workflows/ci.yml scripts/check-structure.sh PLAN.md docs/
git commit -m "chore: initialise repository skeleton and CI lint job"
```

---

### Task 2: The `dot` Entry Point

**Files:**
- Create: `scripts/lib.sh`
- Create: `bin/dot`
- Test: `scripts/test-dot-cli.sh`

**Interfaces:**
- Consumes: the layout from Task 1.
- Produces:
  - `scripts/lib.sh` exporting `DOT_ROOT`, and functions `info(msg)`, `warn(msg)`, `err(msg)`, `die(msg)`, `dot_packages()` (prints one package name per line), `have(cmd)` (returns 0 if the command exists).
  - `bin/dot` with subcommands `help`, `link`, `unlink`, `brew`, `macos`, `update`, `doctor`, `bootstrap`. Unknown subcommands exit 1. In this task every subcommand except `help` prints `not implemented yet` and exits 0.

- [ ] **Step 1: Write the failing CLI test**

Create `scripts/test-dot-cli.sh`:

```bash
#!/usr/bin/env bash
# Behavioural tests for bin/dot. No test framework — plain assertions.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOT="$ROOT/bin/dot"
status=0

assert_exit() {
  local expected="$1" label="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    printf '  ok   %s (exit %s)\n' "$label" "$actual"
  else
    printf '  FAIL %s (expected exit %s, got %s)\n' "$label" "$expected" "$actual"
    status=1
  fi
}

assert_stdout_contains() {
  local needle="$1" label="$2"
  shift 2
  local out
  out="$("$@" 2>&1)"
  case "$out" in
    *"$needle"*) printf '  ok   %s\n' "$label" ;;
    *) printf '  FAIL %s (output missing %s)\n' "$label" "$needle"; status=1 ;;
  esac
}

assert_exit 0 "dot help exits 0" "$DOT" help
assert_exit 0 "bare dot exits 0" "$DOT"
assert_exit 1 "unknown subcommand exits 1" "$DOT" definitely-not-a-command
assert_stdout_contains "Usage: dot" "help prints usage" "$DOT" help
assert_stdout_contains "doctor" "help lists the doctor subcommand" "$DOT" help

# dot_packages must list every directory under packages/ and nothing else.
# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"
expected_count="$(find "$ROOT/packages" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
actual_count="$(dot_packages | wc -l | tr -d ' ')"
if [ "$expected_count" = "$actual_count" ]; then
  printf '  ok   dot_packages lists %s packages\n' "$actual_count"
else
  printf '  FAIL dot_packages listed %s, expected %s\n' "$actual_count" "$expected_count"
  status=1
fi

exit "$status"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/test-dot-cli.sh`
Expected: FAIL on every assertion, because `bin/dot` and `scripts/lib.sh` do not exist yet.

- [ ] **Step 3: Write `scripts/lib.sh`**

```bash
#!/usr/bin/env bash
# Shared helpers. Sourced by bin/dot and by the scripts under scripts/.
# Do not run this file directly.

# Resolved once, so callers can rely on it regardless of their cwd.
DOT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export DOT_ROOT

# Colour is opt-out via NO_COLOR and automatically disabled when stdout
# is not a terminal, so piped output stays clean.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
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
```

- [ ] **Step 4: Write `bin/dot`**

```bash
#!/usr/bin/env bash
# dot — the single entry point for this dotfiles repository.
# See PLAN.md section 5 for the command contract.
set -euo pipefail

# shellcheck source=scripts/lib.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"

usage() {
  cat <<'EOF'
Usage: dot <command> [options]

Commands:
  bootstrap [--yes] [--skip-macos] [--skip-gui]
                      Full install on a fresh machine
  link [package...]   Symlink packages into $HOME (default: all)
  unlink [package...] Remove those symlinks
  brew [--gui]        Install Homebrew packages
  macos               Apply macOS system defaults
  update              Update Homebrew, plugins, and runtimes
  doctor              Check that everything is in place
  help                Show this message
EOF
}

main() {
  local cmd="${1:-help}"
  [ "$#" -gt 0 ] && shift

  case "$cmd" in
    help | -h | --help) usage ;;
    link | unlink | brew | macos | update | doctor | bootstrap)
      info "$cmd: not implemented yet"
      ;;
    *)
      err "unknown command: $cmd"
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
```

- [ ] **Step 5: Make it executable and run the test to verify it passes**

```bash
chmod +x bin/dot
bash scripts/test-dot-cli.sh
```

Expected: every line `ok`, exit code 0.

- [ ] **Step 6: Run shellcheck**

Run: `shellcheck bin/dot scripts/lib.sh scripts/test-dot-cli.sh scripts/check-structure.sh`
Expected: no output, exit code 0.

- [ ] **Step 7: Add the CLI test to CI**

In `.github/workflows/ci.yml`, add this step after `Check repository structure`:

```yaml
      - name: dot CLI tests
        run: bash scripts/test-dot-cli.sh
```

- [ ] **Step 8: Commit**

```bash
git add bin/dot scripts/lib.sh scripts/test-dot-cli.sh .github/workflows/ci.yml
git commit -m "feat: add dot entry point and shared shell helpers"
```

---

### Task 3: The Doctor Harness

**Files:**
- Create: `scripts/doctor.sh`
- Modify: `bin/dot` (wire up the `doctor` subcommand)

**Interfaces:**
- Consumes: `scripts/lib.sh` from Task 2.
- Produces: `scripts/doctor.sh` defining `check_ok(msg)`, `check_warn(msg, fix)`, `check_fail(msg, fix)`, and a `main` that runs all registered checks and exits 1 when any check failed. Later tasks add checks to this file. `dot doctor` runs it.

- [ ] **Step 1: Write the failing test**

Add to `scripts/test-dot-cli.sh`, before the final `exit "$status"`:

```bash
assert_stdout_contains "Homebrew" "doctor checks for Homebrew" "$DOT" doctor
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/test-dot-cli.sh`
Expected: `FAIL doctor checks for Homebrew (output missing Homebrew)` — `dot doctor` still prints `not implemented yet`.

- [ ] **Step 3: Write `scripts/doctor.sh`**

```bash
#!/usr/bin/env bash
# doctor — verifies the installed environment matches this repository.
# Every layer added to the repo registers its check here. See PLAN.md section 8.
set -uo pipefail

# shellcheck source=scripts/lib.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"

DOCTOR_FAILED=0

check_ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
check_warn() { printf '  %s⚠%s %s\n      fix: %s\n' "$C_YELLOW" "$C_RESET" "$1" "$2"; }
check_fail() {
  DOCTOR_FAILED=1
  printf '  %s✗%s %s\n      fix: %s\n' "$C_RED" "$C_RESET" "$1" "$2"
}

# require_command <binary> <install hint>
require_command() {
  if have "$1"; then
    check_ok "$1 is on PATH"
  else
    check_fail "$1 is missing" "$2"
  fi
}

check_homebrew() {
  section "Homebrew"
  if have brew; then
    check_ok "Homebrew is installed"
  else
    check_fail "Homebrew is missing" "run: dot bootstrap"
  fi
}

main() {
  check_homebrew
  printf '\n'
  if [ "$DOCTOR_FAILED" -eq 0 ]; then
    info "doctor: all checks passed"
  else
    err "doctor: some checks failed — see the fix hints above"
  fi
  return "$DOCTOR_FAILED"
}

main "$@"
```

- [ ] **Step 4: Wire it into `bin/dot`**

In `bin/dot`, replace the combined case arm with a dedicated `doctor` arm placed before it:

```bash
    doctor)
      bash "$DOT_ROOT/scripts/doctor.sh"
      ;;
    link | unlink | brew | macos | update | bootstrap)
      info "$cmd: not implemented yet"
      ;;
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash scripts/test-dot-cli.sh`
Expected: every line `ok`, exit code 0.

Then run: `./bin/dot doctor`
Expected: a `== Homebrew ==` section. On this machine Homebrew is not installed yet, so the line reads `✗ Homebrew is missing` and the exit code is 1. That is correct — the harness works.

- [ ] **Step 6: Run shellcheck**

Run: `shellcheck bin/dot scripts/doctor.sh scripts/lib.sh`
Expected: no output, exit code 0.

- [ ] **Step 7: Commit**

```bash
git add bin/dot scripts/doctor.sh scripts/test-dot-cli.sh
git commit -m "feat: add doctor harness with the first Homebrew check"
```

---

### Task 4: Linking with `dot link`

**Files:**
- Modify: `bin/dot`
- Create: `scripts/link.sh`
- Create: `packages/git/.config/git/config`
- Create: `packages/git/.config/git/ignore`
- Create: `packages/git/.config/git/local.example`
- Modify: `scripts/doctor.sh` (add the symlink check)
- Test: `scripts/test-link.sh`

**Interfaces:**
- Consumes: `dot_packages()` and the logging helpers from Task 2.
- Produces:
  - `scripts/link.sh` with `link_packages(action, packages...)` where `action` is `link` or `unlink`, and `backup_conflicts(package)` which renames existing non-symlink destinations to `<path>.bak-YYYYMMDD-HHMMSS`.
  - `dot link [package...]` and `dot unlink [package...]`.
  - A `check_symlinks` function in `scripts/doctor.sh`.

- [ ] **Step 1: Write the failing link test**

Create `scripts/test-link.sh`:

```bash
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
[ -L "$FAKE_HOME/.config/git/config" ]
report $? "dot link git creates ~/.config/git/config as a symlink"

# 2. .config/git itself must be a real directory, not a symlink (--no-folding).
[ -d "$FAKE_HOME/.config/git" ] && [ ! -L "$FAKE_HOME/.config/git" ]
report $? "--no-folding keeps ~/.config/git a real directory"

# 3. Re-running is idempotent.
HOME="$FAKE_HOME" "$ROOT/bin/dot" link git >/dev/null 2>&1
[ -L "$FAKE_HOME/.config/git/config" ]
report $? "dot link git is idempotent"

# 4. An existing real file is backed up, never overwritten.
HOME="$FAKE_HOME" "$ROOT/bin/dot" unlink git >/dev/null 2>&1
mkdir -p "$FAKE_HOME/.config/git"
printf 'pre-existing\n' > "$FAKE_HOME/.config/git/config"
HOME="$FAKE_HOME" "$ROOT/bin/dot" link git >/dev/null 2>&1
backup_count="$(find "$FAKE_HOME/.config/git" -name 'config.bak-*' | wc -l | tr -d ' ')"
[ "$backup_count" = "1" ] && [ -L "$FAKE_HOME/.config/git/config" ]
report $? "an existing real file is backed up and replaced by the symlink"

# 5. The backup still holds the original content.
grep -q 'pre-existing' "$FAKE_HOME"/.config/git/config.bak-* 2>/dev/null
report $? "the backup preserves the original content"

# 6. Unlinking removes the symlink.
HOME="$FAKE_HOME" "$ROOT/bin/dot" unlink git >/dev/null 2>&1
[ ! -L "$FAKE_HOME/.config/git/config" ]
report $? "dot unlink git removes the symlink"

exit "$status"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/test-link.sh`
Expected: FAIL on all six assertions — `dot link` still prints `not implemented yet`.

- [ ] **Step 3: Create the git package**

`packages/git/.config/git/config`:

```ini
# Git configuration. Personal identity lives in ~/.config/git/local,
# which is gitignored — see PLAN.md section 2.15.
[include]
	path = ~/.config/git/local
[include]
	path = ~/.config/delta/catppuccin.gitconfig

[init]
	defaultBranch = main

[push]
	autoSetupRemote = true

[pull]
	rebase = true

[rebase]
	autoStash = true

[fetch]
	prune = true

[credential]
	helper = osxkeychain

[core]
	pager = delta
	excludesfile = ~/.config/git/ignore

[interactive]
	diffFilter = delta --color-only

[delta]
	features = catppuccin-mocha
	navigate = true
	line-numbers = true
	side-by-side = true

[merge]
	conflictstyle = zdiff3

[diff]
	algorithm = histogram
```

`packages/git/.config/git/ignore`:

```gitignore
.DS_Store
*.swp
*.swo
.idea/
.vscode/
node_modules/
.env
.env.local
```

`packages/git/.config/git/local.example`:

```ini
# Copy to ~/.config/git/local and fill in. This file is never committed.
[user]
	name = Your Name
	email = you@example.com
```

- [ ] **Step 4: Write `scripts/link.sh`**

```bash
#!/usr/bin/env bash
# Stow wrapper. Sourced by bin/dot; not meant to be run directly.

# backup_conflicts <package>
# Stow refuses to overwrite an existing real file. Rather than failing the
# whole install, move each conflicting file aside with a timestamped name.
backup_conflicts() {
  local pkg="$1" pkg_dir src rel target stamp
  pkg_dir="$DOT_ROOT/packages/$pkg"
  stamp="$(date +%Y%m%d-%H%M%S)"

  while IFS= read -r src; do
    rel="${src#"$pkg_dir"/}"
    target="$HOME/$rel"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      mv "$target" "$target.bak-$stamp"
      warn "backed up $target -> $target.bak-$stamp"
    fi
  done < <(find "$pkg_dir" -type f)
}

# link_packages <link|unlink> [package...]
link_packages() {
  local action="$1"
  shift

  local packages
  if [ "$#" -gt 0 ]; then
    packages="$*"
  else
    packages="$(dot_packages)"
  fi

  have stow || die "stow is missing — run: brew install stow"

  local pkg
  for pkg in $packages; do
    if [ ! -d "$DOT_ROOT/packages/$pkg" ]; then
      die "no such package: $pkg"
    fi

    if [ "$action" = "unlink" ]; then
      stow --dir="$DOT_ROOT/packages" --target="$HOME" \
           --no-folding --delete "$pkg"
      info "unlinked $pkg"
    else
      backup_conflicts "$pkg"
      # --no-folding is mandatory: without it stow symlinks whole
      # directories and applications can no longer write their state
      # into them. See PLAN.md section 9.4.
      stow --dir="$DOT_ROOT/packages" --target="$HOME" \
           --no-folding --restow "$pkg"
      info "linked $pkg"
    fi
  done
}
```

- [ ] **Step 5: Wire it into `bin/dot`**

Add below the `lib.sh` source line:

```bash
# shellcheck source=scripts/link.sh
. "$DOT_ROOT/scripts/link.sh"
```

And replace the placeholder arms:

```bash
    link)
      link_packages link "$@"
      ;;
    unlink)
      link_packages unlink "$@"
      ;;
    brew | macos | update | bootstrap)
      info "$cmd: not implemented yet"
      ;;
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash scripts/test-link.sh`
Expected: six `ok` lines, exit code 0. If `stow` is missing, install it first: `brew install stow`.

- [ ] **Step 7: Add the symlink check to doctor**

In `scripts/doctor.sh`, add this function and call it from `main` after `check_homebrew`:

```bash
check_symlinks() {
  section "Symlinks"
  local pkg pkg_dir src rel target linked missing broken
  for pkg in $(dot_packages); do
    pkg_dir="$DOT_ROOT/packages/$pkg"
    linked=0
    missing=0
    broken=0
    while IFS= read -r src; do
      rel="${src#"$pkg_dir"/}"
      case "$rel" in
        *.example) continue ;;
      esac
      target="$HOME/$rel"
      if [ -L "$target" ]; then
        if [ -e "$target" ]; then
          linked=$((linked + 1))
        else
          broken=$((broken + 1))
        fi
      else
        missing=$((missing + 1))
      fi
    done < <(find "$pkg_dir" -type f)

    if [ "$broken" -gt 0 ]; then
      check_fail "$pkg has $broken broken symlink(s)" "run: dot link $pkg"
    elif [ "$missing" -gt 0 ]; then
      check_fail "$pkg is not fully linked ($missing file(s) missing)" "run: dot link $pkg"
    elif [ "$linked" -eq 0 ]; then
      check_warn "$pkg contains no linkable files" "add configuration under packages/$pkg"
    else
      check_ok "$pkg is linked ($linked file(s))"
    fi
  done
}
```

- [ ] **Step 8: Verify doctor reports the git package**

Run: `./bin/dot link git && ./bin/dot doctor`
Expected: a `== Symlinks ==` section containing `✓ git is linked (3 file(s))`. The other packages are still empty, so they report the `contains no linkable files` warning — that is expected until their tasks run.

- [ ] **Step 9: Run shellcheck and commit**

```bash
shellcheck bin/dot scripts/link.sh scripts/doctor.sh scripts/test-link.sh
git add bin/dot scripts/link.sh scripts/doctor.sh scripts/test-link.sh packages/git
git commit -m "feat: add dot link/unlink with conflict backup and the git package"
```

Also add the new test to `.github/workflows/ci.yml` after the `dot CLI tests` step:

```yaml
      - name: dot link tests
        run: bash scripts/test-link.sh
```

---

### Task 5: Homebrew Bundles

**Files:**
- Create: `homebrew/Brewfile`
- Create: `homebrew/Brewfile.gui`
- Modify: `bin/dot` (implement `brew`)
- Modify: `scripts/doctor.sh` (add the bundle check)

**Interfaces:**
- Consumes: the logging helpers.
- Produces: `dot brew [--gui]`, and a `check_bundle` function in doctor.

- [ ] **Step 1: Add the failing bundle check to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_bundle() {
  section "Homebrew bundle"
  if ! have brew; then
    check_fail "cannot check the bundle without Homebrew" "run: dot bootstrap"
    return
  fi
  if brew bundle check --file="$DOT_ROOT/homebrew/Brewfile" >/dev/null 2>&1; then
    check_ok "every formula in homebrew/Brewfile is installed"
  else
    check_fail "some formulae are missing" "run: dot brew"
  fi
}
```

- [ ] **Step 2: Run doctor to verify the check fails**

Run: `./bin/dot doctor`
Expected: `✗ cannot check the bundle without Homebrew` (Homebrew is not installed on this machine yet) or `✗ some formulae are missing`.

- [ ] **Step 3: Write `homebrew/Brewfile`**

```ruby
# Core command-line environment. Headless-safe: no casks here, so this file
# can be installed in CI and on servers. GUI applications live in Brewfile.gui.

# Engine
brew "stow"
brew "shellcheck"

# Shell
brew "zsh"
brew "sheldon"
brew "starship"
brew "tmux"

# Modern replacements for the classics
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
brew "tealdeer"   # man pages, practical examples
brew "yazi"       # terminal file manager
brew "jq"
brew "yq"

# Git and development
brew "git"
brew "gh"
brew "lazygit"
brew "neovim"
brew "mise"
brew "trash"
```

- [ ] **Step 4: Write `homebrew/Brewfile.gui`**

```ruby
# GUI applications and fonts. Skipped by `dot bootstrap --skip-gui` and
# never installed in CI.

cask "ghostty"

# Anka/Coder is not a Nerd Font, so the symbols-only font provides the
# glyph fallback. See PLAN.md section 9.1.
cask "font-anka-coder"
cask "font-symbols-only-nerd-font"
```

- [ ] **Step 5: Implement `dot brew`**

In `bin/dot`, replace the placeholder arm:

```bash
    brew)
      have brew || die "Homebrew is missing — run: dot bootstrap"
      brew bundle --file="$DOT_ROOT/homebrew/Brewfile"
      if [ "${1:-}" = "--gui" ]; then
        brew bundle --file="$DOT_ROOT/homebrew/Brewfile.gui"
      fi
      ;;
    macos | update | bootstrap)
      info "$cmd: not implemented yet"
      ;;
```

- [ ] **Step 6: Install Homebrew and run the bundle**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
./bin/dot brew --gui
```

Expected: every formula installs. This takes several minutes on a fresh machine.

- [ ] **Step 7: Run doctor to verify the check passes**

Run: `./bin/dot doctor`
Expected: `✓ Homebrew is installed` and `✓ every formula in homebrew/Brewfile is installed`.

- [ ] **Step 8: Commit the lock file**

```bash
shellcheck bin/dot scripts/doctor.sh
git add homebrew/Brewfile homebrew/Brewfile.gui bin/dot scripts/doctor.sh .gitignore
git commit -m "feat: add Homebrew bundles and the dot brew command"
```

---

### Task 6: The zsh Package

**Files:**
- Create: `packages/zsh/.zshenv`
- Create: `packages/zsh/.config/zsh/.zprofile`
- Create: `packages/zsh/.config/zsh/.zshrc`
- Create: `packages/zsh/.config/zsh/exports.zsh`
- Create: `packages/zsh/.config/zsh/aliases.zsh`
- Create: `packages/zsh/.config/zsh/functions.zsh`
- Create: `packages/zsh/.config/zsh/keybindings.zsh`
- Create: `packages/zsh/.config/zsh/local.zsh.example`
- Modify: `scripts/doctor.sh` (startup-time and local-file checks)

**Interfaces:**
- Consumes: the linking machinery from Task 4.
- Produces: a working interactive zsh whose startup stays under 150 ms; the environment variables `DOTFILES`, `ZDOTDIR`, `EDITOR`, `FZF_DEFAULT_OPTS`, `BAT_THEME`.

- [ ] **Step 1: Add the failing startup-budget check to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_shell_startup() {
  section "Shell startup"
  if [ ! -L "$HOME/.zshenv" ]; then
    check_fail "~/.zshenv is not linked" "run: dot link zsh"
    return
  fi
  local start end ms
  start="$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')"
  zsh -i -c exit >/dev/null 2>&1
  end="$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')"
  ms=$((end - start))
  if [ "$ms" -lt 150 ]; then
    check_ok "interactive zsh starts in ${ms}ms (budget 150ms)"
  else
    check_warn "interactive zsh starts in ${ms}ms, over the 150ms budget" \
      "profile with: zsh -i -c 'zmodload zsh/zprof; zprof'"
  fi
}

check_local_files() {
  section "Machine-local files"
  local f
  for f in "$HOME/.config/git/local" "$HOME/.config/zsh/local.zsh"; do
    if [ ! -f "$f" ]; then
      check_fail "$f is missing" "copy the matching .example file and fill it in"
    elif grep -q 'you@example.com' "$f" 2>/dev/null; then
      check_fail "$f still holds template values" "edit $f"
    else
      check_ok "$f exists"
    fi
  done
}
```

- [ ] **Step 2: Run doctor to verify both checks fail**

Run: `./bin/dot doctor`
Expected: `✗ ~/.zshenv is not linked` and two `✗ ... is missing` lines under `Machine-local files`.

- [ ] **Step 3: Write `packages/zsh/.zshenv`**

```zsh
# Read by every zsh invocation, including non-interactive scripts.
# Keep this file tiny — anything slow here also slows down `zsh -c`.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Everything else zsh reads lives under $ZDOTDIR, keeping $HOME clean.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Where this repository is checked out. Override in local.zsh if it moves.
export DOTFILES="$HOME/workspace/dotfiles-next"
```

- [ ] **Step 4: Write `packages/zsh/.config/zsh/.zprofile`**

```zsh
# Login shells only. PATH and one-time environment setup belong here so
# interactive shells never pay for them twice.

eval "$(/opt/homebrew/bin/brew shellenv)"

# The dot command, available everywhere.
[[ -d "$DOTFILES/bin" ]] && path=("$DOTFILES/bin" $path)
```

- [ ] **Step 5: Write `packages/zsh/.config/zsh/.zshrc`**

```zsh
# Interactive shells. Budget: under 150ms (PLAN.md section 1.7).
# Order matters here — read PLAN.md section 9.5 before rearranging.

# 1. All fpath additions must happen before the single compinit call.
#    A hardcoded path is used on purpose: `brew --prefix` costs a subprocess.
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

# 2. compinit runs in full at most once a day and reads the cache otherwise.
autoload -Uz compinit
_zcompdump="$ZDOTDIR/.zcompdump"
_compinit_full=0
for _dump in $_zcompdump(N.mh+24); do _compinit_full=1; done
if (( _compinit_full )); then
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
# Compile the dump to bytecode in the background; saves 30-80ms next time.
if [[ ! -e "$_zcompdump.zwc" || "$_zcompdump" -nt "$_zcompdump.zwc" ]]; then
  zcompile -R -- "$_zcompdump" &!
fi
unset _zcompdump _compinit_full _dump

# 3. History. Atuin owns Ctrl+R, but the plain history file still matters.
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
setopt hist_ignore_all_dups hist_reduce_blanks share_history extended_history
setopt auto_cd interactive_comments no_beep

# 4. Plugins and tool initialisation. sheldon owns the ordering.
eval "$(sheldon source)"

# 5. Our own configuration.
for _module in exports aliases functions keybindings; do
  source "$ZDOTDIR/$_module.zsh"
done
unset _module

# 6. Machine-local overrides, sourced last so they win.
[[ -r "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
```

- [ ] **Step 6: Write `packages/zsh/.config/zsh/exports.zsh`**

```zsh
# Environment variables. No secrets here — those belong in local.zsh.

export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R"

# bat as the man pager, with the escape sequences stripped.
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"
export BAT_THEME="Catppuccin Mocha"

# fzf, themed to match Catppuccin Mocha.
export FZF_DEFAULT_OPTS="\
--height 40% --layout=reverse --border \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--color=border:#6c7086,label:#cdd6f4"

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :200 {}'"

# Homebrew: never run an implicit update on every install.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1
```

- [ ] **Step 7: Write `packages/zsh/.config/zsh/aliases.zsh`**

```zsh
# Modern replacements. See PLAN.md section 6.9 for the migration table.

alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first --git'
alias la='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'

alias cat='bat'
alias du='dust'
alias df='duf'
alias ps='procs'
alias top='btop'
alias help='tldr'

alias v='nvim'
alias vim='nvim'
alias y='yazi'
alias lg='lazygit'

alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph -20'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# rm goes to the trash instead of vanishing. Use /bin/rm to bypass.
alias rm='trash'

# Reload the shell without opening a new window.
alias reload='exec zsh'
```

- [ ] **Step 8: Write `packages/zsh/.config/zsh/functions.zsh`**

```zsh
# Small helpers. Anything longer than a screen belongs in its own script.

# mkcd <dir> — create a directory and enter it.
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

# fbat — pick a file with fzf and open it in bat.
fbat() {
  local file
  file="$(fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always {}')" || return
  [[ -n "$file" ]] && bat "$file"
}

# fcd — pick a directory with fzf and cd into it.
fcd() {
  local dir
  dir="$(fd --type d --hidden --exclude .git | fzf)" || return
  [[ -n "$dir" ]] && cd "$dir" || return
}

# scratch — a throwaway directory that survives until reboot.
scratch() {
  cd "$(mktemp -d)" || return
  pwd
}
```

- [ ] **Step 9: Write `packages/zsh/.config/zsh/keybindings.zsh`**

```zsh
# Key bindings. Ctrl+R belongs to Atuin and Ctrl+T to fzf; both are bound
# by their own init lines in sheldon's inline plugin.

bindkey -e   # emacs bindings

# Up/Down search history using what is already typed.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Ctrl+X Ctrl+E opens the current command line in $EDITOR.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Copy the current buffer to the clipboard.
copy-buffer-to-clipboard() {
  printf '%s' "$BUFFER" | pbcopy
  zle -M "copied to clipboard"
}
zle -N copy-buffer-to-clipboard
bindkey '^Xc' copy-buffer-to-clipboard
```

- [ ] **Step 10: Write `packages/zsh/.config/zsh/local.zsh.example`**

```zsh
# Copy to ~/.config/zsh/local.zsh and edit. Never committed.
# Sourced last, so anything here overrides the rest of the configuration.

# export ANTHROPIC_API_KEY="..."
# export GITHUB_TOKEN="..."

# Override the repository location if it is not ~/workspace/dotfiles-next:
# export DOTFILES="$HOME/code/dotfiles-next"
```

- [ ] **Step 11: Link the package and create the local files**

```bash
./bin/dot link zsh git
cp packages/zsh/.config/zsh/local.zsh.example ~/.config/zsh/local.zsh
cp packages/git/.config/git/local.example ~/.config/git/local
```

Then edit `~/.config/git/local` and replace the template name and email with real values.

- [ ] **Step 12: Verify the checks pass**

Run: `zsh -i -c 'echo $ZDOTDIR'`
Expected: `/Users/ahankendi/.config/zsh`

Run: `./bin/dot doctor`
Expected: `✓ interactive zsh starts in NNms (budget 150ms)` and `✓ /Users/ahankendi/.config/git/local exists`.

Note: sheldon is not configured until Task 7, so `eval "$(sheldon source)"` prints an error until then. That is expected; the shell still starts.

- [ ] **Step 13: Commit**

```bash
shellcheck scripts/doctor.sh
git add packages/zsh scripts/doctor.sh
git commit -m "feat: add the zsh package with a 150ms startup budget"
```

---

### Task 7: The sheldon Package

**Files:**
- Create: `packages/sheldon/.config/sheldon/plugins.toml`
- Modify: `scripts/doctor.sh` (plugin check)

**Interfaces:**
- Consumes: the zsh package from Task 6, which calls `eval "$(sheldon source)"`.
- Produces: `sheldon source` emitting the plugin loads plus the inline tool initialisation for starship, zoxide, mise, atuin, and fzf.

- [ ] **Step 1: Add the failing check to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_sheldon() {
  section "sheldon"
  if ! have sheldon; then
    check_fail "sheldon is missing" "run: dot brew"
    return
  fi
  if sheldon source >/dev/null 2>&1; then
    check_ok "sheldon source runs cleanly"
  else
    check_fail "sheldon source fails" "check ~/.config/sheldon/plugins.toml"
  fi
}
```

- [ ] **Step 2: Run doctor to verify it fails**

Run: `./bin/dot doctor`
Expected: `✗ sheldon source fails` — there is no `plugins.toml` yet.

- [ ] **Step 3: Write `packages/sheldon/.config/sheldon/plugins.toml`**

```toml
# Plugin manager and, more importantly, the single ordering authority for
# shell initialisation. Read PLAN.md section 6.3 before reordering anything.

shell = "zsh"

[templates]
# Loads a plugin lazily through zsh-defer instead of blocking startup.
defer = "{{ hooks?.pre | nl }}{% for file in files %}zsh-defer source \"{{ file }}\"\n{% endfor %}{{ hooks?.post | nl }}"

# zsh-defer must be available before anything that uses the defer template.
[plugins.zsh-defer]
github = "romkatv/zsh-defer"

# fzf-tab has to come after compinit, which .zshrc already guarantees.
[plugins.fzf-tab]
github = "Aloxaf/fzf-tab"

[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"
apply = ["defer"]

# Initialisation for tools installed as Homebrew binaries rather than as
# plugins. They live here so that one file owns the whole ordering problem.
# starship is deliberately not deferred: a prompt that arrives late is useless.
[plugins.tooling]
inline = '''
eval "$(starship init zsh)"
eval "$(zoxide init zsh --cmd cd)"
eval "$(mise activate zsh)"
source <(fzf --zsh)
eval "$(atuin init zsh --disable-up-arrow)"
'''

# Syntax highlighting must always be last.
[plugins.zsh-syntax-highlighting]
github = "zsh-users/zsh-syntax-highlighting"
apply = ["defer"]
```

- [ ] **Step 4: Link and lock**

```bash
./bin/dot link sheldon
sheldon lock
```

Expected: sheldon clones the four GitHub plugins.

- [ ] **Step 5: Verify the check passes**

Run: `./bin/dot doctor`
Expected: `✓ sheldon source runs cleanly`.

Run: `zsh -i -c 'echo ok'`
Expected: `ok` with no error output. starship is not configured until Task 8, but its defaults work, so the prompt renders.

- [ ] **Step 6: Re-check the startup budget**

Run: `./bin/dot doctor`
Expected: the startup line still reads under 150 ms. If it does not, profile with `zsh -i -c 'zmodload zsh/zprof; zprof'` and move the slowest plugin to `apply = ["defer"]`.

- [ ] **Step 7: Commit**

```bash
git add packages/sheldon scripts/doctor.sh
git commit -m "feat: add the sheldon package as the shell ordering authority"
```

---

### Task 8: The starship Package

**Files:**
- Create: `packages/starship/.config/starship.toml`
- Modify: `scripts/doctor.sh` (version check)

**Interfaces:**
- Consumes: the `starship init zsh` line from Task 7.
- Produces: a Catppuccin Mocha prompt, plus the `[profiles]` entry consumed by the Claude status line in Task 13.

- [ ] **Step 1: Add the failing version check to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_starship() {
  section "starship"
  if ! have starship; then
    check_fail "starship is missing" "run: dot brew"
    return
  fi
  local version major minor
  version="$(starship --version | head -1 | awk '{print $2}')"
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"
  if [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -ge 25 ]; }; then
    check_ok "starship $version supports the Claude status line"
  else
    check_fail "starship $version is older than 1.25" "run: brew upgrade starship"
  fi
  if starship config --help >/dev/null 2>&1 && \
     starship print-config >/dev/null 2>&1; then
    check_ok "starship.toml parses"
  else
    check_fail "starship.toml does not parse" "check ~/.config/starship.toml"
  fi
}
```

- [ ] **Step 2: Run doctor to verify it fails**

Run: `./bin/dot doctor`
Expected: `✗ starship.toml does not parse` — the file does not exist yet, and `starship print-config` reports the missing configuration.

- [ ] **Step 3: Write `packages/starship/.config/starship.toml`**

```toml
"$schema" = 'https://starship.rs/config-schema.json'

format = """
$directory\
$git_branch\
$git_status\
$line_break\
$character"""

right_format = """
$cmd_duration\
$nodejs\
$python\
$golang\
$rust\
$java\
$swift\
$kubernetes\
$time"""

add_newline = true
command_timeout = 1000
palette = "catppuccin_mocha"

[directory]
style = "bold blue"
truncation_length = 3
truncation_symbol = "…/"
format = "[$path]($style)[$read_only]($read_only_style) "
read_only = " "

[git_branch]
symbol = " "
style = "bold mauve"
format = "[$symbol$branch]($style) "

[git_status]
style = "bold peach"
format = "[$all_status$ahead_behind]($style) "
conflicted = "="
ahead = "⇡"
behind = "⇣"
diverged = "⇕"
untracked = "?"
stashed = "*"
modified = "!"
staged = "+"
deleted = "-"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
vimcmd_symbol = "[❮](bold green)"

[cmd_duration]
min_time = 500
style = "yellow"
format = "[ $duration]($style) "

[time]
disabled = false
time_format = "%R"
style = "overlay1"
format = "[$time]($style)"

[nodejs]
symbol = " "
style = "green"
format = "[$symbol$version]($style) "

[python]
symbol = " "
style = "yellow"
format = "[$symbol$version]($style) "

[golang]
symbol = " "
style = "teal"
format = "[$symbol$version]($style) "

[rust]
symbol = " "
style = "peach"
format = "[$symbol$version]($style) "

[java]
symbol = " "
style = "flamingo"
format = "[$symbol$version]($style) "

[swift]
symbol = " "
style = "red"
format = "[$symbol$version]($style) "

[kubernetes]
disabled = false
symbol = "☸ "
style = "sapphire"
format = '[$symbol$context( \($namespace\))]($style) '

# ── Claude Code status line ───────────────────────────────────────────
# Rendered by `starship statusline claude-code`, wired up from
# ~/.claude/settings.json. See PLAN.md section 6.7.
# Both key spellings are defined because the released documentation and the
# pull request disagree; the unused one is simply ignored.
[profiles]
claude-code = "$claude_model$claude_context$claude_cost"
claude_code = "$claude_model$claude_context$claude_cost"

[claude_model]
format = "[$symbol$model ]($style)"
symbol = "󰚩 "
style = "bg:lavender fg:crust"
model_aliases = { "claude-opus-5" = "opus 5", "claude-sonnet-5" = "sonnet 5", "claude-fable-5" = "fable 5", "claude-haiku-4-5-20251001" = "haiku 4.5" }

[claude_context]
format = "[ $percentage $gauge ]($style)"
gauge_width = 4
gauge_full_symbol = "▰"
gauge_empty_symbol = "▱"

[[claude_context.display]]
threshold = 0
style = "bg:surface1 fg:blue"

[[claude_context.display]]
threshold = 60
style = "bg:surface1 fg:yellow"

[[claude_context.display]]
threshold = 80
style = "bg:surface1 fg:red"

[claude_cost]
format = "[ \\$$cost ]($style)"

[[claude_cost.display]]
threshold = 0.0
hidden = true

[[claude_cost.display]]
threshold = 0.10
style = "bg:mauve fg:crust"

[palettes.catppuccin_mocha]
rosewater = "#f5e0dc"
flamingo = "#f2cdcd"
pink = "#f5c2e7"
mauve = "#cba6f7"
red = "#f38ba8"
maroon = "#eba0ac"
peach = "#fab387"
yellow = "#f9e2af"
green = "#a6e3a1"
teal = "#94e2d5"
sky = "#89dceb"
sapphire = "#74c7ec"
blue = "#89b4fa"
lavender = "#b4befe"
text = "#cdd6f4"
subtext1 = "#bac2de"
subtext0 = "#a6adc8"
overlay2 = "#9399b2"
overlay1 = "#7f849c"
overlay0 = "#6c7086"
surface2 = "#585b70"
surface1 = "#45475a"
surface0 = "#313244"
base = "#1e1e2e"
mantle = "#181825"
crust = "#11111b"
```

- [ ] **Step 4: Link and verify**

```bash
./bin/dot link starship
./bin/dot doctor
```

Expected: `✓ starship 1.25.x supports the Claude status line` and `✓ starship.toml parses`.

- [ ] **Step 5: Confirm the profile key experimentally**

Run: `echo '{}' | starship statusline claude-code`
Expected: output rendered from the profile rather than the default prompt. If the command errors with an unknown-profile message, delete whichever of the two keys is unused from `[profiles]` and re-run. Record the answer in `PLAN.md` section 12 item 4.

- [ ] **Step 6: Verify the prompt renders**

Run: `zsh -i -c 'exit'` then open a new terminal.
Expected: the prompt shows the directory in blue and a green `❯`.

- [ ] **Step 7: Commit**

```bash
shellcheck scripts/doctor.sh
git add packages/starship scripts/doctor.sh PLAN.md
git commit -m "feat: add the starship prompt with the Claude status line profile"
```

---

### Task 9: The Ghostty Package

**Files:**
- Create: `packages/ghostty/.config/ghostty/config`
- Modify: `scripts/doctor.sh` (config validation and font check)

**Interfaces:**
- Consumes: the linking machinery.
- Produces: a validated Ghostty configuration, and `check_ghostty` in doctor.

- [ ] **Step 1: Add the failing checks to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_ghostty() {
  section "Ghostty"
  local ghostty="/Applications/Ghostty.app/Contents/MacOS/ghostty"
  if have ghostty; then
    ghostty="$(command -v ghostty)"
  elif [ ! -x "$ghostty" ]; then
    check_fail "Ghostty is not installed" "run: dot brew --gui"
    return
  fi

  if "$ghostty" +validate-config >/dev/null 2>&1; then
    check_ok "ghostty +validate-config is clean"
  else
    check_fail "the Ghostty config has errors" "run: $ghostty +validate-config"
  fi

  if "$ghostty" +list-fonts 2>/dev/null | grep -qi 'anka'; then
    check_ok "the Anka/Coder font is installed"
  else
    check_fail "the Anka/Coder font is missing" "run: brew install --cask font-anka-coder"
  fi

  if "$ghostty" +list-fonts 2>/dev/null | grep -qi 'symbols nerd font'; then
    check_ok "the Nerd Font symbol fallback is installed"
  else
    check_warn "the Nerd Font symbol fallback is missing" \
      "run: brew install --cask font-symbols-only-nerd-font"
  fi
}
```

- [ ] **Step 2: Run doctor to verify it fails**

Run: `./bin/dot doctor`
Expected: `✗ the Ghostty config has errors` or, if Ghostty is not yet installed, `✗ Ghostty is not installed`.

- [ ] **Step 3: Write `packages/ghostty/.config/ghostty/config`**

```conf
# Ghostty. Plain key = value; see PLAN.md section 6.4.
# Validate any change with: ghostty +validate-config

# ── Appearance ────────────────────────────────────────────────────────
theme = catppuccin-mocha
font-family = Anka/Coder
# Anka/Coder is not a Nerd Font, so symbols come from a second family.
font-family = Symbols Nerd Font Mono
font-size = 14
# Approximates the Condensed variant, which Homebrew does not carry.
adjust-cell-width = -3%
cursor-style = block
cursor-style-blink = false
mouse-hide-while-typing = true
window-padding-x = 8
window-padding-y = 6
background-opacity = 0.97
background-blur = 20

# ── Shell and TUI behaviour ───────────────────────────────────────────
shell-integration = zsh
shell-integration-features = cursor,sudo,title,ssh-env,ssh-terminfo
# Lets alt+b / alt+f jump by word at the prompt.
macos-option-as-alt = true
# Stops a running agent from being killed by an accidental cmd+w.
confirm-close-surface = true
# 100 MB, sized for long agent output.
scrollback-limit = 104857600
clipboard-paste-protection = true

# ── Quick terminal: the drop-down agent session ───────────────────────
quick-terminal-position = top
quick-terminal-size = 40%
# Must not disappear when focus moves elsewhere while an agent is running.
quick-terminal-autohide = false

# ── Notifications ─────────────────────────────────────────────────────
notify-on-command-finish = unfocused
notify-on-command-finish-after = 30s

# ── Keybinds: only what tmux cannot do ────────────────────────────────
# Splits live in tmux, so no split bindings are defined here.
keybind = global:cmd+grave=toggle_quick_terminal
# Writes the whole pane to a file and pastes the path into the prompt.
keybind = cmd+shift+s=write_scrollback_file:paste
keybind = cmd+shift+r=reload_config
# Multi-line input in Claude Code.
keybind = shift+enter=text:\n

# ── Machine-local overrides (gitignored) ──────────────────────────────
config-file = ?local.conf
```

- [ ] **Step 4: Link and validate**

```bash
./bin/dot link ghostty
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config
```

Expected: no errors. If a key is rejected — the likely candidates are the repeated `font-family`, `quick-terminal-size`, and `notify-on-command-finish-after` — delete that single line, re-run, and note the removal in a comment. The design does not depend on any of them.

- [ ] **Step 5: Verify the checks pass**

Run: `./bin/dot doctor`
Expected: `✓ ghostty +validate-config is clean`, `✓ the Anka/Coder font is installed`, `✓ the Nerd Font symbol fallback is installed`.

- [ ] **Step 6: Verify the two headline keybinds by hand**

Open Ghostty and confirm:
1. `cmd+grave` toggles the quick terminal from anywhere, including when Ghostty is not focused.
2. Run `ls -la`, press `cmd+shift+s`, and confirm a path is pasted into the prompt.

- [ ] **Step 7: Commit**

```bash
shellcheck scripts/doctor.sh
git add packages/ghostty scripts/doctor.sh
git commit -m "feat: add the Ghostty configuration"
```

---

### Task 10: The tmux Package

**Files:**
- Create: `packages/tmux/.config/tmux/tmux.conf`
- Modify: `scripts/doctor.sh` (plugin check)

**Interfaces:**
- Consumes: the linking machinery.
- Produces: a tmux configuration with TPM at `~/.config/tmux/plugins/tpm` and Catppuccin cloned to `~/.config/tmux/plugins/catppuccin/tmux`.

- [ ] **Step 1: Add the failing check to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_tmux() {
  section "tmux"
  if ! have tmux; then
    check_fail "tmux is missing" "run: dot brew"
    return
  fi
  if [ -d "$HOME/.config/tmux/plugins/tpm" ]; then
    check_ok "TPM is installed"
  else
    check_fail "TPM is missing" \
      "run: git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm"
  fi
  if [ -f "$HOME/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux" ]; then
    check_ok "the Catppuccin theme is installed"
  else
    check_fail "the Catppuccin theme is missing" "run: dot bootstrap"
  fi
  if tmux -f "$HOME/.config/tmux/tmux.conf" start-server \; kill-server 2>/dev/null; then
    check_ok "tmux.conf loads without errors"
  else
    check_fail "tmux.conf has errors" "run: tmux -f ~/.config/tmux/tmux.conf start-server"
  fi
}
```

- [ ] **Step 2: Run doctor to verify it fails**

Run: `./bin/dot doctor`
Expected: `✗ TPM is missing` and `✗ the Catppuccin theme is missing`.

- [ ] **Step 3: Write `packages/tmux/.config/tmux/tmux.conf`**

```conf
# tmux. Splits live here, not in Ghostty. See PLAN.md section 6.5.

# ── The two critical lines ────────────────────────────────────────────
# Zero ESC delay. Required for esc-esc in Claude Code and for nvim.
set -sg escape-time 0
# Let OSC sequences (Kitty graphics, OSC 52 clipboard) pass through tmux.
set -g allow-passthrough on

# ── Core behaviour ────────────────────────────────────────────────────
set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-ghostty:RGB"
set -g prefix C-a
unbind C-b
bind C-a send-prefix
set -g mouse on
set -g history-limit 200000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g set-clipboard on
# Closing the last window should not eject you from tmux entirely.
set -g detach-on-destroy off
set -g status-position top
setw -g mode-keys vi
set -g focus-events on

# ── Bindings ──────────────────────────────────────────────────────────
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# ── Theme ─────────────────────────────────────────────────────────────
# Catppuccin v2 is loaded directly from a tag-pinned clone rather than
# through TPM, which the project recommends because of a name collision.
set -g @catppuccin_flavor 'mocha'
set -g @catppuccin_window_status_style 'rounded'
run '~/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux'
set -g status-left '#{E:@catppuccin_status_session}'
set -g status-right '#{E:@catppuccin_status_directory}'

# ── Plugins ───────────────────────────────────────────────────────────
set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.config/tmux/plugins/'
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Sessions survive a reboot, which is the entire reason tmux is here.
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-nvim 'session'

run '~/.config/tmux/plugins/tpm/tpm'
```

- [ ] **Step 4: Link and install the plugins**

```bash
./bin/dot link tmux
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
mkdir -p ~/.config/tmux/plugins/catppuccin
git clone -b v2.3.0 https://github.com/catppuccin/tmux.git \
  ~/.config/tmux/plugins/catppuccin/tmux
~/.config/tmux/plugins/tpm/bin/install_plugins
```

- [ ] **Step 5: Verify the checks pass**

Run: `./bin/dot doctor`
Expected: `✓ TPM is installed`, `✓ the Catppuccin theme is installed`, `✓ tmux.conf loads without errors`.

- [ ] **Step 6: Verify the OSC 133 trade-off recorded in the spec**

Start tmux, run a few commands, and try Ghostty's prompt jump.

```bash
tmux new -s test
```

Note in `PLAN.md` section 6.5 whether `jump_to_prompt` works under tmux. Either answer is acceptable — the spec already accepts losing it. Then `tmux kill-session -t test`.

- [ ] **Step 7: Commit**

```bash
shellcheck scripts/doctor.sh
git add packages/tmux scripts/doctor.sh PLAN.md
git commit -m "feat: add tmux with resurrect, continuum, and Catppuccin v2"
```

---

### Task 11: CLI Tool Configurations

**Files:**
- Create: `packages/bat/.config/bat/config`
- Create: `packages/bat/.config/bat/themes/Catppuccin Mocha.tmTheme`
- Create: `packages/delta/.config/delta/catppuccin.gitconfig`
- Create: `packages/atuin/.config/atuin/config.toml`
- Create: `packages/mise/.config/mise/config.toml`
- Modify: `scripts/doctor.sh` (theme and Atuin privacy checks)

**Interfaces:**
- Consumes: the git config from Task 4, which already includes the delta theme path.
- Produces: themed `bat` and `delta`, an Atuin configuration with sync disabled, and pinned runtimes.

- [ ] **Step 1: Add the failing checks to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_cli_tools() {
  section "CLI tools"

  if have bat; then
    if bat --list-themes 2>/dev/null | grep -q 'Catppuccin Mocha'; then
      check_ok "the bat Catppuccin Mocha theme is built"
    else
      check_fail "the bat theme cache is not built" "run: bat cache --build"
    fi
  else
    check_fail "bat is missing" "run: dot brew"
  fi

  if [ -f "$HOME/.config/delta/catppuccin.gitconfig" ]; then
    check_ok "the delta theme is present"
  else
    check_fail "the delta theme is missing" "run: dot link delta"
  fi

  # Atuin must never sync. This is a privacy guarantee, not a preference.
  if [ -f "$HOME/.config/atuin/config.toml" ]; then
    if grep -q '^auto_sync = false' "$HOME/.config/atuin/config.toml"; then
      check_ok "Atuin sync is disabled"
    else
      check_fail "Atuin sync is not explicitly disabled" \
        "set auto_sync = false in ~/.config/atuin/config.toml"
    fi
  else
    check_fail "the Atuin config is missing" "run: dot link atuin"
  fi

  if have mise; then
    if mise doctor >/dev/null 2>&1; then
      check_ok "mise is healthy"
    else
      check_warn "mise reports problems" "run: mise doctor"
    fi
  else
    check_fail "mise is missing" "run: dot brew"
  fi
}
```

- [ ] **Step 2: Run doctor to verify it fails**

Run: `./bin/dot doctor`
Expected: four `✗` lines under `CLI tools`.

- [ ] **Step 3: Vendor the two theme files**

These are downloaded once and committed, so installation never depends on a
network fetch. This is the deliberate exception to the no-binaries rule —
both files are plain text.

```bash
mkdir -p "packages/bat/.config/bat/themes"
curl -fsSL -o "packages/bat/.config/bat/themes/Catppuccin Mocha.tmTheme" \
  https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme

mkdir -p packages/delta/.config/delta
curl -fsSL -o packages/delta/.config/delta/catppuccin.gitconfig \
  https://raw.githubusercontent.com/catppuccin/delta/main/catppuccin.gitconfig
```

Verify both files are non-empty text:

```bash
file "packages/bat/.config/bat/themes/Catppuccin Mocha.tmTheme"
grep -c 'catppuccin-mocha' packages/delta/.config/delta/catppuccin.gitconfig
```

Expected: XML text for the first, at least 1 for the second.

- [ ] **Step 4: Write `packages/bat/.config/bat/config`**

```
# bat. The theme file lives in themes/ and needs `bat cache --build`
# after any change. See PLAN.md section 6.9.
--theme="Catppuccin Mocha"
--style="numbers,changes,header"
--italic-text=always
--paging=auto
```

- [ ] **Step 5: Write `packages/atuin/.config/atuin/config.toml`**

```toml
# Shell history. Sync is off and stays off: nothing leaves this machine.
# See PLAN.md section 2.11.

auto_sync = false
update_check = false

search_mode = "fuzzy"
filter_mode = "global"
style = "compact"
inline_height = 20
show_preview = true
enter_accept = true

# Never record anything that looks like a credential.
secrets_filter = true
history_filter = [
  "^\\s*export .*(TOKEN|KEY|SECRET|PASSWORD)",
]
```

- [ ] **Step 6: Write `packages/mise/.config/mise/config.toml`**

```toml
# Runtime versions. Add a language here rather than installing it with brew,
# so projects can pin their own version with a local .mise.toml.

[tools]
node = "22"
python = "3.13"

[settings]
python.uv_venv_auto = true
```

- [ ] **Step 7: Link, build the bat cache, install the runtimes**

```bash
./bin/dot link bat delta atuin mise
bat cache --build
mise install
```

- [ ] **Step 8: Verify the checks pass**

Run: `./bin/dot doctor`
Expected: `✓ the bat Catppuccin Mocha theme is built`, `✓ the delta theme is present`, `✓ Atuin sync is disabled`, `✓ mise is healthy`.

Run: `git diff HEAD~1 --stat | head`
Expected: the diff renders side by side with Catppuccin colours.

- [ ] **Step 9: Commit**

```bash
shellcheck scripts/doctor.sh
git add packages/bat packages/delta packages/atuin packages/mise scripts/doctor.sh
git commit -m "feat: add bat, delta, atuin, and mise configurations"
```

---

### Task 12: The Neovim Package

**Files:**
- Create: `packages/nvim/.config/nvim/init.lua`
- Create: `packages/nvim/.config/nvim/lua/config/lazy.lua`
- Create: `packages/nvim/.config/nvim/lua/config/options.lua`
- Create: `packages/nvim/.config/nvim/lua/config/keymaps.lua`
- Create: `packages/nvim/.config/nvim/lua/config/autocmds.lua`
- Create: `packages/nvim/.config/nvim/lua/plugins/catppuccin.lua`
- Create: `packages/nvim/.config/nvim/lazyvim.json`
- Create: `packages/nvim/.config/nvim/stylua.toml`
- Modify: `scripts/doctor.sh` (headless health check)

**Interfaces:**
- Consumes: the reference configuration at `macos-dot-files-main/nvim/.config/nvim/`.
- Produces: a LazyVim installation themed Catppuccin Mocha, with `lazy-lock.json` committed.

- [ ] **Step 1: Add the failing check to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_neovim() {
  section "Neovim"
  if ! have nvim; then
    check_fail "nvim is missing" "run: dot brew"
    return
  fi
  if [ ! -f "$HOME/.config/nvim/init.lua" ]; then
    check_fail "the nvim config is not linked" "run: dot link nvim"
    return
  fi
  if nvim --headless "+qa" >/dev/null 2>&1; then
    check_ok "nvim starts without errors"
  else
    check_fail "nvim reports startup errors" "run: nvim --headless +qa"
  fi
  if [ -f "$DOT_ROOT/packages/nvim/.config/nvim/lazy-lock.json" ]; then
    check_ok "lazy-lock.json is committed"
  else
    check_warn "lazy-lock.json is missing" \
      "run nvim once, then commit packages/nvim/.config/nvim/lazy-lock.json"
  fi
}
```

- [ ] **Step 2: Run doctor to verify it fails**

Run: `./bin/dot doctor`
Expected: `✗ the nvim config is not linked`.

- [ ] **Step 3: Copy the reference configuration and prune it**

```bash
cp -R macos-dot-files-main/nvim/.config/nvim/ packages/nvim/.config/nvim/
# iOS/Xcode specific and template leftovers are not adopted (PLAN.md 6.10).
rm -f packages/nvim/.config/nvim/lua/plugins/xcodebuild.lua
rm -f packages/nvim/.config/nvim/lua/plugins/example.lua
# The lock file is regenerated locally in step 6.
rm -f packages/nvim/.config/nvim/lazy-lock.json
```

- [ ] **Step 4: Switch the theme to Mocha**

Replace `packages/nvim/.config/nvim/lua/plugins/catppuccin.lua` — note the
reference file is misspelled `catppuchin.lua`, so delete that one — with:

```lua
-- Catppuccin Mocha, matching every other layer of this setup.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      integrations = {
        gitsigns = true,
        telescope = true,
        treesitter = true,
        which_key = true,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
```

```bash
rm -f packages/nvim/.config/nvim/lua/plugins/catppuchin.lua
```

- [ ] **Step 5: Link and install the plugins**

```bash
./bin/dot link nvim
nvim --headless "+Lazy! sync" +qa
```

Expected: lazy.nvim downloads the plugin set and exits. This takes a minute.

- [ ] **Step 6: Verify the checks pass**

Run: `./bin/dot doctor`
Expected: `✓ nvim starts without errors` and `✓ lazy-lock.json is committed`.

Run: `nvim` and confirm the colours are Mocha, then `:q`.

- [ ] **Step 7: Commit**

```bash
shellcheck scripts/doctor.sh
git add packages/nvim scripts/doctor.sh
git commit -m "feat: add LazyVim with the Catppuccin Mocha theme"
```

---

### Task 13: The AI Layer

**Files:**
- Create: `packages/claude/.claude/settings.json`
- Create: `packages/claude/.claude/CLAUDE.md`
- Create: `packages/claude/.claude/commands/add-tool.md`
- Create: `packages/claude/.claude/commands/dot-doctor.md`
- Create: `packages/claude/.claude/commands/dot-sync.md`
- Modify: `.gitignore` (exclude Claude runtime state)
- Modify: `scripts/doctor.sh` (status line and folding checks)

**Interfaces:**
- Consumes: the starship profile from Task 8.
- Produces: `~/.claude/settings.json` wired to `starship statusline claude-code`, and three slash commands.

- [ ] **Step 1: Add the failing checks to doctor**

In `scripts/doctor.sh`, add and call from `main`:

```bash
check_claude() {
  section "Claude Code"

  # The folding trap: if ~/.claude is itself a symlink, Claude Code writes
  # its session state into this repository. See PLAN.md section 9.4.
  if [ -L "$HOME/.claude" ]; then
    check_fail "~/.claude is a symlink, not a directory" \
      "run: rm ~/.claude && dot link claude   (dot link uses --no-folding)"
  elif [ -d "$HOME/.claude" ]; then
    check_ok "~/.claude is a real directory"
  else
    check_fail "~/.claude does not exist" "run: dot link claude"
  fi

  if [ -L "$HOME/.claude/settings.json" ]; then
    if grep -q 'starship statusline claude-code' "$HOME/.claude/settings.json"; then
      check_ok "the Claude status line is wired to starship"
    else
      check_fail "settings.json does not reference the starship status line" \
        "check packages/claude/.claude/settings.json"
    fi
  else
    check_fail "~/.claude/settings.json is not linked" "run: dot link claude"
  fi

  # Runtime state must never end up inside the repository.
  local leaked
  leaked="$(find "$DOT_ROOT/packages/claude/.claude" \
    \( -name 'sessions' -o -name 'projects' -o -name 'history.jsonl' \) \
    -print -quit 2>/dev/null)"
  if [ -n "$leaked" ]; then
    check_fail "Claude runtime state leaked into the repo: $leaked" \
      "delete it and confirm dot link uses --no-folding"
  else
    check_ok "no Claude runtime state in the repo"
  fi
}
```

- [ ] **Step 2: Run doctor to verify it fails**

Run: `./bin/dot doctor`
Expected: `✗ ~/.claude/settings.json is not linked`.

- [ ] **Step 3: Write `packages/claude/.claude/settings.json`**

The two existing keys are preserved from the current `~/.claude/settings.json`.

```json
{
  "theme": "dark",
  "tui": "fullscreen",
  "statusLine": {
    "type": "command",
    "command": "starship statusline claude-code"
  }
}
```

- [ ] **Step 4: Write `packages/claude/.claude/CLAUDE.md`**

```markdown
# Global working rules

## Language
Write every file, comment, and commit message in English, regardless of the
language of the conversation.

## Shell environment
This machine runs zsh with the configuration in `~/workspace/dotfiles-next`.
Modern replacements are aliased over the classics: `ls` is eza, `cat` is bat,
`cd` is zoxide, `rm` is trash. When writing scripts, call the real binaries
(`/bin/ls`, `/bin/rm`) rather than relying on the interactive aliases.

## Long-running work
tmux is available and sessions survive a reboot. Prefer starting long jobs
inside a named tmux session over running them in the foreground.

## Dotfiles changes
Never edit files under `~/.config` directly — they are symlinks into
`~/workspace/dotfiles-next/packages/`. Edit the file in the repository and
run `dot link`.
```

- [ ] **Step 5: Write the three slash commands**

`packages/claude/.claude/commands/add-tool.md`:

```markdown
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
```

`packages/claude/.claude/commands/dot-doctor.md`:

```markdown
---
description: Run the dotfiles health check and explain the results
---

Run `dot doctor` and read the output.

For every ✗ and ⚠ line, explain in one sentence what is broken and why it
matters, then apply the suggested fix if it is safe and reversible. Do not
apply anything that would overwrite a file in `$HOME` without showing me
first. Finish by re-running `dot doctor` and reporting the new state.
```

`packages/claude/.claude/commands/dot-sync.md`:

```markdown
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
```

- [ ] **Step 6: Extend `.gitignore`**

Append to `.gitignore`:

```gitignore
# Claude Code runtime state must never enter the repository (PLAN.md 6.11)
packages/claude/.claude/projects/
packages/claude/.claude/sessions/
packages/claude/.claude/shell-snapshots/
packages/claude/.claude/plugins/
packages/claude/.claude/telemetry/
packages/claude/.claude/ide/
packages/claude/.claude/backups/
packages/claude/.claude/cache/
packages/claude/.claude/history.jsonl
packages/claude/.claude/settings.local.json
```

- [ ] **Step 7: Link and verify**

```bash
./bin/dot link claude
ls -la ~/.claude/settings.json
```

Expected: `settings.json` is a symlink, `~/.claude` itself is a real
directory, and the previous file was saved as `settings.json.bak-*`.

- [ ] **Step 8: Verify the checks pass**

Run: `./bin/dot doctor`
Expected: `✓ ~/.claude is a real directory`, `✓ the Claude status line is wired to starship`, `✓ no Claude runtime state in the repo`.

Open a new Claude Code session and confirm the status line shows the model
name, a context gauge, and — after enough usage — the cost.

- [ ] **Step 9: Commit**

```bash
shellcheck scripts/doctor.sh
git add packages/claude .gitignore scripts/doctor.sh
git commit -m "feat: manage the Claude Code environment as a stow package"
```

---

### Task 14: macOS Defaults

**Files:**
- Create: `macos/defaults.sh`
- Modify: `bin/dot` (implement `macos`)

**Interfaces:**
- Consumes: the logging helpers.
- Produces: `dot macos`, and `macos/defaults.sh` which accepts `--yes` to skip the confirmation prompt.

- [ ] **Step 1: Write the failing test**

Add to `scripts/test-dot-cli.sh`, before the final `exit "$status"`:

```bash
assert_exit 0 "dot macos --help exits 0" bash "$ROOT/macos/defaults.sh" --help
assert_stdout_contains "would change" "defaults.sh --dry-run explains itself" \
  bash "$ROOT/macos/defaults.sh" --dry-run
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/test-dot-cli.sh`
Expected: FAIL on both — `macos/defaults.sh` does not exist.

- [ ] **Step 3: Write `macos/defaults.sh`**

```bash
#!/usr/bin/env bash
# macOS system defaults. Curated, not exhaustive: every setting here is one
# you would otherwise change by hand on a new machine. See PLAN.md 6.12.
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0

usage() {
  cat <<'EOF'
Usage: defaults.sh [--yes] [--dry-run] [--help]

  --yes      Apply without asking for confirmation
  --dry-run  List what would change and exit
  --help     Show this message
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --help | -h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if [ "$DRY_RUN" -eq 1 ]; then
  cat <<'EOF'
This script would change:
  Keyboard  faster key repeat, shorter delay, press-and-hold disabled
  Finder    show extensions, path bar, status bar, hidden files, list view,
            no .DS_Store on network or USB volumes
  Dock      autohide with no delay, no recent applications, 48px tiles
  Screen    screenshots to ~/Desktop/Screenshots as PNG without shadows
  Misc      expanded save and print dialogs, no smart quotes or dashes
EOF
  exit 0
fi

# Confirmation. Skipped with --yes, and never shown when there is no TTY,
# so bootstrap can run unattended in CI.
if [ "$ASSUME_YES" -eq 0 ]; then
  if [ ! -t 0 ]; then
    printf 'no TTY and no --yes: skipping macOS defaults\n'
    exit 0
  fi
  printf 'Apply macOS system defaults? [y/N] '
  read -r reply
  case "$reply" in
    [yY] | [yY][eE][sS]) ;;
    *) printf 'skipped\n'; exit 0 ;;
  esac
fi

# Ask for the administrator password once and keep the session alive.
sudo -v

# ── Keyboard ──────────────────────────────────────────────────────────
# Fastest key repeat and the shortest delay before it starts.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Holding a key repeats it instead of opening the accent picker.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Full keyboard access: tab moves between all controls, not just text fields.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# ── Text ──────────────────────────────────────────────────────────────
# Smart quotes and dashes corrupt code snippets.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# ── Dialogs ───────────────────────────────────────────────────────────
# Always show the expanded save and print panels.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
# Save to disk by default rather than to iCloud.
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# ── Finder ────────────────────────────────────────────────────────────
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
# Search the current folder by default instead of the whole Mac.
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# List view everywhere.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# No warning when changing a file extension.
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Keep folders on top when sorting by name.
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# Do not litter network and USB volumes with .DS_Store files.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Dock ──────────────────────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock show-recents -bool false
# No bouncing icons demanding attention.
defaults write com.apple.dock no-bouncing -bool true

# ── Screenshots ───────────────────────────────────────────────────────
mkdir -p "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# ── Apply ─────────────────────────────────────────────────────────────
for app in Finder Dock SystemUIServer; do
  killall "$app" >/dev/null 2>&1 || true
done

printf '\nDone. Some changes need a logout to take effect:\n'
printf '  - full keyboard access\n'
printf '  - press-and-hold behaviour\n'
```

- [ ] **Step 4: Wire it into `bin/dot`**

Replace the placeholder arm:

```bash
    macos)
      bash "$DOT_ROOT/macos/defaults.sh" "$@"
      ;;
    update | bootstrap)
      info "$cmd: not implemented yet"
      ;;
```

- [ ] **Step 5: Run the dry run and the test**

```bash
./bin/dot macos --dry-run
bash scripts/test-dot-cli.sh
```

Expected: the dry run lists five categories; every test line reads `ok`.

- [ ] **Step 6: Apply for real and spot-check**

```bash
./bin/dot macos
```

Answer `y`. Then confirm: the Dock hides instantly, Finder shows a path bar, and a screenshot lands in `~/Desktop/Screenshots`.

- [ ] **Step 7: Run shellcheck and commit**

```bash
shellcheck macos/defaults.sh bin/dot
git add macos/defaults.sh bin/dot scripts/test-dot-cli.sh
git commit -m "feat: add curated macOS defaults behind a confirmation prompt"
```

---

### Task 15: Bootstrap and Update

**Files:**
- Create: `bootstrap.sh`
- Modify: `bin/dot` (implement `bootstrap` and `update`)

**Interfaces:**
- Consumes: every command implemented so far.
- Produces: `dot bootstrap [--yes] [--skip-macos] [--skip-gui]` and `dot update`; `bootstrap.sh` which clones the repository and delegates.

- [ ] **Step 1: Write the failing test**

Add to `scripts/test-dot-cli.sh`, before the final `exit "$status"`:

```bash
assert_stdout_contains "Xcode" "bootstrap --dry-run lists its steps" \
  "$DOT" bootstrap --dry-run
assert_exit 1 "bootstrap rejects unknown flags" "$DOT" bootstrap --nonsense
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/test-dot-cli.sh`
Expected: FAIL on both — `bootstrap` still prints `not implemented yet` and exits 0.

- [ ] **Step 3: Implement `bootstrap` and `update` in `bin/dot`**

Replace the placeholder arm with:

```bash
    bootstrap)
      cmd_bootstrap "$@"
      ;;
    update)
      cmd_update
      ;;
```

And add these functions above `main`:

```bash
cmd_bootstrap() {
  local assume_yes=0 skip_macos=0 skip_gui=0 dry_run=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --yes) assume_yes=1 ;;
      --skip-macos) skip_macos=1 ;;
      --skip-gui) skip_gui=1 ;;
      --dry-run) dry_run=1 ;;
      *) err "unknown bootstrap option: $1"; exit 1 ;;
    esac
    shift
  done

  if [ "$dry_run" -eq 1 ]; then
    cat <<'EOF'
bootstrap would run, in order:
  1. Xcode Command Line Tools
  2. Homebrew
  3. brew bundle (Brewfile, plus Brewfile.gui unless --skip-gui)
  4. sheldon lock
  5. dot link (every package)
  6. tmux plugin managers: TPM and Catppuccin
  7. mise install
  8. bat cache --build
  9. macOS defaults (unless --skip-macos)
 10. dot doctor
EOF
    return 0
  fi

  # Installing Homebrew needs root to create /opt/homebrew, and applying the
  # macOS defaults needs it too. Ask once, here, so the rest of the run is
  # uninterrupted rather than stalling on a password prompt ten minutes in.
  # Skipped when there is no TTY, so CI still works.
  if [ -t 0 ] && ! have brew; then
    section "Administrator access"
    info "Homebrew needs to create /opt/homebrew — asking for your password once"
    sudo -v
    # Refresh the credential in the background so it does not expire mid-run.
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  fi

  section "Xcode Command Line Tools"
  if xcode-select -p >/dev/null 2>&1; then
    info "already installed"
  else
    info "installing — follow the GUI prompt, then re-run this command"
    xcode-select --install
    exit 0
  fi

  section "Homebrew"
  if have brew; then
    info "already installed"
  else
    # NONINTERACTIVE stops the installer waiting for a RETURN keypress.
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"

  section "Homebrew packages"
  brew bundle --file="$DOT_ROOT/homebrew/Brewfile"
  if [ "$skip_gui" -eq 0 ]; then
    brew bundle --file="$DOT_ROOT/homebrew/Brewfile.gui"
  else
    info "skipping GUI packages"
  fi

  section "Shell plugins"
  link_packages link sheldon
  sheldon lock

  section "Dotfiles"
  link_packages link

  section "Machine-local files"
  bootstrap_local_file "$DOT_ROOT/packages/git/.config/git/local.example" \
    "$HOME/.config/git/local"
  bootstrap_local_file "$DOT_ROOT/packages/zsh/.config/zsh/local.zsh.example" \
    "$HOME/.config/zsh/local.zsh"

  section "tmux plugins"
  if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm \
      "$HOME/.config/tmux/plugins/tpm"
  fi
  if [ ! -d "$HOME/.config/tmux/plugins/catppuccin/tmux" ]; then
    mkdir -p "$HOME/.config/tmux/plugins/catppuccin"
    git clone --depth 1 -b v2.3.0 https://github.com/catppuccin/tmux.git \
      "$HOME/.config/tmux/plugins/catppuccin/tmux"
  fi
  "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" || \
    warn "tmux plugin install reported a problem; run prefix+I inside tmux"

  section "Runtimes"
  mise install

  section "bat theme cache"
  bat cache --build

  section "Neovim plugins"
  nvim --headless "+Lazy! sync" +qa || warn "nvim plugin sync reported a problem"

  if [ "$skip_macos" -eq 0 ]; then
    section "macOS defaults"
    if [ "$assume_yes" -eq 1 ]; then
      bash "$DOT_ROOT/macos/defaults.sh" --yes
    else
      bash "$DOT_ROOT/macos/defaults.sh"
    fi
  else
    info "skipping macOS defaults"
  fi

  section "Doctor"
  bash "$DOT_ROOT/scripts/doctor.sh" || true

  printf '\n'
  info "bootstrap complete — open a new terminal"
}

# bootstrap_local_file <example> <destination>
# Copies the template only when the destination does not exist, so the
# install stays unattended and never overwrites real secrets.
bootstrap_local_file() {
  local example="$1" dest="$2"
  if [ -f "$dest" ]; then
    info "$dest already exists"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$example" "$dest"
  warn "created $dest from the template — fill it in"
}

cmd_update() {
  section "Homebrew"
  brew update
  brew upgrade
  brew bundle --file="$DOT_ROOT/homebrew/Brewfile"

  section "Shell plugins"
  sheldon lock --update

  section "Runtimes"
  mise upgrade

  section "tmux plugins"
  if [ -x "$HOME/.config/tmux/plugins/tpm/bin/update_plugins" ]; then
    "$HOME/.config/tmux/plugins/tpm/bin/update_plugins" all
  fi

  section "Neovim plugins"
  nvim --headless "+Lazy! sync" +qa

  section "Doctor"
  bash "$DOT_ROOT/scripts/doctor.sh" || true

  printf '\n'
  info "update complete — review and commit the lock files:"
  printf '  packages/nvim/.config/nvim/lazy-lock.json\n'
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash scripts/test-dot-cli.sh`
Expected: every line `ok`.

Run: `./bin/dot bootstrap --dry-run`
Expected: the ten numbered steps.

- [ ] **Step 5: Write `bootstrap.sh`**

```bash
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
```

- [ ] **Step 6: Verify the whole flow is idempotent**

Run: `./bin/dot bootstrap --skip-macos`
Expected: every section reports "already installed" or re-links cleanly; nothing is duplicated; `dot doctor` ends green.

- [ ] **Step 7: Run shellcheck and commit**

```bash
shellcheck bin/dot bootstrap.sh scripts/*.sh macos/defaults.sh
chmod +x bootstrap.sh
git add bin/dot bootstrap.sh scripts/test-dot-cli.sh
git commit -m "feat: add bootstrap and update commands"
```

---

### Task 16: Documentation and CI Completion

**Files:**
- Create: `README.md`
- Create: `CLAUDE.md`
- Modify: `.github/workflows/ci.yml`
- Modify: `PLAN.md` (mark the design as implemented, resolve section 12)

**Interfaces:**
- Consumes: everything.
- Produces: the repository's front door and the rules an agent follows when changing it.

- [ ] **Step 1: Write `README.md`**

```markdown
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

Afterwards, fill in `~/.config/git/local` and `~/.config/zsh/local.zsh`.
`dot doctor` tells you if you forgot.

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

## Commands

| Command | What it does |
|---------|--------------|
| `dot bootstrap` | Full install on a fresh machine |
| `dot link [pkg]` | Symlink packages into `$HOME` |
| `dot brew [--gui]` | Install Homebrew packages |
| `dot macos` | Apply macOS system defaults |
| `dot update` | Update everything, then stage the lock files |
| `dot doctor` | Check that everything is in place |

## Shortcuts

| Key | Action |
|-----|--------|
| `cmd+\`` | Toggle the Ghostty quick terminal, from anywhere |
| `cmd+shift+s` | Dump the pane to a file and paste its path |
| `cmd+shift+p` | Ghostty command palette |
| `ctrl+a` then `\|` / `-` | Split the tmux pane |
| `ctrl+r` | Atuin history search |
| `ctrl+t` | fzf file picker |

## Adding a tool

1. One line in `homebrew/Brewfile`.
2. If it has a config, create `packages/<tool>/.config/<tool>/<file>`.
3. `dot link && dot brew`.

There is no package list to update — `dot` reads `packages/*` directly.

## Layout

See [PLAN.md](PLAN.md) for the full design, the rejected alternatives, and
the traps worth knowing about.
```

- [ ] **Step 2: Write the root `CLAUDE.md`**

```markdown
# Working in this repository

Read `PLAN.md` before proposing structural changes. It records the decisions
and, more usefully, the ten alternatives that were rejected and why.

## Non-negotiables

- Everything in this repository is written in **English** — code, comments,
  documentation, commit messages.
- Every shell script targets macOS system **bash 3.2**. No associative
  arrays, no `mapfile`, no `${var^^}`.
- Every shell script starts with `set -euo pipefail` and passes `shellcheck`.
- `stow` is always called with `--no-folding`. Dropping it makes Claude Code
  write its session state into this repository. See `PLAN.md` section 9.4.
- No binaries. Fonts and applications come from Homebrew. The only committed
  theme files are plain text.
- Never commit personal data. Identity and keys live in `~/.config/git/local`
  and `~/.config/zsh/local.zsh`, both gitignored.

## Adding a tool

1. Add one line to `homebrew/Brewfile`, in the matching section, with a
   trailing comment.
2. If it has configuration, create `packages/<tool>/...` mirroring the target
   path in `$HOME`. Theme it Catppuccin Mocha.
3. Add a check to `scripts/doctor.sh`.
4. Run `dot link && dot brew && dot doctor`.

Never add the package name to a list — `dot` discovers `packages/*` itself.

## Definition of done

`dot doctor` exits 0. If it does not, the work is not finished.

## Editing configuration

Files under `~/.config` are symlinks into `packages/`. Edit the file in this
repository and run `dot link`; never edit through the symlink target path.
```

- [ ] **Step 3: Complete the CI workflow**

Replace the `shellcheck` and `stow dry run` steps in `.github/workflows/ci.yml` with:

```yaml
      - name: shellcheck
        run: shellcheck bin/dot bootstrap.sh scripts/*.sh macos/defaults.sh

      - name: Validate TOML and JSON
        run: |
          python3 - <<'PY'
          import json, pathlib, sys, tomllib
          bad = 0
          for p in pathlib.Path("packages").rglob("*.toml"):
              try:
                  tomllib.loads(p.read_text())
              except Exception as exc:
                  print(f"FAIL {p}: {exc}")
                  bad = 1
          for p in pathlib.Path("packages").rglob("*.json"):
              if p.name == "lazy-lock.json":
                  continue
              try:
                  json.loads(p.read_text())
              except Exception as exc:
                  print(f"FAIL {p}: {exc}")
                  bad = 1
          sys.exit(bad)
          PY

      - name: stow dry run
        run: |
          mkdir -p "$HOME/stow-target"
          for pkg in packages/*/; do
            name="$(basename "$pkg")"
            stow --dir=packages --target="$HOME/stow-target" \
                 --no-folding --simulate --verbose=1 "$name"
          done
```

- [ ] **Step 4: Run the whole local suite**

```bash
bash scripts/check-structure.sh
bash scripts/test-dot-cli.sh
bash scripts/test-link.sh
shellcheck bin/dot bootstrap.sh scripts/*.sh macos/defaults.sh
./bin/dot doctor
```

Expected: all green, `dot doctor` exits 0.

- [ ] **Step 5: Close out `PLAN.md` section 12**

Edit `PLAN.md`:
- Change the status line in the header to `implemented`.
- In section 12, replace each open item with the answer that was reached:
  the tmux prefix actually used, whether the bat theme was vendored, whether
  the Ghostty transparency lines survived, which starship profile key works,
  and the real repository URL in section 10 replacing `<user>` and `<repo>`.

- [ ] **Step 6: Commit**

```bash
git add README.md CLAUDE.md .github/workflows/ci.yml PLAN.md
git commit -m "docs: add README, agent rules, and complete the CI pipeline"
```

- [ ] **Step 7: Stop — do not push**

The remote `https://github.com/alperhankendi/dotfiles` exists and is empty,
but publishing is explicitly held back until the whole build is finished and
reviewed. Do not run `git push`, `gh repo create`, or anything else that
contacts the remote. Report that the build is complete and local, and let the
owner decide when to publish.

---

## Self-Review

**Spec coverage.** Every section of `PLAN.md` maps to a task: §4 topology →
Task 1; §5 the `dot` contract → Tasks 2, 4, 5, 14, 15; §6.1 Homebrew → Task 5;
§6.2 zsh → Task 6; §6.3 sheldon → Task 7; §6.4 Ghostty → Task 9; §6.5 tmux →
Task 10; §6.6 starship → Task 8; §6.7 Claude status line → Tasks 8 and 13;
§6.8 git → Task 4; §6.9 CLI configs → Task 11; §6.10 Neovim → Task 12; §6.11
the AI layer → Task 13; §6.12 macOS defaults → Task 14; §7 the add-a-tool
recipe → Task 13 (`add-tool.md`) and Task 16 (`CLAUDE.md`); §8 verification →
Task 3 and every subsequent task's doctor check, with CI completed in Task 16;
§9 the traps → encoded as the `--no-folding` flag (Task 4), the compinit
pattern (Task 6), the tag-pinned Catppuccin clone (Task 10), the font
fallback (Task 9), and the folding check in doctor (Task 13); §10 the install
flow → Task 15; §12 the open points → resolved in Tasks 8, 9, 10, 11, and 16.

**Naming consistency.** `dot_packages`, `link_packages`, `backup_conflicts`,
`bootstrap_local_file`, `cmd_bootstrap`, `cmd_update`, `check_ok`,
`check_warn`, `check_fail`, `require_command`, `have`, `info`, `warn`, `err`,
`die`, `section` — each is defined once and used with the same signature
everywhere. `DOT_ROOT` is exported by `lib.sh` and consumed by `link.sh`,
`doctor.sh`, and `bin/dot`.

**Known gaps, stated rather than hidden.** `require_command` is defined in
Task 3 but only used by later checks that call it indirectly; if no task ends
up calling it, delete it rather than leaving dead code. The `check_starship`
version comparison assumes a `major.minor.patch` string and will need
adjusting if starship ever ships a two-component version.
