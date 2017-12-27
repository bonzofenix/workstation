set +e

echo
echo "Installing Ruby tools and Ruby 2.4.1"
brew install readline 
brew install rbenv 
eval "$(rbenv init -)"
rbenv install 2.4.1 --skip-existing
rbenv global 2.4.1
rbenv local --unset
rbenv shell --unset
gem install bundler
rbenv rehash

