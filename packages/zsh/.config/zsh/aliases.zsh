# Modern replacements. See PLAN.md section 6.9 for the migration table.

alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first --git'
alias la='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'

alias cat='bat'
alias du='dust'
alias df='duf'
alias ps='procs'
alias top='btop'
alias help='tldr'

alias v='nvim'
alias vim='nvim'
alias y='yazi'
alias lg='lazygit'

alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph -20'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# rm goes to the trash instead of vanishing. Use /bin/rm to bypass.
alias rm='trash'

# Reload the shell without opening a new window.
alias reload='exec zsh'
