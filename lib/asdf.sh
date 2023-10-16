export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source $SCRIPT_DIR/common.sh

echo 'Adding ASDF env vars to path'
add_to_profile '# Adding ASDF env vars to path' \
               'export ASDFROOT=$HOME/.asdf' \
               'export ASDFINSTALLS=$HOME/.asdf/installs'
