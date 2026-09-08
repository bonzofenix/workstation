#!/usr/bin/env bash

# Server-only packages: the runtime a VPS needs to host apps, as opposed to
# the editor/shell tooling in linux-packages.sh. Kept separate so a Linux dev
# box can take the workstation setup without dragging in a database and a
# web server it will never run.
#
# Installs: Go, PostgreSQL, Caddy, the Python deps for Garmin sync, and a
# default-deny firewall.

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

# Pin Go rather than taking the archive's version, which lags well behind and
# would not match the .tool-versions of the apps deployed here.
GO_VERSION="${GO_VERSION:-1.25.14}"

log_section "Linux server runtime"

if ! command -v apt-get >/dev/null 2>&1; then
  log_error "linux-server.sh expects a Debian/Ubuntu host (no apt-get found)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

run_with_spin "Updating apt index..." $SUDO apt-get update -qq

log_step "Installing server packages"
$SUDO apt-get install -y -qq \
  postgresql postgresql-contrib \
  python3 python3-pip python3-venv \
  ufw fail2ban \
  debian-keyring debian-archive-keyring apt-transport-https

log_step "Installing Go ${GO_VERSION}"
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q "go${GO_VERSION}"; then
  ARCH=$(dpkg --print-architecture)
  GO_TARBALL="/tmp/go${GO_VERSION}.tar.gz"
  # -4 because Google's CDN answers 404 over IPv6 from some hosting ranges
  # (Hetzner among them) while the same URL serves fine over IPv4.
  if ! curl -4 -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o "$GO_TARBALL"; then
    log_error "Failed to download Go ${GO_VERSION} for ${ARCH}"
    rm -f "$GO_TARBALL"
    exit 1
  fi
  $SUDO rm -rf /usr/local/go
  $SUDO tar -C /usr/local -xzf "$GO_TARBALL"
  rm -f "$GO_TARBALL"
  # Verify rather than trust: a truncated or wrong-arch tarball extracts
  # happily and only fails at the first build.
  if ! /usr/local/go/bin/go version | grep -q "go${GO_VERSION}"; then
    log_error "Go ${GO_VERSION} did not install correctly"
    exit 1
  fi
  log_success "Go ${GO_VERSION} installed"
else
  log_success "Go ${GO_VERSION} already installed"
fi
# Login shells need this even when the profile snippet has not been sourced yet.
echo 'export PATH=$PATH:/usr/local/go/bin' | $SUDO tee /etc/profile.d/go.sh >/dev/null

log_step "Installing Caddy"
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | $SUDO gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | $SUDO tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq caddy
  log_success "Caddy installed"
else
  log_success "Caddy already installed"
fi

# The Garmin sync sidecar has no official API; the Python library tracks
# Garmin's endpoints far better than any Go client. Pinned so the session
# token format matches what the local seed helper uploads.
#
# This goes in a venv rather than the system Python: on Ubuntu 26.04,
# --break-system-packages fails outright when a dependency (requests) is
# already apt-managed, and overwriting distro packages breaks apt later.
log_step "Installing garminconnect"
GARMIN_VENV="${GARMIN_VENV:-/opt/garmin-venv}"
if [ ! -x "$GARMIN_VENV/bin/python" ]; then
  $SUDO python3 -m venv "$GARMIN_VENV"
fi
if $SUDO "$GARMIN_VENV/bin/pip" install --quiet 'garminconnect==0.3.11'; then
  log_success "garminconnect installed in $GARMIN_VENV"
  log_step "Point GARMIN_SYNC_PYTHON at $GARMIN_VENV/bin/python"
else
  log_warning "garminconnect install failed; Garmin sync will not run"
fi

log_step "Configuring PostgreSQL"
$SUDO systemctl enable --now postgresql
log_success "PostgreSQL running (listening on localhost only by default)"

log_step "Configuring firewall"
# Postgres is deliberately absent: it stays bound to localhost, reachable
# through an SSH or Tailscale session rather than the public internet.
#
# Read the port from sshd rather than using the OpenSSH app profile, which
# hardcodes 22. On a host where SSH was moved, `ufw --force enable` would
# otherwise drop the connection running this script, and recovery needs
# console access at the provider.
SSH_PORT="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
SSH_PORT="${SSH_PORT:-22}"
$SUDO ufw allow "${SSH_PORT}/tcp"
[ "$SSH_PORT" != "22" ] && log_warning "SSH is on port ${SSH_PORT}; allowed that instead of 22"
$SUDO ufw allow 80/tcp
$SUDO ufw allow 443/tcp
$SUDO ufw --force enable
log_success "Firewall active (${SSH_PORT}, 80, 443)"

log_step "Hardening SSH"
# A fresh Hetzner box starts taking password brute-force attempts within
# minutes of going live — verified: 34k+ failed logins on one box's first
# few days, enough concurrent connection attempts to visibly slow down
# legitimate SSH sessions. Key auth is assumed to already work (Hetzner sets
# it up at server creation), so disabling passwords is safe here, not a step
# that could lock the operator out.
if [ -f /etc/ssh/sshd_config ]; then
  $SUDO cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak-preharden
  $SUDO sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  $SUDO sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  if $SUDO sshd -t; then
    $SUDO systemctl reload ssh 2>/dev/null || $SUDO systemctl reload sshd 2>/dev/null
    log_success "Password auth disabled, root requires a key"
  else
    log_error "sshd config invalid after edit — reverting"
    $SUDO cp /etc/ssh/sshd_config.bak-preharden /etc/ssh/sshd_config
  fi
fi

cat > /tmp/jail.local <<'EOF'
[sshd]
enabled = true
port = 22
filter = sshd
backend = systemd
maxretry = 3
findtime = 10m
bantime = 1h
EOF
$SUDO cp /tmp/jail.local /etc/fail2ban/jail.local
rm -f /tmp/jail.local
$SUDO systemctl enable --now fail2ban
log_success "fail2ban active on sshd"

log_success "Server runtime ready"
