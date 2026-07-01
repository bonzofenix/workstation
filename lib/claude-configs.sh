#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

function main() {
  local workstation_dir="$HOME/workstation"
  local source_dir="$workstation_dir/assets/claude"
  local target_dir="$HOME/.claude"

  log_section "Claude Code Configs"

  mkdir -p "$target_dir/hooks"

  link_if_missing "$source_dir/settings.json" "$target_dir/settings.json" "settings.json"
  link_if_missing "$source_dir/hooks/peon-ping" "$target_dir/hooks/peon-ping" "hooks/peon-ping"

  # Global memory — source of truth lives in workstation repo
  local home_slug
  home_slug="${HOME//\//-}"
  local global_memory_target="$HOME/.claude/projects/${home_slug}"
  mkdir -p "$global_memory_target"
  link_if_missing "$source_dir/memory" "$global_memory_target/memory" "global memory"

  # Download peon sounds if not present
  local sounds_dir="$source_dir/hooks/peon-ping/packs/peon/sounds"
  if [ ! -d "$sounds_dir" ] || [ -z "$(ls -A "$sounds_dir" 2>/dev/null)" ]; then
    log_step "Downloading peon sounds"
    "$source_dir/hooks/peon-ping/scripts/download-sounds.sh" "$source_dir/hooks/peon-ping" peon \
      || log_warning "Failed to download sounds, run manually later"
  else
    log_success "Peon sounds already present"
  fi

  log_success "Claude Code configs configured"
}

main
