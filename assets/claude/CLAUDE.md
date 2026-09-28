# Working practices

These apply to every project unless a project's own CLAUDE.md overrides them.

## Keep replies short

Final reply to the user: at most 5 lines unless they ask for detail. No
headers or bullet lists for status reports. Result first, then the one
decision the user must make, if any. Do not relay review or subagent findings
item by item.

## Review before opening a PR

Run the `pr-review-toolkit:review-pr` agents against `git diff main...HEAD`
before `gh pr create`, on **every** diff — including copy-only, docs-only and
one-line changes. Opening a PR is not the finish line; an unreviewed PR is
unfinished work.

These repos generally have no required status checks, so the local review
agents are the only review a change gets before it reaches `main`. Skipping
them means shipping unreviewed. They also catch real bugs: on one PR
they independently found an inverted mobile `object-position` and a 737 KB
orphaned asset still deploying.

Manual verification (visual checks, parity counts, curl-ing a route) is a
complement to the review, never a substitute. If the review cannot run or
returns nothing actionable, say so plainly rather than proceeding as though it
had run.

Note that `/yolo` **includes** this review as step 0 — it does not skip it. The
reason to hesitate before `/yolo` is untested behaviour (an auth flow never run
against real credentials, say), not a missing review.

## Branch, don't commit to main

Work on a branch, in a worktree when the project uses them. Do not commit
directly to the default branch.

## File deletion

Never use `rm` or `rmdir`. Always use `trash` so files go to the system
Trash and can be recovered. `rm`/`rmdir` are hard-denied in settings.json;
reaching for them just wastes a turn.
