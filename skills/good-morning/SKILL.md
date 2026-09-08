---
name: good-morning
description: Morning dashboard showing open PRs from GitHub.com and GitHub Enterprise plus currently assigned SAP Jira tickets
allowed-tools:
  - Bash(python* pr_dashboard.py)
  - Bash(gh search prs*)
  - Bash(gh pr view*)
  - Bash(gh api*)
  - Bash(gh pr checks*)
  - mcp__sap-jira__jira_search
  - mcp__sap-jira__jira_get_issue
---

# Good Morning - PR & Jira Dashboard

Display all your open PRs from GitHub.com and any configured GitHub Enterprise hosts, plus currently assigned SAP Jira tickets. Dashboard shows:
- PR link and title
- Review status (approved, changes requested, pending)
- CI job status (passing/failing/pending)
- Unresolved comments count
- Draft status
- Assigned Jira tickets with status and priority
- **PRs where you are a reviewer** (separate section, with your review state per PR)

## Requirements

- SAP VPN must be connected (both `mcp.jira.tools.sap` and `github.tools.sap` are SAP-internal)
- `sap-jira` MCP server configured: `claude mcp add sap-jira --transport http https://mcp.jira.tools.sap/mcp`
- `GITHUB_REMOTES=github.com,github.tools.sap` set in shell profile

## Configuration

Add to `~/.bash_profile` or `~/.zshrc`:

```bash
export GITHUB_REMOTES="github.com,github.tools.sap"
```

The script will fetch PRs from all configured hosts in parallel.

## Implementation

### Step 1: Fetch Jira Assigned Tickets (run first, in parallel with PR fetch)

**IMPORTANT: Use ONLY `mcp__sap-jira__jira_search`. Never use Atlassian plugin tools, never use `atlassian:search-company-knowledge`, never fall back to any other Jira source.**

If `mcp__sap-jira__jira_search` is unavailable (tool not found, auth error, network error), display exactly:
```
⚠️ SAP Jira unavailable. Run: claude mcp add sap-jira --transport http https://mcp.jira.tools.sap/mcp
   Then restart Claude and ensure SAP VPN is connected.
```
Then continue to Step 2 (PR dashboard). Do NOT attempt any other Jira or knowledge search tool.

First, get the current user ID (SAP I/D-number) by running `whoami` in bash. Use that value as the assignee in the JQL query.

Call `mcp__sap-jira__jira_search` with this JQL (replacing `<whoami>` with the result):

```
assignee = <whoami> AND statusCategory != Done ORDER BY updated DESC
```

For each ticket, display:
- Ticket key + URL: `https://jira.tools.sap/browse/<KEY>`
- Summary (title)
- Status
- Priority
- Issue type

**Number each ticket line with a consecutive integer starting at 1**, e.g.:
```
1. https://jira.tools.sap/browse/PROJ-123 - Ticket title | 🔴 In Progress | P2
2. https://jira.tools.sap/browse/PROJ-456 - Another ticket | 📋 To Do | P3
```

After rendering all Jira tickets, count the total number of Jira items displayed (call it `J`). Pass `--start <J+1>` to the Python script in Step 2 so PR item numbers continue from where Jira left off.

Group tickets into:
- **🔴 In Progress** — statusCategory = "In Progress"
- **📋 To Do / Backlog** — statusCategory = "To Do"
- **🚫 Blocked** — has a "is blocked by" link to an open issue

### Step 2: Fetch GitHub PRs

Run the Python script and display its full output directly in your response:

```bash
python3 ~/.claude/skills/good-morning/pr_dashboard.py --start <J+1>
```

Replace `<J+1>` with the actual number (e.g., if 3 Jira tickets were shown, run `--start 4`).

**IMPORTANT**: After running the script, you MUST display the complete output in your response text (not just in the tool result). Copy the entire dashboard output and present it to the user so they can see and click the URLs directly.

### Step 3: Combine Output

Display Jira section FIRST, then PR dashboard below it. Full format:

```
# Good Morning! ☀️

## 🎫 My Jira Tickets

### 🔴 In Progress:
1. https://jira.tools.sap/browse/PROJ-123 - Ticket title | 🔴 In Progress | P2

### 📋 To Do:
2. https://jira.tools.sap/browse/PROJ-456 - Another ticket | 📋 To Do | P3

---

[PR dashboard output here — own PRs first (continuing from 3.), then reviewer PRs section]
```

The reviewer PRs section appears after your own PRs:

```
## 🔍 PRs to Review (N total):

### ⏰ Needs Your Review:
3. https://github.com/owner/repo/pull/123 - Title (@author) | 👀 Needs your review | ✅ All 5 checks passing

### ✅ Already Reviewed:
4. https://github.com/owner/repo/pull/456 - Title (@author) | ✅ You approved | ✅ All 3 checks passing
```

If `mcp__sap-jira__jira_search` unavailable, show setup instructions (see Step 1) and continue to PR dashboard. Never use alternative Jira tools.

The script:
- Reads GitHub hosts from `GITHUB_REMOTES` environment variable
- Fetches PRs from all configured hosts in parallel
- Fetches detailed PR information (reviews, checks, comments) in parallel using ThreadPoolExecutor
- Categorizes PRs into priority buckets
- Formats output with clear status indicators

## Manual Steps (if script unavailable)

### Fetch Open PRs

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

1. 🚧 https://github.com/owner/repo/pull/123 - Title | ❌ Changes requested by @reviewer | 3 failing checks | 5 unresolved comments

---

## 👀 Awaiting Review:

2. https://github.com/owner/repo/pull/456 - Title | 👀 Waiting on @reviewer | ⏳ 2 pending checks

---

## ✅ Approved and Passing:

3. https://github.com/owner/repo/pull/789 - Title | ✅ Approved by @reviewer | ✅ All 15 checks passing

---

**Key Issues to Address:**
4. 🔥 **N PRs with changes requested** need updates
5. ⚠️ **N failing CI checks** across all PRs
6. 💬 **N total unresolved comments**
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
