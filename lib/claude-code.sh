#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Installs the Claude Code CLI with Anthropic's official installer, on macOS
# and Linux alike. It puts `claude` in ~/.local/bin, which configurations.sh
# and linux-configurations.sh already add to PATH.
function main() {
  log_section "Claude Code"

  if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
    log_success "Claude Code already installed"
    return 0
  fi

  log_step "Installing Claude Code"
  # A failed install warns rather than failing `make`: the rest of the setup
  # does not need the binary, and the one-liner is easy to rerun by hand.
  if curl -fsSL https://claude.ai/install.sh | bash; then
    log_success "Claude Code installed"
  else
    log_warning "Claude Code install failed; run 'curl -fsSL https://claude.ai/install.sh | bash' manually"
  fi
}

main
