#!/usr/bin/env bash

# Installs cloudflared and wires a Cloudflare Tunnel in front of Caddy.
#
# The tunnel dials out to Cloudflare, so inbound 80/443 are no longer needed
# and the origin IP stops being reachable directly. Traffic path becomes:
#
#   visitor -> Cloudflare edge -> tunnel -> localhost:80 -> Caddy -> app
#
# Caddy keeps doing hostname routing, so existing Caddy config is untouched.
# TLS terminates at the Cloudflare edge; Caddy serves plain HTTP on loopback.
#
# This script does NOT create the tunnel or touch the firewall. Tunnel
# creation needs an interactive browser login, and closing 80/443 before the
# tunnel is verified up would take every site offline. Both are documented
# manual steps below.

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

log_section "Cloudflare Tunnel"

if ! command -v apt-get >/dev/null 2>&1; then
  log_error "linux-tunnel.sh expects a Debian/Ubuntu host (no apt-get found)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

log_step "Installing cloudflared"
if ! command -v cloudflared >/dev/null 2>&1; then
  # Cloudflare publishes its own apt repo; cloudflared is not in the Ubuntu
  # archive.
  $SUDO mkdir -p -m 755 /etc/apt/keyrings
  if ! curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
       | $SUDO tee /etc/apt/keyrings/cloudflare-main.gpg >/dev/null; then
    log_error "Could not fetch Cloudflare signing key"
    exit 1
  fi
  $SUDO chmod go+r /etc/apt/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/etc/apt/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    | $SUDO tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq cloudflared
  log_success "cloudflared installed"
else
  log_success "cloudflared already installed"
fi

# The tunnel config references a credentials file that only exists after an
# interactive `cloudflared tunnel create`. Installing a template here would
# produce a service that crash-loops on every boot, so the config is left to
# the manual step and only its directory is prepared.
$SUDO mkdir -p /etc/cloudflared
$SUDO cp "$SCRIPT_DIR/../assets/cloudflare/config.yml.example" /etc/cloudflared/config.yml.example
log_success "Config directory ready at /etc/cloudflared"

if [ -f /etc/cloudflared/config.yml ]; then
  log_success "/etc/cloudflared/config.yml already exists, leaving it alone"
else
  log_warning "No tunnel configured yet — see the manual steps below"
fi

log_success "cloudflared ready"

cat <<'EOF'

  Remaining steps are manual — they need a browser login, and the firewall
  change can take sites offline if done in the wrong order.

  1. Authenticate (opens a browser):
       cloudflared tunnel login

  2. Create the tunnel and note the UUID it prints:
       cloudflared tunnel create <name>

  3. Write /etc/cloudflared/config.yml using the example in that directory.
     Point ingress at http://localhost:80 so Caddy keeps routing by hostname.

  4. Route DNS for each hostname:
       cloudflared tunnel route dns <name> example.com

  5. Start the service and confirm it connects:
       sudo cloudflared service install
       sudo systemctl status cloudflared

  6. VERIFY the sites load through the tunnel before touching the firewall.

  7. Only then close public ingress:
       sudo ufw delete allow 80/tcp
       sudo ufw delete allow 443/tcp

     Leave the SSH rule in place, or the next reboot locks you out of the box.

EOF
