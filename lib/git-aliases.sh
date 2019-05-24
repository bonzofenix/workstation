echo
echo "Setting up Git aliases..."
git config --global alias.gst git status
git config --global alias.st status
git config --global alias.di diff
git config --global alias.co checkout
git config --global alias.ci duet-commit
git config --global alias.br branch
git config --global alias.sta stash
git config --global alias.llog "log --date=local"
git config --global alias.flog "log --pretty=fuller --decorate"
git config --global alias.lg "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"
git config --global alias.lol "log --graph --decorate --oneline"
git config --global alias.lola "log --graph --decorate --oneline --all"
git config --global alias.blog "log origin/master... --left-right"
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
git config --global alias.up 'pull --rebase --autostash'
git config --global alias.logout 'credential-cache exit'
git config --global diff.patience true
git config --global color.ui true
git config --global ui.color auto
git config --global alias.up 'pull --rebase --autostash'
git config --global hub.protocol https

