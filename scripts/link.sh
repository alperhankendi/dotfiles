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
