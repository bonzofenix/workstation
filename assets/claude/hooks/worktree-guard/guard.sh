#!/usr/bin/env bash
# PreToolUse hook: enforce "use a worktree for PR-bound work".
#
# Three triggers, because PR-bound work has three possible first moves:
#
#   1. Bash    — branch-creating git commands (git switch -c, checkout -b,
#                git branch <name>) run from a plain checkout.
#   2. Edit /  — writing to a TRACKED file while on the default branch
#      Write     (main/master) from a plain checkout. This is the case the
#                branch-only check missed: editing files on main is the real
#                start of PR-bound work, and it creates no branch, so trigger
#                1 never fires.
#   3. Bash    — writing to a TRACKED file through the shell rather than the
#                Edit tool: `cat >`, `sed -i`, `mv`, `rm`, `tee`. Sessions in
#                auto mode are instructed to prefer shell redirection over the
#                Edit/Write tools, which routes every real edit around trigger
#                2. A whole feature once landed on main unchallenged that way.
#                What matters is that a tracked file on the default branch is
#                being rewritten, not which tool does the rewriting.
#
# Fail-closed: if the interpreter is missing or the hook payload can't be
# parsed, block (exit 2) with a message rather than silently waving the
# command through — a guard that fails open provides false assurance.
#
# Trigger 3 is the deliberate exception and fails OPEN. Extracting write
# targets from an arbitrary shell command is a heuristic over messy input; a
# parse slip there would block every Bash command in the session rather than
# one edit. A missed edit costs a branch move, a false block costs the session.
#
# This is a heuristic guardrail, not a security boundary: exotic command
# spellings can slip through, which is acceptable for something that only
# prompts. It cannot judge intent — if a plain branch or a direct edit on
# main is genuinely correct, confirm with the user and proceed.
set -euo pipefail

input="$(cat)"

# python3 is required to parse the JSON payload. If it's missing we can't
# make a safe decision, so block loudly rather than no-op.
if ! command -v python3 >/dev/null 2>&1; then
  echo "worktree-guard: python3 not found; cannot evaluate command. Blocking to fail safe." >&2
  exit 2
fi

# Parse the fields we need in one shot. On any parse error the `||` branch
# fires and we fail closed. Fields are newline-separated and read
# positionally; embedded newlines in the command are flattened first so
# they can't shift the line numbering.
parsed="$(printf '%s' "$input" | python3 -c '
import json, sys
d = json.load(sys.stdin)
ti = d.get("tool_input", {}) or {}
print(d.get("tool_name", ""))
print((ti.get("command", "") or "").replace("\n", " "))
print(d.get("cwd", "") or "")
print((ti.get("file_path", "") or "").replace("\n", " "))
')" || {
  echo "worktree-guard: could not parse hook input JSON. Blocking to fail safe." >&2
  exit 2
}

tool_name="$(printf '%s\n' "$parsed" | sed -n '1p')"
command="$(printf '%s\n' "$parsed" | sed -n '2p')"
cwd="$(printf '%s\n' "$parsed" | sed -n '3p')"
file_path="$(printf '%s\n' "$parsed" | sed -n '4p')"

# cwd must be resolvable to decide worktree-vs-plain. Empty means the
# payload omitted it — block explicitly rather than guessing. Checked up
# front since all triggers depend on it.
if [ -z "$cwd" ]; then
  echo "worktree-guard: hook payload had no cwd; cannot confirm worktree. Blocking to fail safe." >&2
  exit 2
fi

