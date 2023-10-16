#!/usr/bin/env bash

echo "Caching password..."
sudo -K
sudo true;

MY_DIR="$(dirname "$0")"



source ${MY_DIR}/lib/homebrew.sh
source ${MY_DIR}/lib/asdf.sh
source ${MY_DIR}/lib/git.sh
source ${MY_DIR}/lib/git-aliases.sh
source ${MY_DIR}/lib/configurations.sh
source ${MY_DIR}/lib/osx-configurations.sh


echo "Reloading Bash..."
source ~/.bash_profile
