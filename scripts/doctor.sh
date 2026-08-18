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

check_binaries() {
  section "PATH"
  # The ten binaries PLAN.md section 8 promises a PATH check for.
  local bin
  for bin in eza bat fzf zoxide atuin starship sheldon tmux mise nvim; do
    require_command "$bin" "run: dot brew"
  done
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

  # stow prunes a link when its source file disappears, but not when a whole
  # source subdirectory does — a broken link survives and the loop above,
  # which only walks the package, cannot see it. Ask the opposite question.
  local orphans
  # The leading "(" on each pattern below is required, not stylistic: bash
  # 3.2 (macOS's shipped /bin/bash) miscounts an unparenthesized case
  # pattern's closing ")" as the closing ")" of the surrounding $(...), and
  # fails to parse this loop at all without it.
  orphans="$(find "$HOME/.config" "$HOME/.claude" -type l ! -exec test -e {} \; -print 2>/dev/null \
    | while IFS= read -r l; do
        case "$(readlink "$l")" in
          (*"$DOT_ROOT"*) printf '%s\n' "$l" ;;
        esac
      done)"
  if [ -n "$orphans" ]; then
    check_fail "broken symlinks into this repo: $(printf '%s' "$orphans" | tr '\n' ' ')" \
      "delete them, or restore the file they pointed at"
  else
    check_ok "no orphaned symlinks pointing into the repo"
  fi
}

check_bundle() {
  section "Homebrew bundle"
  if ! have brew; then
    check_fail "cannot check the bundle without Homebrew" "run: dot bootstrap"
    return
  fi

  local output
  if output="$(brew bundle check --file="$DOT_ROOT/homebrew/Brewfile" --verbose 2>&1)"; then
    check_ok "every formula in homebrew/Brewfile is installed"
    return
  fi

  # brew bundle check --verbose uses the same wording for a formula that is
  # entirely absent and one that is installed but merely outdated:
  #   → Formula NAME needs to be installed or updated.
  # Cross-reference each name against what is actually installed — only the
  # absent ones are fixed by `dot brew`; the rest need `dot update`.
  local names installed name missing outdated
  names="$(printf '%s\n' "$output" | sed -n 's/^→ Formula \(.*\) needs to be installed or updated\.$/\1/p')"
  installed="$(brew list --formula --quiet)"
  missing=""
  outdated=""
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    if printf '%s\n' "$installed" | grep -qxF -- "$name"; then
      outdated="${outdated:+$outdated }$name"
    else
      missing="${missing:+$missing }$name"
    fi
  done <<<"$names"

  if [ -n "$missing" ] && [ -n "$outdated" ]; then
    check_fail "some formulae are missing: $missing; some formulae are outdated: $outdated" \
      "run: dot brew, then dot update"
  elif [ -n "$missing" ]; then
    check_fail "some formulae are missing: $missing" "run: dot brew"
  elif [ -n "$outdated" ]; then
    check_warn "some formulae are outdated: $outdated" "run: dot update"
  else
    # brew bundle check failed but no line matched the formula-shaped
    # message above (e.g. a tap problem) — don't fail silently.
    check_fail "brew bundle check failed for homebrew/Brewfile" \
      "run: brew bundle check --file=homebrew/Brewfile --verbose"
  fi
}

# median_of_three <a> <b> <c> — prints the middle value. No external sort
# needed; this only ever has to handle exactly three numbers.
median_of_three() {
  local a="$1" b="$2" c="$3"
  if { [ "$a" -ge "$b" ] && [ "$a" -le "$c" ]; } || { [ "$a" -le "$b" ] && [ "$a" -ge "$c" ]; }; then
    printf '%s\n' "$a"
  elif { [ "$b" -ge "$a" ] && [ "$b" -le "$c" ]; } || { [ "$b" -le "$a" ] && [ "$b" -ge "$c" ]; }; then
    printf '%s\n' "$b"
  else
    printf '%s\n' "$c"
  fi
}

