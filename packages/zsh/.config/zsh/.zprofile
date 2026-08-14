# Login shells only. PATH and one-time environment setup belong here so
# interactive shells never pay for them twice.

eval "$(/opt/homebrew/bin/brew shellenv)"

# The dot command, available everywhere.
[[ -d "$DOTFILES/bin" ]] && path=("$DOTFILES/bin" $path)
