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

log_step "Configuring herdr"
mkdir -p ~/.config/herdr
# Back up rather than rm: unlike ~/.tmux.conf this path may hold a real
# config that was never symlinked, and losing it silently would be rude.
if [ -e ~/.config/herdr/config.toml ] && [ ! -L ~/.config/herdr/config.toml ]; then
  mv ~/.config/herdr/config.toml ~/.config/herdr/config.toml.bak-$(date +%Y%m%d-%H%M%S)
fi
ln -fs "$WORKSTATION_DIR/assets/herdr/config.toml" ~/.config/herdr/config.toml

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

log_step "Installing Claude skills"
mkdir -p ~/.claude/skills
# Symlink each skill directory so the repo is the single source of truth.
# Previously these were copied by hand, which let ~/.claude/skills/ drift
# behind the repo — a skill could be updated here and the stale copy would
# keep running. Relinking on every run also repairs links left dangling by
# moving a skill's source directory.
#
# nullglob: bash 3.2 (macOS) leaves an unmatched glob as the literal pattern,
# which is how a directory named `*` ended up in ~/.claude/skills/.
shopt -s nullglob

# Resolve `..` out of WORKSTATION_DIR ("$SCRIPT_DIR/.."): the prune loop below
# compares it against symlink targets, which are stored fully resolved.
WORKSTATION_REAL="$(cd "$WORKSTATION_DIR" && pwd -P)"

for skill_dir in "$WORKSTATION_REAL"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  target=~/.claude/skills/"$skill_name"
  # Back up a real directory rather than clobbering it: it may hold a
  # hand-written skill that was never in the repo. The backup goes OUTSIDE
  # ~/.claude/skills/ — anything left inside is discovered and loaded as a
  # live skill, so a "yolo.bak-..." would show up as a second, stale yolo.
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mkdir -p ~/.claude/skills-backup
    backup=~/.claude/skills-backup/"$skill_name-$(date +%Y%m%d-%H%M%S)"
    # Timestamps are second-granularity and do collide. Never mv onto an
    # existing directory: mv would move the source *inside* it, silently
    # burying the earlier backup instead of replacing it.
    suffix=1
    while [ -e "$backup" ]; do
      backup="$backup.$suffix"
      suffix=$((suffix + 1))
    done
    mv "$target" "$backup"
  fi
  ln -fns "${skill_dir%/}" "$target"
done

# Drop symlinks whose source is gone, e.g. a skill deleted or renamed in the
# repo. Left in place they are invisible: the skill silently fails to load.
# Only reclaim links pointing into this repo — ~/.claude/skills/ also holds
# plugin and marketplace directories, and a dangling link elsewhere may be a
# deliberate pointer to an external volume or an unmounted share.
for link in ~/.claude/skills/*; do
  [ -L "$link" ] || continue
  [ -e "$link" ] && continue
  # Compare the link target's parent resolved, against WORKSTATION_REAL which
  # is also resolved: a raw readlink can differ purely by symlinked ancestor
  # (on macOS /tmp is itself a link to /private/tmp) and would never match.
  link_target="$(readlink "$link")"
  link_parent="$(cd "$(dirname "$link_target")" 2>/dev/null && pwd -P)"
  case "$link_parent" in
    "$WORKSTATION_REAL"/skills)
      echo "  removing dangling skill link: $(basename "$link")"
      rm "$link"
      ;;
  esac
done

shopt -u nullglob

log_step "Installing Claude Code plugins"
if command -v claude &> /dev/null; then
  claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
  claude plugin marketplace add affaan-m/everything-claude-code 2>/dev/null || true
  claude plugin marketplace add JuliusBrussee/caveman 2>/dev/null || true
  claude plugin marketplace add forrestchang/andrej-karpathy-skills 2>/dev/null || true
  claude plugin marketplace add anthropics/skills 2>/dev/null || true
  claude plugin marketplace add kepano/obsidian-skills 2>/dev/null || true
  claude plugin install gopls-lsp@claude-plugins-official 2>/dev/null || true
  claude plugin install ralph-loop@claude-plugins-official 2>/dev/null || true
  claude plugin install code-simplifier@claude-plugins-official 2>/dev/null || true
  claude plugin install atlassian@claude-plugins-official 2>/dev/null || true
  claude plugin install caveman@caveman 2>/dev/null || true
  claude plugin install andrej-karpathy-skills@karpathy-skills 2>/dev/null || true
  claude plugin install skill-creator@claude-plugins-official 2>/dev/null || true
  claude plugin install obsidian@obsidian-skills 2>/dev/null || true
else
  log_warning "Claude Code CLI not found, skipping plugin installation"
fi

