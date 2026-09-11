---
name: yolo
description: Ship the current branch end-to-end without stopping to ask — commit staged/unstaged work, push, open a PR, watch CI, merge once green, and where merging deploys, follow it to production and confirm the new build is actually serving. Use when the user says "yolo", "ship it", "commit push and merge", "just merge it", or otherwise wants the whole commit→PR→merge→deploy pipeline run autonomously. Do NOT use for review-only requests or when the user only wants a commit.
---

# yolo — commit, push, PR, watch CI, merge, verify in production

Run the full ship pipeline autonomously. **Done means running in production**,
not merged: where merging triggers a deploy, the run is not finished until the
new build is confirmed serving (step 7). The point of `yolo` is that the user
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

### 0. Commit FIRST, then review

Commit before review, not after. Review agents run in this same working tree,
and a dirty tree is shared mutable state between you and them.

This is not hypothetical. On a real run a review agent tried to clean up its own
scratch files, hit a permission denial on `rm`, fell back to
`git clean -f internal/store/`, and destroyed five untracked files — two of them
the main thread's in-progress tests, unrecoverable because they were never
committed. A second agent reverted an uncommitted edit that was mid-write.

Committing first makes agent scratch visibly untracked, makes `git clean`
survivable, and means the review reads a stable snapshot rather than a tree
changing underneath it.

