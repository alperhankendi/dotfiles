# Interactive shells. Budget: under 150ms (PLAN.md section 1.7).
# Order matters here — read PLAN.md section 9.5 before rearranging.

# .zprofile handles this for login shells. Non-login interactive shells —
# `zsh -i -c`, some IDE terminals — need it too. String test, no subprocess.
if [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
  path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
fi

# 1. All fpath additions must happen before the single compinit call.
#    A hardcoded path is used on purpose: `brew --prefix` costs a subprocess.
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

# 2. compinit runs in full at most once a day and reads the cache otherwise.
autoload -Uz compinit
_zcompdump="$ZDOTDIR/.zcompdump"
_compinit_full=0
for _dump in $_zcompdump(N.mh+24); do _compinit_full=1; done
if (( _compinit_full )); then
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
# Compile the dump to bytecode in the background; saves 30-80ms next time.
if [[ ! -e "$_zcompdump.zwc" || "$_zcompdump" -nt "$_zcompdump.zwc" ]]; then
  zcompile -R -- "$_zcompdump" &!
fi
unset _zcompdump _compinit_full _dump

# 3. History. Atuin owns Ctrl+R, but the plain history file still matters.
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
setopt hist_ignore_all_dups hist_reduce_blanks share_history extended_history
setopt auto_cd interactive_comments no_beep

# 4. Plugins and tool initialisation. sheldon owns the ordering.
eval "$(sheldon source)"

# 5. Our own configuration.
for _module in exports aliases functions keybindings; do
  source "$ZDOTDIR/$_module.zsh"
done
unset _module

# 6. Machine-local overrides, sourced last so they win.
[[ -r "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
