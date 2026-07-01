---
name: analyze-ci
description: Analyze CI checks for current branch's PR - polls pending checks until complete, diagnoses failures, auto-fixes straightforward issues, and suggests fixes for complex ones.
allowed-tools:
  - Bash(gh pr view*)
  - Bash(gh pr checks*)
  - Bash(gh run view*)
  - Bash(gh run rerun*)
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
  - Bash(*poll_ci.py*)
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

Display summary on a single line with check names:

```bash
gh pr checks --json name,state,bucket,workflow | jq -r '
  group_by(.bucket) | 
  map({bucket: .[0].bucket, count: length, items: map(.name)}) | 
  .[] | 
  "\(.bucket | ascii_upcase): \(.count) - \(.items | join(", "))"
'
```

Format: **CI Status:** ✅ N passed | 🟡 N pending | ❌ N failed

Then list check names per bucket:
- **Passed:** check1, check2, check3
- **Pending:** check4, check5
- **Failed:** check6

If all passed and none pending → report success and stop.

## Step 3: Wait for Pending Checks — Stream Dispatch on Failure

If any checks have `bucket: "pending"`:

1. List which checks are still running with their start times
2. Tell the user: "N checks still running. Polling every 30s — dispatching fix agents as failures are found..."
3. **Do NOT use `gh pr checks --watch`** — it blocks as a single long-lived command, hits bash timeout limits, and dies on transient network errors.
4. Gather **fork context** once now (used by every sub-agent dispatched during polling):
   ```bash
   gh pr view --json number,headRefName,baseRefName,title,body
   git log --oneline -10
   git diff $(gh pr view --json baseRefName -q .baseRefName)...HEAD --stat
   ```
5. Launch `poll_ci.py` in background (completion signal):
   ```bash
   find ~/.claude -name "poll_ci.py" -path "*/analyze-ci/*" | head -1
   python3 <path> --interval 30 --timeout 3600
   ```
   Run with `run_in_background: true`, `timeout: 3600000`.
6. **Polling loop** — run until `poll_ci.py` background task completes:
   Every 30s, fetch current check state:
   ```bash
   gh pr checks --json name,state,bucket,workflow,link
   ```
   For each check that just flipped to `bucket: "fail"` (not seen as failed before this iteration):
   - Group it with matrix siblings already known to have failed (same base name)
   - **Immediately dispatch a fix sub-agent** for the group (see sub-agent prompt below)
   - Track dispatched groups — do not re-dispatch a group already dispatched
   - Continue polling; do not wait for the agent to finish before polling again

7. When `poll_ci.py` signals completion, do a final fetch to catch any last failures missed between poll ticks, dispatch agents for any new groups not yet dispatched, then proceed.
8. If all checks passed (no failures ever seen) → report success and stop.

## Step 4: Fix Sub-Agents — Dispatch and Collect

### 4a: Grouping Rule (apply at dispatch time during polling)

For each newly-failed check:
1. Extract run ID from link: `https://github.com/OWNER/REPO/actions/runs/RUN_ID/...`
2. Derive **base job name** by stripping trailing ` (...)` suffix:
   - `test (postgres-14)` → `test`
   - `build / lint (node-18)` → `build / lint`
   - `integration-tests (mysql, ubuntu)` → `integration-tests`
3. If a group with this base name was already dispatched, skip (matrix sibling handled). If a group exists but agent not yet dispatched, add sibling and dispatch now.

### 4b: Sub-Agent Prompt (fill in per group at dispatch time)

Each agent works in isolation — no shared state with other agents.

