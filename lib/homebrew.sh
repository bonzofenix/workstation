#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/common.sh

# Detect Homebrew prefix based on architecture
if [ -d "/opt/homebrew" ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi


/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew update
brew doctor
# sudo chown -R $(whoami) /usr/local/bin
brew upgrade
brew cleanup
brew bundle --file $SCRIPT_DIR/../assets/work/Brewfile

add_to_profile '# Homebrew Path' \
               'path=("'"$HOMEBREW_PREFIX"'/bin" $path)'


add_to_profile '# Adds coreutils path' \
               'path=("'"$HOMEBREW_PREFIX"'/opt/coreutils/libexec/gnubin" $path)'