# now_ms — current time in milliseconds, via perl (portable, no bashism).
now_ms() { perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000'; }

# check_shell_startup — one function, two related measurements, so they run
# back to back under comparable conditions instead of racing the page cache
# as two independent `zsh -i -c` invocations. A single cold sample is noisy
# (the very first invocation absorbs exec/page-cache costs the rest do not),
# so a warm-up run is discarded, then three timed samples are taken and their
# median reported against the 150ms budget. One further startup-plus-prompt
# sample is taken in the same run and reported against its own 300ms budget.
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

  # Warm-up: discarded, just to get the shell binary and its dotfiles into
  # the page cache before any sample that counts.
  zsh -i -c exit >/dev/null 2>&1

  local i start end ms s1 s2 s3
  for i in 1 2 3; do
    start="$(now_ms)"
    zsh -i -c exit >/dev/null 2>&1
    end="$(now_ms)"
    # An empty or non-numeric reading means the measurement broke, not that
    # the shell is instant. Never report success on a shell never measured.
    case "$start$end" in
      '' | *[!0-9]*)
        check_fail "startup measurement produced no usable reading" \
          "measure by hand: time zsh -i -c exit"
        return
        ;;
    esac
    ms=$((end - start))
    case "$i" in
      1) s1="$ms" ;;
      2) s2="$ms" ;;
      3) s3="$ms" ;;
    esac
  done

  local median
  median="$(median_of_three "$s1" "$s2" "$s3")"
  if [ "$median" -lt 150 ]; then
    check_ok "interactive zsh starts in ${median}ms (median of 3: ${s1}/${s2}/${s3}ms, budget 150ms)"
  else
    check_warn "interactive zsh starts in ${median}ms (median of 3: ${s1}/${s2}/${s3}ms), over the 150ms budget" \
      "profile with: zsh -i -c 'zmodload zsh/zprof; zprof'"
  fi

  # This repeats a full shell startup and then renders the prompt once, so on
  # average it costs more than the startup figure above — but it is a single
  # separate zsh invocation racing the same page cache the warm-up above was
  # meant to settle, so a single pair of samples is not guaranteed to be
  # ordered that way. The median above is the number to trust for the
  # startup budget; this one is its own, independent budget.
  start="$(now_ms)"
  zsh -i -c 'for f in $precmd_functions; do $f; done; print -rP "$PROMPT$RPROMPT"' >/dev/null 2>&1
  end="$(now_ms)"
  case "$start$end" in
    '' | *[!0-9]*)
      check_fail "prompt render measurement produced no usable reading" \
        "measure by hand: time zsh -i -c 'for f in \$precmd_functions; do \$f; done; print -rP \"\$PROMPT\$RPROMPT\"'"
      return
      ;;
  esac
  ms=$((end - start))
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
  if [ -x "$HOME/.config/tmux/plugins/tpm/tpm" ]; then
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
  # `tmux -f conf start-server \; kill-server` exits 0 even for a config full
  # of errors, so it proves nothing. Sourcing into a throwaway server on its
  # own socket does surface them, and `-L` keeps it from touching a real
  # session.
  local sock="dot-doctor-$$" conf_out conf_rc
  conf_out="$(
    tmux -L "$sock" -f /dev/null new-session -d -s probe >/dev/null 2>&1
    tmux -L "$sock" source-file "$HOME/.config/tmux/tmux.conf" 2>&1
  )"
  conf_rc=$?
  tmux -L "$sock" kill-server >/dev/null 2>&1
  # kill-server stops the server but leaves the socket file behind, and doctor
  # would otherwise litter one per run. tmux puts sockets under
  # ${TMUX_TMPDIR:-/tmp}/tmux-<uid>/.
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock"
  if [ "$conf_rc" -eq 0 ]; then
    check_ok "tmux.conf loads without errors"
  else
    check_fail "tmux.conf has errors: $conf_out" \
      "reproduce with: tmux -L probe -f /dev/null new-session -d \\; source-file ~/.config/tmux/tmux.conf"
  fi
}

check_cli_tools() {
  section "CLI tools"

  if have bat; then
    if bat --list-themes 2>/dev/null | grep -q 'Catppuccin Mocha'; then
      check_ok "the bat Catppuccin Mocha theme is built"
    else
      # bat has shipped Catppuccin Mocha built in since 0.25 — if it is
      # missing, the cause is an old bat, not an unbuilt cache. `bat cache
      # --build` does not add themes that don't ship with the binary.
      check_fail "the bat Catppuccin Mocha theme is missing" \
        "run: brew upgrade bat (Catppuccin Mocha ships built in since 0.25)"
    fi
  else
    check_fail "bat is missing" "run: dot brew"
  fi

  # A file on disk proves nothing: delta falls back to unstyled diff silently
  # if git never resolves the include. Ask git what it actually sees.
  if [ "$(git config --get delta.catppuccin-mocha.syntax-theme 2>/dev/null)" != "" ]; then
    check_ok "git resolves the delta Catppuccin include"
  else
    check_fail "git does not resolve the delta theme include" \
      "run: dot link delta git   (then: git config --get delta.catppuccin-mocha.syntax-theme)"
  fi

  # Atuin must never sync. This is a privacy guarantee, not a preference.
  # This verifies the committed file DECLARES sync off — the privacy guarantee,
  # and the part we control. It deliberately does not claim to prove atuin can
  # parse the file; no cheap config-validation subcommand exists, and a check
  # that overstated itself would be worse than one with a stated limit.
  if [ -f "$HOME/.config/atuin/config.toml" ]; then
    if grep -qE '^[[:space:]]*auto_sync[[:space:]]*=[[:space:]]*false' "$HOME/.config/atuin/config.toml"; then
      check_ok "Atuin sync is disabled"
    else
      check_fail "Atuin sync is not explicitly disabled" \
        "set auto_sync = false in ~/.config/atuin/config.toml"
    fi
  else
    check_fail "the Atuin config is missing" "run: dot link atuin"
  fi

  if have mise; then
    if mise cfg >/dev/null 2>&1; then
      check_ok "mise reads its configuration"
    else
      check_fail "mise cannot read its configuration" "run: mise cfg"
    fi
  else
    check_fail "mise is missing" "run: dot brew"
  fi
}

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
  # `nvim --headless +qa` exits 0 even when init.lua raises — the exit status
  # is useless here. Lua errors do reach stderr, so key on that instead. Not
  # every stderr line is a failure though: harmless deprecation notices and
  # treesitter compile messages also land there, so only match lines that
  # look like an actual Neovim error. Case-insensitive, since a plugin or LSP
  # subprocess writing a lowercase "error:" is still a real failure — but not
  # bare `-i`, which would also flag a harmless line that merely contains the
  # word "errors" (e.g. a checkhealth summary).
  local nvim_err
  nvim_err="$(nvim --headless "+qa" 2>&1 >/dev/null \
    | grep -iE '^E[0-9]+:|^error|[[:space:]]error:|Error in' | head -1)"
  if [ -z "$nvim_err" ]; then
    check_ok "nvim starts without errors"
  else
    check_fail "nvim reports startup errors: $(printf '%s' "$nvim_err" | head -1)" \
      "run: nvim --headless +qa"
  fi
  local lock="$DOT_ROOT/packages/nvim/.config/nvim/lazy-lock.json"
  local pins=0
  [ -f "$lock" ] && pins="$(grep -c '"commit"' "$lock")"
  if [ "$pins" -gt 0 ]; then
    check_ok "lazy-lock.json pins $pins plugin(s)"
  else
    check_warn "lazy-lock.json pins nothing" \
      "run nvim once, then commit packages/nvim/.config/nvim/lazy-lock.json"
  fi
}

