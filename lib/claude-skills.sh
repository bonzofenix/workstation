#!/usr/bin/env bash
set -euo pipefail

# Source common functions
source "$(dirname "$0")/common.sh"

function main() {
  local workstation_dir="$HOME/workstation"
  local skills_source_dir="$workstation_dir/assets/claude/skills"
  local global_skills_dir="$HOME/.claude/skills"

  echo "Setting up global Claude Code skills..."

  mkdir -p "$global_skills_dir"

  # Dynamically find all skill directories
  for source in "$skills_source_dir"/*; do
    [ -d "$source" ] || continue

    local skill=$(basename "$source")
    local target="$global_skills_dir/$skill"

    if [ -L "$target" ]; then
      echo "  Skill /$skill already linked"
    elif [ -e "$target" ]; then
      echo "  Warning: $target exists and is not a symlink, skipping"
    else
      ln -s "$source" "$target"
      echo "  Linked skill: /$skill"
    fi
  done

  echo "✓ Claude Code skills configured globally"
}

main
