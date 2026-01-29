---
name: unresolved-comments
description: Fetch and display only unresolved comments from a GitHub pull request
allowed-tools:
  - Bash(gh pr view*)
  - Bash(gh api*)
---

Fetch and display ONLY unresolved comments from a GitHub pull request.

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
5. Return formatted output with no additional text

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

## Important Notes

- Only show threads where `isResolved: false`
- PR-level comments (not in review threads) won't appear
- Preserve comment threading and nesting
- Show file and line number context
- Note outdated comments using `isOutdated` field
- Use jq to parse GraphQL JSON responses
- No explanatory text, only formatted comments
