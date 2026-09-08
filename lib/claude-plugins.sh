#!/usr/bin/env bash

# Installs the Claude Code marketplaces and plugins listed in
# assets/claude/settings.json.
#
# Shared by configurations.sh (macOS) and claude-configs.sh (Linux) so the
# two paths cannot drift apart. Sourced, not executed, so callers keep their
# own logging context.
#
# Every call is `|| true`: a marketplace being unreachable, or a plugin
# already installed, must not fail an otherwise good setup run.

install_claude_plugins() {
  log_step "Installing Claude Code plugins"

  if ! command -v claude >/dev/null 2>&1; then
    log_warning "Claude Code CLI not found, skipping plugin installation"
    return 0
  fi

  local marketplaces=(
    anthropics/claude-plugins-official
    affaan-m/everything-claude-code
    JuliusBrussee/caveman
    forrestchang/andrej-karpathy-skills
    anthropics/skills
    kepano/obsidian-skills
  )

  local plugins=(
    gopls-lsp@claude-plugins-official
    ralph-loop@claude-plugins-official
    code-simplifier@claude-plugins-official
    atlassian@claude-plugins-official
    caveman@caveman
    andrej-karpathy-skills@karpathy-skills
    skill-creator@claude-plugins-official
    obsidian@obsidian-skills
  )

  local m p
  for m in "${marketplaces[@]}"; do
    claude plugin marketplace add "$m" 2>/dev/null || true
  done
  for p in "${plugins[@]}"; do
    claude plugin install "$p" 2>/dev/null || true
  done

  log_success "Claude Code plugins installed"
}
