---
name: good-morning
description: Show all your open PRs from GitHub.com and GitHub Enterprise with status, reviews, and CI jobs
allowed-tools:
  - Bash(python* pr_dashboard.py)
  - Bash(gh search prs*)
  - Bash(gh pr view*)
  - Bash(gh api*)
  - Bash(gh pr checks*)
---

# Good Morning - PR Dashboard

Display all your open PRs from GitHub.com and any configured GitHub Enterprise hosts in a comprehensive dashboard showing:
- PR link and title
- Review status (approved, changes requested, pending)
- CI job status (passing/failing/pending)
- Unresolved comments count
- Draft status

## Configuration

Add to `~/.bash_profile` or `~/.zshrc`:

```bash
export GITHUB_REMOTES="github.com,github.enterprise.local"
```

The script will fetch PRs from all configured hosts in parallel.

## Implementation

Run the Python script and display its full output directly in your response:

```bash
python3 ~/.claude/skills/good-morning/pr_dashboard.py
```

**IMPORTANT**: After running the script, you MUST display the complete output in your response text (not just in the tool result). Copy the entire dashboard output and present it to the user so they can see and click the URLs directly.

The script:
- Reads GitHub hosts from `GITHUB_REMOTES` environment variable
- Fetches PRs from all configured hosts in parallel
- Fetches detailed PR information (reviews, checks, comments) in parallel using ThreadPoolExecutor
- Categorizes PRs into priority buckets
- Formats output with clear status indicators

## Manual Steps (if script unavailable)

### Step 1: Fetch Open PRs

```bash
# GitHub.com
gh search prs --author=@me --state=open --json number,title,url,repository,updatedAt,isDraft --limit 100

# Enterprise
GH_HOST=github.tools.sap gh search prs --author=@me --state=open --json number,title,url,repository,updatedAt,isDraft --limit 100
```

### Step 2: For Each PR, Gather Details (in parallel)

**a) Reviews and review requests:**
```bash
gh pr view <number> -R <repo> --json reviews,reviewRequests
```

**b) CI checks (use `state` field, not `status`):**
```bash
gh pr checks <number> -R <repo> --json name,state
```

**c) Unresolved comments:**
```bash
gh api graphql -f query='{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: NUMBER) {
      reviewThreads(first: 100) {
        nodes { isResolved }
      }
    }
  }
}'
```

For Enterprise PRs, prefix with `GH_HOST=github.tools.sap`.

### Step 3: Categorize PRs

**Needs Attention:**
- Has changes requested, OR
- Has failing CI checks, OR
- Has unresolved comments

**Awaiting Review:**
- Has pending review requests, OR
- No reviewers assigned

**Approved and Passing:**
- Approved by reviewers AND
- All CI checks passing

### Step 4: Display Summary

```
# Good Morning! ☀️

**📊 X total open PRs** (Y on GitHub.com, Z on Enterprise)

---

## 🚨 Top Priority - Needs Attention:

- 🚧 https://github.com/owner/repo/pull/123 - Title | ❌ Changes requested by @reviewer | 3 failing checks | 5 unresolved comments

---

## 👀 Awaiting Review:

- https://github.com/owner/repo/pull/456 - Title | 👀 Waiting on @reviewer | ⏳ 2 pending checks

---

## ✅ Approved and Passing:

- https://github.com/owner/repo/pull/789 - Title | ✅ Approved by @reviewer | ✅ All 15 checks passing

---

**Key Issues to Address:**
- 🔥 **N PRs with changes requested** need updates
- ⚠️ **N failing CI checks** across all PRs
- 💬 **N total unresolved comments**
```

## Display Symbols

- ✅ Approved/Passing
- ❌ Changes requested/Failing
- ⏳ Pending/Running
- 👀 Awaiting review
- ⚠️ No reviewers
- 🚧 Draft PR

## Error Handling

- **No PRs found**: "No open PRs found. Great job! 🎉"
- **Host unavailable**: Continue with available data, note error
- **API rate limit**: Show partial data with note
- **Network errors**: Display error and retry

## Performance

- Python script uses ThreadPoolExecutor for parallel API calls
- Fetches up to 10 PR details concurrently
- Batch GraphQL queries where possible
- 30-second timeout per API call

## Notes

- **IMPORTANT**: Output uses explicit URLs (not markdown links) for direct clickability in terminals
- **IMPORTANT**: Must set `GITHUB_REMOTES` environment variable in `~/.bash_profile` or `~/.zshrc`
- Check field is `state`, not `status` (SUCCESS/FAILURE/PENDING/SKIPPED)
- PRs sorted by priority (changes requested, failing checks, unresolved comments)
- Supports multiple GitHub Enterprise hosts
- Format: `- [draft emoji] URL - Title | status indicators`
- Standup briefing appended at bottom: finds most recent commit day, lists substantive commits per PR
- Noise commits filtered: merge commits and CI trigger/re-run commits excluded from standup
