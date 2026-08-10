---
name: yolo
description: Ship the current branch end-to-end without stopping to ask — commit staged/unstaged work, push, open a PR, watch CI, and merge once green. Use when the user says "yolo", "ship it", "commit push and merge", "just merge it", or otherwise wants the whole commit→PR→merge pipeline run autonomously. Do NOT use for review-only requests or when the user only wants a commit.
---

# yolo — commit, push, PR, watch CI, merge

Run the full ship pipeline autonomously. The point of `yolo` is that the user
has opted into NOT being asked at each step — proceed through all stages without
pausing for confirmation, stopping ONLY on a hard failure (merge conflict, red
CI that isn't a known flake, a protected-branch rejection).

## Preconditions (check fast, fail loud)

1. Confirm you are in a git repo and NOT on the default branch (`main`/`master`).
   - If on the default branch, create one first:
     `git switch -c <short-kebab-feature-name>` derived from the change.
   - If a worktree/session branch already exists, use it.
2. `gh auth status` must be usable. If `gh` is missing/unauthed, stop and tell
   the user to auth (`gh auth login`) — do not fall back to raw API.

## Pipeline

### 1. Commit
- `git add -A` (stage everything) unless the user scoped specific paths.
- Write a real Conventional Commits message (`type(scope): subject`, imperative,
  ≤50-char subject; body only when the "why" isn't obvious). Never a placeholder.
- If nothing to commit AND the branch is already pushed, skip to step 3.

### 2. Push
- `git push -u origin HEAD`.

### 3. PR
- If a PR for this branch already exists (`gh pr view --json number,url,state`),
  reuse it. Otherwise `gh pr create --fill` (or a written title/body summarizing
  what and why). Base = the repo default branch unless told otherwise.
- Capture the PR number + URL; report the URL to the user.

### 4. Watch CI
- Watch the checks to completion. Prefer a **Monitor** on `gh pr checks <num>`
  that emits one line per terminal check state and exits when the run completes:
  poll `gh pr checks <num> --json name,state,bucket`, emit any check that left
  `pending`, and stop when none are pending. Cover ALL terminal states
  (`pass`/`fail`/`cancel`/`skipping`), not just success — silence must not read
  as green.
- Use `gh run watch` / `gh pr checks --watch` only for a single obvious workflow.

### 5. Merge
- When all required checks are green: `gh pr merge <num> --squash --auto`
  (squash unless the repo convention is otherwise; `--auto` lets it land the
  instant checks finish if there's any lag).
- Delete the branch on merge (`--delete-branch`) when the user works in
  throwaway branches/worktrees.
- Confirm merged state (`gh pr view <num> --json state,mergedAt`) and report.

## Failure handling

- **Red required check:** read the failing job's log (`gh run view <run-id>
  --log-failed`). If it's a genuine failure, STOP, summarize the failure, do not
  merge. If it's a **known flake**, re-run it once (`gh run rerun --failed`);
  escalate to the user if it fails again.
- **Merge conflict / non-fast-forward:** STOP, report, don't force.
- **Protected branch / missing approval:** report exactly what the branch
  protection requires; don't try to bypass it.

## Repo-specific notes

- **tangohub** (github.com/bonzofenix/tangohub): the required `review` check is
  known to flake on a `max_turns` timeout (see the user's memory). If the ONLY
  red check is `review` and it failed on max_turns, that is the known flake:
  re-run it once; if it still blocks a PR that is otherwise green, the documented
  unblock is toggling ruleset `20530825`. Do the re-run automatically; ask before
  touching the ruleset.

## After merge

- If working in a git worktree that's now merged, offer to clean it up.
- Report: PR URL, final check status, merged commit. Keep it terse.
