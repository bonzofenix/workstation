---
name: reference-memory-source
description: Source of truth for Claude memory files is ~/workstation/assets/claude/memory/
metadata:
  type: reference
---

Source of truth for all Claude memory files: `~/workstation/assets/claude/memory/`

These sync to `~/.claude/projects/-Users-myuser-workspace-app-autoscaler/memory/` (and similar per-project paths).

**How to apply:** Always write memory changes to `~/workstation/assets/claude/memory/` first, then copy to the project path. Or write to both. Never only write to the project path — changes there won't persist across workstation resets.
