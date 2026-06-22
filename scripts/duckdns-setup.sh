#!/usr/bin/env bash
set -euo pipefail

# Colour output helpers
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

# Function to print coloured messages
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if already configured
CONFIG_FILE="/etc/duckdns/config"
if [ -f "$CONFIG_FILE" ]; then
  log_info "Configuration found at $CONFIG_FILE, loading..."
  source "$CONFIG_FILE"
else
  log_info "No existing configuration found. Setting up DuckDNS..."

  # Prompt for subdomain
  read -p "Enter your DuckDNS subdomain (e.g., angshu-home): " DUCKDNS_SUBDOMAIN
  if [ -z "$DUCKDNS_SUBDOMAIN" ]; then
    log_error "Subdomain cannot be empty."
    exit 1
  fi

  # Prompt for token
  read -sp "Enter your DuckDNS token: " DUCKDNS_TOKEN
  echo
  if [ -z "$DUCKDNS_TOKEN" ]; then
    log_error "Token cannot be empty."
    exit 1
  fi

  # Create config directory and save config
  log_info "Saving configuration to $CONFIG_FILE..."
  sudo mkdir -p /etc/duckdns
  sudo tee "$CONFIG_FILE" > /dev/null <<EOF
DUCKDNS_SUBDOMAIN=$DUCKDNS_SUBDOMAIN
DUCKDNS_TOKEN=$DUCKDNS_TOKEN
EOF
  sudo chmod 600 "$CONFIG_FILE"
  log_info "Configuration saved securely."
fi

# Create the updater script
log_info "Creating updater script at /usr/local/bin/duckdns-update.sh..."
sudo tee /usr/local/bin/duckdns-update.sh > /dev/null <<'UPDATER'
#!/usr/bin/env bash
source /etc/duckdns/config
RESULT=$(curl -fsSL "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=")
echo "$(date): ${RESULT}" >> /var/log/duckdns.log
if [ "${RESULT}" = "OK" ]; then
  exit 0
else
  exit 1
fi
UPDATER
sudo chmod +x /usr/local/bin/duckdns-update.sh

# Create systemd service
log_info "Creating systemd service at /etc/systemd/system/duckdns.service..."
sudo tee /etc/systemd/system/duckdns.service > /dev/null <<'SERVICE'
[Unit]
Description=DuckDNS IP Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/duckdns-update.sh
SERVICE

# Create systemd timer
log_info "Creating systemd timer at /etc/systemd/system/duckdns.timer..."
sudo tee /etc/systemd/system/duckdns.timer > /dev/null <<'TIMER'
[Unit]
Description=DuckDNS IP Update Timer
Requires=duckdns.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=duckdns.service

[Install]
WantedBy=timers.target
TIMER

# Enable and start the timer
log_info "Enabling and starting the systemd timer..."
sudo systemctl daemon-reload
sudo systemctl enable duckdns.timer
sudo systemctl start duckdns.timer

# Test the updater
log_info "Testing DuckDNS updater..."
sudo /usr/local/bin/duckdns-update.sh
sleep 1

# Check the result
LAST_LOG=$(sudo tail -1 /var/log/duckdns.log)
if echo "$LAST_LOG" | grep -q "OK"; then
  log_info "DuckDNS updater test passed!"
  echo -e "${GREEN}✓ DuckDNS update returned OK${NC}"
else
  log_error "DuckDNS updater test failed!"
  echo -e "${RED}Last log entry: $LAST_LOG${NC}"
  log_error "Please check your DuckDNS token and subdomain at https://www.duckdns.org"
  exit 1
fi

# Print summary
echo ""
echo -e "${GREEN}=== DuckDNS Setup Complete ===${NC}"
echo "Subdomain configured: ${DUCKDNS_SUBDOMAIN}.duckdns.org"
echo "Timer status: sudo systemctl status duckdns.timer"
echo "Log file: /var/log/duckdns.log"
echo "Next step: use ${DUCKDNS_SUBDOMAIN}.duckdns.org as the WG_HOST value in ~/docker-compose.yml"
