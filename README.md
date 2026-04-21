# Workstation

Automated macOS development environment setup based on Pivotal's workstation project. Configures shell, git, editors, and development tools with custom scripts and AI integrations.

## Quick Start

```bash
# Clone or download into ~/workstation
git clone https://github.com/bonzofenix/workstation.git ~/workstation
cd ~/workstation

# Full installation
make install

# Or install individual components
make homebrew          # Install Homebrew packages
make git              # Configure git settings
make configurations   # Link configuration files
make osx-configurations # Setup macOS preferences
```

**Prerequisites**: macOS with Xcode Command Line Tools installed

## Installation Options

```bash
# Skip homebrew installation
NO_BREW=true make install

# Enable debug output
DEBUG=true make install

# Configure SAP GitHub credentials (if needed)
git config credential.https://github.tools.sap.username SAP_USER
```

## What Gets Installed

- **Shell configuration**: bash/zsh with vi mode, TMUX auto-start, custom aliases
- **Git setup**: Git duet, extensive aliases, default branch `develop`
- **Development tools**: Neovim, direnv, asdf, devbox, GitHub Copilot
- **Custom scripts**: 50+ utilities in `bin/` (worktree management, AI-powered tools)
- **AI integration**: autodiff, autorefactor, autocommit, pr_reviewer

## Key Features

### Git Configuration
- **Default branch**: `main`
- **Aliases**: `git st`, `git di`, `git lg`, `git up`, `git amend`
- **Git duet**: Enabled globally for pair programming

### Worktree Management
- `worktrees` - Interactive worktree selector with tmux integration
- `new-worktree` - Create worktrees in `../worktrees/`
- `cleanup-worktrees` - Remove worktrees for merged branches

### AI-Powered Scripts
- `autodiff` - Generate PR descriptions from diffs
- `autorefactor` - Refactor code using clean code principles
- `autocommit` - Auto-generate commit messages

See [`CLAUDE.md`](./CLAUDE.md) for full documentation and architecture details.

## Troubleshooting

- Some brew applications require re-entering sudo password (no workaround)
- Old Homebrew installations can cause issues - follow WARNING messages and re-run
- If TMUX doesn't auto-start, check `~/.bash_profile` or `~/.zshrc` sourcing


