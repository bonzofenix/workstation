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

### 0. Review — mandatory, never skipped

Review is the reason to run yolo, not a preamble to it. This is the only review
the change is guaranteed to get — no required status check gates merges in this
repo, and other repos may have none either. Never assume GitHub will catch what
you skip.

- Run `/pr-review-toolkit:review-pr` (all aspects) against the working diff before
  committing.
- Run it for **every** diff. Do not skip because the change looks small, is
  docs-only, is prose, or "obviously" has no executable code — that judgment is
  not yours to make here, and the cost of a needless review is far lower than the
  cost of an unreviewed change reaching `main` unchecked.
- Apply what it recommends: fix Critical + Important issues directly. Suggestions
  are optional — apply if cheap/obvious, skip otherwise.
- Don't stop to ask before applying fixes — that's the point of yolo. Only stop
  if a finding is ambiguous enough that guessing the fix risks breaking behavior.
- Re-run is not required after fixes; proceed straight to commit.
- If the review cannot run, or does not return findings you can act on (including
  a `max_turns` timeout or a half-completed pass), treat it as not having run:
  say so plainly and STOP. Never merge something that was never reviewed while
  implying it was.

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
- First check whether there is anything to watch: `gh pr checks <num>`. Checks can
  take a few seconds to register after a push, so if it reports none, wait ~15s and
  probe once more before concluding there are none.
- If there are genuinely no checks, skip **the CI watch only** (never step 0) and
  go to step 5 — do not arm a Monitor that will just time out. With
  `Claude Code Review` disabled, that is the expected case in
  `bonzofenix/workstation`.
- When checks DO exist and gate the merge: watch them to completion. Prefer a
  **Monitor** on `gh pr checks <num>`
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
- Do NOT rely on `--delete-branch`. When the branch is checked out in a worktree,
  `gh` aborts that step with `cannot delete branch '<x>' used by worktree at ...`
  and — because it also tries to check out the base branch, which the primary
  worktree already holds — may print `fatal: 'main' is already used by worktree`
  and exit non-zero. **The merge itself still succeeded.** Never retry the merge
  on that error; verify state instead (next line), then delete branches in step 6.
- Confirm merged state (`gh pr view <num> --json state,mergedAt`) and report.
- If the repo has **no required status checks**, a PR merging with checks pending
  or absent is expected — do not report it as a misconfiguration. But if required
  checks ARE configured and a PR merged with them still pending, that IS a real
  gap: say so.

### 6. After merge — clean up

Run this automatically once the PR is merged; it is part of the pipeline, not an
optional offer.

1. **Sync the primary worktree**: `git -C <primary> pull --ff-only`. If it refuses
   because of dirty tracked files, see "Reconciling a dirty primary" below.
2. **Delete the remote branch**: `git push origin --delete <branch>`. Do this
   explicitly — `--delete-branch` in step 5 usually did not run. Verify with
   `git ls-remote --heads origin <branch>` (empty = gone); a `git fetch --prune`
   that deletes nothing means the branch is still on the remote.
3. **Remove the worktree**:
   - If this session created it via `EnterWorktree`: `ExitWorktree` with
     `action: "remove"`. This also deletes the branch, so step 4 will report
     `branch '<x>' not found` — that is success, not an error.
   - Otherwise: `git -C <primary> worktree remove <path>` — a session cannot
     remove the worktree it is running inside, so this must run from the primary.
4. **Delete the local branch**, if it still exists: `git branch -D <branch>`.
5. **Pull `main` again, now that the session is back on it.** `ExitWorktree`
   returns the session to the primary checkout, and the step-1 sync ran before
   the merge commit was reachable — so without this the local `main` sits behind
   the very commit just merged. Run `git pull --ff-only` and confirm
   `git log --oneline -1` shows the squash commit (`... (#<num>)`).
   Use `--ff-only` so a diverged local `main` fails loudly instead of
   silently creating a merge commit.
6. Confirm: `git worktree list`, `git worktree prune -v`, and `git status`.
   Verify the merged files are actually present in the primary checkout — a
   clean `git status` alone does not prove the pull landed.

### The squash-merge SHA trap

Squash merges create a NEW commit, so the branch's commits never match by hash.
Both `git log origin/main..HEAD` and `ExitWorktree` will therefore claim the
branch has unmerged work when the content landed perfectly.

**Never discard on that signal alone.** Verify by content first:

```sh
git diff origin/main <branch> -- <changed-paths>   # empty = content landed
```

Only when that is empty (or the sole differences are versions the merge
deliberately superseded) may you use `ExitWorktree` with `discard_changes: true`.
If real unique content exists, STOP and tell the user — do not discard.

### Reconciling a dirty primary

After copying changes into branches, the primary worktree still holds its own
copies, which block `pull --ff-only`. For each dirty file:

- `diff <file> <(git show origin/main:<file>)` — if identical, the local copy is
  redundant: `git checkout -- <file>`.
- If it differs, it holds work the PR did not include. Do NOT revert it. Stash
  only that file (`git stash push -m "<what it is>" <file>`), pull, then pop and
  verify the content survived.
- Untracked files that landed in the merge (e.g. a new script) also block the
  pull. Confirm byte-identical first, then `trash` the local copy.

### Report

PR URL, final check status, merged commit, and what cleanup removed. Keep it
terse. Call out anything deliberately left behind.

## Failure handling

- **Red required check:** read the failing job's log (`gh run view <run-id>
  --log-failed`). If it's a genuine failure, STOP, summarize the failure, do not
  merge. If it's a **known flake**, re-run it once (`gh run rerun --failed`);
  escalate to the user if it fails again.
- **Merge conflict / non-fast-forward:** STOP, report, don't force.
- **Protected branch / missing approval:** report exactly what the branch
  protection requires; don't try to bypass it.

## Repo-specific notes

Config facts below were observed 2026-08 and are live-mutable. Verify with
`gh api repos/:owner/:repo/rulesets` and `gh api repos/:owner/:repo/actions/workflows`.
**If what you observe disagrees with this section, trust the observation** and
tell the user the note is stale — never dismiss evidence because this file
predicts otherwise.

- **bonzofenix/workstation**: review happens locally (step 0), not on GitHub.
  - Ruleset `protect-main` (`20983003`) has three rules: `deletion`,
    `non_fast_forward`, and `pull_request` — and **no `required_status_checks`**.
    That absence is intentional; do not "fix" it or report it as a defect.
  - The `pull_request` rule requires 0 approvals, so it does not gate ordinary
    merges, but it does force changes through a PR and sets
    `require_extra_approval_for_unattributed_changes: true`. An unattributed
    commit **will** require an approval. A merge refused on that ground is a
    real gate, not the "no checks" case — report it per "Protected branch /
    missing approval" and do not bypass it.
  - The `Claude Code Review` workflow is disabled (`disabled_manually`); it
    duplicated the local review. The `Claude Code` workflow (the `@claude`
    mention responder) stays active. So PRs here are expected to have no checks
    at all — which is exactly why step 0 has no exceptions.

- **tangohub** (github.com/bonzofenix/tangohub): the required `review` check is
  known to flake on a `max_turns` timeout (see the user's memory). If the ONLY
  red check is `review` and it failed on max_turns, that is the known flake:
  re-run it once; if it still blocks a PR that is otherwise green, the documented
  unblock is toggling ruleset `20753720`. Do the re-run automatically; ask before
  touching the ruleset.

