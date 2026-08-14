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
