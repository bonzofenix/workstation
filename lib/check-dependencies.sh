#!/usr/bin/env bash

# Pre-installation dependency checker
# Validates critical dependencies before attempting installation

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."

_has_gum() { command -v gum >/dev/null 2>&1; }

_ok()   {
  if _has_gum; then
    gum log --level info "$(gum style --foreground 2 "✓") $*"
  else
    echo "✓ $*"
  fi
}

_fail() {
  if _has_gum; then
    gum log --level error "$(gum style --foreground 1 "✗") $*"
  else
    echo "✗ $*" >&2
  fi
}

_warn() {
  if _has_gum; then
    gum log --level warn "$@"
  else
    echo "⚠ $*"
  fi
}

MISSING=()
FAILED=false

check_critical() {
  local cmd=$1
  local install_hint=$2

  if command -v "$cmd" >/dev/null 2>&1; then
    _ok "$cmd is installed"
    return 0
  else
    _fail "$cmd is missing — $install_hint"
    MISSING+=("$cmd: $install_hint")
    FAILED=true
    return 1
  fi
}

if _has_gum; then
  gum style --foreground 212 --bold --border-foreground 212 --border normal --padding "0 1" " Checking dependencies "
else
  echo "Checking critical dependencies for installation..."
fi
echo ""

check_critical "git" "Should be pre-installed on macOS"
check_critical "curl" "Should be pre-installed on macOS"

if ! command -v brew >/dev/null 2>&1; then
  _warn "brew not found — will be installed automatically"
else
  _ok "brew is installed"
fi

echo ""

if [ "$FAILED" = true ]; then
  if _has_gum; then
    gum style --foreground 1 --bold "Installation cannot proceed without critical dependencies."
  else
    echo "Installation cannot proceed without critical dependencies." >&2
  fi
  echo ""
  echo "Missing dependencies:"
  for dep in "${MISSING[@]}"; do
    echo "  • $dep"
  done
  echo ""
  exit 1
else
  _ok "Critical dependencies are present"
  echo ""
  _warn "Additional tools (gum, jq, tmux, etc.) will be installed via Homebrew during installation."
  echo "Run 'bin/check-deps' after installation to verify all dependencies."
  echo ""
  exit 0
fi
