# Global working rules

## Language
Write every file, comment, and commit message in English, regardless of the
language of the conversation.

## Shell environment
This machine runs zsh with the configuration in `~/workspace/dotfiles-next`.
Modern replacements are aliased over the classics: `ls` is eza, `cat` is bat,
`cd` is zoxide, `rm` is trash. When writing scripts, call the real binaries
(`/bin/ls`, `/bin/rm`) rather than relying on the interactive aliases.

## Long-running work
tmux is available and sessions survive a reboot. Prefer starting long jobs
inside a named tmux session over running them in the foreground.

## Dotfiles changes
Never edit files under `~/.config` directly — they are symlinks into
`~/workspace/dotfiles-next/packages/`. Edit the file in the repository and
run `dot link`.
