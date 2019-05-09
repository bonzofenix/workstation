#!/bin/bash

echo "Adding usr/local/bin to your PATH"
if ! grep -q "/usr/local/bin" ~/.bash_profile; then
  echo                                      >> ~/.bash_profile
  echo '# Adds usr/local/bin to path'       >> ~/.bash_profile
  echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bash_profile
fi


# AG
sudo apt-get install -y silversearcher-ag

# Direnv
sudo apt-get install -y direnv

# Git-duet
GOVENDOREXPERIMENT=1 go get github.com/git-duet/git-duet/...

# Spruce
sudo wget -O /usr/local/bin/spruce "https://github.com/geofffranks/spruce/releases/download/v1.18.0/spruce-linux-amd64"
sudo chmod +x /usr/local/bin/spruce

# Fly
sudo wget "https://github.com/concourse/concourse/releases/download/v5.0.0/fly-5.0.0-linux-amd64.tgz" && tar xzvf fly-5.0.0-linux-amd64.tgz
sudo mv fly /usr/local/bin/fly
rm -fr fly-5.0.0-linux-amd64.tgz
sudo chmod +x /usr/local/bin/fly
