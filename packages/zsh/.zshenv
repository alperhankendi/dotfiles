# Read by every zsh invocation, including non-interactive scripts.
# Keep this file tiny — anything slow here also slows down `zsh -c`.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Everything else zsh reads lives under $ZDOTDIR, keeping $HOME clean.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Where this repository is checked out. Override in local.zsh if it moves.
export DOTFILES="$HOME/workspace/dotfiles-next"

# Deduplicate PATH entries; zsh keeps the first occurrence of each.
typeset -U path PATH

# Locally installed tools (uv, pipx) live here. Static assignment, no subprocess.
path=("$HOME/.local/bin" $path)