check_claude() {
  section "Claude Code"

  # The folding trap: if ~/.claude is itself a symlink, Claude Code writes
  # its session state into this repository. See PLAN.md section 9.4.
  # shellcheck disable=SC2088
  if [ -L "$HOME/.claude" ]; then
    check_fail "~/.claude is a symlink, not a directory" \
      "run: rm ~/.claude && dot link claude   (dot link uses --no-folding)"
  elif [ -d "$HOME/.claude" ]; then
    check_ok "~/.claude is a real directory"
  else
    check_fail "~/.claude does not exist" "run: dot link claude"
  fi

  # shellcheck disable=SC2088
  if [ -L "$HOME/.claude/settings.json" ]; then
    # This proves settings.json asks for the starship status line. Whether Claude
    # Code actually executes it is not observable from a shell script, so the
    # check deliberately claims no more than the file's content.
    if grep -q 'starship statusline claude-code' "$HOME/.claude/settings.json"; then
      check_ok "the Claude status line is wired to starship"
    else
      check_fail "settings.json does not reference the starship status line" \
        "check packages/claude/.claude/settings.json"
    fi
  else
    check_fail "~/.claude/settings.json is not linked" "run: dot link claude"
  fi

  # This is the guard against a folding accident silently committing session
  # state. It must cover every path the spec lists as never-versioned, not a
  # sample of them.
  local leaked
  leaked="$(find "$DOT_ROOT/packages/claude/.claude" \
    \( -name 'sessions' -o -name 'projects' -o -name 'cache' \
       -o -name 'shell-snapshots' -o -name 'plugins' -o -name 'telemetry' \
       -o -name 'ide' -o -name 'backups' -o -name 'history.jsonl' \
       -o -name 'settings.local.json' \) \
    -print -quit 2>/dev/null)"
  if [ -n "$leaked" ]; then
    check_fail "Claude runtime state leaked into the repo: $leaked" \
      "delete it and confirm dot link uses --no-folding"
  else
    check_ok "no Claude runtime state in the repo"
  fi
}

check_containers() {
  section "Containers"
  if ! have colima || ! have docker; then
    check_fail "colima or docker is missing" "run: dot brew"
    return
  fi

  # `docker compose` is a plugin Homebrew installs outside docker's default
  # search path, so it only works once ~/.docker/config.json registers the
  # directory. Without that registration `docker compose` reports
  # "unknown command" — verified. That file also holds registry credentials
  # after `docker login`, which is why it is seeded from a template into
  # $HOME rather than symlinked into this repository.
  if docker compose version >/dev/null 2>&1; then
    check_ok "the docker compose plugin is registered"
  else
    check_fail "docker compose is not registered" \
      "copy packages/docker/.docker/config.json.example to ~/.docker/config.json"
  fi

  # A stopped VM is a normal resting state, not a broken environment — you
  # start it when you need containers. Failing here would make doctor red on
  # every ordinary day and teach the owner to ignore it.
  if colima status >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      check_ok "colima is running and the docker daemon answers"
    else
      check_fail "colima is running but the docker daemon does not answer" \
        "run: colima delete && colima start"
    fi
  else
    check_warn "colima is not running; docker commands will fail until it is" \
      "run: colima start"
  fi
}

main() {
  check_homebrew
  check_symlinks
  check_bundle
  check_binaries
  check_shell_startup
  check_local_files
  check_sheldon
  check_starship
  check_ghostty
  check_tmux
  check_cli_tools
  check_neovim
  check_claude
  check_containers
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
