#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source ${WORKSTATION_DIR}/lib/homebrew.sh

echo "Caching password..."
sudo -K
sudo true;

SETUP_TYPE=$1


echo "Setting up a $SETUP_TYPE machine..."

configure_homebrew
source ${WORKSTATION_DIR}/lib/asdf.sh
source ${WORKSTATION_DIR}/lib/git.sh
source ${WORKSTATION_DIR}/lib/git-aliases.sh
source ${WORKSTATION_DIR}/lib/configurations.sh
source ${WORKSTATION_DIR}/lib/osx-configurations.sh


echo "Reloading Bash..."
source ~/.bash_profile
