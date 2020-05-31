#!/usr/bin/env bash

# include my library helpers for colorized echo and require_brew, etc
source ./lib_sh/echos.sh
source ./lib_sh/requirers.sh
source ./lib_sh/setupFunctions.sh
source ./lib_sh/os.sh
bot "Hi! I'm going to install tooling and tweak your system settings. Here I go..."

# Do we need to ask for sudo password or is it already passwordless?
needToAskSudo

# /etc/hosts -- spyware/ad blocking
wannaBlockAds

# Git Config
wannaSetupGit

# Install homebrew (CLI Packages)
setupBrew

# Skip those GUI clients, git command-line all the way
require_brew git
# update zsh to latest
#require_brew zsh

#### bu bölümü adam et. daha sonra açılacak.
#sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
#git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v2/install)"


# set zsh as the user login shell
#changeShell

# symlink files
dotfilesSetup


bot "VIM Setup"
read -r -p "Do you want to install vim plugins now? [y|N] " response
if [[ $response =~ (y|yes|Y) ]];then
  bot "Installing vim plugins"

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim


  vim +PluginInstall +qall > /dev/null 2>&1
  ok
else
  ok "skipped. Install by running :PluginInstall within vim"
fi



read -r -p "Install fonts? [y|N] " response
if [[ $response =~ (y|yes|Y) ]];then
  bot "installing fonts"
  # need fontconfig to install/build fonts
  require_brew fontconfig
  ./.local/fonts/install.sh
  ./.local/fonts/powerline/install.sh  
  ok
fi


##setup.js & install my stack
# node version manager
require_brew nvm
# nvm
require_nvm stable
# always pin versions (no surprises, consistent dev/build machines)
npm config set save-exact true
bot "installing npm tools needed to run this project..."
npm install
ok
bot "installing packages from config.js..."
node index.js
ok
running "cleanup homebrew"
brew cleanup --force > /dev/null 2>&1
rm -f -r /Library/Caches/Homebrew/* > /dev/null 2>&1
ok






#cleanup
running "cleanup homebrew"
brew cleanup --force > /dev/null 2>&1
rm -f -r /Library/Caches/Homebrew/* > /dev/null 2>&1
ok




## OS Configuration for MacOS
bot "OS Configuration"
read -r -p "Do you want to update the system configurations? [y|N] " response
if [[ -z $response || $response =~ ^(y|Y) ]]; then
    osConfiguration
fi

open /Applications/iTerm.app
bot "Woot! All done"



