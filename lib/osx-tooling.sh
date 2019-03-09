# All these applications are independent, so if one
# fails to install, don't stop.
set +e

# Utilities

brew cask install spectacle
brew cask install postman 

brew install ag
brew install gpg
brew install tmux
brew install wget --with-libressl

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


echo
echo "Installing spruce"
brew tap starkandwayne/cf
brew install spruce 

echo
echo "Installing concourse fly"
rm -rf /usr/local/bin/fly
brew cask install fly 

echo "Installing tree"
brew install tree

echo
echo "Installing jq"
brew install jq 

echo
echo "Installing nmap"
brew install nmap 

echo
echo "Installing sshpass"
brew install https://raw.githubusercontent.com/kadwanev/bigboybrew/master/Library/Formula/sshpass.rb

echo
echo "Installing coreutils"
brew install coreutils

echo
echo "Installing Cloud Foundry Command-line Interface"
brew tap cloudfoundry/tap
brew install cf-cli 

echo
echo 'Installing yaml2json'
gem install yaml2json

echo
echo "Installing Git and associated tools"
brew install git 
brew tap git-duet/tap
brew install git-duet

echo
echo "Installing GO"
brew install go 

set -e
