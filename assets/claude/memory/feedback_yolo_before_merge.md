---
name: yolo-before-merge
description: "Finishing an implementation means running /yolo through to merge — it carries the mandatory review, so hand-rolling commit/push/PR skips it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f4076fd9-4b81-4230-8bc3-6798e35c6a26
  modified: 2026-09-12T00:36:16.283Z
---

When implementation work is done, run `Skill(yolo)` and let it finish the job. Do not hand-roll commit → push → `gh pr create`, and do not stop at a green PR to ask whether to merge.

**Why:** Two separate misreadings of this, both worth naming.

The first: an earlier version of this memory said only "use /yolo instead of `gh pr merge`", which reads as a rule about *how* to merge. So a finished implementation got a hand-rolled commit, push and PR, then stopped at green CI and offered to merge. The user: "you should always run it before asking to merge, merge is the last step of yolo right?" Merge is yolo's last step, not a separate decision to bring back.

The second, and the more expensive one: **yolo's step 1 is a mandatory review** (`/pr-review-toolkit:review-pr` against the committed diff — the skill says "Review is the reason to run yolo, not a preamble to it", and never to merge something unreviewed). Hand-rolling the pipeline does not just skip the merge — it silently skips the review. That is how tangotracker PR #60 reached green CI with no review at all. Green CI is not a substitute: CI runs lint and tests, the review is what reads the change.

Asked how autonomous this should be, the user chose "Always, no asking": straight through commit, review, push, PR, CI watch, merge, deploy follow. Stop only when CI actually fails, when review surfaces something real, or for something genuinely destructive.

**How to apply:** Invoke `Skill(yolo)` as the finishing move on any implementation — do not announce a finished PR and wait. If a PR was already opened by hand, still run yolo so the review step happens before merge. Order the skill enforces: commit FIRST (so review reads a stable snapshot and cannot revert uncommitted work), then review, then ship. Honour [[no-push-during-ci]] and [[worktrees]] alongside it.
