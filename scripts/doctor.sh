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

check_shell_startup() {
  section "Shell startup"
  # shellcheck disable=SC2088
  if [ ! -L "$HOME/.zshenv" ]; then
    check_fail "~/.zshenv is not linked" "run: dot link zsh"
    return
  fi
  if ! have perl; then
    check_fail "cannot measure startup: perl is missing" \
      "measure by hand: time zsh -i -c exit"
    return
  fi
  local start end ms
  start="$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')"
  zsh -i -c exit >/dev/null 2>&1
  end="$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')"
  # An empty or non-numeric reading means the measurement broke, not that the
  # shell is instant. Never report success on a shell that was never measured.
  case "$start$end" in
    '' | *[!0-9]*)
      check_fail "startup measurement produced no usable reading" \
        "measure by hand: time zsh -i -c exit"
      return
      ;;
  esac
  ms=$((end - start))
  if [ "$ms" -lt 150 ]; then
    check_ok "interactive zsh starts in ${ms}ms (budget 150ms)"
  else
    check_warn "interactive zsh starts in ${ms}ms, over the 150ms budget" \
      "profile with: zsh -i -c 'zmodload zsh/zprof; zprof'"
  fi
}

check_prompt_render() {
  section "Prompt render"
  if ! have perl; then
    check_fail "cannot measure prompt render: perl is missing" \
      "measure by hand: time zsh -i -c 'for f in \$precmd_functions; do \$f; done; print -rP \"\$PROMPT\$RPROMPT\"'"
    return
  fi
  local start end ms
  start="$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')"
  zsh -i -c 'for f in $precmd_functions; do $f; done; print -rP "$PROMPT$RPROMPT"' >/dev/null 2>&1
  end="$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')"
  case "$start$end" in
    '' | *[!0-9]*)
      check_fail "prompt render measurement produced no usable reading" \
        "measure by hand: time zsh -i -c 'for f in \$precmd_functions; do \$f; done; print -rP \"\$PROMPT\$RPROMPT\"'"
      return
      ;;
  esac
  ms=$((end - start))
  # This includes shell startup, so it is always larger than the startup
  # number above; what matters is the gap between them.
  if [ "$ms" -lt 300 ]; then
    check_ok "shell startup plus one prompt render takes ${ms}ms"
  else
    check_warn "shell startup plus one prompt render takes ${ms}ms" \
      "profile the prompt with: starship timings"
  fi
}

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
  # `starship print-config` exits 0 even on invalid TOML, printing an error to
  # stderr and falling back to defaults — so the exit status proves nothing.
  # stderr is noisy on a healthy config too, so match the specific failure.
  #
  # Deliberately `grep -c`, not `grep -q`: on invalid TOML, starship keeps
  # writing to stderr after the "Unable to parse" line (a follow-up warning
  # dump). `grep -q` exits the instant it sees the match, closing its end of
  # the pipe; starship's next stderr write then fails with EPIPE, which the
  # Rust runtime surfaces as a panic (exit 101) rather than a silent SIGPIPE
  # death. Because this script runs with `set -o pipefail`, that 101 becomes
  # the pipeline's exit status instead of grep's own (successful) 0 — so
  # `if pipeline; then` reads a match as "no match" and silently reports the
  # broken config as fine.
  # `-c` reads to EOF, so starship never has its pipe closed early and the
  # race cannot occur. The failure is timing-dependent and does not reproduce
  # on every machine — the mechanism is the reason for `-c`, not a frequency.
  local hits
  hits="$(starship print-config 2>&1 >/dev/null | grep -c 'Unable to parse the config file')"
  if [ "$hits" -gt 0 ]; then
    check_fail "starship.toml does not parse" "run: starship print-config"
  else
    check_ok "starship.toml parses"
  fi
}

