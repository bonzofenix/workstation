---
name: feedback-worktrees
description: Use git worktrees for all PR-bound work (features, fixes, bugs)
metadata:
  type: feedback
---

Use `EnterWorktree` at the start of any feature, bug fix, or task that will become a PR.

**Why:** User explicitly requested worktrees be prioritized for all PR-bound work.

**How to apply:** Before writing any code for a new feature/fix/bug, create a worktree via `EnterWorktree`. Do not work directly on `main` for PR work.
