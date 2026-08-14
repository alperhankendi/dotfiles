#!/usr/bin/env bash
# macOS system defaults. Curated, not exhaustive: every setting here is one
# you would otherwise change by hand on a new machine. See PLAN.md 6.12.
#
# No `dot doctor` check watches these settings. Every other layer in this
# repository is owned by the repository; this one is owned by the person —
# the owner is expected to change these by hand in System Settings whenever
# they like, and a doctor check would report that deliberate choice as a
# fault.
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
  printf 'This script would change the following, all in per-user preference domains:\n\n'
  # Pair each explanatory comment with the setting it documents, so this
  # summary cannot drift from the script the way a hand-written one does.
  awk '
    /^#/            { comment = substr($0, 3); next }
    /^defaults write/ { if (comment != "") { printf "  %-46s %s\n", $3 " " $4, comment; comment = "" } }
    /^$/            { comment = "" }
  ' "$0"
  printf '\nNothing has been changed. Run without --dry-run to apply.\n'
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

# No sudo: every domain below is per-user. If a future setting needs a system
# domain, add the sudo call next to it rather than blanket-elevating the script.

# ── Keyboard ──────────────────────────────────────────────────────────
# Fastest key repeat.
defaults write NSGlobalDomain KeyRepeat -int 2
# Shortest delay before repeat starts.
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Holding a key repeats it instead of opening the accent picker.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Full keyboard access: tab moves between all controls, not just text fields.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# ── Text ──────────────────────────────────────────────────────────────
# No smart quotes; they corrupt code snippets.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
# No smart dashes; they corrupt code snippets.
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
# No automatic capitalization while typing.
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
# No automatic spelling correction while typing.
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# ── Dialogs ───────────────────────────────────────────────────────────
# Always show the expanded save panel.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
# Always show the expanded print panel.
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
# Save to disk by default rather than to iCloud.
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# ── Finder ────────────────────────────────────────────────────────────
# Show file extensions in every filename, not just some.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Show files and folders that start with a dot.
defaults write com.apple.finder AppleShowAllFiles -bool true
# Show the folder path bar at the bottom of every window.
defaults write com.apple.finder ShowPathbar -bool true
# Show the item-count status bar at the bottom of every window.
defaults write com.apple.finder ShowStatusBar -bool true
# Search the current folder by default instead of the whole Mac.
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# List view everywhere.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# No warning when changing a file extension.
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Keep folders on top when sorting by name.
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# Do not litter network volumes with .DS_Store files.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
# Do not litter USB volumes with .DS_Store files.
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Dock ──────────────────────────────────────────────────────────────
# Hide the Dock until the pointer reaches the edge of the screen.
defaults write com.apple.dock autohide -bool true
# No pause before the hidden Dock starts sliding in.
defaults write com.apple.dock autohide-delay -float 0
# Fast slide animation when the Dock shows or hides.
defaults write com.apple.dock autohide-time-modifier -float 0.15
# 48px icons.
defaults write com.apple.dock tilesize -int 48
# No "recent applications" section cluttering the Dock.
defaults write com.apple.dock show-recents -bool false
# No bouncing icons demanding attention.
defaults write com.apple.dock no-bouncing -bool true

# ── Screenshots ───────────────────────────────────────────────────────
mkdir -p "$HOME/Desktop/Screenshots"
# Save screenshots under ~/Desktop/Screenshots instead of directly on the desktop.
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
# PNG, not whatever format the last screenshot happened to use.
defaults write com.apple.screencapture type -string "png"
# No drop shadow around window screenshots.
defaults write com.apple.screencapture disable-shadow -bool true

# ── Apply ─────────────────────────────────────────────────────────────
for app in Finder Dock SystemUIServer; do
  killall "$app" >/dev/null 2>&1 || true
done

printf '\nDone. Some changes need a logout to take effect:\n'
printf '  - full keyboard access\n'
printf '  - press-and-hold behaviour\n'
