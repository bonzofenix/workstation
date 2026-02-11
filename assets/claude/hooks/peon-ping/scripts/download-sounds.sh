#!/bin/bash
# Download and extract sounds for a peon-ping sound pack
# Usage: download-sounds.sh <install_dir> [pack_name]
set -euo pipefail

INSTALL_DIR="${1:?Usage: download-sounds.sh <install_dir> [pack_name]}"
PACK_NAME="${2:-peon}"
PACK_DIR="$INSTALL_DIR/packs/$PACK_NAME"
MANIFEST="$PACK_DIR/manifest.json"

if [ ! -f "$MANIFEST" ]; then
  echo "Error: manifest not found at $MANIFEST"
  exit 1
fi

# Parse manifest for download source
eval "$(/usr/bin/python3 -c "
import json, sys, shlex
m = json.load(open(sys.argv[1]))
print('SOURCE_URL=' + shlex.quote(m['source_url']))
print('SUBFOLDER=' + shlex.quote(m['source_subfolder']))
" "$MANIFEST")"

SOUNDS_DIR="$PACK_DIR/sounds"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Downloading $PACK_NAME sounds..."
if ! curl -L -o "$TEMP_DIR/sounds.zip" "$SOURCE_URL" 2>/dev/null; then
  cat <<EOF

Automatic download failed. Please download manually:
  1. Go to: $SOURCE_URL
  2. Save the ZIP file
  3. Extract the '$SUBFOLDER' folder to: $SOUNDS_DIR/

EOF
  exit 1
fi

echo "Extracting $PACK_NAME sounds..."
mkdir -p "$SOUNDS_DIR"
unzip -o -j "$TEMP_DIR/sounds.zip" "$SUBFOLDER/*" -d "$SOUNDS_DIR" > /dev/null 2>&1

# Verify extraction succeeded
COUNT=$(find "$SOUNDS_DIR" -name "*.wav" 2>/dev/null | wc -l | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
  echo "Error: No WAV files found after extraction"
  exit 1
fi

echo "Extracted $COUNT sound files to $SOUNDS_DIR/"
