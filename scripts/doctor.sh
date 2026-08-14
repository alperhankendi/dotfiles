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
  if ! src="$(sheldon source 2>/dev/null)"; then
    check_fail "sheldon source fails" "check ~/.config/sheldon/plugins.toml"
    return
  fi
  # Exit status alone is not enough: a plugins.toml that parses but wires
  # nothing still exits 0. Confirm the emitted script really initialises the
  # tools the shell layer depends on.
  local want missing=""
  for want in zsh-defer fzf-tab zsh-autosuggestions zsh-syntax-highlighting \
              starship zoxide mise fzf atuin; do
    case "$src" in
      *"$want"*) ;;
      *) missing="$missing $want" ;;
    esac
  done
  if [ -n "$missing" ]; then
    check_fail "sheldon source omits:$missing" \
      "check the plugin list and the [plugins.tooling] block in ~/.config/sheldon/plugins.toml"
  else
    check_ok "sheldon source wires every expected tool"
  fi
}

main() {
  check_homebrew
  check_symlinks
  check_bundle
  check_shell_startup
  check_local_files
  check_sheldon
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
