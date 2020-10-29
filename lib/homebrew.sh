source ~/workstation/lib/common.sh

if hash brew 2>/dev/null; then
  echo "Homebrew is already installed!"
else
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

echo "Adding Homebrew's bin to your PATH..."
add_to_profile '# Homebrew Path' \
               'export PATH="/usr/local/bin:$PATH"' \
               'export PATH="/usr/local/sbin:$PATH"'

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
