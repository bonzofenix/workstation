#!/usr/bin/env bash

echo "Caching password..."
sudo -K
sudo true;

SETUP_TYPE=$1
MY_DIR="$(dirname "$0")"

echo "Setting up a $SETUP_TYPE machine..."

source ${MY_DIR}/lib/homebrew.sh
source ${MY_DIR}/lib/git.sh
source ${MY_DIR}/lib/git-aliases.sh
source ${MY_DIR}/lib/go.sh
source ${MY_DIR}/lib/configurations.sh
source ${MY_DIR}/lib/osx-configurations.sh


echo "Reloading Bash..."
source ~/.bash_profile
