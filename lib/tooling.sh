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
echo 'Adding workstation/bin to path'
if ! grep -q '~/workstation/bin' ~/.bash_profile; then
  echo                                          >> ~/.bash_profile
  echo '# Add workstation binaries'          	>> ~/.bash_profile
  echo 'export PATH=$PATH:~/workstation/bin' 	>> ~/.bash_profile
fi

echo
echo 'Adding ~/bin to path'
if ! grep -q '~/bin' ~/.bash_profile; then
  echo                                          >> ~/.bash_profile
  echo '# Add ~/bin binaries'                   >> ~/.bash_profile
  echo 'export PATH=$PATH:~/bin'                >> ~/.bash_profile
fi

echo
echo 'Enabling VI mode for bash'
if ! grep -q 'set -o vi' ~/.bash_profile; then
  echo                              >> ~/.bash_profile
  echo '# Enable VI mode for bash'  >> ~/.bash_profile
  echo 'set -o vi'                  >> ~/.bash_profile
fi

echo
echo 'Setting tmux config'
if [[ -fe ~/.tmux.conf ]]; then
 rm -f ~/.tmux.conf
fi
ln -fs ~/workstation/assets/tmux.conf ~/.tmux.conf

echo
echo 'Setting LANG for UTF-8 tmux support'
if ! grep -q 'LANG=' ~/.bash_profile; then
  echo 'export LANG=en_US.UTF-8' >> ~/.bash_profile
fi

echo
echo 'Enabling TMUX to run by default'
if !  grep -q "TMUX" ~/.bash_profile ; then
  echo                                                             >> ~/.bash_profile
  echo '# Adding tmux to run by default on new terminal'           >> ~/.bash_profile
  echo 'if [[ ! $TMUX ]] ; then' >> ~/.bash_profile
  echo 'tmux attach -t base || tmux new -s base'                   >> ~/.bash_profile
  echo 'fi'                                                        >> ~/.bash_profile
fi

set -e
