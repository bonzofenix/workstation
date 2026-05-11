#!/usr/bin/env bash

set -euo pipefail

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

if ! command -v bun >/dev/null 2>&1; then
  echo "bun not found; skipping global package install (install via 'make homebrew')"
  exit 0
fi

PACKAGES=(
  "@tobilu/qmd"
)

for pkg in "${PACKAGES[@]}"; do
  echo "Installing global bun package: $pkg"
  bun install -g "$pkg"
done

add_to_profile '# Bun global bin' \
               'path=("$HOME/.bun/bin" $path)'

OBSIDIAN_VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/wiki"

if command -v qmd >/dev/null 2>&1 && [ -d "$OBSIDIAN_VAULT_PATH" ]; then
  echo "Setting up qmd Obsidian collection..."
  qmd collection add "$OBSIDIAN_VAULT_PATH" --name obsidian 2>/dev/null || true
  qmd context add qmd://obsidian "My personal Obsidian knowledge base, notes, projects, and ideas" 2>/dev/null || true
  qmd embed
fi
