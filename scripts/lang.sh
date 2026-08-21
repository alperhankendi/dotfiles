#!/usr/bin/env bash
# lang — the language toolchain picker behind `dot lang`.
# Sourced by bin/dot, so it carries no `set` line of its own.

# Where the picker records its choices. The repository file, never the
# symlink in $HOME: CLAUDE.md forbids editing through the link. mise is what
# actually writes it — `mise config set` preserves the comments and the
# surrounding table, which a hand-rolled sed would not.
LANG_MISE_CONFIG="$DOT_ROOT/packages/mise/.config/mise/config.toml"

# The catalogue. One line per language:
#   id | backend | spec | description
#
# `mise` entries become a key under [tools] in the mise config and are
# installed by `mise install`. `brew` entries are formulae, and their spec is
# a space-separated list. macOS already ships clang with the Xcode command
# line tools, so the cpp entry is the build tooling around the compiler
# rather than a compiler.
#
# Versions are major pins, matching how node and python are already pinned:
# specific enough to reproduce a machine, loose enough that `dot update`
# picks up patch releases without a repo edit. java is pinned to 11 because
# that is what the projects on this machine build against.
lang_catalogue() {
  cat <<'EOF'
cpp|brew|cmake llvm|C/C++ build tooling (clang ships with Xcode CLT)
dotnet|mise|10|.NET SDK
go|mise|1.27|Go
java|mise|temurin-11|Java 11 (Temurin)
python|mise|3.13|Python
zig|mise|0.16|Zig
EOF
}

# lang_field <line> <n> — the nth pipe-separated field of a catalogue line.
lang_field() { printf '%s\n' "$1" | cut -d'|' -f"$2"; }

# lang_ids — every catalogue id, one per line, in catalogue order.
lang_ids() { lang_catalogue | cut -d'|' -f1; }

# lang_line <id> — the catalogue line for an id, empty when the id is
# unknown. Guarded against grep's exit 1, which would abort `dot`'s set -e.
lang_line() { lang_catalogue | grep "^$1|" 2>/dev/null || true; }

# lang_status <id> <backend> <spec> — a short human-readable install state.
# Reports what is on the machine, not what the config declares; the two
# differ exactly when someone edited the config without running an install,
# and that gap is the thing worth showing.
lang_status() {
  local id="$1" backend="$2" spec="$3" formula version

  case "$backend" in
    brew)
      # During `dot bootstrap` the menu is shown before Homebrew exists.
      # Nothing is installed on that machine yet, so this is accurate rather
      # than a fallback.
      have brew || { printf 'not installed\n'; return 0; }
      for formula in $spec; do
        if ! brew list --formula "$formula" >/dev/null 2>&1; then
          printf 'not installed\n'
          return 0
        fi
      done
      printf 'installed\n'
      ;;
    *)
      have mise || { printf 'not installed\n'; return 0; }
      version=$(mise ls --installed "$id" 2>/dev/null | awk 'NR == 1 { print $2 }')
      if [ -n "$version" ]; then
        printf 'installed (%s)\n' "$version"
      else
        printf 'not installed\n'
      fi
      ;;
  esac
}

# lang_table — the catalogue with live install state, one row per language.
lang_table() {
  local line id backend spec desc n=0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id=$(lang_field "$line" 1)
    backend=$(lang_field "$line" 2)
    spec=$(lang_field "$line" 3)
    desc=$(lang_field "$line" 4)
    n=$((n + 1))
    printf '  %2d) %-7s %-44s %s\n' \
      "$n" "$id" "$desc" "$(lang_status "$id" "$backend" "$spec")"
  done <<EOF
$(lang_catalogue)
EOF
}

# lang_brewfile_add <formula> — record a formula in the Brewfile, once.
# Appended under its own trailing section so the curated sections above keep
# their grouping and a `dot lang` choice survives a fresh install.
lang_brewfile_add() {
  local formula="$1"
  local brewfile="$DOT_ROOT/homebrew/Brewfile"
  local header='# Language toolchains — added by: dot lang'

  if grep -q "^brew \"$formula\"" "$brewfile" 2>/dev/null; then
    return 0
  fi
  grep -qF "$header" "$brewfile" 2>/dev/null || printf '\n%s\n' "$header" >>"$brewfile"
  printf 'brew "%s"\n' "$formula" >>"$brewfile"
}

