#### Compozed Custom Aliases #####

# misc #
alias authors="vim ~/.git-authors"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias grpe='grep'

alias more="less"

alias cls="clear"

alias vi="vim"
alias vim="vim -X -O"

alias ls="/usr/local/opt/coreutils/libexec/gnubin/ls --color=auto"
alias ll="ls -lah"

alias gl="git log -n 20 --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset %an' --abbrev-commit --date=relative"
alias gs="git status"

function go_build_linux {
  GOOS=linux GOARCH=amd64 go build -v
}
