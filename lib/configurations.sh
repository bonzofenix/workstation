#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

touch ~/.bash_profile
ln -fs ~/.bash_profile ~/.zshenv

echo 'Adding workstation/bin to path'
add_to_profile '# Add workstation binaries' \
               'path+=("$HOME/workstation/bin")'

echo 'Adding ~/bin to path'
add_to_profile '# Add ~/bin binaries' \
               'path=("$HOME/bin" $path)'


echo 'Adding coreutil path'
add_to_profile '# Add gnubin for coreutil tooling to path' \
               'path=("/usr/local/opt/coreutils/libexec/gnubin" $path)'

echo "Adds asdf to path"
add_to_profile '# Adds asdf bin path' \
               'path=("$HOME/.asdf/shims" $path)'

echo "Configures asdf golang mod version"
add_to_profile '# Sets asdf golang' \
               'export ASDF_GOLANG_MOD_VERSION_ENABLED=true'

echo "Configures git duet to set git user config"
add_to_profile '# Sets git duet' \
               'export GIT_DUET_SET_GIT_USER_CONFIG=1'

echo "Configure homebrew to not show env hints"
add_to_profile '# set homebrew no env hints' \
               'export HOMEBREW_NO_ENV_HINTS=1'

echo "Configure homebrew to not install cleanup"
add_to_profile '# set homebrew no install cleanup' \
               'export HOMEBREW_NO_INSTALL_CLEANUP=1'

echo "Configure homebrew to not auto update"
add_to_profile '# set homebrew no auto update' \
               'export HOMEBREW_NO_AUTO_UPDATE=1'

echo "adds local bin to path"
add_to_profile '# Adds local bin to path' \
               'path=("$HOME/.local/bin" $path)'

echo "Points to openssl instead of libressl"
add_to_profile '# Points to openssl instead of libressl' \
               'path=("opt/homebrew/opt/openssl@1.1/bin" $path)'

echo 'Adding ASDF env vars to path'
add_to_profile '# Adding ASDF env vars to path' \
               'export ASDFROOT=$HOME/.asdf' \
               'export ASDFINSTALLS=$HOME/.asdf/installs'


[ ! -d ~/.tmux/plugins/tpm ] && git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
echo 'Setting tmux config'
[ -e ~/.tmux.conf ] && rm -f ~/.tmux.conf
ln -fs "$WORKSTATION_DIR/assets/tmux.conf" ~/.tmux.conf




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


add_to_profile '# Enable bash completion' \
               'export BASH_DEFAULT_TIMEOUT_MS=900000' \
               'export BASH_MAX_TIMEOUT_MS=900000' 

echo "Configuring custom aliases"
[[ -L ~/.aliases.bash ]] && rm ~/.aliases.bash
ln -fs "$WORKSTATION_DIR/assets/aliases.bash" ~/.aliases.bash

add_to_profile '# Load custom aliases' \
               'source ~/.aliases.bash'

echo "Enable git duet"
add_to_profile '# git duet works globally' \
                'export GIT_DUET_GLOBAL=true'

echo "Enable Claude Code notifications"
add_to_profile '# Enable Claude Code notifications' \
               'export CLAUDE_NOTIFY=1'

echo "Configuring GPG"
add_to_profile '# configure GPG' \
               'GPG_TTY=$(tty)' \
               'export GPG_TTY'

echo 'Enabling TMUX to run by default'
if ! grep -q 'TMUX' ~/.bash_profile; then
add_to_profile '# Adding tmux to run by default on new terminal' \
               '[ -z $TMUX ] && /opt/homebrew/bin/tmux new -As base'
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

echo "Adds fuck alias"
add_to_rc '# Adds fuck alias' \
          'eval $(thefuck --alias)'

echo "Adds direnv hook"
add_to_rc '# Adds direnv hook' \
          'eval "$(direnv hook zsh)"'

add_to_profile '# sets editor' \
               'export EDITOR=nvim'

add_to_profile '# sets editor' \
               'export CGO_ENABLED=1'

if `hash direnv`; then
  add_to_profile '# Load direnv' \
                 'eval "$( direnv hook bash )"'
fi

add_to_profile '# sets devbox' \
               'eval "$(devbox global shellenv)"'

echo "Installing NeoVim configs"
[ -d ~/.config/nvim ] && rm -rf ~/.config/nvim
ln -fs "$WORKSTATION_DIR/assets/config/nvim" ~/.config/nvim

[ ! -d ~/.local/share/nvim/lazy/lazy.nvim ] && git clone https://github.com/folke/lazy.nvim ~/.local/share/nvim/lazy/lazy.nvim
[ ! -d ~/.config/nvim/pack/github/start/copilot.vim ] && git clone https://github.com/github/copilot.vim.git ~/.config/nvim/pack/github/start/copilot.vim

echo 'Setting LANG for UTF-8 tmux support'
add_to_profile '# Setting UTF-8 tmux support' \
               'export LANG=en_US.UTF-8'

vim -c ":GoInstallBinaries" -c ":q" - </dev/null


echo "create symlink to icloud folder"
ln -fs ~/Library/Mobile\ Documents/com~apple~CloudDocs/ ~/icloud

