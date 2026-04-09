---
name: last-screenshot
description: Last Screenshot Skill
allowed-tools:
  - Bash(ls -t ~/Desktop/Screenshot*.png*)
  - Read
---

# Last Screenshot Skill

References the most recent screenshot from the user's Desktop for analysis.

## Usage

Invoke with `/last-screenshot` when the user wants you to look at their latest screenshot.

Examples:
- "look at last screenshot and fix the issue"
- "/last-screenshot what's the error?"
- "check my last screenshot"

## Instructions

1. Find the most recent screenshot file on the Desktop:
   ```bash
   ls -t ~/Desktop/Screenshot*.png 2>/dev/null | head -1
   ```

2. If no screenshot is found, inform the user.

3. If found, read the screenshot file using the Read tool to analyze its contents.

4. Proceed with whatever task the user requested (fix issue, explain error, etc.)
