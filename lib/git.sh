# All these applications are independent, so if one
# fails to install, don't stop.
set +e

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."

echo "Cleanup git configs"
rm -rf ~/.gitconfig


echo "Setting global Git configurations"
git config --global core.editor "$(which nvim)"
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


echo "Setting up global gitignore"
[ -e ~/.gitignore_global ] && rm -f ~/.gitignore_global 
git config --global core.excludesFile ~/.gitignore_global
ln -fs "$WORKSTATION_DIR/assets/gitignore_global" ~/.gitignore_global

# Force unset osxkeychain cache
git config --system --unset credential.helper

echo  "Configuring authors file"
if [ ! -e ~/.git-authors ]; then
  echo "Creating ~/.git-authors from template"
  cp "$WORKSTATION_DIR/assets/git-authors" ~/.git-authors
  echo "Please edit ~/.git-authors with your own author information"
else
  echo "~/.git-authors already exists, skipping template copy"
fi

echo
echo "Setting up Git aliases..."
git config --global alias.gst git status
git config --global alias.st status
git config --global alias.di diff --color-words
git config --global alias.co checkout
git config --global alias.ci 'duet-commit --signoff'
git config --global alias.cp 'cherry-pick'
git config --global alias.br "branch --sort=-committerdate"
git config --global alias.sta stash
git config --global alias.llog "log --date=local"
git config --global alias.flog "log --pretty=fuller --decorate"
git config --global alias.lg "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"
git config --global alias.us "submodule update --init --force --recursive"
git config --global alias.lol "log --graph --decorate --oneline"
git config --global alias.lola "log --graph --decorate --oneline --all"
git config --global alias.blog "log origin/master... --left-right"
git config --global alias.amend 'commit --amend --no-edit'
git config --global alias.ds diff --staged
git config --global alias.dsc "diff --stat --name-status --cached"
git config --global alias.fixup commit --fixup
git config --global alias.squash commit --squash
git config --global alias.unstage reset HEAD
git config --global alias.rum "rebase master@{u}"
git config --global credential.helper "cache --timeout=36000"
git config --global alias.up "pull --rebase --autostash"
git config --global alias.drv = duet-revert
git config --global alias.dmg duet-merge
git config --global alias.drh "rebase -i --exec 'git duet-commit --amend --reset-author'"
git config --global alias.discard '!git restore -p && git clean -i'
git config --global alias.logout 'credential-cache exit'
git config --global diff.patience true
git config --global color.ui true
git config --global ui.color auto
git config --global hub.protocol https
git config --global alias.head 'rev-parse --short HEAD'

set -e
