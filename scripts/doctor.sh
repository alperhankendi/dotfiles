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
  if [ ! -L "$HOME/.zshenv" ]; then
    # shellcheck disable=SC2088 # literal message text, not a path to expand
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

main() {
  check_homebrew
  check_symlinks
  check_bundle
  check_shell_startup
  check_local_files
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
