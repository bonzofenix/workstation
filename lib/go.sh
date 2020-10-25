source ~/workstation/bin/common.sh

echo
echo "Installing Go"

if [ ! -d ~/go ]; then
  mkdir ~/go
  pushd ~/go
    mkdir src bin pkg
  popd
fi

echo "Configuring Go PATH"
add_to_profile '# Use rbenv' \
               '# GOPATH Configuration' \
               'export GOPATH=~/go' \
               'export PATH=$PATH:$GOPATH/bin'

