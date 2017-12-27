echo
echo "Installing Bash-It"

echo
echo "Installing VIM configs"
if [[ -de ~/.vim ]]; then
  rm -rf ~/.vim
fi

if [[ -L ~/.vimrc ]]; then
  rm ~/.vimrc
fi
cp ~/workstation/assets/vim/vimrc ~/.vimrc
cp -R ~/workstation/assets/vim ~/.vim
vim -c ":GoInstallBinaries" -c ":q" - </dev/null

echo
echo "Configuring iTerm"
cp assets/com.googlecode.iterm2.plist ~/Library/Preferences

echo
echo "Configuring rbenv"
if ! grep -q 'rbenv init -' ~/.bash_profile; then
  echo                                        >> ~/.bash_profile
  echo '# Use rbenv'                          >> ~/.bash_profile
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
  echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
fi

echo
echo "Configuring ~/pe-workstation/bin in PATH"
if ! grep -q '~/pe-workstation/bin' ~/.bash_profile; then
  echo                                            >> ~/.bash_profile
  echo '# Adds pe workstation binaries to path'   >> ~/.bash_profile
  echo 'export PATH="~/pe-workstation/bin:$PATH"' >> ~/.bash_profile
fi

echo
echo "Allowing history to track lines beginning with whitespace"
if ! grep -q '^HISTCONTROL=ignoredups$' ~/.bash_profile; then
  echo                                       >> ~/.bash_profile
  echo '# Only ignore duplicates in history' >> ~/.bash_profile
  echo '# (disables ignorespace)'            >> ~/.bash_profile
  echo 'export HISTCONTROL=ignoredups'       >> ~/.bash_profile
fi

echo
echo "Configuring custom aliases"
if [[ -L ~/.aliases.bash ]]; then
  rm ~/.aliases.bash
fi
ln -fs ~/workstation/assets/aliases.bash ~/.aliases.bash

if ! grep -q 'source ~/.aliases.bash' ~/.bash_profile; then
  echo                                 >> ~/.bash_profile
  echo '# Load custom aliases'         >> ~/.bash_profile
  echo 'source ~/.aliases.bash'        >> ~/.bash_profile
fi

if ! grep -q 'GIT_DUET_GLOBAL' ~/.bash_profile; then
  echo                               >> ~/.bash_profile
  echo '# git duet works globally'   >> ~/.bash_profile
  echo 'export GIT_DUET_GLOBAL=true' >> ~/.bash_profile
fi

echo
echo "Configuring GPG"
if ! grep -q 'source ~/.custom_aliases.bash' ~/.bash_profile; then
  echo                                 >> ~/.bash_profile
  echo '# configure GPG '              >> ~/.bash_profile
  echo 'GPG_TTY=$(tty)'                >> ~/.bash_profile
  echo 'export GPG_TTY'                >> ~/.bash_profile
fi

echo
echo "Configuring shell prompt"
if ! grep -q 'PS1' ~/.bash_profile; then
  echo                                 >> ~/.bash_profile
  echo '# configure shell prompt'      >> ~/.bash_profile
  echo "PS1='\$ '"                     >> ~/.bash_profile
fi
