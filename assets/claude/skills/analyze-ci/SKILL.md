---
name: analyze-ci
description: Analyze failed GitHub Action jobs for the current branch's PR.
allowed-tools:
  - Bash(gh pr view*)
  - Bash(gh pr checks*)
  - Bash(gh run view*)
  - Bash(gh api*)
---

# Analyze CI Failures

Analyzes logs from failed GitHub Action jobs for the current branch's PR.

## Prerequisites

- **GitHub CLI**: Authenticated via `gh auth login`
- **Current Branch**: Has an open PR on GitHub

## Usage

When invoked:
1. Detects the PR number for current branch
2. **Checks if PR is already merged** (exits early if merged)
3. Checks status of all CI checks
4. Identifies failed jobs
5. Fetches and analyzes logs from failed jobs
6. Provides summary with root causes and error snippets

## How it Works

Uses GitHub CLI to:
- Detect current PR: `gh pr view --json number`
- **Check merge status: `gh pr view --json state,mergedAt,mergedBy`**
- List checks: `gh pr checks <pr-number>`
- View run details: `gh run view <run-id>`
- Fetch logs: `gh api repos/.../actions/jobs/<job-id>/logs`

Output includes:
- **PR merge status** (if already merged, reports merge time and author)
- PR number and branch
- Failed job names
- Root cause analysis
- Error messages and stack traces
- Relevant log snippets
- Suggested fixes (when applicable)
