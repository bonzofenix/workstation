#!/bin/bash
# peon-ping: Warcraft III Peon voice lines for Claude Code hooks
# Handles sounds, tab titles, and tmux notifications
set -uo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-$HOME/.claude/hooks/peon-ping}"
CONFIG_FILE="$PEON_DIR/config.json"
STATE_FILE="$PEON_DIR/.state.json"

INPUT=$(cat)

# Load configuration with safe shell variable export
eval "$(/usr/bin/python3 -c "
import json, shlex
try:
    cfg = json.load(open('$CONFIG_FILE'))
except:
    cfg = {}

def quote(val):
    return shlex.quote(str(val))

print('ENABLED=' + quote(cfg.get('enabled', True)).lower())
print('VOLUME=' + quote(cfg.get('volume', 0.5)))
print('ACTIVE_PACK=' + quote(cfg.get('active_pack', 'peon')))
print('ANNOYED_THRESHOLD=' + quote(cfg.get('annoyed_threshold', 3)))
print('ANNOYED_WINDOW=' + quote(cfg.get('annoyed_window_seconds', 10)))
print('TMUX_ALERT_STYLE=' + quote(cfg.get('tmux_alert_style', 'fg=white,bg=red,bold')))

categories = cfg.get('categories', {})
for name in ['greeting','acknowledge','complete','error','permission','resource_limit','annoyed']:
    print('CAT_' + name.upper() + '=' + quote(categories.get(name, True)).lower())
" 2>/dev/null)"

[ "$ENABLED" = "false" ] && exit 0

# Walk up process tree to find a TTY for tab title updates
find_session_tty() {
  local pid=$$
  while [ "$pid" -gt 1 ] 2>/dev/null; do
    local tty
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$tty" ] && [ "$tty" != "??" ]; then
      echo "$tty"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

SESSION_TTY=$(find_session_tty)

# Parse hook event from stdin JSON
eval "$(/usr/bin/python3 -c "
import sys, json, shlex
event = json.load(sys.stdin)
for key in ['hook_event_name', 'notification_type', 'cwd', 'session_id', 'permission_mode']:
    var_name = key.upper().replace('HOOK_EVENT_NAME', 'EVENT').replace('NOTIFICATION_TYPE', 'NOTIFY_TYPE')
    print(var_name + '=' + shlex.quote(event.get(key, '')))
" <<< "$INPUT" 2>/dev/null)"

# Skip non-interactive agent/teammate sessions
# Agent modes: acceptEdits, ignoreEdits, bypassPermissions, delegate, etc.
# Normal interactive modes: default, plan (these should get sounds)
IS_AGENT_SESSION=$(/usr/bin/python3 -c "
import json, os

state_file = '$STATE_FILE'
session_id = '$SESSION_ID'
perm_mode = '$PERMISSION_MODE'

# These permission modes indicate non-interactive agent sessions
AGENT_MODES = {'acceptEdits', 'ignoreEdits', 'bypassPermissions', 'delegate'}

try:
    state = json.load(open(state_file))
except:
    state = {}

agent_sessions = set(state.get('agent_sessions', []))

if perm_mode in AGENT_MODES:
    agent_sessions.add(session_id)
    state['agent_sessions'] = list(agent_sessions)
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    json.dump(state, open(state_file, 'w'))
    print('true')
elif session_id in agent_sessions:
    print('true')
else:
    print('false')
" 2>/dev/null)

[ "$IS_AGENT_SESSION" = "true" ] && exit 0

# Extract and sanitize project name for display
PROJECT="${CWD##*/}"
PROJECT="${PROJECT:-claude}"
PROJECT=$(printf '%s' "$PROJECT" | tr -cd '[:alnum:] ._-')

# Check if user is rapidly submitting prompts (triggers annoyed responses)
is_user_spamming() {
  /usr/bin/python3 -c "
import json, time, os

state_file = '$STATE_FILE'
now = time.time()
window = float('$ANNOYED_WINDOW')
threshold = int('$ANNOYED_THRESHOLD')

try:
    state = json.load(open(state_file))
except:
    state = {}

timestamps = [t for t in state.get('prompt_timestamps', []) if now - t < window]
timestamps.append(now)

state['prompt_timestamps'] = timestamps
os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
json.dump(state, open(state_file, 'w'))

print('true' if len(timestamps) >= threshold else 'false')
" 2>/dev/null
}

# Pick random sound from category, avoiding immediate repeats
pick_sound() {
  local category="$1"
  /usr/bin/python3 -c "
import json, random, os, sys

pack_dir = '$PEON_DIR/packs/$ACTIVE_PACK'
state_file = '$STATE_FILE'
category = '$category'

manifest = json.load(open(os.path.join(pack_dir, 'manifest.json')))
sounds = manifest.get('categories', {}).get(category, {}).get('sounds', [])
if not sounds:
    sys.exit(1)

try:
    state = json.load(open(state_file))
except:
    state = {}

last_file = state.get('last_played', {}).get(category, '')
candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s['file'] != last_file]
pick = random.choice(candidates)

state.setdefault('last_played', {})[category] = pick['file']
json.dump(state, open(state_file, 'w'))

print(os.path.join(pack_dir, 'sounds', pick['file']))
" 2>/dev/null
}

# Determine sound category and status based on event type
SOUND_CATEGORY=""
TAB_STATUS=""
SHOW_MARKER=""
TRIGGER_ALERT=""

case "$EVENT" in
  SessionStart)
    SOUND_CATEGORY="greeting"
    TAB_STATUS="ready"
    ;;
  UserPromptSubmit)
    # Annoyed easter egg when user spams prompts rapidly
    if [ "$CAT_ANNOYED" = "true" ] && [ "$(is_user_spamming)" = "true" ]; then
      SOUND_CATEGORY="annoyed"
    fi
    TAB_STATUS="working"
    ;;
  Stop)
    # No sound - Stop fires after each tool, idle_prompt is the real completion signal
    TAB_STATUS="done"
    SHOW_MARKER="1"
    ;;
  Notification)
    case "$NOTIFY_TYPE" in
      permission_prompt)
        SOUND_CATEGORY="permission"
        TAB_STATUS="needs approval"
        SHOW_MARKER="1"
        TRIGGER_ALERT="1"
        ;;
      idle_prompt)
        SOUND_CATEGORY="complete"
        TAB_STATUS="done"
        SHOW_MARKER="1"
        TRIGGER_ALERT="1"
        ;;
      *)
        exit 0
        ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac

