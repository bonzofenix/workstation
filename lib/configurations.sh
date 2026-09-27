#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

# Detect Homebrew prefix based on architecture
if [ -d "/opt/homebrew" ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

log_section "Configurations"

touch ~/.bash_profile
ln -fs ~/.bash_profile ~/.zshenv

log_step "Configuring PATH"
add_to_profile '# Add workstation binaries' \
               'path+=("$HOME/workstation/bin")'

add_to_profile '# Add ~/bin binaries' \
               'path=("$HOME/bin" $path)'

add_to_profile '# Add gnubin for coreutil tooling to path' \
               'path=("'"$HOMEBREW_PREFIX"'/opt/coreutils/libexec/gnubin" $path)'

add_to_profile '# Adds local bin to path' \
               'path=("$HOME/.local/bin" $path)'

add_to_profile '# Points to openssl instead of libressl' \
               'path=("'"$HOMEBREW_PREFIX"'/opt/openssl@3/bin" $path)'

log_step "Configuring environment variables"
add_to_profile '# Sets git duet' \
               'export GIT_DUET_SET_GIT_USER_CONFIG=1'

add_to_profile '# set homebrew no env hints' \
               'export HOMEBREW_NO_ENV_HINTS=1'

add_to_profile '# set homebrew no install cleanup' \
               'export HOMEBREW_NO_INSTALL_CLEANUP=1'

add_to_profile '# set homebrew no auto update' \
               'export HOMEBREW_NO_AUTO_UPDATE=1'



log_step "Configuring tmux"
[ ! -d ~/.tmux/plugins/tpm ] && run_with_spin "Cloning tmux plugin manager..." git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
[ -e ~/.tmux.conf ] && rm -f ~/.tmux.conf
ln -fs "$WORKSTATION_DIR/assets/tmux.conf" ~/.tmux.conf
install_tmux_plugins

# Start tmux in interactive terminals. Two guards:
# - $- == *i*: ~/.zprofile is read by every zsh login shell, non-interactive
#   ones included (zsh -lc). Where ~/.zprofile is also linked to
#   ~/.bash_profile (this script only links ~/.zshenv; older setups added the
#   other by hand), every zsh reads it through ~/.zshenv, and so does make's
#   `source ~/.bash_profile`.
# - TMUX_AUTOSTARTED: in that linked layout zsh sources the file twice (as
#   ~/.zshenv, then ~/.zprofile); without it, detaching re-attached at once.
#
# Older installs wrote unguarded forms (`if [ -z $TMUX ] ; then tmux new -As
# base ; fi`, `[ -z $TMUX ] && <prefix>/bin/tmux new -As base`) that #4 stopped
# adding but left in place. Drop them and their header so they cannot attach
# ahead of the guarded line.
legacy_tmux_re='^(if )?\[ -z \$TMUX \].*tmux new -As base|^# Adding tmux to run by default on new terminal$'
if grep -qsE -- "$legacy_tmux_re" ~/.zprofile; then
  profile_without_legacy="$(grep -vE -- "$legacy_tmux_re" ~/.zprofile)"
  # grep -v exits 1 when nothing is left and 2 on a read error; never rewrite
  # the profile from a failed read.
  if [ $? -le 1 ]; then
    # Rewrite in place rather than mv, so a symlinked ~/.zprofile stays a link.
    printf '%s\n' "$profile_without_legacy" > ~/.zprofile
    log_success "Removed legacy tmux autostart from ~/.zprofile"
  else
    log_error "Could not read ~/.zprofile; remove its unguarded tmux autostart line by hand"
  fi
fi
add_to_profile '# Start tmux in interactive terminals' \
               '[[ -z $TMUX && -z $TMUX_AUTOSTARTED && $- == *i* ]] && TMUX_AUTOSTARTED=1 && '"$HOMEBREW_PREFIX"'/bin/tmux new -As base'

log_step "Configuring history"
add_to_profile '# Only ignore duplicates in history' \
               'export HISTCONTROL=ignoredups'
add_to_profile '# Infinite bash history' \
               'export HISTTIMEFORMAT="%d/%m/%y %T "' \
               'export HISTSIZE=' \
               'export HISTFILESIZE=' \
               'export HISTFILE=~/.bash_eternal_history' \
               'export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"'
add_to_profile '# Enable bash completion' \
               'export BASH_DEFAULT_TIMEOUT_MS=900000' \
               'export BASH_MAX_TIMEOUT_MS=900000'

log_step "Configuring shell aliases and hooks"
[[ -L ~/.aliases.bash ]] && rm ~/.aliases.bash
ln -fs "$WORKSTATION_DIR/assets/aliases.bash" ~/.aliases.bash
add_to_profile '# Load custom aliases' \
               'source ~/.aliases.bash'
add_to_profile '# git duet works globally' \
                'export GIT_DUET_GLOBAL=true'
add_to_profile '# Enable Claude Code notifications' \
               'export CLAUDE_NOTIFY=1'
add_to_profile '# configure GPG' \
               'GPG_TTY=$(tty)' \
               'export GPG_TTY'
add_to_profile '# sets editor' \
               'export EDITOR=nvim'
add_to_profile '# enables CGO' \
               'export CGO_ENABLED=1'
add_to_profile '# sets devbox' \
               'eval "$(devbox global shellenv)"'

if hash direnv 2>/dev/null; then
  add_to_profile '# Load direnv' \
                 'eval "$( direnv hook bash )"'
fi

log_step "Configuring Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  run_with_spin "Installing Oh My Zsh..." RUNZSH=CHSH= sh -c "$(curl -fsSL https://install.ohmyz.sh/)"
  log_success "Oh My Zsh installed"
else
  log_success "Oh My Zsh already installed"
fi

log_step "Configuring zsh"
add_to_rc '# Enables z shell plugin' \
  ". $WORKSTATION_DIR/bin/z.sh"
add_to_profile '# sets vi mode' \
               'set -o vi'
add_to_rc '# sets vi mode for zsh' \
               'bindkey -v'
add_to_rc '# sets vi mode for zsh' \
          'bindkey "^R" history-incremental-search-backward'
add_to_rc '# Adds fuck alias' \
          'eval $(thefuck --alias)'
add_to_rc '# Adds direnv hook' \
          'eval "$(direnv hook zsh)"'
add_to_rc '# Disable zsh beeps' \
          'unsetopt BEEP'

log_step "Configuring Neovim"
[ -d ~/.config/nvim ] && rm -rf ~/.config/nvim
ln -fs "$WORKSTATION_DIR/assets/config/nvim" ~/.config/nvim
[ ! -d ~/.local/share/nvim/lazy/lazy.nvim ] && run_with_spin "Cloning lazy.nvim..." git clone https://github.com/folke/lazy.nvim ~/.local/share/nvim/lazy/lazy.nvim
[ ! -d ~/.config/nvim/pack/github/start/copilot.vim ] && run_with_spin "Cloning copilot.vim..." git clone https://github.com/github/copilot.vim.git ~/.config/nvim/pack/github/start/copilot.vim

log_step "Configuring Ghostty"
[ -d ~/.config/ghostty ] && rm -rf ~/.config/ghostty
ln -fs "$WORKSTATION_DIR/assets/config/ghostty" ~/.config/ghostty
add_to_profile '# TERM for ghostty/tmux compatibility' \
               'export TERM=xterm-256color'
add_to_profile '# Setting UTF-8 tmux support' \
               'export LANG=en_US.UTF-8'

log_step "Linking iCloud folder"
ln -fs "$HOME/Library/Mobile Documents/com~apple~CloudDocs/" "$HOME/icloud"

log_step "Installing Claude settings"
mkdir -p ~/.claude
# Symlink so the repo is the single source of truth for Claude Code settings
# (statusLine, hooks, permissions). Previously only the statusline script was
# linked, so ~/.claude/settings.json never picked up the statusLine block and
# the status line silently never appeared.
ln -fs "$WORKSTATION_DIR/assets/claude/settings.json" ~/.claude/settings.json

log_step "Installing Claude statusline script"
ln -fs "$WORKSTATION_DIR/assets/claude/statusline-command.sh" ~/.claude/statusline-command.sh

log_step "Installing Claude hooks"
mkdir -p ~/.claude/hooks
# Symlink each hook directory so settings.json references under
# ~/.claude/hooks/ resolve on a fresh machine (e.g. worktree-guard).
for hook_dir in "$WORKSTATION_DIR"/assets/claude/hooks/*/; do
  [ -d "$hook_dir" ] || continue
  ln -fns "${hook_dir%/}" ~/.claude/hooks/"$(basename "$hook_dir")"
done

# Claude skills and plugins are installed by lib/claude-configs.sh (via
# bin/skills-bundle), which both `make install` and `make install-linux` run.

