#!/bin/bash
# peon-ping: Warcraft III Peon voice lines for Claude Code hooks
# Handles sounds and tmux notifications
set -uo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-$HOME/.claude/hooks/peon-ping}"
CONFIG_FILE="$PEON_DIR/config.json"
STATE_FILE="$PEON_DIR/.state.json"

# One python pass: read the config, parse the hook event off stdin, and decide
# whether this is a non-interactive agent session. Values reach python through
# the environment and stdin, never spliced into its source, so a quote or a
# space in a path cannot break the script.
eval "$(
  PEON_CONFIG_FILE="$CONFIG_FILE" PEON_STATE_FILE="$STATE_FILE" \
  /usr/bin/python3 -c '
import json, os, shlex, sys

config_file = os.environ["PEON_CONFIG_FILE"]
state_file = os.environ["PEON_STATE_FILE"]

def emit(name, value):
    print(name + "=" + shlex.quote(str(value)))

def emit_bool(name, value):
    print(name + "=" + ("true" if value else "false"))

try:
    cfg = json.load(open(config_file))
except Exception:
    cfg = {}

emit_bool("ENABLED", cfg.get("enabled", True))
emit("VOLUME", cfg.get("volume", 0.5))
emit("ACTIVE_PACK", cfg.get("active_pack", "peon"))
emit("ANNOYED_THRESHOLD", cfg.get("annoyed_threshold", 3))
emit("ANNOYED_WINDOW", cfg.get("annoyed_window_seconds", 10))
emit("TMUX_ALERT_STYLE", cfg.get("tmux_alert_style", "fg=white,bg=red,bold"))
emit_bool("TMUX_RENAME_WINDOW", cfg.get("tmux_rename_window", False))

categories = cfg.get("categories", {})
for name in ["greeting", "acknowledge", "complete", "error", "permission",
             "resource_limit", "annoyed"]:
    emit_bool("CAT_" + name.upper(), categories.get(name, True))

try:
    event = json.load(sys.stdin)
except Exception:
    event = {}

emit("EVENT", event.get("hook_event_name", ""))
emit("NOTIFY_TYPE", event.get("notification_type", ""))
emit("CWD", event.get("cwd", ""))

# Permission modes that mark a non-interactive agent or teammate session.
# Interactive modes (default, plan) still get sounds. Once a session shows up
# in an agent mode it stays classified that way, since later events on the
# same session no longer carry the mode.
AGENT_MODES = {"acceptEdits", "ignoreEdits", "bypassPermissions", "delegate"}
session_id = event.get("session_id", "")
perm_mode = event.get("permission_mode", "")

try:
    state = json.load(open(state_file))
except Exception:
    state = {}

agent_sessions = set(state.get("agent_sessions", []))
if perm_mode in AGENT_MODES:
    agent_sessions.add(session_id)
    state["agent_sessions"] = sorted(agent_sessions)
    os.makedirs(os.path.dirname(state_file) or ".", exist_ok=True)
    json.dump(state, open(state_file, "w"))

emit_bool("IS_AGENT_SESSION", session_id in agent_sessions)
' 2>/dev/null
)"

[ "${ENABLED:-true}" = "false" ] && exit 0
[ "${IS_AGENT_SESSION:-false}" = "true" ] && exit 0

# Extract and sanitize project name for display
PROJECT="${CWD##*/}"
PROJECT="${PROJECT:-claude}"
PROJECT=$(printf '%s' "$PROJECT" | tr -cd '[:alnum:] ._-')

# Check if user is rapidly submitting prompts (triggers annoyed responses)
is_user_spamming() {
  PEON_STATE_FILE="$STATE_FILE" \
  PEON_ANNOYED_WINDOW="$ANNOYED_WINDOW" \
  PEON_ANNOYED_THRESHOLD="$ANNOYED_THRESHOLD" \
  /usr/bin/python3 -c '
import json, os, time

state_file = os.environ["PEON_STATE_FILE"]
now = time.time()
window = float(os.environ["PEON_ANNOYED_WINDOW"])
threshold = int(os.environ["PEON_ANNOYED_THRESHOLD"])

try:
    state = json.load(open(state_file))
except Exception:
    state = {}

timestamps = [t for t in state.get("prompt_timestamps", []) if now - t < window]
timestamps.append(now)

state["prompt_timestamps"] = timestamps
os.makedirs(os.path.dirname(state_file) or ".", exist_ok=True)
json.dump(state, open(state_file, "w"))

print("true" if len(timestamps) >= threshold else "false")
' 2>/dev/null
}

# Pick random sound from category, avoiding immediate repeats
pick_sound() {
  PEON_PACK_DIR="$PEON_DIR/packs/$ACTIVE_PACK" \
  PEON_STATE_FILE="$STATE_FILE" \
  PEON_CATEGORY="$1" \
  /usr/bin/python3 -c '
import json, os, random, sys

pack_dir = os.environ["PEON_PACK_DIR"]
state_file = os.environ["PEON_STATE_FILE"]
category = os.environ["PEON_CATEGORY"]

manifest = json.load(open(os.path.join(pack_dir, "manifest.json")))
sounds = manifest.get("categories", {}).get(category, {}).get("sounds", [])
if not sounds:
    sys.exit(1)

try:
    state = json.load(open(state_file))
except Exception:
    state = {}

last_file = state.get("last_played", {}).get(category, "")
candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s["file"] != last_file]
pick = random.choice(candidates)

state.setdefault("last_played", {})[category] = pick["file"]
json.dump(state, open(state_file, "w"))

print(os.path.join(pack_dir, "sounds", pick["file"]))
' 2>/dev/null
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

# A volume of 0 makes the sound inaudible, so skip picking and playing it.
case "$VOLUME" in
  0|0.0|0.00) SOUND_CATEGORY="" ;;
esac

# Nothing audible and no tmux window to touch means there is no work left.
[ -z "$SOUND_CATEGORY" ] && [ -z "${TMUX_PANE:-}" ] && exit 0

# Build tab title with optional attention marker
TAB_TITLE="${SHOW_MARKER:+● }${PROJECT}: ${TAB_STATUS}"

# Get tmux window ID once for reuse
WINDOW_ID=""
if [ -n "${TMUX_PANE:-}" ] && { [ "$TMUX_RENAME_WINDOW" = "true" ] || [ -n "$TRIGGER_ALERT" ]; }; then
  WINDOW_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}')

  # Renaming the window is opt-in: the colour alert alone is enough to draw
  # attention, and rewriting the tab title churns the window list.
  if [ "$TMUX_RENAME_WINDOW" = "true" ]; then
    # Store original window name if not already stored
    ORIGINAL_NAME=$(tmux show-window-option -t "$WINDOW_ID" -v @claude_original_name 2>/dev/null || echo "")
    if [ -z "$ORIGINAL_NAME" ]; then
      ORIGINAL_NAME=$(tmux display-message -t "$WINDOW_ID" -p '#{window_name}')
      tmux set-option -w -t "$WINDOW_ID" @claude_original_name "$ORIGINAL_NAME"
    fi

    # Set window name with attention marker
    tmux rename-window -t "$WINDOW_ID" "$TAB_TITLE"
  fi
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
