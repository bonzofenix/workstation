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

## Comment Classification

Before presenting a comment to the user, classify it:

- **Style/preference** — formatting, naming, if/return vs match, cosmetic structure. Reviewer has a preference, no correctness impact.
- **Correctness/logic** — the suggestion fixes a bug, closes a gap, or prevents future breakage.
- **Architectural** — changes where responsibility lives, call signatures, abstraction level.

## Comment Resolution Workflow

For each unresolved comment:

1. **Analyze the comment**: Read the relevant code context and classify it (style, correctness, or architectural).

2. **Present to user — lead with disposition, not reasoning**:

   - **Style/preference**: Skip the tradeoff essay. Just ask apply or skip with a one-liner max.
     > "Style preference — apply it or skip?"
   - **Correctness/architectural**: Brief assessment (2-3 sentences max). State your recommendation clearly first, reasoning second.
     > "Recommend applying — [one-line reason]. [Optional: one-line tradeoff only if genuinely non-obvious]."

   Never defend the existing approach AND propose applying the change in the same message — pick one.

3. **Let user decide**: Wait for user input.

4. **Apply + reply atomically**: Do both in one step — never explain in a reply and commit separately.
   - Make the code change
   - Commit: `"fix: address review comment - [brief description]"`
   - Post reply: `"Done in [commit_hash]."` — no re-explanation of what was already discussed

5. **If skipping**:
   - One sentence max for the reply. State the reason, not the history.
   - Format: `"Keeping this — [reason]."`

## Code References in Replies

When replying to comments, **always include GitHub permalink references** to support claims:

- Link to the changed code: `[methodName](https://github.com/OWNER/REPO/blob/BRANCH/path/file.go#L42)`
- Link to line ranges: `#L10-L25` for multi-line references
- Link to relevant test cases when tests were added
- Link to third-party library source when explaining library behavior
- Build links using the PR's head branch: `https://github.com/OWNER/REPO/blob/BRANCH/path`

Example reply:
```
Switched to Bearer auth via [`HTTPAuthClient().Do()`](https://github.com/org/repo/blob/branch/cf/wrapper.go#L177).
Uses [`doAuthRequest`](https://github.com/org/repo/blob/branch/cf/wrapper.go#L174) for /introspect
and [`doUaaRequest`](https://github.com/org/repo/blob/branch/cf/wrapper.go#L185) for /userinfo.
```

This makes it easy for reviewers to verify claims without searching the codebase.

## Important Notes

- Only show threads where `isResolved: false`
- PR-level comments (not in review threads) won't appear
- Preserve comment threading and nesting
- Show file and line number context
- Note outdated comments using `isOutdated` field
- Use jq to parse GraphQL JSON responses
