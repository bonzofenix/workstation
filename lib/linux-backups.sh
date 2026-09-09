#!/usr/bin/env bash

# Sets up daily off-site backups with restic to a Cloudflare R2 bucket.
#
# Covers the server state that cannot be rebuilt from this repo: PostgreSQL
# databases and the hand-tuned /etc config (Caddy, systemd units, ufw,
# fail2ban). Application data directories are opt-in via BACKUP_PATHS in the
# config file, since they differ per host.
#
# This is the off-site leg of a 3-2-1 strategy, not the whole strategy: a
# restic repository in one bucket is one copy. Keep another copy elsewhere if
# the data matters.

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

log_section "Backups (restic to R2)"

if ! command -v apt-get >/dev/null 2>&1; then
  log_error "linux-backups.sh expects a Debian/Ubuntu host (no apt-get found)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

log_step "Installing restic"
if ! command -v restic >/dev/null 2>&1; then
  run_with_spin "Updating apt index..." $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq restic
  log_success "restic installed"
else
  log_success "restic already installed"
fi

# This target also runs on its own, not only after linux-server, so it cannot
# assume the sqlite3 CLI is already there. SQLITE_DATABASES is useless
# without it: the nightly run would fail at the first database.
log_step "Installing sqlite3"
if ! command -v sqlite3 >/dev/null 2>&1; then
  $SUDO apt-get install -y -qq sqlite3
  log_success "sqlite3 installed"
else
  log_success "sqlite3 already installed"
fi

# The config carries R2 credentials and the restic password, so it is
# root-owned and unreadable by anyone else. Installed from a template on
# first run and never overwritten, so re-running this script cannot clobber
# live credentials.
CONFIG_TARGET="/etc/workstation-backup.env"
log_step "Installing backup config"
if [ -f "$CONFIG_TARGET" ]; then
  log_success "$CONFIG_TARGET already exists, leaving it alone"
else
  $SUDO cp "$SCRIPT_DIR/../assets/backup/backup.env.example" "$CONFIG_TARGET"
  $SUDO chown root:root "$CONFIG_TARGET"
  $SUDO chmod 600 "$CONFIG_TARGET"
  log_warning "Created $CONFIG_TARGET from template — fill in R2 credentials before backups can run"
fi

log_step "Installing backup script"
$SUDO cp "$SCRIPT_DIR/../assets/backup/workstation-backup" /usr/local/bin/workstation-backup
$SUDO chown root:root /usr/local/bin/workstation-backup
$SUDO chmod 755 /usr/local/bin/workstation-backup
log_success "Installed /usr/local/bin/workstation-backup"

log_step "Installing systemd timer"
$SUDO tee /etc/systemd/system/workstation-backup.service >/dev/null <<'EOF'
[Unit]
Description=Daily restic backup to R2
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/workstation-backup
# Backups are IO-heavy and not latency-sensitive; keep them out of the way of
# whatever the box is actually serving.
Nice=10
IOSchedulingClass=idle
EOF

# RandomizedDelaySec spreads the run so every host built from this repo does
# not hit R2 at exactly 03:00. Persistent=true catches up a run missed while
# the box was off, which matters more than hitting the exact hour.
$SUDO tee /etc/systemd/system/workstation-backup.timer >/dev/null <<'EOF'
[Unit]
Description=Run workstation-backup daily

[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable --now workstation-backup.timer
log_success "Timer active (daily ~03:00, up to 30m jitter)"

log_success "Backups configured"
log_step "Next: fill in $CONFIG_TARGET, then run 'sudo workstation-backup init' once"
