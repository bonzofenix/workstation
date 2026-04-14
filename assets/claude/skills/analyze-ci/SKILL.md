---
name: analyze-ci
description: Analyze CI checks for current branch's PR - polls pending checks until complete, diagnoses failures, auto-fixes straightforward issues, and suggests fixes for complex ones.
allowed-tools:
  - Bash(gh pr view*)
  - Bash(gh pr checks*)
  - Bash(gh run view*)
  - Bash(gh api*)
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash(git diff*)
  - Bash(git add*)
  - Bash(git commit*)
  - Bash(git status*)
  - Bash(npx *)
  - Bash(go fmt*)
  - Bash(gofmt*)
---

# Analyze CI

Analyze CI checks for the current branch's PR. Polls pending checks until all complete, diagnoses failures, auto-fixes straightforward issues, and suggests fixes for the rest.

## Prerequisites

- **GitHub CLI**: Authenticated via `gh auth login`
- **Current Branch**: Has an open PR on GitHub
- **Clean Working Tree**: No uncommitted changes (required for auto-fix commits)

## Workflow

1. Detect PR and check merge status
2. Fetch CI check status
3. Wait for pending checks (if any)
4. Analyze failures
5. Classify fixability and apply auto-fixes
6. Commit fixes (if any)
7. Report results

---

## Step 1: Detect PR and Check Merge Status

```bash
gh pr view --json number,state,mergedAt,mergedBy,headRefName
```

- If **no PR found**: report "No PR for current branch" and stop
- If **state is MERGED**: report merge time and author, then stop
- Otherwise: continue with the PR number

## Step 2: Fetch CI Check Status

```bash
gh pr checks --json name,state,bucket,workflow,link,completedAt,startedAt
```

Categorize each check by `bucket`:
- `pass` → passed
- `fail` → failed
- `pending` → still running
- `skipping` / `cancel` → skipped/cancelled

Display summary:

```
CI Status:
  ✅ Passed:  N
  🟡 Pending: N
  ❌ Failed:  N
  ⏭️  Skipped: N
```

If all passed and none pending → report success and stop.

## Step 3: Wait for Pending Checks

If any checks have `bucket: "pending"`:

1. List which checks are still running with their start times
2. Tell the user: "N checks still running. Waiting for completion..."
3. Run:
   ```bash
   gh pr checks --watch --interval 30
   ```
   This blocks until all checks complete, printing updates every 30 seconds.
4. After watch completes, re-fetch final status:
   ```bash
   gh pr checks --json name,state,bucket,workflow,link
   ```
5. If all passed after waiting → report success and stop

If the user interrupts the watch, report whatever status is available at that point and proceed to analyze any failures found so far.

## Step 4: Analyze Failures

For each failed check:

1. Extract the run ID from the check link (format: `https://github.com/OWNER/REPO/actions/runs/RUN_ID/...`)
2. Fetch failed job logs:
   ```bash
   gh run view <run-id> --log-failed
   ```
3. If logs are too large, fetch specific job logs:
   ```bash
   gh api repos/{owner}/{repo}/actions/jobs/{job-id}/logs
   ```
4. Parse logs to identify:
   - **Error type**: compilation, test failure, lint violation, format issue, type error, dependency issue, infra/env problem
   - **Affected files**: file paths and line numbers from error output
   - **Error messages**: exact error text

## Step 5: Classify and Fix

### Auto-fix Criteria

Auto-fix when **ALL** of these are true:
- Error identifies exact file and location
- Fix is mechanical (formatting, linting, import ordering, whitespace, EOF newlines)
- Fix does not alter program behavior or logic
- High confidence the fix resolves the CI failure

### Suggest-only Criteria

Suggest only when **ANY** of these are true:
- Fix requires understanding business logic
- Multiple valid approaches exist
- Error is in test assertions or expected values
- Error relates to build config, dependencies, or infrastructure
- Error is a flaky test or timing issue
- Error is a security scan finding

### Auto-fix Workflow

For each auto-fixable issue:

1. Read the affected file
2. Apply the fix using the Edit tool
3. If a local formatter/linter is available, run it to verify:
   ```bash
   # Examples — use whichever applies to the project
   npx prettier --write <file>
   npx eslint --fix <file>
   go fmt <file>
   ```
4. Confirm the fix looks correct
5. Stage the file: `git add <file>`

### Suggest-only Workflow

For each non-auto-fixable issue:

1. Show the root cause and relevant error snippet
2. Identify the affected file(s) and line number(s)
3. Describe the specific fix approach
4. If possible, show the code change needed (but do not apply it)

## Step 6: Commit Fixes

After all auto-fixes are applied:

1. Verify staged changes: `git diff --staged`
2. Commit with conventional commit format:
   ```bash
   git commit -m "$(cat <<'EOF'
   fix: resolve CI failures

   - [specific fix 1]
   - [specific fix 2]
   EOF
   )"
   ```
3. If fixes span categorically different areas (e.g., formatting AND a test snapshot update), use separate commits.
4. **Do NOT push.** Tell the user:
   > Fixes committed locally. Review with `git diff HEAD~1` and push when ready.

If no auto-fixes were applied, skip this step.

## Step 7: Final Report

```
## CI Analysis Complete

### Overall: N passed / N failed (M auto-fixed, K need attention)

### Auto-fixed ✅
- [file:line] — [what was wrong] → [what was changed]

### Needs Attention ⚠️
- **[Check Name]**: [root cause]
  - File: [path:line]
  - Error: [snippet]
  - Suggested fix: [description]

### Passed ✅
- [list of passing check names]

### Next Steps
- [ ] Review auto-fix commit: `git diff HEAD~1`
- [ ] Push changes: `git push`
- [ ] Address remaining failures manually
```

## Error Handling

- **No PR found**: Report and stop — do not attempt to find checks without a PR
- **gh CLI auth failure**: Tell user to run `gh auth login`
- **Rate limiting**: If GitHub API returns 429, wait and retry once
- **Empty logs**: If `--log-failed` returns nothing, try fetching full logs via `gh api`
- **Dirty working tree**: If uncommitted changes exist, skip auto-fix and only report suggestions

## Limitations

- Cannot fix issues that require dependency installation or build system changes
- Cannot fix flaky tests — only reports them
- Auto-fix is conservative: when in doubt, suggests rather than fixes
- Does not push commits — user must review and push manually