check_local_files() {
  section "Machine-local files"

  # The git example ships a placeholder email, so an unedited copy is
  # detectable and worth failing on.
  local gitlocal="$HOME/.config/git/local"
  if [ ! -f "$gitlocal" ]; then
    check_fail "$gitlocal is missing" \
      "copy packages/git/.config/git/local.example to it and fill it in"
  elif grep -q 'you@example.com' "$gitlocal" 2>/dev/null; then
    check_fail "$gitlocal still holds template values" "edit $gitlocal"
  elif ! grep -q '^[[:space:]]*email[[:space:]]*=' "$gitlocal" 2>/dev/null; then
    check_fail "$gitlocal has no email set" "add an email line under [user]"
  else
    check_ok "$gitlocal is filled in"
  fi

  # The zsh example is entirely commented out, so a verbatim copy is a
  # legitimate finished state. Only its presence is meaningfully checkable.
  local zshlocal="$HOME/.config/zsh/local.zsh"
  if [ -f "$zshlocal" ]; then
    check_ok "$zshlocal exists"
  else
    check_fail "$zshlocal is missing" \
      "copy packages/zsh/.config/zsh/local.zsh.example to it"
  fi
}

check_sheldon() {
  section "sheldon"
  if ! have sheldon; then
    check_fail "sheldon is missing" "run: dot brew"
    return
  fi
  local src
  if ! src="$(sheldon source 2>/dev/null | sed 's/#.*//')"; then
    check_fail "sheldon source fails" "check ~/.config/sheldon/plugins.toml"
    return
  fi
  # Exit status alone is not enough: a plugins.toml that parses but wires
  # nothing still exits 0. Match the distinctive strings the emitted script
  # must contain — bare tool names are ambiguous, since `fzf` is a substring
  # of `fzf-tab`. Entries contain spaces, so they are read as whole lines.
  local want missing=""
  while IFS= read -r want; do
    [ -n "$want" ] || continue
    case "$src" in
      *"$want"*) ;;
      *) missing="$missing, $want" ;;
    esac
  done <<'WANTS'
zsh-defer
fzf-tab
zsh-autosuggestions
zsh-syntax-highlighting
starship init
zoxide init
mise activate
fzf --zsh
atuin init
WANTS

  if [ -n "$missing" ]; then
    check_fail "sheldon source omits:${missing#,}" \
      "check the plugin list and the [plugins.tooling] block in ~/.config/sheldon/plugins.toml"
  else
    check_ok "sheldon source wires every expected tool"
  fi
}

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

  # Anka/Coder is not a Nerd Font, so this fallback is what actually renders
  # icons and status glyphs; losing it breaks glyph rendering across the
  # stack (starship, tmux, nvim), so it fails the check rather than warning.
  if "$ghostty" +list-fonts 2>/dev/null | grep -qi 'symbols nerd font'; then
    check_ok "the Nerd Font symbol fallback is installed"
  else
    check_fail "the Nerd Font symbol fallback is missing; icons and status glyphs will not render" \
      "run: brew install --cask font-symbols-only-nerd-font"
  fi

  # Losing Anka/Coder just falls back to a system monospace font — Ghostty
  # still works, it only looks wrong — so this only warns.
  if "$ghostty" +list-fonts 2>/dev/null | grep -qi 'anka'; then
    check_ok "the Anka/Coder font is installed"
  else
    check_warn "the Anka/Coder font is missing; Ghostty will fall back to a system font" \
      "run: brew install --cask font-anka-coder"
  fi
}

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

main() {
  check_homebrew
  check_symlinks
  check_bundle
  check_shell_startup
  check_prompt_render
  check_local_files
  check_sheldon
  check_starship
  check_ghostty
  check_tmux
  printf '\n'
  if [ "$DOCTOR_FAILED" -eq 0 ]; then
    info "doctor: all checks passed"
  else
    err "doctor: some checks failed — see the fix hints above"
  fi
  return "$DOCTOR_FAILED"
}

# Run the checks only when this file is executed directly. Sourcing it
# instead exposes the check helpers so tests can exercise them in isolation.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