# Check if sound category is enabled in config
if [ -n "$SOUND_CATEGORY" ]; then
  CAT_VAR="CAT_$(echo "$SOUND_CATEGORY" | tr '[:lower:]' '[:upper:]')"
  [ "${!CAT_VAR:-true}" = "false" ] && SOUND_CATEGORY=""
fi

# Build tab title with optional attention marker
TAB_TITLE="${SHOW_MARKER:+● }${PROJECT}: ${TAB_STATUS}"

# Get tmux window ID once for reuse
WINDOW_ID=""
if [ -n "${TMUX_PANE:-}" ]; then
  WINDOW_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}')

  # Store original window name if not already stored
  ORIGINAL_NAME=$(tmux show-window-option -t "$WINDOW_ID" -v @claude_original_name 2>/dev/null || echo "")
  if [ -z "$ORIGINAL_NAME" ]; then
    ORIGINAL_NAME=$(tmux display-message -t "$WINDOW_ID" -p '#{window_name}')
    tmux set-option -w -t "$WINDOW_ID" @claude_original_name "$ORIGINAL_NAME"
  fi

  # Set window name with attention marker
  tmux rename-window -t "$WINDOW_ID" "$TAB_TITLE"
fi

# Update Terminal.app tab title via AppleScript
if [ -n "$SESSION_TTY" ]; then
  osascript - "$TAB_TITLE" "$SESSION_TTY" <<'APPLESCRIPT' &
on run argv
  set theTitle to item 1 of argv
  set theTTY to "/dev/" & item 2 of argv
  tell application "Terminal"
    repeat with w in windows
      repeat with t in tabs of w
        if tty of t is theTTY then
          set custom title of t to theTitle
          set title displays custom title of t to true
          set title displays device name of t to false
          set title displays shell path of t to false
          set title displays window size of t to false
          set title displays file name of t to false
        end if
      end repeat
    end repeat
  end tell
end run
APPLESCRIPT
fi

# Play sound for category
if [ -n "$SOUND_CATEGORY" ]; then
  SOUND_FILE=$(pick_sound "$SOUND_CATEGORY")
  if [ -n "$SOUND_FILE" ] && [ -f "$SOUND_FILE" ]; then
    afplay -v "$VOLUME" "$SOUND_FILE" &
  fi
fi

# Highlight tmux window when attention needed
if [ -n "$TRIGGER_ALERT" ] && [ -n "$WINDOW_ID" ]; then
  tmux set-window-option -t "$WINDOW_ID" window-status-style "$TMUX_ALERT_STYLE"
  tmux set-option -w -t "$WINDOW_ID" @claude_alert 1
fi

wait
