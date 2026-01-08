#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export WORKSTATION_DIR="$SCRIPT_DIR/.."
source $SCRIPT_DIR/common.sh

echo "Installing agents..."

# Find system Python using same priority as agent wrappers
# Prioritize asdf (workstation default), then Homebrew, then system
SYSTEM_PYTHON=""
for py_path in "$HOME/.asdf/shims/python3" "$HOME/.asdf/shims/python" /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
    if [ -x "$py_path" ]; then
        SYSTEM_PYTHON="$py_path"
        break
    fi
done

# Fallback: use PATH but unset Nix/direnv variables first
if [ -z "$SYSTEM_PYTHON" ]; then
    SYSTEM_PYTHON=$(env -u VIRTUAL_ENV -u PYTHONPATH -u NIX_PATH which python3 2>/dev/null)
fi

if [ -z "$SYSTEM_PYTHON" ] || [ ! -x "$SYSTEM_PYTHON" ]; then
    echo "Warning: Could not find system Python3. Skipping agent installation."
    exit 0
fi

echo "Using Python: $SYSTEM_PYTHON"
$SYSTEM_PYTHON --version

AGENTS_DIR="$WORKSTATION_DIR/lib/agents"

# Find all requirements.txt files in the agents directory
while IFS= read -r requirements_file; do
    agent_name=$(basename "$(dirname "$requirements_file")")
    echo "Installing dependencies for agent: $agent_name"

    # Use the same Python that agents will use, with its pip module
    env -u VIRTUAL_ENV -u PYTHONPATH "$SYSTEM_PYTHON" -m pip install --user --break-system-packages -r "$requirements_file"

    if [ $? -eq 0 ]; then
        echo "✓ Successfully installed dependencies for $agent_name"
    else
        echo "✗ Failed to install dependencies for $agent_name"
    fi
done < <(find "$AGENTS_DIR" -name "requirements.txt" -type f)

echo "✓ Agent installation complete"
