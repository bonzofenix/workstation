#### Compozed Custom Aliases #####

# misc #
alias authors="vim ~/.git-authors"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias grpe='grep'

alias tree="tree -I 'node_modules|site|Godeps|vendor'"

alias ag="ag -U --ignore 'node_modules' --ignore 'site' --ignore 'Godeps' --ignore 'vendor'"
alias more="less"

alias cls="clear"

alias rm="rm -i"

alias vim="nvim -X -O"
alias vi="nvim"
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

alias tmux="tmux -2"

alias om="om -t '$OM_TARGET' -u '$OM_USERNAME' -p '$OM_PASSWORD'"

alias rec='ffmpeg -f avfoundation -r 30 -s "1280x720" -i "0:1" out.mp4'

alias docker_prune='sudo docker system prune -a'

alias trading='tmuxp load -y trading'
alias tango='tmuxp load -y tango'
alias reading='tmuxp load -y reading'
alias fitness='tmuxp load -y fitness'
alias bitex='tmuxp load -y bitex'

alias amend='git amend && git push -f'
alias k9s='k9s --context foo'
