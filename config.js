module.exports = {
  brewtap: [
    'blacknon/lssh',
    'derailed/k9s'
  ],
  brew: [
    'bat',              // alternative to `cat`: https://github.com/sharkdp/bat
    'coreutils',        // upgrade grep so we can get things like inverted match (-v)
    'grep --with-default-names',
    'vim --with-client-server --with-override-system-vi',
    'lsd',              //https://github.com/Peltoche/lsd
    'autojump',         //https://github.com/wting/autojump
    'sourcetree',
    'adr-tools',            //https://github.com/npryce/adr-tools
    'k9s',             //https://github.com/derailed/k9s
    'kubectx',
    'yarn',
    'kind',
    'skaffold', //https://skaffold.dev/docs/,
    'asciinema',
    'minikube',
    'lssh',
    'entr'
  ],
  cask: [
    'docker',
    'evernote',
    'iterm2',
    'visual-studio-code',
    'dropbox',
    'slack',
    'dotnet'
  ],
  gem: [
  ],
  npm: [
    'prettyjson',
    'buzzphrase',
    'vtop',
    'tldr'  //https://tldr.sh/
  ]
};
