#!/usr/bin/env bash

# Linux counterpart to configurations.sh.
#
# Same idea — link the repo's assets into $HOME and extend the shell profile —
# minus the Homebrew prefix handling, which has no meaning here.

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

log_section "Configurations (Linux)"

SUDO_CMD=""
[ "$(id -u)" -ne 0 ] && SUDO_CMD="sudo"

touch ~/.zshrc ~/.zprofile

# Everything below writes zsh array syntax (path+=(...)), which bash cannot
# parse. Ubuntu defaults to bash, so without this the profile is never read
# and none of the PATH entries or aliases take effect.
log_step "Ensuring zsh is the login shell"
if [ "$(basename "${SHELL:-}")" != "zsh" ] && command -v zsh >/dev/null 2>&1; then
  if $SUDO_CMD chsh -s "$(command -v zsh)" "$(id -un)" 2>/dev/null; then
    log_success "Login shell set to zsh (takes effect on next login)"
  else
    log_warning "Could not change login shell; run: chsh -s $(command -v zsh)"
  fi
else
  log_success "zsh already the login shell"
fi

log_step "Configuring PATH"
add_to_profile '# Add workstation binaries' \
               'path+=("$HOME/workstation/bin")'

add_to_profile '# Add ~/bin binaries' \
               'path=("$HOME/bin" $path)'

add_to_profile '# Adds local bin to path' \
               'path=("$HOME/.local/bin" $path)'

add_to_profile '# Add Go toolchain' \
               'path+=("/usr/local/go/bin")'

log_step "Configuring environment variables"
add_to_profile '# Sets git duet' \
               'export GIT_DUET_SET_GIT_USER_CONFIG=1'

log_step "Configuring tmux"
[ ! -d ~/.tmux/plugins/tpm ] && run_with_spin "Cloning tmux plugin manager..." \
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Back up a real config rather than clobbering it; only replace our own symlink.
if [ -e ~/.tmux.conf ] && [ ! -L ~/.tmux.conf ]; then
  mv ~/.tmux.conf "$HOME/.tmux.conf.bak-$(date +%Y%m%d-%H%M%S)"
fi
ln -fs "$WORKSTATION_DIR/assets/tmux.conf" ~/.tmux.conf

log_step "Configuring Oh My Zsh"
# Provides the prompt and completion. RUNZSH= stops the installer dropping
# into an interactive shell; CHSH= stops it changing the login shell, which
# the step above already handled.
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  run_with_spin "Installing Oh My Zsh..." env RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://install.ohmyz.sh/)"
  log_success "Oh My Zsh installed"
else
  log_success "Oh My Zsh already installed"
fi

log_step "Configuring zsh"
# Match the plugin set used on macOS. The installer writes plugins=(git), so
# this rewrites that line in place rather than appending a second assignment
# that would be shadowed by the first.
if [ -f ~/.zshrc ] && grep -q '^plugins=(git)$' ~/.zshrc; then
  sed -i 's/^plugins=(git)$/plugins=(git vi-mode)/' ~/.zshrc
  log_success "Enabled zsh plugins: git vi-mode"
fi
add_to_rc '# Enables z shell plugin' \
  ". $WORKSTATION_DIR/bin/z.sh"
add_to_rc '# sets vi mode for zsh' \
          'bindkey -v'
add_to_rc '# sets vi mode for zsh' \
          'bindkey "^R" history-incremental-search-backward'
add_to_rc '# Disable zsh beeps' \
          'unsetopt BEEP'
if command -v direnv >/dev/null 2>&1; then
  add_to_rc '# Adds direnv hook' \
            'eval "$(direnv hook zsh)"'
fi

log_step "Configuring shell aliases"
add_to_rc '# Workstation aliases' \
          "source $WORKSTATION_DIR/assets/aliases.bash"

log_step "Configuring Neovim"
# Back up a real config directory rather than removing it; only replace a
# symlink this script owns.
if [ -e ~/.config/nvim ] && [ ! -L ~/.config/nvim ]; then
  mv ~/.config/nvim "$HOME/.config/nvim.bak-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p ~/.config
ln -fsn "$WORKSTATION_DIR/assets/config/nvim" ~/.config/nvim
[ ! -d ~/.local/share/nvim/lazy/lazy.nvim ] && run_with_spin "Cloning lazy.nvim..." \
  git clone https://github.com/folke/lazy.nvim ~/.local/share/nvim/lazy/lazy.nvim

add_to_profile '# TERM for tmux compatibility' \
               'export TERM=xterm-256color'

log_step "Configuring git ignore"
ln -fs "$WORKSTATION_DIR/assets/gitignore_global" ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global

log_success "Linux configuration complete"
