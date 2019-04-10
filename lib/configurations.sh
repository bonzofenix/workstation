set -e

echo
echo 'Adding workstation/bin to path'
if ! grep -q '~/workstation/bin' ~/.bash_profile; then
    echo                                        >> ~/.bash_profile
    echo '# Add workstation binaries'          	>> ~/.bash_profile
    echo 'export PATH=$PATH:~/workstation/bin' 	>> ~/.bash_profile
  fi

  echo
  echo 'Adding ~/bin to path'
  if ! grep -q '~/bin' ~/.bash_profile; then
    echo                                          >> ~/.bash_profile
    echo '# Add ~/bin binaries'                   >> ~/.bash_profile
    echo 'export PATH=$PATH:~/bin'                >> ~/.bash_profile
  fi

  echo
  echo 'Setting tmux config'
  if [ -e ~/.tmux.conf ]; then
   rm -f ~/.tmux.conf
  fi
  ln -fs ~/workstation/assets/tmux.conf ~/.tmux.conf

  echo
  echo 'Setting LANG for UTF-8 tmux support'
  if ! grep -q 'LANG=' ~/.bash_profile; then
    echo 'export LANG=en_US.UTF-8' >> ~/.bash_profile
  fi

  echo
  echo 'Enabling TMUX to run by default'
  if !  grep -q "TMUX" ~/.bash_profile ; then
    echo                                                             >> ~/.bash_profile
    echo '# Adding tmux to run by default on new terminal'           >> ~/.bash_profile
    echo 'if [[ ! $TMUX ]] ; then' >> ~/.bash_profile
    echo 'tmux attach -t base || tmux new -s base'                   >> ~/.bash_profile
    echo 'fi'                                                        >> ~/.bash_profile
  fi


  echo
  echo "Installing VIM configs"
  if [ -d ~/.vim ]; then
    rm -rf ~/.vim
  fi

  if [ -L ~/.vimrc ]; then
    rm ~/.vimrc
  fi
  cp ~/workstation/assets/vim/vimrc ~/.vimrc
  cp -R ~/workstation/assets/vim ~/.vim
  vim -c ":GoInstallBinaries" -c ":q" - </dev/null

  echo
  echo "Configuring rbenv"
  if ! grep -q 'rbenv init -' ~/.bash_profile; then
    echo                                        >> ~/.bash_profile
    echo '# Use rbenv'                          >> ~/.bash_profile
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
    echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
  fi

  echo
  echo "Configuring ~/workstation/bin in PATH"
  if ! grep -q '~/workstation/bin' ~/.bash_profile; then
    echo                                            >> ~/.bash_profile
    echo '# Adds pe workstation binaries to path'   >> ~/.bash_profile
    echo 'export PATH="~/workstation/bin:$PATH"'    >> ~/.bash_profile
  fi

  echo
  echo "Allowing history to track lines beginning with whitespace"
  if ! grep -q 'HISTCONTROL' ~/.bash_profile; then
    echo                                       >> ~/.bash_profile
    echo '# Only ignore duplicates in history' >> ~/.bash_profile
    echo '# (disables ignorespace)'            >> ~/.bash_profile
    echo 'export HISTCONTROL=ignoredups'       >> ~/.bash_profile
  fi

  echo
  echo "Configuring custom aliases"
  if [[ -L ~/.aliases.bash ]]; then
    rm ~/.aliases.bash
  fi
  ln -fs ~/workstation/assets/aliases.bash ~/.aliases.bash

  if ! grep -q 'source ~/.aliases.bash' ~/.bash_profile; then
    echo                                 >> ~/.bash_profile
    echo '# Load custom aliases'         >> ~/.bash_profile
    echo 'source ~/.aliases.bash'        >> ~/.bash_profile
  fi

  if ! grep -q 'GIT_DUET_GLOBAL' ~/.bash_profile; then
    echo                               >> ~/.bash_profile
    echo '# git duet works globally'   >> ~/.bash_profile
    echo 'export GIT_DUET_GLOBAL=true' >> ~/.bash_profile
  fi

  echo
  echo "Configuring GPG"
  if ! grep -q 'GPG_TTY' ~/.bash_profile; then
    echo                                 >> ~/.bash_profile
    echo '# configure GPG '              >> ~/.bash_profile
    echo 'GPG_TTY=$(tty)'                >> ~/.bash_profile
    echo 'export GPG_TTY'                >> ~/.bash_profile
  fi

  echo
  echo "Configuring shell prompt"
  if ! grep -q 'PS1' ~/.bash_profile; then
    echo                                      >> ~/.bash_profile
    echo '# configure shell prompt'           >> ~/.bash_profile
    echo "if [[ $TERM =~ 256color ]]; then"   >> ~/.bash_profile
    echo "  PS1='\[\033[01;32m\]\u\[\033[0m\]:\[\033[01;34m\]\W\[\033[0m\]\\$ '" >> ~/.bash_profile
    echo "else"                               >> ~/.bash_profile
    echo "PS1='\[\e[1;35m\]\$\[\e[0m\] '"     >> ~/.bash_profile
    echo "fi"                                 >> ~/.bash_profile
  fi

  echo
  echo "Enables z shell plugin"
  if ! grep -q 'bin/z.sh' ~/.bash_profile; then
    echo                                 >> ~/.bash_profile
    echo '# Enables z shell plugin'      >> ~/.bash_profile
    echo ". ~/workstation/bin/z.sh"      >> ~/.bash_profile
  fi

  echo
  echo "Disables case sensitive completion"
  if ! grep -q 'completion-ignore-case' ~/.bash_profile; then
    echo                                          >> ~/.bash_profile
    echo '# Disables case sensitive completion'   >> ~/.bash_profile
    echo "[[ \"\$-\" =~ 'i' ]] && bind 'set completion-ignore-case on'"   >> ~/.bash_profile
  fi

  echo
  echo "cds into the HOME directory"
  if ! grep -q 'cd $HOME' ~/.bash_profile; then
    echo                                          >> ~/.bash_profile
    echo '# cds into $HOME directory'             >> ~/.bash_profile
    echo 'cd $HOME'                               >> ~/.bash_profile
  fi

  echo
  echo "sets vi mode"
  if ! grep -q 'set -o vi' ~/.bash_profile; then
    echo                                          >> ~/.bash_profile
    echo '# sets vi mode'                         >> ~/.bash_profile
    echo 'set -o vi'                              >> ~/.bash_profile
  fi

  if `hash direnv`; then
    echo
    echo "Adds direnv hook"
    if ! grep -q 'direnv hook' ~/.bash_profile; then
      echo                                        >> ~/.bash_profile
      echo '# Load direnv'                        >> ~/.bash_profile
      echo "eval \"\$( direnv hook bash )\""      >> ~/.bash_profile
    fi
fi

ln -fsn ~/workstation/assets/profiles ~/.profiles
