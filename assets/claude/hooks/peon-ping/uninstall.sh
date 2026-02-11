#!/bin/bash
# Uninstall peon-ping hooks and optionally restore notify.sh
set -euo pipefail

INSTALL_DIR="$HOME/.claude/hooks/peon-ping"
SETTINGS_FILE="$HOME/.claude/settings.json"
NOTIFY_BACKUP="$HOME/.claude/hooks/notify.sh.backup"
NOTIFY_SCRIPT="$HOME/.claude/hooks/notify.sh"

echo "=== peon-ping uninstaller ==="
echo ""

# Remove peon hook entries from settings.json
if [ -f "$SETTINGS_FILE" ]; then
  echo "Removing peon hooks from settings.json..."
  /usr/bin/python3 -c "
import json

settings_path = '$SETTINGS_FILE'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
events_cleaned = []

for event, entries in list(hooks.items()):
    original_count = len(entries)
    entries = [
        h for h in entries
        if not any('peon.sh' in hk.get('command', '') for hk in h.get('hooks', []))
    ]
    if len(entries) < original_count:
        events_cleaned.append(event)
    if entries:
        hooks[event] = entries
    else:
        del hooks[event]

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

if events_cleaned:
    print('Removed hooks for: ' + ', '.join(events_cleaned))
else:
    print('No peon hooks found in settings.json')
"
fi

# Optionally restore notify.sh from backup
if [ -f "$NOTIFY_BACKUP" ]; then
  echo ""
  read -p "Restore original notify.sh from backup? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    /usr/bin/python3 -c "
import json

settings_path = '$SETTINGS_FILE'
notify_script = '$NOTIFY_SCRIPT'

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
notify_hook = {
    'matcher': '',
    'hooks': [{'type': 'command', 'command': notify_script, 'timeout': 10}]
}

for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification']:
    event_hooks = hooks.get(event, [])
    has_notify = any(
        'notify.sh' in hk.get('command', '')
        for h in event_hooks for hk in h.get('hooks', [])
    )
    if not has_notify:
        event_hooks.append(notify_hook)
    hooks[event] = event_hooks

settings['hooks'] = hooks
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Restored notify.sh hooks for: SessionStart, UserPromptSubmit, Stop, Notification')
"
    cp "$NOTIFY_BACKUP" "$NOTIFY_SCRIPT"
    rm "$NOTIFY_BACKUP"
    echo "notify.sh restored"
  fi
fi

# Remove install directory
if [ -d "$INSTALL_DIR" ]; then
  echo ""
  echo "Removing $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
  echo "Removed"
fi

echo ""
echo "=== Uninstall complete ==="
echo "Me go now."