# lang_install <id>... — declare the languages, then install them.
# Every id is validated before anything is written, so a typo in the third
# name cannot leave the first two half-applied.
lang_install() {
  local id line backend spec formula use_mise=0 use_brew=0

  # Never report success for an empty list. Reaching here with no arguments
  # means a caller's resolve step failed, and a silent "done" would be a
  # wrong result rather than a missing one.
  [ "$#" -gt 0 ] || die "no languages to install"

  for id in "$@"; do
    [ -n "$(lang_line "$id")" ] || die "unknown language: $id (run: dot lang --list)"
  done

  for id in "$@"; do
    line=$(lang_line "$id")
    backend=$(lang_field "$line" 2)
    spec=$(lang_field "$line" 3)

    case "$backend" in
      brew)
        for formula in $spec; do
          lang_brewfile_add "$formula"
        done
        info "recorded $id in homebrew/Brewfile ($spec)"
        use_brew=1
        ;;
      *)
        mise config set --file "$LANG_MISE_CONFIG" "tools.$id" "$spec"
        info "recorded $id = \"$spec\" in the mise config"
        use_mise=1
        ;;
    esac
  done

  if [ "$use_mise" -eq 1 ]; then
    section "Installing runtimes"
    mise install
  fi

  if [ "$use_brew" -eq 1 ]; then
    section "Installing formulae"
    have brew || die "Homebrew is missing — run: dot bootstrap"
    brew bundle --file="$DOT_ROOT/homebrew/Brewfile"
  fi
}

# lang_prompt — show the menu, read one line, echo the chosen ids.
# Split out from cmd_lang because `dot bootstrap` asks the same question at
# the very start of a run and installs the answer much later, once mise
# exists. Writes the menu to stderr so the ids stay the only thing on stdout.
lang_prompt() {
  local reply picked

  # Loops until the answer is valid or empty. A typo has to be re-asked
  # rather than dropped: lang_resolve's `die` only exits this function's
  # command substitution, so a caller that ignored the status would install
  # nothing while the person believed they had chosen something.
  while true; do
    {
      section "Languages"
      lang_table
      printf '\nSelect by number or name, space separated (empty installs none): '
    } >&2

    IFS= read -r reply </dev/tty || reply=""
    [ -n "$reply" ] || return 0

    # shellcheck disable=SC2086  # $reply is a list of tokens by design
    if picked=$(lang_resolve $reply); then
      printf '%s\n' "$picked" | sort -u
      return 0
    fi
    # lang_resolve named the offending token on stderr; ask again.
  done
}

# lang_resolve <token>... — map numbers and names alike onto catalogue ids.
# The picker prints numbers, so accepting both is the difference between a
# menu that works the way it looks and one that only accepts names.
lang_resolve() {
  local token id

  for token in "$@"; do
    case "$token" in
      '' | *[!0-9]*)
        [ -n "$(lang_line "$token")" ] || die "unknown language: $token"
        printf '%s\n' "$token"
        ;;
      *)
        id=$(lang_ids | sed -n "${token}p")
        [ -n "$id" ] || die "no language numbered $token"
        printf '%s\n' "$id"
        ;;
    esac
  done
}

# cmd_lang [--list | <language>...] — the `dot lang` entry point.
cmd_lang() {
  local reply picked

  case "${1:-}" in
    --list | -l)
      section "Languages"
      lang_table
      return 0
      ;;
    -*)
      die "unknown option for lang: $1 (expected --list)"
      ;;
  esac

  # Named on the command line: no menu, no prompt. This is the form
  # `dot bootstrap` and any script would use.
  #
  # `die` inside lang_resolve exits the command substitution's subshell, not
  # this one, so the status has to be checked here. Resolving as an argument
  # to lang_install instead would swallow the failure and install nothing
  # while reporting success.
  if [ "$#" -gt 0 ]; then
    picked=$(lang_resolve "$@") || return 1
    # shellcheck disable=SC2046  # word splitting is the point: one id per word
    lang_install $(printf '%s\n' "$picked" | sort -u)
    lang_report_done
    return 0
  fi

  # /dev/tty rather than `[ -t 0 ]`: the prompt reads the terminal directly,
  # so it still works when stdin is a pipe. Testing stdin would refuse a case
  # that in fact works.
  if ! ( : </dev/tty ) 2>/dev/null; then
    die "dot lang needs a terminal to prompt — name the languages instead, e.g. dot lang java go"
  fi

  picked=$(lang_prompt) || return 1

  if [ -z "$picked" ]; then
    info "nothing selected"
    return 0
  fi

  # shellcheck disable=SC2086  # one id per word
  lang_install $picked
  lang_report_done
}

# lang_report_done — the closing advice for an interactive `dot lang`.
# Not part of lang_install: `dot bootstrap` calls that too, and runs doctor
# itself a few steps later, so telling the owner to run doctor there would be
# advice they are already about to take.
lang_report_done() {
  printf '\n'
  info "done — the choice is recorded in the repository; commit it to keep it"
  info "run: dot doctor"
}
