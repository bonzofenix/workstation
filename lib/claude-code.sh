#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Installs the Claude Code CLI with Anthropic's official installer, on macOS
# and Linux alike. It puts `claude` in ~/.local/bin, which configurations.sh
# and linux-configurations.sh add to PATH via ~/.zprofile.
function main() {
  log_section "Claude Code"

  if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
    log_success "Claude Code already installed"
    return 0
  fi

  log_step "Installing Claude Code"
  # A failed install warns rather than exiting so the remaining steps still
  # run. claude-configs then fails on the missing CLI (skills-bundle needs it
  # for plugins), so the warning names the real fix.
  if curl -fsSL https://claude.ai/install.sh | bash; then
    log_success "Claude Code installed"
  else
    log_warning "Claude Code install failed, so Claude plugins will not install either; run 'curl -fsSL https://claude.ai/install.sh | bash' manually"
  fi
}

main
