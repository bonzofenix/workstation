#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "ShellCheck Agent - Global Installation"
echo "======================================"
echo

# Check prerequisites
echo "Checking prerequisites..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python3 is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python3 found${NC}"

# Check gh CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}✗ GitHub CLI (gh) is not installed${NC}"
    echo "  Install with: brew install gh"
    exit 1
fi
echo -e "${GREEN}✓ GitHub CLI found${NC}"

# Check shellcheck
if ! command -v shellcheck &> /dev/null; then
    echo -e "${YELLOW}⚠ ShellCheck is not installed${NC}"
    echo "  Install with: brew install shellcheck"
    echo "  Continuing anyway..."
else
    echo -e "${GREEN}✓ ShellCheck found${NC}"
fi

# Check API key
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${YELLOW}⚠ ANTHROPIC_API_KEY not set${NC}"
    echo "  You'll need to set it before using the agent"
    echo "  Add to your ~/.zshrc or ~/.bashrc:"
    echo "    export ANTHROPIC_API_KEY='your-key-here'"
else
    echo -e "${GREEN}✓ ANTHROPIC_API_KEY is set${NC}"
fi

echo

# Choose installation method
echo "Choose installation method:"
echo "1) Install to ~/bin (Recommended - user-only)"
echo "2) Install to /usr/local/bin (System-wide - requires sudo)"
echo "3) Install as standalone package with virtualenv"
echo
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        echo
        echo "Installing to ~/bin..."

        # Create ~/bin if it doesn't exist
        mkdir -p ~/bin

        # Copy script
        cp shellcheck_agent.py ~/bin/shellcheck-agent
        chmod +x ~/bin/shellcheck-agent

        # Install dependencies
        echo "Installing Python dependencies..."
        pip3 install --user anthropic

        echo -e "${GREEN}✓ Installed to ~/bin/shellcheck-agent${NC}"
        echo
        echo "Make sure ~/bin is in your PATH. Add this to ~/.zshrc or ~/.bashrc if not present:"
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        echo
        echo "Then reload your shell:"
        echo "  source ~/.zshrc  # or source ~/.bashrc"
        ;;

    2)
        echo
        echo "Installing to /usr/local/bin (requires sudo)..."

        sudo cp shellcheck_agent.py /usr/local/bin/shellcheck-agent
        sudo chmod +x /usr/local/bin/shellcheck-agent

        # Install dependencies
        echo "Installing Python dependencies..."
        pip3 install anthropic

        echo -e "${GREEN}✓ Installed to /usr/local/bin/shellcheck-agent${NC}"
        ;;

    3)
        echo
        echo "Installing as standalone package with virtualenv..."

        # Create directory structure
        mkdir -p ~/.local/shellcheck-agent

        # Create virtualenv
        echo "Creating virtual environment..."
        python3 -m venv ~/.local/shellcheck-agent/venv

        # Install dependencies
        echo "Installing dependencies..."
        ~/.local/shellcheck-agent/venv/bin/pip install anthropic

        # Copy script
        cp shellcheck_agent.py ~/.local/shellcheck-agent/
        chmod +x ~/.local/shellcheck-agent/shellcheck_agent.py

        # Create wrapper in ~/bin
        mkdir -p ~/bin
        cat > ~/bin/shellcheck-agent << 'EOF'
#!/bin/bash
source ~/.local/shellcheck-agent/venv/bin/activate
python3 ~/.local/shellcheck-agent/shellcheck_agent.py "$@"
EOF
        chmod +x ~/bin/shellcheck-agent

        echo -e "${GREEN}✓ Installed to ~/.local/shellcheck-agent${NC}"
        echo -e "${GREEN}✓ Wrapper created at ~/bin/shellcheck-agent${NC}"
        echo
        echo "Make sure ~/bin is in your PATH. Add this to ~/.zshrc or ~/.bashrc if not present:"
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        echo
        echo "Then reload your shell:"
        echo "  source ~/.zshrc  # or source ~/.bashrc"
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo
echo "======================================"
echo -e "${GREEN}Installation complete!${NC}"
echo "======================================"
echo
echo "Usage:"
echo "  cd /path/to/your/repo"
echo "  shellcheck-agent"
echo
echo "For more information, see SHELLCHECK_AGENT_README.md"
