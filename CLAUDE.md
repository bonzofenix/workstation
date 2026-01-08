# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal workstation configuration repository based on Pivotal's workstation project. It automates the setup of a macOS development environment with custom configurations, scripts, and tooling.

## Installation & Setup

```bash
# Full installation
make install

# Individual components
make homebrew          # Install Homebrew packages
make git              # Configure git settings
make git-aliases      # Setup git aliases
make configurations   # Link configuration files
make osx-configurations # Setup macOS preferences
make nix              # Setup Nix package manager
make agents           # Install all agent dependencies

# Optional flags
NO_BREW=true make install  # Skip homebrew installation
DEBUG=true make install    # Enable debug output
```

## Repository Structure

### Core Components

- **`lib/`** - Installation scripts that configure the development environment
  - `homebrew.sh` - Installs Homebrew and packages from Brewfiles
  - `git.sh` - Configures git global settings and aliases
  - `configurations.sh` - Sets up dotfiles, shell configs, PATH, and symlinks configuration files
  - `osx-configurations.sh` - Configures macOS system preferences
  - `nix.sh` - Sets up Nix package manager
  - `pr_reviewer/` - Python tool for AI-powered PR reviews
  - `agents/` - Autonomous AI agents for automated tasks
    - `reviewdog/` - Auto-fixes reviewdog linter issues in PRs using Claude AI

- **`bin/`** - Custom utility scripts (50+ scripts) added to PATH
  - Git workflow: `cleanup-branches`, `cleanup-worktrees`, `delete-branch`, `worktrees`, `new-worktree`
  - AI-powered: `autodiff`, `autorefactor`, `claude-cost`, `reviewdog-agent`
  - Development: `bosh-*`, `cf-*`, `docker-*` scripts
  - Note: Agent wrappers in `bin/` call the actual agent code in `lib/agents/`

- **`assets/`** - Configuration files and dotfiles
  - `aliases.bash` - Custom bash aliases loaded globally
  - `tmux.conf` - tmux configuration
  - `gitignore_global` - Global git ignore patterns
  - `config/nvim/` - Neovim configuration
  - `work/Brewfile` - Work-specific Homebrew packages
  - `personal/Brewfile` - Personal Homebrew packages

## Key Architecture Patterns

### Installation Flow

1. **Makefile** orchestrates the installation by calling scripts in `lib/`
2. Each `lib/*.sh` script is independent and can be run separately
3. Scripts use `lib/common.sh` for shared functions like `add_to_profile`
4. Configuration is split between work and personal profiles via separate Brewfiles

### Shell Configuration

The setup configures both bash and zsh:
- Symlinks `~/.bash_profile` to `~/.zshenv` for consistency
- Uses `add_to_profile` function to safely add configuration without duplication
- Default shell uses vi mode keybindings
- TMUX automatically starts on new terminal sessions
- PATH includes: `~/workstation/bin`, `~/bin`, `~/.local/bin`, ASDF shims, coreutils

### Git Configuration

- **Default branch**: `develop` (not main/master)
- **Git duet** enabled globally for pair programming
- **Extensive aliases** defined in `lib/git.sh`:
  - `git st` - status
  - `git di` - diff with color-words
  - `git br` - branches sorted by commit date
  - `git lg` - pretty log graph
  - `git up` - pull with rebase and autostash
  - `git amend` - amend without editing message
- **Git-authors file**: `~/.git-authors` for git-duet configuration

### Worktree Management

The repo uses git worktrees extensively with dedicated scripts:
- `worktrees` - Interactive worktree selector with tmux integration (changes all panes)
- `new-worktree` - Creates new worktree in `../worktrees/` directory
- `cleanup-worktrees` - Removes worktrees for merged/gone branches
- `cleanup-branches` - Deletes merged or gone local branches

### AI Integration

The workstation includes both simple AI-powered scripts and autonomous agents:

**Simple AI Scripts** (use `sgpt` or OpenAI API):
- `autodiff` - Generates PR descriptions from diffs
- `autorefactor` - Refactors code using clean code principles
- `autocommit` - Auto-generates commit messages (alias in `aliases.bash`)
- `autoreset` - Soft resets and re-commits with new AI message
- `pr_reviewer.py` - Reviews PRs using GPT-4 (in `lib/pr_reviewer/`)

**Autonomous Agents** (in `lib/agents/`):
- `reviewdog-agent` - Continuously monitors PRs, auto-fixes reviewdog linter issues using Claude API, commits, and iterates until checks pass
  - Supports any reviewdog linter: shellcheck, golangci-lint, eslint, etc.

**Adding New Agents:**
1. Create directory: `lib/agents/your-agent-name/`
2. Add files: `README.md`, `requirements.txt`, agent script
3. Create wrapper: `bin/your-agent-name` that calls the agent
4. Update `lib/agents/README.md`
5. Run `make agents` to install dependencies

**Agent Installation:**
- `make agents` finds all `requirements.txt` files in `lib/agents/` and installs them
- Automatically included in `make install`
- Uses `pip3 install --user --break-system-packages` for modern Python environments
- Wrapper scripts in `bin/` use system Python (not Nix/direnv project-specific Python)
  - Priority order: `~/.asdf/shims/python3`, `~/.asdf/shims/python`, `/opt/homebrew/bin/python3`, `/usr/local/bin/python3`, `/usr/bin/python3`
  - Unsets `VIRTUAL_ENV` and `PYTHONPATH` to avoid environment conflicts
  - See `lib/agents/README.md` for wrapper script template

## Common Development Patterns

### Working with Scripts in bin/

When modifying scripts in `bin/`:
- Scripts use `#!/usr/bin/env bash` or `#!/bin/zsh` shebangs
- Many scripts use `set -euo pipefail` for strict error handling
- Interactive scripts use `gum` for user prompts and confirmations
- Some scripts source `~/workstation/bin/common.sh` for shared functions

### Modifying Configuration

1. **Shell aliases**: Edit `assets/aliases.bash`
2. **Git config**: Modify `lib/git.sh` or run git config commands directly
3. **TMUX**: Edit `assets/tmux.conf`
4. **Neovim**: Edit files in `assets/config/nvim/`
5. **Homebrew packages**: Edit `assets/work/Brewfile` or `assets/personal/Brewfile`

After changes to assets, re-run `make configurations` to apply.

### Environment Variables

Key environment variables set by the installation:
- `EDITOR=nvim` - Default editor
- `GIT_DUET_GLOBAL=true` - Git duet works globally
- `GIT_DUET_SET_GIT_USER_CONFIG=1` - Duet sets git user config
- `ASDF_GOLANG_MOD_VERSION_ENABLED=true` - ASDF golang mod support
- `HISTCONTROL=ignoredups` - Only ignore duplicate commands in history
- Infinite bash history saved to `~/.bash_eternal_history`

## Important Notes

- The workstation uses **`develop`** as the default branch, not `main` or `master`
- Many git workflow scripts filter out `develop` in addition to `main`/`master`
- TMUX starts automatically on new terminal sessions
- Direnv and devbox are configured for per-project environments
- GitHub Copilot is installed for Neovim
- The setup creates a symlink `~/icloud` to iCloud Drive folder
