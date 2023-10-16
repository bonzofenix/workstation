#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source $SCRIPT_DIR/common.sh

touch ~/.bash_profile
ln -fs ~/.bash_profile ~/.zshenv

echo 'Adding workstation/bin to path'
add_to_profile '# Add workstation binaries' \
               "path+=('~/workstation/bin')"

echo 'Adding ~/bin to path'
add_to_profile '# Add ~/bin binaries' \
               'path=("~/bin" $path)'

echo "Adds asdf to path"
add_to_profile '# Adds asdf bin path' \
               "path+=('~/.asdf/shims')"

echo "Points to openssl instead of libressl"
add_to_profile '# Points to openssl instead of libressl' \
               'path=("opt/homebrew/opt/openssl@1.1/bin" $path)'


echo 'Setting tmux config'
[ -e ~/.tmux.conf ] && rm -f ~/.tmux.conf
ln -fs $WORKSTATION_DIR/assets/tmux.conf ~/.tmux.conf



echo "Installing VIM configs"
[ -d ~/.vim ] && rm -rf ~/.vim
ln -fs $WORKSTATION_DIR/assets/vim ~/.vim

echo "Create symlink for vimrc"
[ -e ~/.vimrc ] && rm -f ~/.vimrc
ln -fs $WORKSTATION_DIR/assets/vim/vimrc ~/.vimrc


echo 'Setting LANG for UTF-8 tmux support'
add_to_profile '# Setting UTF-8 tmux support' \
               'export LANG=en_US.UTF-8'

vim -c ":GoInstallBinaries" -c ":q" - </dev/null



echo "Allowing history to track lines beginning with whitespace"
add_to_profile '# Only ignore duplicates in history' \
               'export HISTCONTROL=ignoredups'

echo "Infinite history"
add_to_profile '# Infinite bash history' \
               'export HISTTIMEFORMAT="%d/%m/%y %T "' \
               'export HISTSIZE=' \
               'export HISTFILESIZE=' \
	       m
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

say "Configuring GPG"
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
add_to_rc '# sets vi mode for zsh' \
               'bindkey -v'

echo "sets search to ctr+r"
add_to_rc '# sets vi mode for zsh' \
               'bindkey "^R" history-incremental-search-backward'




add_to_profile '# sets editor' \
               'export EDITOR=nvim'

if `hash direnv`; then
  add_to_profile '# Load direnv' \
                 'eval "$( direnv hook bash )"'
fi

mkdir -p ~/.config
ln -fs $WORKSTATION_DIR/assets/nvim-config/nvim ~/.config/nvim

echo "Install oh my zsh"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
