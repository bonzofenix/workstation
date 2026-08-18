#!/usr/bin/env bash
# PreToolUse hook: enforce "use a worktree for PR-bound work". Blocks
# branch-creating git commands run from a plain checkout instead of a
# .claude/worktrees/ directory, and nudges toward EnterWorktree instead
# of silently allowing a stray branch.
#
# Fail-closed: if the interpreter is missing or the hook payload can't be
# parsed, block (exit 2) with a message rather than silently waving the
# command through — a guard that fails open provides false assurance.
set -euo pipefail

input="$(cat)"

# python3 is required to parse the JSON payload. If it's missing we can't
# make a safe decision, so block loudly rather than no-op.
if ! command -v python3 >/dev/null 2>&1; then
  echo "worktree-guard: python3 not found; cannot evaluate command. Blocking to fail safe." >&2
  exit 2
fi

# Parse tool_name, command, and cwd in one shot. On any parse error the
# `||` branch fires and we fail closed. Fields are newline-separated;
# embedded newlines in the command don't matter — we only need line 1
# (tool_name), line 2 (command), line 3 (cwd), and read them positionally.
parsed="$(printf '%s' "$input" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("tool_name", ""))
print(d.get("tool_input", {}).get("command", "").replace("\n", " "))
print(d.get("cwd", "") or "")
')" || {
  echo "worktree-guard: could not parse hook input JSON. Blocking to fail safe." >&2
  exit 2
}

tool_name="$(printf '%s\n' "$parsed" | sed -n '1p')"
command="$(printf '%s\n' "$parsed" | sed -n '2p')"
cwd="$(printf '%s\n' "$parsed" | sed -n '3p')"

# Only Bash tool calls carry shell commands; anything else is not our concern.
[ "$tool_name" = "Bash" ] || exit 0
[ -n "$command" ] || exit 0

# Only fire on commands that create a new local branch. Case-insensitive,
# and tolerant of a `git -C <path>` global option before the subcommand.
# This is a heuristic nudge, not a security boundary: exotic spellings can
# slip through, which is acceptable for a guardrail that only prompts.
if ! printf '%s' "$command" | grep -qiE '(^|[; &]|&&)[[:space:]]*git[[:space:]]+(-C[[:space:]]+[^ ]+[[:space:]]+)?(checkout[[:space:]]+-b|switch[[:space:]]+-c|branch[[:space:]]+[^-])'; then
  exit 0
fi

# cwd must be resolvable to decide worktree-vs-plain. Empty means the
# payload omitted it — block explicitly rather than guessing.
if [ -z "$cwd" ]; then
  echo "worktree-guard: hook payload had no cwd; cannot confirm worktree. Blocking to fail safe." >&2
  exit 2
fi

case "$cwd" in
  */.claude/worktrees/*)
    exit 0 ;;
esac

# Not inside a worktree — block and point at the standing rule.
cat >&2 <<'EOF'
Blocked: this looks like the start of PR-bound work (creating a new git
branch) outside a Claude Code worktree.

Standing rule: use EnterWorktree before any feature/fix/bug/PR checkout
that involves writing code.

If a plain branch is actually correct here, ask the user to confirm, then
proceed — this hook only checks cwd, it can't judge intent.
EOF
exit 2
