#!/usr/bin/env bash
# SessionStart / SessionEnd hook: tag the tmux pane running this Claude session
# with its session id and directory (@claude_session, @claude_cwd), so
# bin/claude-tmux-session can reopen the same conversation when tmux-resurrect
# restores the pane.
#
# SessionStart fires for every source (startup, resume, /clear, compaction,
# fork) with the then-current id, so the tag follows whatever the pane shows.
# SessionEnd clears it, so a pane Claude has left is never resumed from a
# stale id.
set -euo pipefail

input="$(cat)"
[ -n "${TMUX_PANE:-}" ] || exit 0
pane_pid="$(tmux display -p -t "$TMUX_PANE" '#{pane_pid}' 2>/dev/null)" || exit 0

# TMUX_PANE is inherited, so Claude processes that are not the pane's own
# carry it too: a `claude -p` run from the pane's session (skill evals do
# this), or a background session. Only the claude that is a direct child of
# the pane shell counts; it is also the only one tmux-resurrect records.
pid=$PPID
while [ "${pid:-1}" -gt 1 ]; do
  case "$(ps -o args= -p "$pid" | awk '{ print $1 }')" in
    claude | */claude) break ;;
  esac
  pid="$(ps -o ppid= -p "$pid" | tr -d ' ')"
done
[ "${pid:-1}" -gt 1 ] || exit 0
[ "$(ps -o ppid= -p "$pid" | tr -d ' ')" = "$pane_pid" ] || exit 0

fields="$(printf '%s' "$input" | python3 -c '
import json, sys
event = json.load(sys.stdin)
print("\x1f".join(str(event.get(k) or "") for k in ("hook_event_name", "session_id", "cwd")))
')"
# \x1f, not a tab: read collapses runs of whitespace IFS, shifting empty fields.
IFS=$'\x1f' read -r event session_id cwd <<< "$fields"

case "$event" in
  SessionStart)
    [ -n "$session_id" ] || exit 0
    tmux set -p -t "$TMUX_PANE" @claude_session "$session_id"
    tmux set -p -t "$TMUX_PANE" @claude_cwd "$cwd"
    ;;
  SessionEnd)
    tmux set -pu -t "$TMUX_PANE" @claude_session
    tmux set -pu -t "$TMUX_PANE" @claude_cwd
    ;;
esac
