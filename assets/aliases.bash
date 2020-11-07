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

alias open_ports="sudo lsof -i -P -n | grep LISTEN"

alias ll="ls -lah"

alias k=kubectl

alias gl="git log -n 20 --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset %an' --abbrev-commit --date=relative"
alias gs="git status"

alias list-issues="gh issue list -R $(git remote get-url --push origin | (cut -d: -f2) | sed "s/.git//")"

alias pm="profile-manager"

alias docker-clean=" docker rm -f $(docker ps -a -q)"

alias datacenter-info="govc datacenter.info"
alias go_build_linux="GOOS=linux GOARCH=amd64 go build -v"

alias tmux="tmux -2"

alias om="om -t '$OM_TARGET' -u '$OM_USERNAME' -p '$OM_PASSWORD'"


alias go='TMPDIR=~/tmp go'

alias docker_prune='sudo docker system prune -a'
