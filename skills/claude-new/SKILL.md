---
name: claude-new
description: Start a new background Claude Code session in a project under ~/workspace, so it shows up in the agent view. Use when the user says "claude-new", "new claude session", "start claude in <project>", "spin up a session for <project>", or wants to pick a workspace project and get a session running there.
allowed-tools:
  - Bash(ls ~/workspace)
  - Bash(ls ~/workspace/*)
  - Bash(cd ~/workspace/*)
  - Bash(claude --bg *)
  - Bash(claude agents *)
---

# claude-new — start a background session in a workspace project

Starts a real (non-headless) Claude Code session in a chosen project directory
using `claude --bg`. The session appears in the agent view (`claude agents`)
and can be opened with `claude attach <id>`.

## Steps

### 1. List projects

```bash
ls -1 "${WORKSPACE_DIR:-$HOME/workspace}"
```

Only top-level directories count as projects.

If the directory is missing or empty, say so and stop.

### 2. Let the user pick

If the user already named a project in their request, and it matches a
directory exactly, skip the picker and use it.

Otherwise present the list with **AskUserQuestion**. That is the picker — do
not use `gum`, `fzf`, or any TTY-based selector, because Bash tool calls have
no TTY and those selectors will hang or fail.

AskUserQuestion allows at most 4 options per question. When there are more
projects than that:

- Put the 3 most recently modified projects as the first options.
- Make the 4th option "Show more projects", and ask again with the next batch
  if the user picks it.
- The user can always type a project name into the "Other" field.

### 3. Start the session

```bash
cd "${WORKSPACE_DIR:-$HOME/workspace}/<project>" && claude --bg -n "<project>"
```

`-n` sets the display name so the session is identifiable in the agent view.

If the user asked for a specific model, effort, or permission mode, pass the
matching flag (`--model`, `--effort`, `--permission-mode`).

If the user gave an initial prompt for the new session, append it as the
positional prompt argument so the session starts working immediately:

```bash
cd "${WORKSPACE_DIR:-$HOME/workspace}/<project>" && claude --bg -n "<project>" "<prompt>"
```

Without a prompt the session starts idle and waits for input.

### 4. Report back

Report the short id from the command output, plus:

- `claude attach <id>` — open it in a terminal
- `claude agents` — the agent view listing every session

Do not attach to the session yourself. Attaching is interactive and belongs to
the user.

## Notes

- `--bg` starts a full interactive session that happens to run detached. Do not
  substitute `-p`/`--print`: that is headless and cannot be attached to later.
- Sessions survive this conversation ending. `claude stop <id>` stops one,
  `claude rm <id>` deletes it.
- `bin/claude-new` in this repo does the equivalent from a shell, where a TTY
  exists and `gum` can be used. It starts a *foreground* session in the chosen
  directory, so it does not populate the agent view; this skill starts a
  detached one that does.
