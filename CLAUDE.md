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
  - `claude-configs.sh` - Links Claude settings, hooks, statusline and memory; runs `skills-bundle`

- **`bin/`** - Custom utility scripts (50+ scripts) added to PATH
  - Git workflow: `cleanup-branches`, `cleanup-worktrees`, `delete-branch`, `worktrees`, `new-worktree`
  - AI-powered: `autodiff`, `autorefactor`, `claude-cost`
  - Development: `bosh-*`, `cf-*`, `docker-*` scripts

- **`assets/`** - Configuration files and dotfiles
  - `aliases.bash` - Custom bash aliases loaded globally
  - `tmux.conf` - tmux configuration
  - `herdr/config.toml` - herdr configuration (agent multiplexer, tmux alternative)
  - `gitignore_global` - Global git ignore patterns
  - `config/nvim/` - Neovim configuration
  - `config/ghostty/` - Ghostty terminal configuration
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
- PATH includes: `~/workstation/bin`, `~/bin`, `~/.local/bin`, coreutils

### Git Configuration

- **Default branch**: `main`
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

**Standing rule: never edit a tracked file in the main checkout. Use
`EnterWorktree` before the first such edit, always.** This applies to file
edits, not just branch creation, and there is no size exception — a one-line
fix needs a worktree too. The `worktree-guard` PreToolUse hook enforces a
narrow slice of this (it blocks branch-creating `git` commands outside a
worktree), but the rule is broader than what the hook can detect.

Untracked and local-only files are the only things safe to edit in place, and
still warrant a heads-up to the user.

Why there is no "trivial fix" carve-out: edits stranded on `main` block
`git pull` and collide with incoming merges. A conflict resolved in favour of
the upstream side silently discards the local edit, which is how a settings
block was lost once already.

The repo uses git worktrees extensively with dedicated scripts:
- `worktrees` - Interactive worktree selector with tmux integration (changes all panes)
- `new-worktree` - Creates new worktree in `../worktrees/` directory
- `cleanup-worktrees` - Removes worktrees for merged/gone branches
- `cleanup-branches` - Deletes merged or gone local branches

### AI Integration

The workstation includes simple AI-powered scripts:

**AI Scripts** (use `sgpt` or OpenAI API):
- `autodiff` - Generates PR descriptions from diffs
- `autorefactor` - Refactors code using clean code principles
- `autocommit` - Auto-generates commit messages (alias in `aliases.bash`)
- `autoreset` - Soft resets and re-commits with new AI message

### Claude Code: three repos

This repo is public, so it holds only public-safe tooling. Claude Code content
is split across three repos:

| Repo | Visibility | Holds | Local clone |
|---|---|---|---|
| `bonzofenix/workstation` (this) | public | `bin/`, `lib/`, dotfiles, `assets/claude/` settings, hooks, statusline | `~/workstation` |
| `bonzofenix/skills` | public | general-purpose skills + the `Skillfile` | `$SKILLS_DIR` (`~/workspace/skills`) |
| `bonzofenix/memory` | private | memory, work skills, `Skillfile.local`, anything private | `$MEMORY_DIR` (`~/workspace/memory`) |

**Never add private content here**: memory, hostnames/IPs, employer-specific
details, private repo names. They go in the memory repo. Two guards back this
up:
- `bin/leak-check` runs as the pre-commit hook (`make git` sets
  `core.hooksPath .githooks`) and blocks added lines matching the private
  `leak-denylist.txt` in the memory repo.
- `bin/lint` (CI) fails if `assets/claude/settings.json` gains an
  `autoMode.environment` block or `assets/claude/memory` reappears. Auto-mode
  environment context is per project: it belongs in that project's
  `.claude/settings.local.json`.

**Skills and plugins are declarative.** The `Skillfile` in `bonzofenix/skills`
(Brewfile-style: `marketplace`, `plugin`, `collection`, `skill` lines) lists
everything in use; `Skillfile.local` in the memory repo adds private entries.
`bin/skills-bundle`:
- `install` - clone missing repos, link skills un-namespaced into
  `~/.claude/skills`, fetch pinned third-party skills into
  `~/.claude/skills-vendor/`, install plugins, prune stale links it owns
- `check` - report drift (exit 1 if anything listed is missing)
- `dump` - print a Skillfile of what is installed now

To add a skill or plugin, edit the Skillfile, not `~/.claude`, then run
`skills-bundle install`. Runs automatically in `make claude-configs` (part of
`make install` and `make install-linux`, run last); if anything could not be
installed it lists the failures and exits non-zero, which fails `make` too.

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
4. **herdr**: Edit `assets/herdr/config.toml` (validate with `herdr config check`, apply with `herdr server reload-config`)
5. **Neovim**: Edit files in `assets/config/nvim/`
6. **Homebrew packages**: Edit `assets/work/Brewfile` or `assets/personal/Brewfile`

After changes to assets, re-run `make configurations` to apply.

### Environment Variables

Key environment variables set by the installation:
- `EDITOR=nvim` - Default editor
- `GIT_DUET_GLOBAL=true` - Git duet works globally
- `GIT_DUET_SET_GIT_USER_CONFIG=1` - Duet sets git user config
- `HISTCONTROL=ignoredups` - Only ignore duplicate commands in history
- Infinite bash history saved to `~/.bash_eternal_history`

## Important Notes

- The workstation uses **`main`** as the default branch
- Git workflow scripts filter out `main`/`master` as protected branches
- TMUX starts automatically on new terminal sessions
- Direnv and devbox are configured for per-project environments
- GitHub Copilot is installed for Neovim
- The setup creates a symlink `~/icloud` to iCloud Drive folder
