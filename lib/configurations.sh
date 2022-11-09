#!/usr/bin/env bash

source $WORKSTATION_DIR/lib/common.sh

touch ~/.bash_profile
ln -fs ~/.bash_profile ~/.zshenv

echo 'Adding workstation/bin to path'
add_to_profile '# Add workstation binaries' \
               'export PATH=$PATH:~/workstation/bin'
source $WORKSTATION_DIR/bin/common.sh

echo 'Adding ~/bin to path'
add_to_profile '# Add ~/bin binaries' \
               'export PATH=~/bin:$PATH'

echo "Configuring python bin folder"
add_to_profile '# Use adds python bin folder' \
               'export PATH="~/Library/Python/3.7/bin:$PATH"'

echo 'Setting tmux config'
[ -e ~/.tmux.conf ] && rm -f ~/.tmux.conf
ln -fs $WORKSTATION_DIR/assets/tmux.conf ~/.tmux.conf


echo 'Setting LANG for UTF-8 tmux support'
add_to_profile '# Setting UTF-8 tmux support' \
               'export LANG=en_US.UTF-8'

echo "Installing VIM configs"
[ -d ~/.vim ] && rm -rf ~/.vim
ln -fs $WORKSTATION_DIR/assets/vim ~/.vim

echo "Create symlink for vimrc"
[ -e ~/.vimrc ] && rm -f ~/.vimrc
ln -fs $WORKSTATION_DIR/assets/vim/vimrc ~/.vimrc


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
ln -fs $WORKSTATION_DIR/assets/aliases.bash ~/.aliases.bash

add_to_profile '# Load custom aliases' \
               'source ~/.aliases.bash'

echo "Enable git duet"
add_to_profile '# git duet works globally' \
                'export GIT_DUET_GLOBAL=true'

echo "Configuring GPG"
add_to_profile '# configure GPG' \
               'GPG_TTY=$(tty)' \
               'export GPG_TTY'

echo 'Enabling TMUX to run by default'
if ! grep -q 'TMUX' ~/.bash_profile; then
add_to_profile '# Adding tmux to run by default on new terminal' \
               'if [ -z $TMUX ] ; then tmux new -As base ; fi'
fi

echo "Enables z shell plugin"
add_to_profile '# Enables z shell plugin' \
	". $WORKSTATION_DIR/bin/z.sh"

echo "sets vi mode for bash"
add_to_profile '# sets vi mode' \
               'set -o vi'

echo "sets vi mode for zsh"
add_to_profile '# sets vi mode for zsh' \
               'bindkey -v'



add_to_profile '# sets editor' \
               'export EDITOR=nvim'

mkdir -p ~/.config
ln -fs $WORKSTATION_DIR/assets/nvim-config/nvim ~/.config/nvim

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

echo "Adds python to path"
add_to_profile '# Adds python bin path' \
               'export PATH=$HOME/Library/Python/3.9/bin:$PATH'

echo "Adds asdf to path"
add_to_profile '# Adds asdf bin path' \
               'export PATH=$PATH:$HOME/.asdf/shims'



echo "Install oh my zsh"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