```
You are a CI fix agent. Work independently; do not reference other CI groups.

## Fork Context
- Repo: <OWNER/REPO>
- PR branch: <BRANCH_NAME>
- Base branch: <BASE_BRANCH>
- PR title: <PR_TITLE>
- Recent commits:
<GIT_LOG_ONELINE_10>
- Changed files (diff stat vs base):
<GIT_DIFF_STAT>

## Your Group
- Base job name: <BASE_JOB_NAME>
- Is matrix group: <true|false>
- Checks in this group:
  - <CHECK_NAME_1> | Run ID: <RUN_ID_1>
  - <CHECK_NAME_2> | Run ID: <RUN_ID_2>  ← omit if single

## Tasks

1. Fetch failed job logs. If matrix group, fetch all variants in parallel:
   gh run view <RUN_ID> --log-failed
   If logs too large:
   gh api repos/<OWNER/REPO>/actions/jobs/<JOB_ID>/logs

2. Parse logs to identify:
   - Error type: compilation | test failure | lint | format | type error | dependency | infra/env
   - Affected files: paths and line numbers
   - Exact error messages
   - If matrix: are failures consistent across variants, or variant-specific?

3. Classify fixability:
   AUTO-FIX if ALL true:
   - Error identifies exact file and location
   - Fix is mechanical (formatting, linting, import ordering, whitespace, EOF newlines)
   - Fix does not alter program behavior or logic
   - High confidence the fix resolves the failure

   SUGGEST-ONLY if ANY true:
   - Fix requires understanding business logic
   - Multiple valid approaches exist
   - Error is in test assertions or expected values
   - Error relates to build config, dependencies, or infrastructure
   - Error is a flaky test or timing issue
   - Error is a security scan finding

   INFRA if ANY true:
   - CF route 404, route/space conflicts, deploy service down, network errors, external service unavailable

4. If AUTO-FIX:
   - Read affected file(s)
   - If matrix variants fail in different files, fix each separately; otherwise fix once
   - Run local formatter/linter if available (npx prettier, npx eslint --fix, go fmt)
   - Stage AND commit immediately:
     git add <file>
     git commit -m "fix: resolve <BASE_JOB_NAME> CI failure

     - <what was wrong and what was changed>"
   Do not leave fixes staged — commit them so parallel agents don't conflict on the index.

5. Return a structured result:
   {
     "group": "<BASE_JOB_NAME>",
     "matrix_variants": ["<CHECK_NAME_1>"],
     "classification": "auto-fixed | suggest-only | infra | unknown",
     "error_type": "<type>",
     "affected_files": ["<path:line>"],
     "error_snippet": "<exact error text>",
     "matrix_consistent": true | false | null,
     "fix_applied": "<description or null>",
     "suggested_fix": "<description or null>"
   }
```

### 4c: Collect Results

After all agents complete (all dispatched during polling + any dispatched after final fetch), collect their structured results. Proceed to Step 4d.

### 4d: Infra-Only Auto-Retrigger

If **all** groups returned `"classification": "infra"`, automatically retrigger all failed run IDs:

```bash
gh run rerun <run-id> --failed
```

Report:
> All failures are CI infrastructure issues (not code). Retriggered failed jobs. Monitor with `/analyze-ci`.

Do **not** retrigger if any group is code-related.

## Step 5: Verify Commits

Each auto-fix agent commits independently as it finishes. After all agents complete:

1. Check what was committed: `git log --oneline HEAD~5..HEAD`
2. Check for anything staged but not committed: `git diff --staged`
3. If staged changes exist (agent staged but didn't commit), commit them:
   ```bash
   git commit -m "$(cat <<'EOF'
   fix: resolve CI failures

   - [specific fix 1]
   - [specific fix 2]
   EOF
   )"
   ```
4. **Do NOT push.** Tell the user:
   > N fix commit(s) ready locally. Review with `git log --oneline HEAD~N..HEAD` and `git diff HEAD~N` then push when ready.

If no auto-fixes were applied and nothing is staged, skip this step.

## Step 6: Final Report

```
## CI Analysis Complete

### Overall: N passed / N failed (M auto-fixed, K need attention)

### Auto-fixed ✅
- [file:line] — [what was wrong] → [what was changed]
  (covers: check-name-1, check-name-2)  ← for matrix groups, list all variants

### Needs Attention ⚠️
- **[Base Job Name]** *(matrix: variant-1, variant-2)*: [root cause]
  - File: [path:line]
  - Error: [snippet]
  - Matrix consistent: yes/no
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
