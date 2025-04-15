#### Compozed Custom Aliases #####

# misc #
alias authors="vim ~/.git-authors"

alias default-interface="route get default | grep interface"

alias tree="tree -I 'node_modules|site|Godeps|vendor'"

alias ag="ag -U --ignore 'node_modules' --ignore 'site' --ignore 'Godeps' --ignore 'vendor' --ignore 'images'"

alias more="less"

alias cls="clear"

alias rm="rm -i"

alias vim="nvim -X -O"
alias vimdiff="nvim -d"

alias open_ports="sudo lsof -i -P -n | grep LISTEN"

alias ll="ls -lah"

alias k=kubectl
alias tf=terraform

alias gl="git log -n 20 --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset %an' --abbrev-commit --date=relative"
alias gs="git status"

#alias list-issues="gh issue list -R $(git remote get-url --push origin | (cut -d: -f2) | sed "s/.git//")"

alias pm="profile-manager"


alias datacenter-info="govc datacenter.info"
alias go_build_linux="GOOS=linux GOARCH=amd64 go build -v"

alias om="om -t '$OM_TARGET' -u '$OM_USERNAME' -p '$OM_PASSWORD'"

alias rec='ffmpeg -f avfoundation -r 30 -s "1280x720" -i "0:1" out.mp4'

alias docker_prune='sudo docker system prune -a'

alias amend='git amend && git push -f'
alias k9s='k9s --context foo'
alias dammit='git commit --amend --no-edit --reset-author && git push -f'

alias download-audio='yt-dlp -x --audio-format mp3 --audio-quality 0 '

alias bosh-deployments='bosh deployments --json | jq ".Tables | .[0] | .Rows | .[] | .name" -r'
#alias iacbox='iacbox -iv=iacbox.common.cdn.repositories.cloud.sap/iacbox-dev-test:latest'
alias chatgpt='~/.asdf/shims/gpt'
alias download-video='yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" '

commit_command="Generate a concise git commit message that summarizes the key changes. Stay high-level and combine smaller changes to overarching topics. Skip describing any reformatting changes"
alias autocommit="MSG=\"\$(git diff --staged | sgpt '$commit_command')\" && git commit -e -m \${MSG}"
alias autoreset="git reset --soft HEAD~1; autocommit"

alias makepick='TARGET=$(grep -E "^[a-zA-Z0-9_-]+:" Makefile | sed "s/://" | gum filter --limit 1) && make "$TARGET"'

alias worktrees='cd $(git worktree list --porcelain | grep worktree | cut -d" " -f2 | gum choose --limit 1)'

