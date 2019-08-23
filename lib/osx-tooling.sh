# All these applications are independent, so if one
# fails to install, don't stop.
set +e

# Utilities

brew cask install spectacle
brew cask install calibre
brew cask install postman

brew install ag
brew install gpg
brew install tmux
brew install wget

# Terminals

brew cask install iterm2

# Browsers

brew cask install google-chrome

# Communication

brew cask install slack
brew cask install skype

# Video player
brew cask install vlc

# Emulation tools

brew cask install virtualbox

# Data tools

brew install mysql
brew install postgresql

# Docker For Mac

brew install docker

# Ruby tools
brew install readline
brew install rbenv

# spruce
brew tap starkandwayne/cf
brew install spruce


# concourse fly
rm -rf /usr/local/bin/fly
brew cask install fly

# tree
brew install tree

# jq
brew install jq

# nmap
brew install nmap

# hub
brew install hub

# direnv
brew install direnv

# sshpass
brew install https://raw.githubusercontent.com/kadwanev/bigboybrew/master/Library/Formula/sshpass.rb

# coreutils
brew install coreutils

# Cloud Foundry Command-line Interface
brew tap cloudfoundry/tap
brew install cf-cli

# yaml2json
gem install yaml2json

# Git and associated tools
brew install git
brew tap git-duet/tap
brew install git-duet

# GO
brew install go

set -e
