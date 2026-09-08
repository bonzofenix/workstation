#!/usr/bin/env bash

# Installs the Linux equivalents of the Brewfile package set.
#
# This is the apt-based counterpart to homebrew.sh. It deliberately covers a
# smaller surface: the Brewfile carries desktop-only tooling (duti,
# pam-reattach, reattach-to-user-namespace) that has no meaning on a headless
# server, and heavier optional installs (devbox, vault, ffmpeg) that a small
# VPS should not pay for by default.

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

log_section "Linux packages"

if ! command -v apt-get >/dev/null 2>&1; then
  log_error "linux-packages.sh expects a Debian/Ubuntu host (no apt-get found)"
  exit 1
fi

# Everything below runs unattended; without this, packages that ship a config
# prompt (or a service restart question) will hang the install.
export DEBIAN_FRONTEND=noninteractive

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

run_with_spin "Updating apt index..." $SUDO apt-get update -qq

# Package names that differ from their Homebrew formula:
#   ag        -> silversearcher-ag
#   gnupg     -> gnupg (same, but pulls a different default set)
#   uv        -> not packaged; installed separately below
#   gum       -> not in the Ubuntu archive; installed from Charm's repo below
#   herdr     -> macOS-only tap, skipped
#   bun/node  -> node from the archive; bun installed separately if wanted
APT_PACKAGES=(
  zsh
  tmux
  git
  curl
  wget
  jq
  tree
  htop
  rsync
  ripgrep
  silversearcher-ag
  shellcheck
  neovim
  direnv
  sqlite3
  gnupg
  openssl
  nmap
  procps                  # provides watch
  libimage-exiftool-perl  # provides exiftool
  coreutils
  ca-certificates
  build-essential
)

log_step "Installing apt packages"
# apt-get is all-or-nothing: one bad name installs none of the rest, so a
# failure here must stop the run rather than let later steps build on a host
# that is missing its toolchain.
# shellcheck disable=SC2086  # SUDO is intentionally word-split when empty
if ! $SUDO apt-get install -y -qq "${APT_PACKAGES[@]}"; then
  log_error "apt package installation failed"
  exit 1
fi

# gh is not in the Ubuntu archive; GitHub publishes its own apt repo.
if ! command -v gh >/dev/null 2>&1; then
  log_step "Installing GitHub CLI"
  $SUDO mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq gh
fi

# gum drives the pretty logging in common.sh. Without it the scripts still
# work (they fall back to plain echo), so a failure here is not fatal.
if ! command -v gum >/dev/null 2>&1; then
  log_step "Installing gum (Charm)"
  $SUDO mkdir -p -m 755 /etc/apt/keyrings
  if curl -fsSL https://repo.charm.sh/apt/gpg.key \
       | $SUDO gpg --dearmor -o /etc/apt/keyrings/charm.gpg 2>/dev/null; then
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
      | $SUDO tee /etc/apt/sources.list.d/charm.list >/dev/null
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq gum || log_warning "gum install failed; logging falls back to plain output"
  else
    log_warning "Could not fetch Charm signing key; skipping gum"
  fi
fi

# uv is the Python toolchain the workstation relies on; it ships its own
# installer rather than a distro package.
if ! command -v uv >/dev/null 2>&1; then
  log_step "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Node from NodeSource rather than the Ubuntu archive, which ships a version
# too old for the Claude Code CLI.
if ! command -v node >/dev/null 2>&1; then
  log_step "Installing Node.js"
  curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO -E bash -
  $SUDO apt-get install -y -qq nodejs
  log_success "Node.js installed"
fi

# Claude Code runs on the server itself, so a phone SSH session gets the same
# agent as a laptop. npm's global prefix is moved under ~/.npm-global first:
# installing to /usr/lib/node_modules would need sudo for every later
# update, and running npm as root is how permissions get wrecked.
if ! command -v claude >/dev/null 2>&1; then
  log_step "Installing Claude Code"
  NPM_PREFIX="$HOME/.npm-global"
  mkdir -p "$NPM_PREFIX"
  npm config set prefix "$NPM_PREFIX"
  # The PATH entry for this lives in linux-configurations.sh, which runs
  # after this script and is what creates ~/.zprofile.
  if npm install -g @anthropic-ai/claude-code; then
    log_success "Claude Code installed"
  else
    log_warning "Claude Code install failed; run 'npm install -g @anthropic-ai/claude-code' manually"
  fi
else
  log_success "Claude Code already installed"
fi

log_success "Linux packages installed"
