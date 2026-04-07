---
name: unresolved-comments
description: Fetch and display only unresolved comments from a GitHub pull request
allowed-tools:
  - Bash(gh pr view*)
  - Bash(gh api*)
  - Read
  - Edit
  - Write
  - Bash(git*)
---

Fetch and display ONLY unresolved comments from a GitHub pull request, then assist with addressing them.

## Steps

1. Get PR number and repository: `gh pr view --json number,headRepository`

2. Fetch review threads using GitHub's GraphQL API:
   ```bash
   gh api graphql -f query='
   {
     repository(owner: "OWNER", name: "REPO") {
       pullRequest(number: NUMBER) {
         reviewThreads(first: 100) {
           nodes {
             isResolved
             isOutdated
             comments(first: 50) {
               nodes {
                 author { login }
                 body
                 path
                 line
                 originalLine
                 diffHunk
                 createdAt
               }
             }
           }
         }
       }
     }
   }'
   ```
   Replace OWNER, REPO, and NUMBER with actual values.

3. Filter threads where `isResolved: false`
4. Parse and format unresolved comments
5. Display formatted output

## Output Format

```markdown
## Unresolved Comments

- @author file.ts#line:
  ```diff
  [diff_hunk]
  ```
  > comment text

  [replies indented]
```

If no unresolved comments exist, return "No unresolved comments found."

## Comment Resolution Workflow

For each unresolved comment:

1. **Analyze the comment**: Read the relevant code context
2. **Provide your assessment**: 
   - Explain whether the suggestion makes sense
   - Discuss trade-offs and implications
   - Give your recommendation (apply or skip)
3. **Let user decide**: Present options and wait for user input
4. **If applying the fix**:
   - Make the code change
   - Commit with message format: "fix: address review comment - [brief description]"
   - Reply with: "Fixed in {commit_hash}"
5. **If skipping**:
   - Provide a concise explanation for the user to reply with
   - Format: 1-2 sentences explaining why the suggestion wasn't applied

## Important Notes

- Only show threads where `isResolved: false`
- PR-level comments (not in review threads) won't appear
- Preserve comment threading and nesting
- Show file and line number context
- Note outdated comments using `isOutdated` field
- Use jq to parse GraphQL JSON responses