# Already inside a Claude Code worktree: the rule is satisfied, nothing to do.
case "$cwd" in
  */.claude/worktrees/*) exit 0 ;;
esac

# on_guarded_branch reports whether cwd is a git repo, with commits, sitting on
# the default branch. Shared by triggers 2 and 3 so the two cannot drift on
# what counts as protected.
on_guarded_branch() {
  # Not a git repo (or git unavailable) — nothing to protect.
  git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  # Bootstrap exception: a repo with no commits yet. There is no history to
  # protect and no PR to target — the first commit has to land on the default
  # branch by definition. Stated explicitly rather than relying on the
  # tracked-files check to incidentally allow it, so that tightening that
  # check later cannot silently break `git init` workflows.
  git -C "$cwd" rev-parse --verify HEAD >/dev/null 2>&1 || return 1

  # Only guard the default branch. Feature branches in a plain checkout are
  # the user's business; this hook is about not writing on main.
  case "$(git -C "$cwd" branch --show-current 2>/dev/null || true)" in
    main|master) return 0 ;;
    *) return 1 ;;
  esac
}

# tracked reports whether git already indexes a path. New/untracked files are
# usually scratch work, notes, or generated output — blocking those is noise.
# `--error-unmatch` exits non-zero for anything not in the index.
tracked() {
  git -C "$cwd" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

current_branch() {
  git -C "$cwd" branch --show-current 2>/dev/null || true
}

case "$tool_name" in

  Bash)
    [ -n "$command" ] || exit 0

    # --- Trigger 1: branch creation ---------------------------------------
    # Case-insensitive, and tolerant of a `git -C <path>` global option before
    # the subcommand.
    if printf '%s' "$command" | grep -qiE '(^|[; &]|&&)[[:space:]]*git[[:space:]]+(-C[[:space:]]+[^ ]+[[:space:]]+)?(checkout[[:space:]]+-b|switch[[:space:]]+-c|branch[[:space:]]+[^-])'; then
      cat >&2 <<'EOF'
Blocked: this looks like the start of PR-bound work (creating a new git
branch) outside a Claude Code worktree.

Standing rule: use EnterWorktree before any feature/fix/bug/PR checkout
that involves writing code.

If a plain branch is actually correct here, ask the user to confirm, then
proceed — this hook only checks cwd, it can't judge intent.
EOF
      exit 2
    fi

    # --- Trigger 3: shell writes to tracked files -------------------------
    # Only worth parsing the command at all if we are somewhere protected.
    on_guarded_branch || exit 0

    # Extract candidate write targets, one per line. A non-zero exit or an
    # unparseable command yields nothing and the command is allowed; see the
    # fail-open note in the header.
    targets="$(printf '%s' "$command" | python3 -c '
import shlex, sys

try:
    words = shlex.split(sys.stdin.read(), comments=False)
except ValueError:
    # Unbalanced quotes, usually a heredoc body flattened into the line.
    sys.exit(0)

WRITERS_ALL  = {"rm", "unlink", "truncate", "shred"}   # every operand destroyed
WRITERS_LAST = {"mv", "cp", "install", "ln", "rsync"}  # last operand is dest
INPLACE      = {"sed", "gsed", "perl", "ruby"}         # only with -i
TEE          = {"tee", "sponge"}
OPERATORS    = (";", "&&", "||", "|", "&")

out = []

def add(p):
    if not p or p.startswith("-") or p.startswith("&"):
        return
    # Devices and fds are not files anyone tracks.
    if p.startswith("/dev/"):
        return
    out.append(p)

i = 0
segment_start = True
while i < len(words):
    w = words[i]

    if w in OPERATORS:
        segment_start = True
        i += 1
        continue

    # Redirections. `<` and heredoc markers are reads, skipped deliberately.
    # Detached forms first: `>`, `>>`, `2>`, `2>>`.
    if w in (">", ">>") or (len(w) > 1 and w[0].isdigit() and w[1:] in (">", ">>")):
        if i + 1 < len(words):
            add(words[i + 1])
            i += 2
            continue
    # Attached forms: `>file`, `>>file`, `2>file`.
    if w.startswith(">>") and len(w) > 2:
        add(w[2:]); i += 1; continue
    if w.startswith(">") and len(w) > 1:
        add(w[1:]); i += 1; continue
    if len(w) > 2 and w[0].isdigit() and w[1] == ">":
        add(w[2:].lstrip(">")); i += 1; continue

    if segment_start:
        base = w.rsplit("/", 1)[-1]
        rest = words[i + 1:]
        # Stop at the next operator so `rm a && ls b` does not treat b as an
        # rm target.
        stop = len(rest)
        for j, r in enumerate(rest):
            if r in OPERATORS:
                stop = j
                break
        operands = rest[:stop]
        flags = [r for r in operands if r.startswith("-")]
        plain = [r for r in operands if not r.startswith("-")]

        if base in WRITERS_ALL:
            for p in plain:
                add(p)
        elif base in WRITERS_LAST and plain:
            add(plain[-1])
        elif base in TEE:
            for p in plain:
                add(p)
        elif base in INPLACE and any(f.startswith("-i") for f in flags):
            # The script operand is not a file, so skip the first plain word.
            for p in plain[1:]:
                add(p)
        segment_start = False

    i += 1

for p in dict.fromkeys(out):
    print(p)
' 2>/dev/null)" || targets=""

    [ -n "$targets" ] || exit 0

    while IFS= read -r target; do
      [ -n "$target" ] || continue
      if tracked "$target"; then
        branch="$(current_branch)"
        cat >&2 <<EOF
Blocked: this command writes to a tracked file on '$branch' outside a
Claude Code worktree.

  file: $target

Standing rule: use EnterWorktree before any code-writing work bound for a
PR. Rewriting a tracked file through the shell (cat >, sed -i, mv, rm, tee)
is the same act as editing it — the tool used does not change what it means.
Auto mode prefers shell redirection over the Edit tool, so this is the usual
shape a real edit takes.

Call EnterWorktree, then redo this from inside the worktree. If writing to
'$branch' directly is genuinely correct here (a trivial fix the user asked
for in place), ask the user to confirm first — this hook checks cwd, branch
and paths, it can't judge intent.
EOF
        exit 2
      fi
    done <<< "$targets"

    exit 0
    ;;

  Edit|Write|NotebookEdit|MultiEdit)
    [ -n "$file_path" ] || exit 0

    on_guarded_branch || exit 0
    tracked "$file_path" || exit 0

    branch="$(current_branch)"
    cat >&2 <<EOF
Blocked: editing a tracked file on '$branch' outside a Claude Code worktree.

  file: $file_path

Standing rule: use EnterWorktree before any code-writing work bound for a
PR. Editing tracked files on the default branch IS the start of that work,
even before a branch exists.

Call EnterWorktree, then redo this edit inside the worktree. If editing
'$branch' directly is genuinely correct here (a trivial fix the user asked
for in place), ask the user to confirm first — this hook checks cwd and
branch, it can't judge intent.
EOF
    exit 2
    ;;

esac

exit 0
