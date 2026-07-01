#!/bin/bash
# Claude Code statusLine
# Shows: [model] | Repo: repo_name | Branch: branch | Diff: +lines/-lines | Context: percent%

# Colors (ANSI)
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

# Read input from stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Model display in cyan brackets, with effort level if present
if [ -n "$effort" ]; then
    model_display="${CYAN}[${model} ${YELLOW}${effort}${CYAN}]${RESET}"
else
    model_display="${CYAN}[${model}]${RESET}"
fi

# Git info - Repo and Branch
repo_info=""
branch_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # Get repo name from git remote URL
    git_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
        # Extract repo name from remote URL (handles both SSH and HTTPS)
        remote_url=$(git -C "$cwd" --no-optional-locks config --get remote.origin.url 2>/dev/null)
        if [ -n "$remote_url" ]; then
            # Remove .git suffix and extract last component
            repo_name=$(basename "$remote_url" .git)
        else
            # Fallback to folder name if no remote
            repo_name=$(basename "$git_root")
        fi
        repo_info="${MAGENTA}Repo:${RESET} ${BRIGHT_CYAN}${repo_name}${RESET}"
    fi

    # Get branch name
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check if dirty
        if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
            branch_info="${MAGENTA}Branch:${RESET} ${GREEN}${branch}${RESET} ${YELLOW}*${RESET}"
        else
            branch_info="${MAGENTA}Branch:${RESET} ${GREEN}${branch}${RESET}"
        fi
    fi
fi

# Git diff statistics (uncommitted changes)
diff_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # Get diff stats for staged and unstaged changes
    diff_stats=$(git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null | awk '{added+=$1; deleted+=$2} END {printf "%d %d", added, deleted}')
    if [ -n "$diff_stats" ] && [ "$diff_stats" != "0 0" ]; then
        added=$(echo "$diff_stats" | cut -d' ' -f1)
        deleted=$(echo "$diff_stats" | cut -d' ' -f2)
        diff_info="${MAGENTA}Diff:${RESET} ${GREEN}+${added}${RESET}/${RED}-${deleted}${RESET}"
    fi
fi

# Context percentage with color based on usage
context_info=""
if [ -n "$used_pct" ]; then
    # Color based on usage: green < 50%, yellow 50-80%, red > 80%
    if [ "$used_pct" -lt 50 ]; then
        pct_color="${GREEN}"
    elif [ "$used_pct" -lt 80 ]; then
        pct_color="${YELLOW}"
    else
        pct_color="${RED}"
    fi
    context_info="${MAGENTA}Context:${RESET} ${pct_color}${used_pct}%${RESET}"
fi

# Build output
output="$model_display"
if [ -n "$repo_info" ]; then
    output="$output ${CYAN}|${RESET} $repo_info"
fi
if [ -n "$branch_info" ]; then
    output="$output ${CYAN}|${RESET} $branch_info"
fi
if [ -n "$diff_info" ]; then
    output="$output ${CYAN}|${RESET} $diff_info"
fi
if [ -n "$context_info" ]; then
    output="$output ${CYAN}|${RESET} $context_info"
fi

printf "%b" "$output"
