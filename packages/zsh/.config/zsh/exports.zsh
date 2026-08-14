# Environment variables. No secrets here — those belong in local.zsh.

export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R"

# bat as the man pager, with the escape sequences stripped.
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"
export BAT_THEME="Catppuccin Mocha"

# fzf, themed to match Catppuccin Mocha.
export FZF_DEFAULT_OPTS="\
--height 40% --layout=reverse --border \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--color=border:#6c7086,label:#cdd6f4"

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :200 {}'"

# Homebrew: never run an implicit update on every install.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1
