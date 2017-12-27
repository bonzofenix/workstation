echo
echo "Installing Go"

if [ ! -d ~/go ]; then
  mkdir ~/go
  pushd ~/go
    mkdir src bin pkg
  popd
fi

echo
echo "Configuring Go PATH"
if ! grep -q "GOPATH" ~/.bash_profile; then
  echo                                  >> ~/.bash_profile
  echo '# GOPATH Configuration'         >> ~/.bash_profile
  echo 'export GOPATH=~/go'             >> ~/.bash_profile
  echo 'export PATH=$PATH:$GOPATH/bin'  >> ~/.bash_profile
fi

brew install go 
