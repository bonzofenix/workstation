#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Create a symlink if target doesn't exist, report status
link_if_missing() {
  local source="$1"
  local target="$2"
  local name="$3"

  if [ -L "$target" ]; then
    echo "  $name already linked"
  elif [ -e "$target" ]; then
    echo "  Warning: $target exists and is not a symlink, skipping"
  else
    ln -s "$source" "$target"
    echo "  Linked $name"
  fi
}

function main() {
  local workstation_dir="$HOME/workstation"
  local source_dir="$workstation_dir/assets/claude"
  local target_dir="$HOME/.claude"

  echo "Setting up Claude Code configs..."

  mkdir -p "$target_dir/hooks"

  link_if_missing "$source_dir/settings.json" "$target_dir/settings.json" "settings.json"
  link_if_missing "$source_dir/hooks/peon-ping" "$target_dir/hooks/peon-ping" "hooks/peon-ping"

  # Download peon sounds if not present
  local sounds_dir="$source_dir/hooks/peon-ping/packs/peon/sounds"
  if [ ! -d "$sounds_dir" ] || [ -z "$(ls -A "$sounds_dir" 2>/dev/null)" ]; then
    echo "  Downloading peon sounds..."
    "$source_dir/hooks/peon-ping/scripts/download-sounds.sh" "$source_dir/hooks/peon-ping" peon \
      || echo "  Warning: Failed to download sounds, run manually later"
  else
    echo "  Peon sounds already present"
  fi

  echo "Claude Code configs configured"
}

main
