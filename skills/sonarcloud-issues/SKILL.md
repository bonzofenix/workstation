---
name: sonarcloud-issues
description: Fetch and display SonarCloud/SonarQube analysis issues for a GitHub PR
allowed-tools:
  - Bash(gh pr view*)
  - Bash(gh api*)
  - WebFetch
---

# SonarCloud Issues

Fetches and displays SonarCloud/SonarQube code quality issues for the current branch's pull request.

## Prerequisites

- **GitHub CLI**: Authenticated via `gh auth login`
- **Current Branch**: Has an open PR on GitHub
- **SonarCloud Integration**: Repository must have SonarCloud/SonarQube analysis enabled

## Usage

When invoked:
1. Detects the PR number for current branch
2. Fetches SonarCloud bot comments from the PR
3. Extracts the SonarCloud project ID and PR number
4. Attempts to fetch detailed issue information
5. Displays summary of issues found

## How it Works

Uses GitHub CLI and APIs to:
- Detect current PR: `gh pr view --json number,title`
- Fetch PR comments: `gh pr view --comments`
- Parse SonarCloud bot comments for links and issue counts
- Extract quality gate status (passed/failed)
- Display issue summary with links to detailed reports

## Output includes:
- Quality Gate status (passed/failed)
- Number of new issues by severity
- Coverage on new code
- Code duplication metrics
- Security hotspots count
- Direct links to SonarCloud dashboard for detailed analysis

## Limitations

- Cannot fetch detailed issue descriptions without SonarCloud API authentication
- Shows summary from GitHub comments and links to full report
- For detailed issue analysis, users must visit the SonarCloud dashboard
- Works best when SonarCloud bot posts comments on PRs

## Example Output

```
## SonarCloud Analysis for PR #1062

✅ Quality Gate: PASSED

### Issues Summary
⚠️  1 New Issue
✅ 0 Accepted Issues
✅ 0 Security Hotspots

### Code Quality Metrics
📊 Coverage on New Code: 0.0%
📊 Duplication on New Code: 0.0%

🔗 View detailed analysis: https://sonarcloud.io/dashboard?id=project&pullRequest=1062
🔗 View new issues: https://sonarcloud.io/project/issues?id=project&pullRequest=1062&issueStatuses=OPEN,CONFIRMED
```

## Policy

**DO NOT introduce new SonarCloud issues.** If new issues are detected:
- Review each issue in the analysis output
- Fix all new issues before proceeding with the PR
- Re-run SonarCloud analysis to verify issues are resolved

Quality Gate passing does NOT mean issues should be ignored - all new issues must be addressed.

## Tips

- Run this after CI checks complete and SonarCloud has posted results
- For inline code issues, visit the SonarCloud dashboard link provided
- Some issues may be "Code Smells" (minor) vs "Bugs" (critical)
- Fix new issues immediately rather than accumulating technical debt
