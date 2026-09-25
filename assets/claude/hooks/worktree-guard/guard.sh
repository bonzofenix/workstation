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
#                Edit tool: `cat >`, `sed -i`, `mv`, `rm`/`trash`, `tee`. Sessions in
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
#
# Directories are never "tracked" here: `ls-files` matches a directory by any
# tracked file under it, so `cp new.png assets/` would otherwise be blocked
# even though it only adds an untracked file. `:(literal)` keeps glob
# characters and pathspec magic in a filename from matching other paths.
tracked() {
  local p="$1"
  case "$p" in /*) ;; *) p="$cwd/$p" ;; esac
  [ -d "$p" ] && return 1
  git -C "$cwd" ls-files --error-unmatch -- ":(literal)$1" >/dev/null 2>&1
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
    # shellcheck disable=SC2016 # Python source; the $ and backticks are its own.
    targets="$(printf '%s' "$command" | python3 -c '
import os, sys

SQ = chr(39)  # a literal single quote would end the surrounding bash string

def tokenize(s):
    """Split a command into ("w", word) and ("op", operator) tokens.

    Quote-aware on purpose: `grep ">" f` must yield the word ">" rather than
    a redirect, which shlex cannot distinguish once quotes are stripped.
    Unbalanced quotes raise ValueError.
    """
    toks, cur, has, i, n = [], [], False, 0, len(s)
    def flush():
        nonlocal cur, has
        if has:
            toks.append(("w", "".join(cur)))
        cur, has = [], False
    while i < n:
        c = s[i]
        if c == "\\" and i + 1 < n:
            cur.append(s[i + 1]); has = True; i += 2; continue
        if c == SQ:
            j = s.find(SQ, i + 1)
            if j < 0:
                raise ValueError
            cur.append(s[i + 1:j]); has = True; i = j + 1; continue
        if c == "\"":
            j, buf = i + 1, []
            while j < n and s[j] != "\"":
                if s[j] == "\\" and j + 1 < n and s[j + 1] in "\"\\$`":
                    buf.append(s[j + 1]); j += 2; continue
                buf.append(s[j]); j += 1
            if j >= n:
                raise ValueError
            cur.append("".join(buf)); has = True; i = j + 1; continue
        if c.isspace():
            flush(); i += 1; continue
        if c == "#" and not has:
            break
        if c in ";&|<>":
            # `2>file`: a bare fd number before a redirect is not a word.
            if c in "<>" and has and "".join(cur).isdigit():
                cur, has = [], False
            else:
                flush()
            j = i
            while j < n and s[j] in ";&|<>":
                j += 1
            toks.append(("op", s[i:j])); i = j; continue
        cur.append(c); has = True; i += 1
    flush()
    return toks

try:
    toks = tokenize(sys.stdin.read())
except ValueError:
    # Unbalanced quotes, usually a heredoc body flattened into the line.
    sys.exit(0)

WRITERS_ALL  = {"rm", "unlink", "truncate", "shred", "trash", "trash-put"}  # every operand
WRITERS_LAST = {"mv", "cp", "install", "ln", "rsync"}  # last operand is dest
INPLACE      = {"sed", "gsed", "perl", "ruby"}         # only with -i
TEE          = {"tee", "sponge"}
CHDIR        = {"cd", "pushd", "popd"}
SEPARATORS   = {";", "&&", "||", "|", "&", "|&", ";;"}
WRITE_REDIR  = {">", ">>", ">|", "&>", "&>>"}
READ_REDIR   = {"<", "<<<", "<>"}
DUP_REDIR    = {">&", "<&"}
HEREDOC      = {"<<", "<<-"}

out = []

def add(p):
    # Devices and fds are not files anyone tracks.
    if not p or p.startswith("-") or p.startswith("/dev/"):
        return
    out.append(p)

def handle(words):
    """Collect targets for one simple command; False means stop parsing."""
    while words and "=" in words[0] and not words[0].startswith("-"):
        words = words[1:]  # leading VAR=value assignments
    if not words:
        return True
    base = os.path.basename(words[0])
    if base in CHDIR:
        # Later relative paths resolve somewhere other than cwd; guessing
        # would mean false blocks, so stop and fail open.
        return False
    operands = words[1:]
    flags = [w for w in operands if w.startswith("-")]
    # Empty words are dropped: macOS `sed -i ""` passes one as the suffix.
    plain = [w for w in operands if w and not w.startswith("-")]
    if base in WRITERS_ALL or base in TEE:
        for p in plain:
            add(p)
    elif base in WRITERS_LAST and plain:
        add(plain[-1])
    elif base in INPLACE and any(
        f.startswith("-i") or f == "--in-place"
        or (base in ("perl", "ruby") and not f.startswith("--") and "i" in f[1:])
        for f in flags
    ):
        # The script operand is not a file, so skip the first plain word.
        for p in plain[1:]:
            add(p)
    return True

words, i = [], 0
while i < len(toks):
    kind, val = toks[i]
    nxt = toks[i + 1] if i + 1 < len(toks) and toks[i + 1][0] == "w" else None
    if kind == "w":
        words.append(val); i += 1; continue
    if val in SEPARATORS:
        if not handle(words):
            words = None
            break
        words = []; i += 1; continue
    if val in WRITE_REDIR:
        if nxt:
            add(nxt[1]); i += 2; continue
    elif val in DUP_REDIR:
        if nxt:
            # `>&2` duplicates an fd; `>&file` is bash shorthand for `&>file`.
            if not (nxt[1].isdigit() or nxt[1] == "-") and val == ">&":
                add(nxt[1])
            i += 2; continue
    elif val in READ_REDIR:
        if nxt:
            i += 2; continue
    elif val in HEREDOC:
        # The body was flattened onto this line; skip to the terminator word
        # so its text is not parsed as commands.
        if nxt:
            marker, i = nxt[1], i + 2
            while i < len(toks) and toks[i] != ("w", marker):
                i += 1
            i += 1
            continue
    i += 1

if words:
    handle(words)

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
