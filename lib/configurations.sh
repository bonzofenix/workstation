#!/usr/bin/env bash

source ~/workstation/bin/common.sh

local profile_file="~/.bash_profile"


echo 'Adding workstation/bin to path'
add_to_profile '# Add workstation binaries' \
               'export PATH=$PATH:~/workstation/bin'

echo 'Adding ~/bin to path'
add_to_profile '# Add ~/bin binaries' \
               'export PATH=~/bin:$PATH'

echo "Configuring python bin folder"
add_to_profile '# Use adds python bin folder' \
               'export PATH="~/Library/Python/3.7/bin:$PATH"'

echo 'Setting tmux config'
[ -e ~/.tmux.conf ] && rm -f ~/.tmux.conf
ln -fs ~/workstation/assets/tmux.conf ~/.tmux.conf


echo 'Setting LANG for UTF-8 tmux support'
add_to_profile '# Setting UTF-8 tmux support' \
               'export LANG=en_US.UTF-8'

echo "Installing VIM configs"
[ -d ~/.vim ] && rm -rf ~/.vim
ln -fs ~/workstation/assets/vim ~/.vim

echo "Create symlink for vimrc"
[ -e ~/.vimrc ] && rm -f ~/.vimrc
ln -fs ~/workstation/assets/vim/vimrc ~/.vimrc


vim -c ":GoInstallBinaries" -c ":q" - </dev/null


echo "Configuring ~/workstation/bin in PATH"
add_to_profile '# Adds pe workstation binaries to path' \
               'export PATH=~/workstation/bin:$PATH'

echo "Allowing history to track lines beginning with whitespace"
add_to_profile '# Only ignore duplicates in history' \
               'export HISTCONTROL=ignoredups'

echo "Infinite history"
add_to_profile '# Infinite bash history' \
               'export HISTTIMEFORMAT="%d/%m/%y %T "' \
               'export HISTSIZE=' \
               'export HISTFILESIZE=' \
               'export HISTFILE=~/.bash_eternal_history' \
               'export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"'


echo "Configuring custom aliases"
[[ -L ~/.aliases.bash ]] && rm ~/.aliases.bash
ln -fs ~/workstation/assets/aliases.bash ~/.aliases.bash

add_to_profile '# Load custom aliases' \
               'source ~/.aliases.bash'

echo "Enable git duet"
add_to_profile '# git duet works globally' \
                'export GIT_DUET_GLOBAL=true'

echo "Configuring GPG"
add_to_profile '# configure GPG' \
               'GPG_TTY=$(tty)' \
               'export GPG_TTY'

echo
echo "Configuring shell prompt"
if ! grep -q 'PS1' $profile_file; then
  echo '# configure shell prompt'           >> $profile_file
  echo "PS1='\[\e[01;32m\]\u\[\e[0m\]:\[\e[01;34m\]\W\[\e[0m\]\[\e[91m\]$(parse_git_branch)\[\e[0m\]$ '" >> ~/.bash_profile
  echo
fi

echo "Configuring debug shell prompt"
if ! grep -q 'PS4' ~/.bash_profile; then
  echo "# Configuring debug shell prompt"    >> $profile_file
  export PS4='(${BASH_SOURCE}:${LINENO}) $ ' >> $profile_file
fi

echo 'Enabling TMUX to run by default'
add_to_profile '# Adding tmux to run by default on new terminal' \
               'if [ -z $TMUX ] ; then tmux new -As base ; fi'

echo "Enables z shell plugin"
add_to_profile '# Enables z shell plugin' \
               '. ~/workstation/bin/z.sh'

echo "Disables case sensitive completion"
add_to_profile '# Disables case sensitive completion' \
               'bind "set completion-ignore-case on"'

echo "sets vi mode"
add_to_profile '# sets vi mode' \
               'set -o vi'

add_to_profile '# sets editor' \
               'export EDITOR=nvim'

if `hash direnv`; then
  add_to_profile '# Load direnv' \
                 'eval "$( direnv hook bash )"'
fi

if `hash rbenv`; then
  echo "Configuring rbenv"
  add_to_profile '# Use rbenv' \
                 'export PATH=$HOME/.rbenv/bin:$PATH' \
                 'eval "$(rbenv init -)"'

fi

echo "Coonfigure nvim"
mkdir -p ~/.config/nvim/
cat <<EOT >> ~/.config/nvim/init.vim
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
EOT


ln -s .bash_profile .zprofile
