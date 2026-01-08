# Reviewdog Auto-Fix Agent

An intelligent agent that automatically monitors your PR for reviewdog linter failures, fixes them using Claude AI, and continuously iterates until all checks pass.

Supports any linter that reviewdog runs: shellcheck, golangci-lint, eslint, and more.

## Features

- Automatically detects open PRs for the current branch
- Runs linters locally to identify issues (currently supports shellcheck)
- Uses Claude AI to fix linter violations
- Commits and pushes fixes automatically
- Continuously monitors until all reviewdog checks pass
- Minimal, targeted fixes (doesn't refactor unnecessarily)
- Works with any GitHub repository

## Prerequisites

1. **GitHub CLI (`gh`)**: Must be installed and authenticated
   ```bash
   brew install gh
   gh auth login
   ```

2. **ShellCheck**: Must be installed locally
   ```bash
   brew install shellcheck
   ```

3. **Git**: Configured with your credentials

4. **Claude API Key**: Get one from https://console.anthropic.com/

## Global Installation

### Option 1: Install to ~/bin (Recommended)

1. Create a bin directory in your home folder if it doesn't exist:
   ```bash
   mkdir -p ~/bin
   ```

2. Copy the agent script:
   ```bash
   cp reviewdog_agent.py ~/bin/reviewdog-agent
   chmod +x ~/bin/reviewdog-agent
   ```

3. Install Python dependencies globally or in a virtual environment:
   ```bash
   pip3 install anthropic
   ```

4. Add ~/bin to your PATH if not already (add to ~/.zshrc or ~/.bashrc):
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```

5. Reload your shell:
   ```bash
   source ~/.zshrc  # or source ~/.bashrc
   ```

### Option 2: Install to /usr/local/bin (System-wide)

1. Copy and make executable:
   ```bash
   sudo cp reviewdog_agent.py /usr/local/bin/reviewdog-agent
   sudo chmod +x /usr/local/bin/reviewdog-agent
   ```

2. Install dependencies:
   ```bash
   pip3 install anthropic
   ```

### Option 3: Create a Standalone Package

1. Create a dedicated directory:
   ```bash
   mkdir -p ~/.local/reviewdog-agent
   ```

2. Set up a virtual environment:
   ```bash
   python3 -m venv ~/.local/reviewdog-agent/venv
   source ~/.local/reviewdog-agent/venv/bin/activate
   pip install anthropic
   ```

3. Copy the script:
   ```bash
   cp reviewdog_agent.py ~/.local/reviewdog-agent/
   chmod +x ~/.local/reviewdog-agent/reviewdog_agent.py
   ```

4. Create a wrapper script in ~/bin:
   ```bash
   cat > ~/bin/reviewdog-agent << 'EOF'
#!/bin/bash
source ~/.local/reviewdog-agent/venv/bin/activate
python3 ~/.local/reviewdog-agent/reviewdog_agent.py "$@"
EOF
   chmod +x ~/bin/reviewdog-agent
   ```

## Configuration

Set your Anthropic API key as an environment variable (add to ~/.zshrc or ~/.bashrc):

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

## Usage

1. Navigate to any git repository with shell scripts
2. Create and push a PR (or work on an existing PR)
3. Run the agent:
   ```bash
   reviewdog-agent
   ```

The agent will:
- Detect the current branch's PR
- Run shellcheck to find issues
- Fix issues using Claude AI
- Commit and push fixes
- Wait for CI checks to complete
- Repeat until all shellcheck issues are resolved

## Configuration Options

You can modify the agent behavior by editing the script:

- `max_iterations`: Maximum number of fix attempts (default: 10)
- `timeout`: How long to wait for checks (default: 600 seconds)
- `poll_interval`: How often to check status (default: 30 seconds)

## Troubleshooting

### "No open PR found"
- Make sure you have a PR open for the current branch
- Run `gh pr list --head $(git branch --show-current)` to verify

### "ANTHROPIC_API_KEY not set"
- Set the environment variable: `export ANTHROPIC_API_KEY="your-key"`
- Or pass it when running: `ANTHROPIC_API_KEY="your-key" reviewdog-agent`

### "shellcheck: command not found"
- Install shellcheck: `brew install shellcheck`

### API Rate Limits
- The agent uses Claude Sonnet 4, which has rate limits
- If you hit limits, the agent will show an error
- Wait a few minutes and try again

## Examples

### Basic usage
```bash
cd ~/my-project
reviewdog-agent
```

### Use with a specific API key
```bash
ANTHROPIC_API_KEY="sk-xxx" reviewdog-agent
```

### Run in background (with nohup)
```bash
nohup reviewdog-agent > reviewdog-agent.log 2>&1 &
```

## How It Works

1. **Detection**: Finds the PR for your current branch using `gh pr list`
2. **Analysis**: Runs `shellcheck` locally on all `.sh` files (excluding vendor directories)
3. **Fixing**: For each file with issues:
   - Reads the file content
   - Sends to Claude with the shellcheck errors
   - Claude returns fixed code
   - Writes the fixed content back
4. **Committing**: Stages all changes, commits with co-author attribution, and pushes
5. **Monitoring**: Waits for GitHub checks to complete using `gh pr checks`
6. **Iteration**: Repeats until shellcheck passes or max iterations reached

## Limitations

- Only works with repositories that use GitHub and have shellcheck in CI
- Requires the reviewdog action or similar shellcheck CI setup
- May not fix all types of shellcheck issues perfectly
- Uses API calls which have associated costs

## Contributing

Feel free to modify the agent for your specific needs. The code is well-commented and modular.

## License

This tool is provided as-is for use in your projects.
