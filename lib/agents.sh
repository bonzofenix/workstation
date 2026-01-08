#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source $SCRIPT_DIR/common.sh

echo "Installing agents..."

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "Warning: python3 is not installed. Skipping agent installation."
    exit 0
fi

# Check if pip3 is available
if ! command -v pip3 &> /dev/null; then
    echo "Warning: pip3 is not installed. Skipping agent installation."
    exit 0
fi

AGENTS_DIR="$WORKSTATION_DIR/lib/agents"

# Find all requirements.txt files in the agents directory
while IFS= read -r requirements_file; do
    agent_name=$(basename "$(dirname "$requirements_file")")
    echo "Installing dependencies for agent: $agent_name"

    pip3 install --user --break-system-packages -r "$requirements_file"

    if [ $? -eq 0 ]; then
        echo "✓ Successfully installed dependencies for $agent_name"
    else
        echo "✗ Failed to install dependencies for $agent_name"
    fi
done < <(find "$AGENTS_DIR" -name "requirements.txt" -type f)

echo "✓ Agent installation complete"
