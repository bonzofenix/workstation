echo

if hash brew 2>/dev/null; then
  echo "Homebrew is already installed!"
else
  echo "Installing Homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo
echo "Adding Homebrew's sbin to your PATH..."
if ! grep -q "/usr/local/sbin" ~/.bash_profile; then
  echo                                  >> ~/.bash_profile
  echo '# Homebrew Path'                >> ~/.bash_profile
  echo 'export PATH="/usr/local/sbin:$PATH"' >> ~/.bash_profile
fi

echo
echo "Ensuring you have the latest Homebrew..."
brew update

echo
echo "Ensuring you have a healthy Homebrew environment..."
brew doctor || :

echo
echo "Ensuring your Homebrew directory is writable..."
sudo chown -R $(whoami) /usr/local/bin

echo
echo "Installing Homebrew services..."
brew tap homebrew/services

echo
echo "Adding pivotal tap to Homebrew"
brew tap pivotal/tap

echo
echo "Removing old Homebrew Caskroom directory..."
sudo rm -rf /opt/homebrew-cask/Caskroom

echo
echo "Upgrading existing brews..."
brew upgrade

echo "Cleaning up your Homebrew installation..."
brew cleanup
