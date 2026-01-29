#!/usr/bin/env bash

# Pre-installation dependency checker
# Validates critical dependencies before attempting installation

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

MISSING=()
FAILED=false

check_critical() {
  local cmd=$1
  local install_hint=$2

  if command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${RESET} $cmd is installed"
    return 0
  else
    echo -e "${RED}✗${RESET} $cmd is missing - $install_hint"
    MISSING+=("$cmd: $install_hint")
    FAILED=true
    return 1
  fi
}

echo "Checking critical dependencies for installation..."
echo ""

# Check absolutely required tools for installation to proceed
check_critical "git" "Should be pre-installed on macOS"
check_critical "curl" "Should be pre-installed on macOS"

# Homebrew is installed by the installation process if missing, so just warn
if ! command -v brew >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠${RESET} brew not found - will be installed automatically"
else
  echo -e "${GREEN}✓${RESET} brew is installed"
fi

echo ""

if [ "$FAILED" = true ]; then
  echo -e "${RED}Installation cannot proceed without critical dependencies.${RESET}"
  echo ""
  echo "Missing dependencies:"
  for dep in "${MISSING[@]}"; do
    echo "  • $dep"
  done
  echo ""
  exit 1
else
  echo -e "${GREEN}✓ Critical dependencies are present${RESET}"
  echo ""
  echo "Note: Additional tools (gum, jq, tmux, etc.) will be installed via Homebrew during installation."
  echo "Run 'bin/check-deps' after installation to verify all dependencies."
  echo ""
  exit 0
fi
