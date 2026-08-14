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
