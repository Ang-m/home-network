#!/usr/bin/env bash

# Home Server Service Verification Script
# Checks the health of all services running on a home server

SERVER_IP="${1:-192.168.1.10}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service definitions: service_name|port|endpoint|expected_codes
declare -a SERVICES=(
  "Pi-hole|80|/admin/index.php|200"
  "Portainer|9000|/|200"
  "Jellyfin|8096|/health|200"
  "Home Assistant|8123|/|200,302"
  "WireGuard UI|51821|/|200"
  "Syncthing|8384|/|200"
  "Open-WebUI|3000|/|200"
  "Ollama|11434|/api/tags|200"
)

# Container name mapping
declare -A CONTAINER_MAP=(
  ["Pi-hole"]="pihole"
  ["Portainer"]="portainer"
  ["Jellyfin"]="jellyfin"
  ["Home Assistant"]="homeassistant"
  ["WireGuard UI"]="wg-easy"
  ["Syncthing"]="syncthing"
  ["Open-WebUI"]="open-webui"
  ["Ollama"]="ollama"
)

# Print header
echo "=== Home Server Service Verification ==="
echo "Server: $SERVER_IP"
echo ""

passed=0
failed=0
declare -a failed_services

# Check each service
for service_def in "${SERVICES[@]}"; do
  IFS='|' read -r service_name port endpoint expected_codes <<< "$service_def"

  url="http://$SERVER_IP:$port$endpoint"
  http_code=$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
  curl_exit=$?

  # Determine if the check passed
  if [[ $curl_exit -eq 0 ]] && [[ "$expected_codes" == *"$http_code"* ]]; then
    echo -e "${GREEN}✓${NC} $service_name (HTTP $http_code)"
    ((passed++))
  else
    if [[ -z "$http_code" ]] && [[ $curl_exit -ne 0 ]]; then
      result="TIMEOUT"
    else
      result="HTTP $http_code"
    fi
    echo -e "${RED}✗${NC} $service_name ($result)"
    ((failed++))
    failed_services+=("$service_name")
  fi
done

echo ""

# Print summary
total=$((passed + failed))
if [[ $failed -eq 0 ]]; then
  echo -e "${GREEN}✓ All $total services healthy${NC}"
  exit_code=0
else
  echo -e "${RED}✗ $passed/$total services healthy — check docker logs <container> on the server${NC}"
  exit_code=1
fi

# Print troubleshooting commands for failed services
if [[ $failed -gt 0 ]]; then
  echo ""
  echo "Troubleshooting commands:"
  for failed_service in "${failed_services[@]}"; do
    container_name="${CONTAINER_MAP[$failed_service]}"
    echo "  → ssh angshu@$SERVER_IP \"docker logs $container_name --tail 20\""
  done
fi

exit $exit_code
