#!/bin/bash
# Claude Code statusLine (compact / Nerd Font)
#
# Renders a single short line so it stays readable on a narrow phone terminal:
#
#   󰚩 O5·hi   workstation  main*  +12/-3  45%
#
# Glyphs require a Nerd Font patched font in the terminal. Set
# CLAUDE_STATUSLINE_ASCII=1 to fall back to plain ASCII labels.

# Colors (ANSI)
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Icons. Nerd Font glyphs by default, ASCII labels when opted out.
if [ -n "${CLAUDE_STATUSLINE_ASCII:-}" ]; then
    ICON_MODEL="M:"
    ICON_REPO="R:"
    ICON_BRANCH="B:"
    ICON_DIFF="D:"
    ICON_CONTEXT="C:"
else
    # Trailing space: glyphs need breathing room, the ASCII "X:" labels do not.
    ICON_MODEL=$' '      # nf-fa-bolt
    ICON_REPO=$' '       # nf-fa-git
    ICON_BRANCH=$' '     # nf-dev-git_branch
    ICON_DIFF=$' '       # nf-oct-diff
    ICON_CONTEXT=$' '    # nf-oct-meter
fi

# Read input from stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Abbreviate the model name: "Opus 5" -> O5, "Sonnet 5" -> S5, "Haiku 4.5" -> H4.5.
# Unknown names keep their first word so new models still render something useful.
abbreviate_model() {
    local name="$1" family version
    family=$(printf '%s' "$name" | awk '{print toupper(substr($1,1,1))}')
    version=$(printf '%s' "$name" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    case "$name" in
        Opus*|Sonnet*|Haiku*|Fable*) printf '%s%s' "$family" "$version" ;;
        *) printf '%s' "${name%% *}" ;;
    esac
}

# Effort levels are long words; two letters are enough to tell them apart.
abbreviate_effort() {
    case "$1" in
        high) printf 'hi' ;;
        medium) printf 'md' ;;
        low) printf 'lo' ;;
        *) printf '%s' "${1:0:2}" ;;
    esac
}

model_short=$(abbreviate_model "$model")
if [ -n "$effort" ]; then
    model_display="${CYAN}${ICON_MODEL}${model_short}${RESET}·${YELLOW}$(abbreviate_effort "$effort")${RESET}"
else
    model_display="${CYAN}${ICON_MODEL}${model_short}${RESET}"
fi

# Git info - repo, branch, diff. One rev-parse guards all three.
repo_info=""
branch_info=""
diff_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
        # Prefer the remote's name over the folder name, so worktrees and
        # clones with local directory names still show the canonical repo.
        remote_url=$(git -C "$cwd" --no-optional-locks config --get remote.origin.url 2>/dev/null)
        if [ -n "$remote_url" ]; then
            repo_name=$(basename "$remote_url" .git)
        else
            repo_name=$(basename "$git_root")
        fi
        repo_info="${BRIGHT_CYAN}${ICON_REPO}${repo_name}${RESET}"
    fi

    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
            branch_info="${GREEN}${ICON_BRANCH}${branch}${RESET}${YELLOW}*${RESET}"
        else
            branch_info="${GREEN}${ICON_BRANCH}${branch}${RESET}"
        fi
    fi

    # Uncommitted changes, staged and unstaged.
    diff_stats=$(git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null | awk '{added+=$1; deleted+=$2} END {printf "%d %d", added, deleted}')
    if [ -n "$diff_stats" ] && [ "$diff_stats" != "0 0" ]; then
        added=$(echo "$diff_stats" | cut -d' ' -f1)
        deleted=$(echo "$diff_stats" | cut -d' ' -f2)
        diff_info="${ICON_DIFF}${GREEN}+${added}${RESET}/${RED}-${deleted}${RESET}"
    fi
fi

# Context percentage, colored by how much headroom is left.
context_info=""
if [ -n "$used_pct" ]; then
    if [ "$used_pct" -lt 50 ]; then
        pct_color="${GREEN}"
    elif [ "$used_pct" -lt 80 ]; then
        pct_color="${YELLOW}"
    else
        pct_color="${RED}"
    fi
    context_info="${pct_color}${ICON_CONTEXT}${used_pct}%${RESET}"
fi

# Join the present segments with a single space; icons replace the separators.
output="$model_display"
for segment in "$repo_info" "$branch_info" "$diff_info" "$context_info"; do
    if [ -n "$segment" ]; then
        output="$output  $segment"
    fi
done

printf "%b" "$output"
