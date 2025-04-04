#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/common.sh

if [ -d "/nix" ]; then
    echo "Nix is already installed."
else
    echo "Nix is not installed. Proceeding with installation."
    curl -L https://nixos.org/nix/install | sh
fi
