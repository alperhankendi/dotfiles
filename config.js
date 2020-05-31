module.exports = {
  brew: [
    // alternative to `cat`: https://github.com/sharkdp/bat
    'bat',
    // Install GNU core utilities (those that come with macOS are outdated)
    // Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
    'coreutils',
    // upgrade grep so we can get things like inverted match (-v)
    'grep --with-default-names',
    'vim --with-client-server --with-override-system-vi',

    //https://github.com/Peltoche/lsd
    'lsd',
    //https://github.com/wting/autojump
    'autojump',
    'sourcetree',
    //https://github.com/npryce/adr-tools
    'adr-tools',
    //https://github.com/derailed/k9s
    'derailed/k9s/k9s',
    'kubectx',
    'yarn',
    'k9s',
    'kind',
    'skaffold', //https://skaffold.dev/docs/,
    'asciinema'
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
    'tldr',  //https://tldr.sh/
  ]
};
