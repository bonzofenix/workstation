
echo 'Adding ASDF env vars to path'
add_to_profile '# Adding ASDF env vars to path' \
               'export ASDFROOT=$HOME/.asdf' \
               'export ASDFINSTALLS=$HOME/.asdf/installs'
