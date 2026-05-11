#!/usr/bin/env bash

set -euo pipefail

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

if ! command -v bun >/dev/null 2>&1; then
  echo "bun not found; skipping global package install (install via 'make homebrew')"
  exit 0
fi

PACKAGES=(
  "https://github.com/tobi/qmd"
)

for pkg in "${PACKAGES[@]}"; do
  echo "Installing global bun package: $pkg"
  bun install -g "$pkg"
done

add_to_profile '# Bun global bin' \
               'path=("$HOME/.bun/bin" $path)'
