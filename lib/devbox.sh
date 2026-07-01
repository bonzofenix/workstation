#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

log_section "Devbox"

log_step "Installing global packages"
devbox global add fly@8.1.1

log_step "Updating devbox"
LAUNCHER_PATH=devbox devbox version update
