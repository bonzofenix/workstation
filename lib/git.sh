# All these applications are independent, so if one
# fails to install, don't stop.
set +e

echo
echo "Cleanup git configs"
rm ~/.gitconfig


echo
echo "Setting global Git configurations"
git config --global core.editor /usr/bin/vim
git config --global transfer.fsckobjects true
git config --global hub.protocol https
git config --global push.default simple


echo
echo "Enables colors to git output"
git config --global color.ui true
git config color.status.changed "blue normal bold"
git config color.status.header "white normal dim"
git config --global color.status.untracked "magenta"


# Force unset osxkeychain cache
git config --system --unset credential.helper

echo
echo  "Configuring authors file"
rm ~/.authors
ln -fs ~/workstation/assets/git-authors ~/.git-authors

set -e
