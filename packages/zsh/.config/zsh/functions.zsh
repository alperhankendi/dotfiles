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

# ── Curl helpers ──────────────────────────────────────────────────────

# curlheader [header] <url> — one response header, or all of them.
curlheader() {
  if [[ -z "$2" ]]; then
    curl -k -s -D - "$1" -o /dev/null
  else
    curl -k -s -D - "$2" -o /dev/null | grep -i "$1:"
  fi
}

# curltime <url> — where the time actually goes on a request.
curltime() {
  curl -w '   time_namelookup:  %{time_namelookup}\n\
      time_connect:  %{time_connect}\n\
   time_appconnect:  %{time_appconnect}\n\
  time_pretransfer:  %{time_pretransfer}\n\
     time_redirect:  %{time_redirect}\n\
time_starttransfer:  %{time_starttransfer}\n\
--------------------------\n\
        time_total:  %{time_total}\n' -o /dev/null -s "$1"
}

# curlhammer <url> <count> — repeat a request and print each status line.
curlhammer() {
  if [[ -z "$2" ]]; then
    print -u2 "usage: curlhammer <url> <count>"
    return 1
  fi
  local i
  for i in {1..$2}; do
    curl -k -s -D - "$1" -o /dev/null | grep 'HTTP/' | sed 's|HTTP/[0-9.]* ||'
  done
}

# ── Finder ────────────────────────────────────────────────────────────
# `dot macos` turns hidden files on permanently; these toggle it per session.

showhiddenfiles() {
  defaults write com.apple.finder AppleShowAllFiles YES
  killall Finder
}

hidehiddenfiles() {
  defaults write com.apple.finder AppleShowAllFiles NO
  killall Finder
}

# ── Misc ──────────────────────────────────────────────────────────────

# gitnr <name> — new directory, git repo, first commit, and cd into it.
gitnr() {
  mkdir -p "$1" && cd "$1" || return
  git init -q
  printf '# %s\n' "$1" > README.md
  git add README.md
  git commit -qm "First commit"
}

# fixperms — 755 for directories and scripts, 644 for everything else.
fixperms() {
  find . \( -name '*.sh' -o -type d \) -exec chmod 755 {} \; \
    && find . -type f ! -name '*.sh' -exec chmod 644 {} \;
}

# tre — a tree view that skips the usual noise. Uses eza; the original
# needed `tree`, which this repository does not install.
tre() {
  eza --tree --all --icons --git-ignore \
    --ignore-glob '.git|node_modules|.DS_Store' "$@"
}

# mywatch <command...> — rerun a command every three seconds.
mywatch() {
  while :; do
    local out; out="$("$@" 2>&1)"
    clear
    printf '%s\n\n%s\n' "$(date)" "$out"
    sleep 3
  done
}

# fake-server [port] — static file server in the current directory.
fake-server() {
  npx http-server -p "${1:-8080}"
}

# fake-smtp — throwaway SMTP server with a web UI on :3000.
fake-smtp() {
  docker run --rm -p 3000:80 -p 2525:25 rnwood/smtp4dev:v3
}

# gorun — rerun `go run .` whenever a Go file changes. Needs `entr`.
gorun() {
  find . -type f -name '*.go' | entr -rc go run .
}
