#!/bin/bash

echo "Adding usr/local/bin to your PATH"
if ! grep -q "/usr/local/bin" ~/.bash_profile; then
  echo                                      >> ~/.bash_profile
  echo '# Adds usr/local/bin to path'       >> ~/.bash_profile
  echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bash_profile
fi

wget -q -O - https://raw.githubusercontent.com/starkandwayne/homebrew-cf/master/public.key | sudo apt-key add -
echo "deb http://apt.starkandwayne.com stable main" | sudo tee /etc/apt/sources.list.d/starkandwayne.list

sudo apt-get install -y apt-transport-https
sudo apt-get update

wget -q -O - https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list

# AG
sudo apt-get install -y silversearcher-ag

# Unzip
sudo apt-get install -y unzip

# vim dependencies
sudo apt-get install  vim-gui-common

# Direnv
sudo apt-get install -y direnv

# Direnv
sudo apt-get install -y awscli

# OM
sudo apt-get install -y om

# hub
sudo apt-get install -y hub

# Git-duet
GOVENDOREXPERIMENT=1 go get github.com/git-duet/git-duet/...

# Spruce
sudo apt-get install -y spruce

# Fly
sudo wget "https://github.com/concourse/concourse/releases/download/v5.3.0/fly-5.3.0-linux-amd64.tgz" && tar xzvf fly-5.3.0-linux-amd64.tgz
sudo mv fly /usr/local/bin/fly
rm -fr fly-5.3.0-linux-amd64.tgz
sudo chmod +x /usr/local/bin/fly

# Credhub
sudo wget "https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/2.5.3/credhub-linux-2.5.3.tgz" && tar xzvf credhub-linux-2.5.3.tgz
sudo mv credhub /usr/local/bin/credhub
rm -fr credhub-linux-2.5.3.tgz
sudo chmod +x /usr/local/bin/credhub

# Kubectl
sudo apt-get update
sudo apt-get install -y kubectl

# UAA cli
sudo wget "https://github.com/cloudfoundry-incubator/uaa-cli/releases/download/0.7.0/uaa-linux-amd64-0.7.0"
sudo mv uaa-linux-amd64-0.7.0 /usr/local/bin/uaa
sudo chmod +x /usr/local/bin/uaa

# Vault cli
sudo wget "https://releases.hashicorp.com/vault/1.1.1/vault_1.1.1_linux_amd64.zip"
sudo unzip vault_1.1.1_linux_amd64.zip && rm vault_1.1.1_linux_amd64.zip
sudo mv vault /usr/local/bin/vault
sudo chmod +x /usr/local/bin/vault
