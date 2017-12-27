#!/bin/bash
[ -n "$DEBUG" ] && set -x
set -e

echo "Caching password..."
sudo -K
sudo true;

SETUP_TYPE=$1
MY_DIR="$(dirname "$0")"

echo
echo "Setting up a $SETUP_TYPE machine..."

source ${MY_DIR}/lib/xcode-license.sh
source ${MY_DIR}/lib/homebrew.sh
source ${MY_DIR}/lib/configuration-osx.sh
source ${MY_DIR}/lib/git.sh
source ${MY_DIR}/lib/git-aliases.sh
source ${MY_DIR}/lib/ruby.sh
source ${MY_DIR}/lib/go.sh
source ${MY_DIR}/lib/node.sh
source ${MY_DIR}/lib/tooling.sh
source ${MY_DIR}/lib/configurations.sh

echo
echo "Reloading Bash..."
source ~/.bash_profile
