#!/bin/bash
[ -n "$DEBUG" ] && set -x
set -e

echo "Caching password..."
sudo -K
sudo true;

MY_DIR="$(dirname "$0")"

source ${MY_DIR}/lib/git.sh
source ${MY_DIR}/lib/git-aliases.sh
source ${MY_DIR}/lib/linux-tooling.sh
source ${MY_DIR}/lib/configurations.sh

echo
echo "Reloading Bash..."
source ~/.bash_profile

echo "DONE"
