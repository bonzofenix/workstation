# Agents

This directory contains autonomous agents that perform automated tasks using AI.

## Available Agents

### Reviewdog Agent (`reviewdog/`)

Automatically monitors PRs for reviewdog linter failures, fixes them using Claude AI, and continuously iterates until all checks pass.

Supports any linter that reviewdog runs: shellcheck, golangci-lint, eslint, and more.

**Usage:**
```bash
cd /path/to/your/repo
reviewdog-agent
```

See [reviewdog/README.md](reviewdog/README.md) for detailed documentation.

## Adding New Agents

When adding a new agent:

1. Create a new directory under `lib/agents/your-agent-name/`
2. Include these files:
   - `README.md` - Documentation
   - `requirements.txt` - Python dependencies
   - Main agent script (e.g., `agent.py`)
3. Create a wrapper script in `bin/your-agent-name` for easy CLI access (see template below)
4. Run `make agents` to install dependencies
5. Update this README with a brief description

### Wrapper Script Template

Agent wrappers must use the **system Python** (not project-specific Nix/direnv Python) to access installed dependencies:

```bash
#!/usr/bin/env bash
# Wrapper script for Your Agent

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AGENT_PATH="$SCRIPT_DIR/../lib/agents/your-agent-name/your_agent.py"

if [ ! -f "$AGENT_PATH" ]; then
    echo "Error: Agent not found at $AGENT_PATH"
    exit 1
fi

# Find system Python, avoiding Nix/direnv overrides
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
    echo "Error: Could not find system Python3"
    exit 1
fi

# Execute with system Python, clearing environment variables
exec env -u VIRTUAL_ENV -u PYTHONPATH "$SYSTEM_PYTHON" "$AGENT_PATH" "$@"
```

## Agent Structure

```
lib/agents/
├── README.md              # This file
├── agent_name/
│   ├── README.md          # Agent-specific docs
│   ├── requirements.txt   # Dependencies
│   ├── agent.py           # Main agent code
│   └── install.sh         # Optional installation script
└── ...
```
