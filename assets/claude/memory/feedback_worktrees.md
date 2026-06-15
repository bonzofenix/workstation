---
name: feedback-worktrees
description: "Use git worktrees for all PR-bound work — including checking out existing PRs"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5546de7c-55aa-4a25-9391-d700a302b686
---

Use `EnterWorktree` whenever working on a PR — whether creating new work or checking out an existing PR to work on it.

**Why:** User explicitly requested worktrees for all PR-bound work. Missed once when "checkout this PR" was treated as a simple git op rather than the start of PR work.

**How to apply:** Any of these triggers → create worktree first:
- Starting a new feature/fix/bug that will become a PR
- `gh pr checkout <number>` to work on an existing PR
- Being asked to "look at", "work on", or "fix" a specific PR

**For existing PRs — correct flow:**
Do NOT use `EnterWorktree` with a name (creates a new branch). Instead create the worktree manually on the real PR branch so `gh pr view -w` works:
```bash
gh pr checkout <number>                          # fetch the PR branch into main worktree
git worktree add .claude/worktrees/<name> <branch>  # create worktree on that branch
```
Then use `EnterWorktree` with `path` to switch into it:
```bash
EnterWorktree(path: ".claude/worktrees/<name>")
```
