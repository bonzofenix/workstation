---
name: self-review
description: Find and improve your own comments in PR files - answer questions, clarify wording, add context
allowed-tools:
  - Bash(gh pr view*)
  - Bash(gh api*)
  - Bash(git*)
  - Read
  - Edit
  - Grep
  - Glob
---

Find your own comments in the current PR's changed files and improve them:
- Answer questions posed in comments
- Clarify unclear wording
- Add missing context
- Fix typos or grammar
- Replace verbose explanations with concise ones

## Steps

1. **Get current PR and author**:
   ```bash
   gh pr view --json number,author,headRefName
   ```

2. **Get changed files in PR**:
   ```bash
   git diff --name-only origin/main...HEAD
   ```

3. **Search for your comments**:
   For each changed file, search for comments by the PR author:
   - Code comments (Go: `//`, Python: `#`, etc.)
   - Look for questions (contains `?`)
   - Look for TODOs by author
   - Look for vague explanations ("somehow", "for some reason", "basically")

4. **Analyze each comment**:
   - **Questions**: Research the answer from code/docs, replace question with answer
   - **Unclear wording**: Rewrite for clarity
   - **Missing context**: Add WHY, not just WHAT
   - **Verbose**: Make concise while keeping meaning

5. **Edit files directly**: Use Edit tool to improve comments in place

## Comment Improvement Rules

### Answer Questions
```go
// Before:
// Why does this return 403 instead of 404?

// After:
// Returns 403 for org-manager users (permission check before existence check)
// Admin users get 404 (existence checked first)
```

### Add Context
```go
// Before:
// Custom type for plan_updateable

// After:
// BoolOrInt handles CF API inconsistency where plan_updateable is:
//   - boolean (true/false) for admin users
//   - integer (0/1) for org-manager users
```

### Remove Hedging
```go
// Before:
// This basically just checks if the token is valid or something

// After:
// Validates token by calling Root.Get() API endpoint
```

### Replace What with Why
```go
// Before:
// Loop through spaces and delete services

// After:
// Delete services before spaces to avoid orphaned bindings
```

## Output Format

For each improved comment:
```
📝 file.go:42
   Old: // Why does X happen?
   New: // X happens because [explanation]
   
   Reason: Answered question with researched context
```

After all improvements, commit:
```bash
git commit -m "docs: improve code comments

- Answer questions about behavior
- Add context for non-obvious logic
- Clarify vague explanations"
```

## Search Patterns

Grep for these patterns in changed files:
- `// .*\?` - Questions in comments
- `// TODO.*@yourname` - Your TODOs
- `// .*somehow` - Vague explanations
- `// .*for some reason` - Missing WHY
- `// .*basically` - Hedging language
- `// .*just` - Minimizing language

## Important Notes

- Only edit files changed in current PR
- Don't change logic, only comments
- Keep comments short (1-2 lines max unless explaining complex behavior)
- Remove comments that just repeat function names
- If answer requires research, read relevant code/docs first
- Commit all improvements in single commit