- `git add -A` (stage everything) unless the user scoped specific paths.
- Write a real Conventional Commits message (`type(scope): subject`, imperative,
  ≤50-char subject; body only when the "why" isn't obvious). Never a placeholder.
- If nothing to commit AND the branch is already pushed, skip to step 2.

### 1. Review — mandatory, never skipped

Review is the reason to run yolo, not a preamble to it. This is the only review
the change is guaranteed to get — no required status check gates merges in this
repo, and other repos may have none either. Never assume GitHub will catch what
you skip.

- Run `/pr-review-toolkit:review-pr` (all aspects) against the committed diff
  (`git diff origin/<default-branch>...HEAD`).
- **Tell the agents they may read and report only.** They must not delete, move,
  or modify any file, and must not run `git clean`, `git checkout --`,
  `git stash`, or `git restore`. Scratch files they create are to be left in
  place and named in their report so the main thread can remove them. An agent
  that "tidies up" is editing a tree someone else is working in.
- Run it for **every** diff. Do not skip because the change looks small, is
  docs-only, is prose, or "obviously" has no executable code — that judgment is
  not yours to make here, and the cost of a needless review is far lower than the
  cost of an unreviewed change reaching `main` unchecked.
- **State the stakes in the prompt.** Findings track what the agents are told to
  look for: "review this diff" surfaces style, while naming what the change can
  destroy ("this migration runs against a live database holding 318
  irreplaceable rows") surfaces data loss. Say what is irreversible, what is
  production, and what cannot be regenerated.
- Apply what it recommends: fix Critical + Important issues directly. Suggestions
  are optional — apply if cheap/obvious, skip otherwise. Amend or add commits as
  you go; the branch is already committed, so fixes are ordinary commits.
- Don't stop to ask before applying fixes — that's the point of yolo. Only stop
  if a finding is ambiguous enough that guessing the fix risks breaking behavior.
- Re-run is not required after fixes; proceed straight to push.
- If the review cannot run, or does not return findings you can act on (including
  a `max_turns` timeout or a half-completed pass), treat it as not having run:
  say so plainly and STOP. Never merge something that was never reviewed while
  implying it was.

### 1b. Schema migrations — run it against real data before shipping

If the diff touches `migrations/` (or otherwise changes a schema), reading it is
not enough. Both of the worst bugs found on a real run were invisible in the
diff and only appeared when the migration was executed:

- **A cascade nobody mentioned.** Foreign keys were on, so `DROP TABLE videos`
  during a table rebuild fired `ON DELETE CASCADE` and silently emptied
  `video_index_notes` — a table the diff never names, joined by every search.
  No error, and the scanner that could have rebuilt it was deleted in the same
  change.
- **A plausible value that aborts the deploy.** One teacher name appearing twice
  made a name-join fan one row into two, failing on
  `UNIQUE constraint failed: videos_new.id` — naming neither the table at fault
  nor the duplicate.

So:

- Copy the production database and run the migration against the copy. **Copy
  the `-wal` and `-shm` files too** for SQLite — a copy of the `.db` alone reads
  stale committed state and will show you a migration that "did not run".
- Assert **row conservation on every table**, not just the one being altered.
  Count before, count after, compare. That single check catches both bugs above:
  a cascade is a count that dropped, a fan-out is a count that grew.
- Check the invariants the new schema claims. If a column caches something
  derived, verify no row disagrees with the function that derives it.
- Report the before/after table in the PR body. It is the evidence the migration
  is safe, and the reviewer cannot reproduce it.

Add a regression test that seeds the tables the migration does *not* mention.
A test that only seeds what the diff touches will pass while a neighbouring
table is being emptied.

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
- If there are genuinely no checks, skip **the CI watch only** (never the review
  in step 1) and go to step 5 — do not arm a Monitor that will just time out. With
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

**First, know what merging does.** In repos that deploy on merge, this step is
the deploy. Answer these three before merging anything that touches a schema,
a migration, or production config — and say the answers to the user:

1. **Does merging deploy?** Check for a deploy timer or workflow
   (`systemctl list-timers | grep -i deploy`, `.github/workflows/`,
   `deploy/*.sh`). A pull-based timer means merging ships within its interval
   with nobody pressing anything.
2. **Is it reversible?** A binary rollback does not undo a migration. If the app
   migrates on boot, a rolled-back binary meets a schema it cannot read, and the
   real recovery is a database restore. Confirm a pre-deploy snapshot exists —
   and that the deploy aborts when the snapshot fails, rather than proceeding
   without one.
3. **Would the health check notice?** Read the healthz query. One that names no
   columns (`SELECT count(*) FROM t`) passes under any schema, so an automatic
   rollback will report the old binary healthy while every page 500s. If it
   cannot detect the failure this change could cause, fix it in this PR.

Where any answer is bad, say so plainly in the PR body. The reviewer cannot see
what you checked.

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
   **Skip this entirely if the primary checkout is also the deploy checkout** —
   pulling there disarms a pull-based deploy and strands production on the old
   build. See step 7.
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
7. **Remove scratch files the review left behind.** Agents create probe files
   and are told (step 1) not to delete them. Check `git status` for untracked
   paths and clear the ones the report named. If a `rm` is permission-denied,
   say which files are left rather than reaching for `git clean`, which is what
   destroyed real work on a previous run.

### 7. If merging deploys — verify it actually shipped

Where step 5 established that merging triggers a deploy, "merged" is not
"shipped". Finish the job:

- Watch the deploy, don't assume it. A pull-based timer fires on its own
  schedule, so a run that happened *before* your merge will report "nothing to
  deploy" and mean nothing. Monitor the deploy unit's log for the commit SHA.
- Confirm the running version is yours — the deploy log naming your SHA, or the
  service restart timestamp moving.
- **Verify against the served artifact, not the checkout.** `git log` in the
  deploy directory shows what was *fetched*, which is not what is *running*.
  Fetch something the new build serves (a changed asset, a version endpoint) and
  assert the change is in it. A checkout at the right commit with a stale binary
  looks identical to a successful deploy from every angle except this one.

**Never run `git pull` in a deploy checkout.** This is the trap, and it is easy
to walk into while "tidying up" after a merge:

- A pull-based deploy typically decides whether to build by asking whether *its
  own* fetch moved HEAD. Advance HEAD yourself and the next run finds nothing to
  do, reports "nothing to deploy", and repeats that forever while the binary
  stays where it was. The site serves the old build indefinitely, and every log
  line says everything is fine.
- Observed on a real run: three merged PRs sat undeployed for 40 minutes across
  8 timer ticks, each logging `Already at a2deaab - nothing to deploy`, because
  the primary checkout — which was also the deploy checkout — had been pulled
  after each merge.
- Step 6's "sync the primary worktree" is what causes this when the primary IS
  the deploy checkout. **Check first**: if the repo's deploy script runs against
  the directory you are about to pull in, skip that sync and let the deploy do
  its own fetch.
- Know where you are. `hostname -I` against the address in the deploy script
  answers whether the dev box and production are the same machine — and when
  they are, an "unrelated" server on a port you were told to leave alone may be
  the live site.
- If a deploy is already stuck this way, run the deploy script by hand to
  recover, then fix the detection so it compares against the *deployed* commit
  (a stamp file written at binary swap) rather than against HEAD-before-fetch.
- For a schema change, verify the migration against the live database (copying
  the `-wal` too). Report the same before/after numbers the PR body promised.
- If it rolled back, say so immediately and loudly. Do not report a merge as a
  successful ship because CI was green.

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

Where merging deployed, add the deployed SHA and the evidence it is running —
plus, for a migration, the before/after numbers from the live database. "Merged"
and "shipped" are different claims; report the one you actually verified.

Name what review found and what you did about it. A run that fixed two data-loss
bugs before they reached production is the pipeline working, and the user cannot
see that from a green checkmark.

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

- **bonzofenix/workstation**: review happens locally (step 1), not on GitHub.
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
    at all — which is exactly why step 1 has no exceptions.

- **tangohub** (github.com/bonzofenix/tangohub): the required `review` check is
  known to flake on a `max_turns` timeout (see the user's memory). If the ONLY
  red check is `review` and it failed on max_turns, that is the known flake:
  re-run it once; if it still blocks a PR that is otherwise green, the documented
  unblock is toggling ruleset `20753720`. Do the re-run automatically; ask before
  touching the ruleset.

