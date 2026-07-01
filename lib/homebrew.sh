#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

log_section "Homebrew"

# Detect Homebrew prefix based on architecture
if [ -d "/opt/homebrew" ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi


if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew update
brew doctor
# sudo chown -R $(whoami) /usr/local/bin
brew upgrade
brew cleanup
brew trust git-duet/tap oven-sh/bun josephpage/jetpack-io hashicorp/tap yakitrak/yakitrak steipete/tap 2>/dev/null || true
brew bundle --file $SCRIPT_DIR/../assets/work/Brewfile

add_to_profile '# Homebrew Path' \
               'path=("'"$HOMEBREW_PREFIX"'/bin" $path)'


add_to_profile '# Adds coreutils path' \
               'path=("'"$HOMEBREW_PREFIX"'/opt/coreutils/libexec/gnubin" $path)'

