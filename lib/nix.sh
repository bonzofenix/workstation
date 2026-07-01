#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

log_section "Nix"

if [ -d "/nix" ]; then
  log_success "Nix is already installed."
else
  log_step "Installing Nix"
  curl -L https://nixos.org/nix/install | sh
fi
