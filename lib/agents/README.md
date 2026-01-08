# Agents

This directory contains autonomous agents that perform automated tasks using AI.

## Available Agents

### ShellCheck Agent (`shellcheck/`)

Automatically monitors PRs for shellcheck failures, fixes them using Claude AI, and continuously iterates until all checks pass.

**Usage:**
```bash
cd /path/to/your/repo
shellcheck-agent
```

See [shellcheck/README.md](shellcheck/README.md) for detailed documentation.

## Adding New Agents

When adding a new agent:

1. Create a new directory under `lib/agents/your-agent-name/`
2. Include these files:
   - `README.md` - Documentation
   - `requirements.txt` - Python dependencies
   - Main agent script (e.g., `agent.py`)
3. Create a wrapper script in `bin/your-agent-name` for easy CLI access
4. Update this README with a brief description

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
