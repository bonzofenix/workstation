# All these applications are independent, so if one
# fails to install, don't stop.
set +e

echo
echo "Cleanup git configs"
rm ~/.gitconfig

echo
echo "Installing Git and associated tools"
brew install git 
brew tap git-duet/tap
brew install git-duet

echo
echo "Setting global Git configurations"
git config --global core.editor /usr/bin/vim
git config --global transfer.fsckobjects true
git config --global hub.protocol https
git config --global push.default simple

# Force unset osxkeychain cache
git config --system --unset credential.helper

echo
echo  "Configuring authors file"
rm ~/.authors
ln -fs ~/workstation/assets/git-authors ~/.git-authors

set -e
