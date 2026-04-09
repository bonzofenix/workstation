---
name: good-morning
description: Show all your open PRs from GitHub.com and GitHub Enterprise with status, reviews, and CI jobs
allowed-tools:
  - Bash(gh pr list*)
  - Bash(gh pr view*)
  - Bash(gh api*)
  - Bash(gh pr checks*)
---

# Good Morning - PR Dashboard

Display all your open PRs from both GitHub.com and GitHub Enterprise (github.tools.sap) in a comprehensive table showing:
- PR link and title
- Review status (who needs to review)
- CI job status (passing/failing/pending)
- Unresolved comments indicator

## Steps

### Step 1: Fetch Open PRs from GitHub.com

```bash
gh pr list --author @me --state open --json number,title,url,repository,isDraft,reviewDecision --limit 100
```

### Step 2: Fetch Open PRs from GitHub Enterprise

```bash
GH_HOST=github.tools.sap gh pr list --author @me --state open --json number,title,url,repository,isDraft,reviewDecision --limit 100
```

### Step 3: For Each PR, Gather Detailed Information

For each PR, run in parallel:

**a) Get reviewers and review status:**
```bash
gh pr view <number> -R <repo> --json reviews,reviewRequests
```

**b) Get CI checks:**
```bash
gh pr checks <number> -R <repo> --json name,status,conclusion
```

**c) Get unresolved comments count:**
```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
        }
      }
    }
  }
}'
```

Count threads where `isResolved: false`.

For Enterprise PRs, add `GH_HOST=github.tools.sap` before commands.

### Step 4: Categorize CI Job Status

For each PR, summarize CI jobs:
- **Passing**: All checks successful
- **Failing**: Any check failed
- **Pending**: Jobs still running
- **N/A**: No checks configured

Count jobs in each category: "3 passing, 1 failing"

### Step 5: Determine Review Status

Parse reviews and reviewRequests to show:
- **Approved**: ✅ + reviewer names
- **Changes requested**: ❌ + reviewer names  
- **Pending review**: 👀 + reviewer names
- **No reviewers**: ⚠️ (if no one assigned)

### Step 6: Display Results Table

Format as a markdown table:

```markdown
## GitHub.com PRs

| PR | Title | Reviews | CI Status | Comments |
|----|-------|---------|-----------|----------|
| [#123](url) | Fix auth bug | ✅ @alice, 👀 @bob | ✅ 5 passing | ✅ None |
| [#124](url) | Add feature | ❌ @charlie | ❌ 2 passing, 1 failing | ⚠️ 3 unresolved |

## GitHub Enterprise (github.tools.sap) PRs

| PR | Title | Reviews | CI Status | Comments |
|----|-------|---------|-----------|----------|
| [#456](url) | Update deps | 👀 @dave | ⏳ 3 pending | ✅ None |
```

### Step 7: Add Summary Statistics

At the top, show:
```markdown
# Good Morning! ☀️

**Summary**: X open PRs (Y on GitHub.com, Z on Enterprise)
- ✅ N approved and passing
- ⚠️ N needing attention (failing CI or unresolved comments)
- 👀 N awaiting review
```

## Display Symbols

- ✅ Green check: Approved/Passing/No issues
- ❌ Red X: Changes requested/Failing
- ⏳ Hourglass: Pending/Running
- 👀 Eyes: Awaiting review
- ⚠️ Warning: Needs attention
- 🚧 Draft PR indicator

## Error Handling

- **No PRs found**: "No open PRs found. Great job! 🎉"
- **GitHub Enterprise unavailable**: Note which host failed, continue with available data
- **API rate limits**: Show partial data with note about rate limit
- **Network errors**: Display error and available cached data if any

## Performance Optimization

- Fetch PR lists in parallel (GitHub.com and Enterprise simultaneously)
- For each PR's detailed data, batch API calls where possible
- Use `--json` format for efficient parsing
- Limit to 100 PRs per host (configurable)

## Usage

```bash
/good-morning           # Show all open PRs
```

## Notes

- Draft PRs are marked with 🚧
- PRs are sorted by update time (most recent first)
- CI status shows aggregate of all checks
- Review status shows latest state from each reviewer
- Enterprise host is hardcoded to `github.tools.sap`
