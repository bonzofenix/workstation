# All these applications are independent, so if one
# fails to install, don't stop.
set +e

echo "Cleanup git configs"
rm ~/.gitconfig


echo "Setting global Git configurations"
git config --global core.editor $(which vim)
git config --global transfer.fsckobjects true
git config --global hub.protocol https
git config --global push.default simple


echo "Setting default branch to develop"
git config --global init.defaultBranch develop

echo "Enables colors to git output"
git config --global color.ui true
git config color.status.changed "blue normal bold"
git config color.status.header "white normal dim"
git config --global color.status.untracked "magenta"


# Force unset osxkeychain cache
git config --system --unset credential.helper

echo  "Configuring authors file"
[ -e ~/.authors ] && rm -f ~/.authors
ln -fs $WORKSTATION_DIR/../assets/git-authors ~/.git-authors

set -e
