
asdf plugin-add kubectl
asdf install kubectl 1.17.4

echo 'Adding ASDF env vars to path'
add_to_profile '# Adding ASDF env vars to path' \
               'export ASDFROOT=$HOME/.asdf' \
               'export ASDFINSTALLS=$HOME/.asdf/installs'
