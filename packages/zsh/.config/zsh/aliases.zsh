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

# ── Navigation ────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'

# ── Networking and diagnostics ────────────────────────────────────────
alias ip='dig +short myip.opendns.com @resolver1.opendns.com'
alias iplocal='ipconfig getifaddr en0'
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"
alias network.connections='lsof -l -i +L -R -V'
alias network.established='lsof -l -i +L -R -V | grep ESTABLISHED'
alias network.externalip='curl -s https://checkip.amazonaws.com'
alias network.internalip="ifconfig en0 | egrep -o '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)'"
alias dnsflush='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'

# Which files the system is touching right now. Needs sudo; read-only.
alias files.open='sudo fs_usage -e -f filesystem | grep -v CACHE_HIT | grep -v grep | grep open'
alias files.usage='sudo fs_usage -e -f filesystem | grep -v CACHE_HIT | grep -v grep'
alias files.usage.user='sudo fs_usage -e -f filesystem | grep -v CACHE_HIT | grep -v grep | grep Users'

# Port forwarding through the packet filter. Reversible: -disable restores
# /etc/pf.conf, which is the state macOS ships with.
alias port-forward-enable="echo 'rdr pass inet proto tcp from any to any port 2376 -> 127.0.0.1 port 2376' | sudo pfctl -ef -"
alias port-forward-disable='sudo pfctl -F all -f /etc/pf.conf'
alias port-forward-list='sudo pfctl -s nat'

# ── macOS ─────────────────────────────────────────────────────────────
# Lock the screen when stepping away.
alias afk='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'
alias spotoff='sudo mdutil -a -i off'
alias spoton='sudo mdutil -a -i on'
alias path='echo -e ${PATH//:/\\n}'
alias pb='tr -d "\n" | pbcopy'
alias pt='pbpaste | tee'

# DESTRUCTIVE and not undoable: empties every Trash, clears system logs and
# the quarantine history. Kept deliberately; read it before running it.
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl; sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"

# Everything the machine can update, including macOS itself. `dot update`
# covers the parts this repository manages; this one goes wider.
alias update='sudo softwareupdate -i -a; brew update && brew upgrade && brew cleanup; mise upgrade'

# ── Containers ────────────────────────────────────────────────────────
alias d='docker'
alias dps='docker ps -a'
alias dup='docker compose up -d --build --force-recreate'
alias ddown='docker compose down'

# ── Kubernetes ────────────────────────────────────────────────────────
alias k='kubectl'
alias kp='kubectl get pods -o wide'
alias kdp='kubectl describe pod'
alias kdn='kubectl describe node'
alias ksys='kubectl --namespace=kube-system'
alias ka='kubectl apply --recursive -f'
alias krm='kubectl delete'
alias kgsvc='kubectl get service'

# ── Editors and apps ──────────────────────────────────────────────────
alias code='open -a "Visual Studio Code"'
alias code.='open -a "Visual Studio Code" .'
alias goland='open -a GoLand .'
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

# ── Git ───────────────────────────────────────────────────────────────
alias gbv="git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"
alias ghc='gh repo create'
alias gpoh='git push origin HEAD'
alias gdc='git diff --cached'
