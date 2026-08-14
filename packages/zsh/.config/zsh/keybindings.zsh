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
