# Documentation: https://github.com/romkatv/zsh4humans/blob/v2/README.md.

# Export XDG environment variables. Other environment variables are exported later.
export XDG_CACHE_HOME="$HOME/.cache"

# URL of zsh4humans repository. Used during initial installation and updates.
Z4H_URL="https://raw.githubusercontent.com/romkatv/zsh4humans/v2"

# Cache directory. Gets recreated if deleted. If already set, must not be changed.
: "${Z4H:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4humans}"

# Do not create world-writable files by default.
umask o-w

# Fetch z4h.zsh if it doesn't exist yet.
if [ ! -e "$Z4H"/z4h.zsh ]; then
  mkdir -p -- "$Z4H" || return
  >&2 printf '\033[33mz4h\033[0m: fetching \033[4mz4h.zsh\033[0m\n'
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -- "$Z4H_URL"/z4h.zsh >"$Z4H"/z4h.zsh.$$ || return
  else
    wget -O-   -- "$Z4H_URL"/z4h.zsh >"$Z4H"/z4h.zsh.$$ || return
  fi
  mv -- "$Z4H"/z4h.zsh.$$ "$Z4H"/z4h.zsh || return
fi

# Code prior to this line should not assume the current shell is Zsh.
# Afterwards we are in Zsh.
. "$Z4H"/z4h.zsh || return

# 'ask': ask to update; 'no': disable auto-update.
zstyle ':z4h:' auto-update                     ask
# Auto-update this often; has no effect if auto-update is 'no'.
zstyle ':z4h:'                auto-update-days 28
# Stability vs freshness of plugins: stable, testing or dev.
zstyle ':z4h:*'               channel          stable
# Bind alt-arrows or ctrl-arrows to change current directory?
# The other key modifier will be bound to cursor movement by words.
zstyle ':z4h:'                cd-key           alt
# Right-arrow key accepts one character ('partial-accept') from
# command autosuggestions or the whole thing ('accept')?
zstyle ':z4h:autosuggestions' forward-char     partial-accept

if (( UID && UID == EUID && ! Z4H_SSH )); then
  # When logged in as a regular user and not via `z4h ssh`, check that
  # login shell is zsh and offer to change it if it isn't.
  z4h chsh
fi

z4h install ohmyzsh/ohmyzsh || return
z4h init || return

#for vim
bindkey -v
# Export environment variables.
export EDITOR="vim"
export GPG_TTY=$TTY
export NVM_DIR=~/.nvm
# Extend PATH.
path=(~/bin $path)

# Use additional Git repositories pulled in with `z4h install`.

z4h source $Z4H/ohmyzsh/ohmyzsh/plugins/colorize/colorize.plugin.zsh
z4h source $Z4H/ohmyzsh/ohmyzsh/plugins/dirpersist/dirpersist.plugin.zsh
z4h source $Z4H/ohmyzsh/ohmyzsh/plugins/autojump/autojump.plugin.zsh

z4h source ~/.dotfiles/ssh-agent.zsh

fpath+=($Z4H/ohmyzsh/ohmyzsh/plugins/supervisor)


#############################################################
# Generic configuration that applies to all shells
#############################################################
source ~/.shellfn
source ~/.shellaliases


# Source additional local files.
if [[ $LC_TERMINAL == iTerm2 ]]; then
  # Enable iTerm2 shell integration (if installed).
  z4h source ~/.iterm2_shell_integration.zsh
fi

# Define key bindings.
bindkey '\C-Z' backward-kill-word #Ctrl+bekspace
#bindkey  "\e[1;5C": forward-word
#bindkey  "\e[1;5D": backward-word


zstyle ':completion:*'                           sort               false
# Should cursor go to the end when Up/Down/Ctrl-Up/Ctrl-Down fetches a command from history?
zstyle ':zle:(up|down)-line-or-beginning-search' leave-cursor       no
# When presented with the list of choices upon hitting Tab, accept selection and
# trigger another completion with this key binding. Great for completing file paths.
zstyle ':fzf-tab:*'                              continuous-trigger tab


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Autoload functions.
autoload -Uz zmv

# Define functions and completions.
function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
compdef _directories md



# Set shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots  # glob matches files starting with dot; `ls *` becomes equivalent to `ls *(D)`