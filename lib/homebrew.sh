
if hash brew 2>/dev/null; then
  echo "Homebrew is already installed!"
else
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

echo
echo "Adding Homebrew's sbin to your PATH..."
if ! grep -q "/usr/local/bin" ~/.bash_profile; then
  echo                                  >> ~/.bash_profile
  echo '# Homebrew Path'                >> ~/.bash_profile
  echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bash_profile
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
echo "Removing old Homebrew Caskroom directory..."
sudo rm -rf /opt/homebrew-cask/Caskroom

echo
echo "Upgrading existing brews..."
brew upgrade

echo "Cleaning up your Homebrew installation..."
brew cleanup

echo "Running brew bundle..."
brew bundle --file  ~/workstation/assets/Brewfile
