#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/common.sh


/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew update || :
brew doctor || :
sudo chown -R $(whoami) /usr/local/bin
brew upgrade
brew cleanup
brew tap "cloudfoundry/cp-core" "https://github.tools.sap/cloudfoundry/homebrew-cp-core.git"
brew bundle --file  $SCRIPT_DIR/../assets/work/Brewfile

add_to_profile '# Homebrew Path' \
               'path=("opt/homebrew/bin" $path)'


add_to_profile '# Adds coreutils path' \
               'path=("$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin" $path)'

