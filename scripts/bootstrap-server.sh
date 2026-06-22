#!/usr/bin/env bash
#
# bootstrap-server.sh
# ===================
# Home server first-run bootstrap script for Ubuntu 22.04 LTS.
#
# Run this script once after fresh Ubuntu installation and first SSH login.
# It performs the following steps automatically:
#
#   1.  Disables sleep/suspend/hibernate (keeps server always on)
#   2.  Enables SSH to start on boot
#   3.  Installs Docker (official get.docker.com method) and adds user to docker group
#   4.  Detects the 2TB data HDD (non-OS disk) and asks for confirmation
#   5.  Partitions the data HDD with a single GPT/ext4 partition (idempotent)
#   6.  Formats the partition as ext4 (idempotent)
#   7.  Mounts the partition at /mnt/data permanently via /etc/fstab (idempotent)
#   8.  Creates the standard directory structure on /mnt/data
#   9.  Verifies Docker installation
#   10. Prints a final summary and next steps
#
# Usage:
#   chmod +x bootstrap-server.sh
#   ./bootstrap-server.sh
#
# Requirements:
#   - Ubuntu 22.04 LTS
#   - Run as user: angshu (with sudo privileges)
#   - Internet access (for Docker installation)
#   - The 2TB data HDD must already be physically installed
#
# After the script completes:
#   - Log out and back in for the docker group to take effect
#   - Run: docker compose up -d portainer
#   - Then open: http://192.168.1.10:9000
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}✓ ${1}${RESET}"; }
err()  { echo -e "${RED}✗ ${1}${RESET}" >&2; }
warn() { echo -e "${YELLOW}⚠ ${1}${RESET}"; }
info() { echo -e "${CYAN}→ ${1}${RESET}"; }
header() { echo -e "\n${BOLD}${CYAN}${1}${RESET}\n"; }

confirm() {
    # Usage: confirm "Prompt text"  →  returns 0 if yes, 1 if no
    local prompt="${1}"
    local reply
    echo -e "${YELLOW}${prompt} [y/N]${RESET} \c"
    read -r reply
    [[ "${reply,,}" == "y" ]]
}

# ---------------------------------------------------------------------------
# Step 0 — Header and initial confirmation
# ---------------------------------------------------------------------------
clear
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║      === Home Server Bootstrap ===       ║"
echo "║         Ubuntu 22.04 LTS Setup           ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${RESET}"

warn "This script will make the following system changes:"
echo "  • Disable sleep/suspend/hibernate"
echo "  • Enable SSH on boot"
echo "  • Install Docker"
echo "  • Partition and format the 2TB data HDD"
echo "  • Mount the HDD at /mnt/data permanently"
echo "  • Create directory structure on /mnt/data"
echo ""

if ! confirm "Do you want to continue?"; then
    echo "Aborted."
    exit 0
fi

echo ""

# ---------------------------------------------------------------------------
# Step 1 — Disable sleep/suspend/hibernate
# ---------------------------------------------------------------------------
header "Step 1 — Disabling sleep/suspend/hibernate"

info "Masking sleep, suspend, hibernate, and hybrid-sleep targets..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
ok "Sleep/suspend/hibernate disabled permanently"

# ---------------------------------------------------------------------------
# Step 2 — Enable SSH on boot
# ---------------------------------------------------------------------------
header "Step 2 — Enabling SSH on boot"

sudo systemctl enable ssh
ok "SSH enabled to start on boot"

# ---------------------------------------------------------------------------
# Step 3 — Install Docker
# ---------------------------------------------------------------------------
header "Step 3 — Installing Docker"

if command -v docker &>/dev/null; then
    ok "Docker is already installed: $(docker --version 2>/dev/null || echo '(version check failed)')"
else
    info "Downloading and running the official Docker install script..."
    curl -fsSL https://get.docker.com | sh
    ok "Docker installed"
fi

info "Adding user 'angshu' to the docker group..."
if groups angshu | grep -q '\bdocker\b'; then
    ok "User 'angshu' is already in the docker group"
else
    sudo usermod -aG docker angshu
    ok "User 'angshu' added to the docker group"
fi

warn "REMINDER: You must log out and back in after this script finishes for the docker group membership to take effect."

# ---------------------------------------------------------------------------
# Step 4 — Detect the 2TB data HDD
# ---------------------------------------------------------------------------
header "Step 4 — Detecting the 2TB data HDD"

# Find the block device that holds the root filesystem
OS_DISK=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || true)
if [[ -z "${OS_DISK}" ]]; then
    # Fallback: get the device for the partition mounted at /
    ROOT_PART=$(findmnt -n -o SOURCE /)
    OS_DISK=$(lsblk -no PKNAME "${ROOT_PART}" 2>/dev/null || echo "")
fi
if [[ -z "${OS_DISK}" ]]; then
    # Last resort: use the disk that contains the root partition
    ROOT_PART=$(df / | tail -1 | awk '{print $1}')
    OS_DISK=$(lsblk -no PKNAME "${ROOT_PART}" 2>/dev/null || echo "")
fi

info "Detected OS disk: /dev/${OS_DISK}"

# List all physical disks, excluding the OS disk
mapfile -t CANDIDATE_DISKS < <(
    lsblk -dpno NAME,SIZE \
    | grep -v "^/dev/${OS_DISK} " \
    | grep -v "loop" \
    | awk '{print $1}'
)

if [[ ${#CANDIDATE_DISKS[@]} -eq 0 ]]; then
    err "No non-OS disks found. Make sure the 2TB HDD is physically installed and visible to the OS."
    exit 1
fi

DATA_DISK=""

if [[ ${#CANDIDATE_DISKS[@]} -eq 1 ]]; then
    DATA_DISK="${CANDIDATE_DISKS[0]}"
    DISK_SIZE=$(lsblk -dpno SIZE "${DATA_DISK}" 2>/dev/null || echo "unknown")
    info "Found one non-OS disk: ${DATA_DISK} (${DISK_SIZE})"
    if ! confirm "Use ${DATA_DISK} (${DISK_SIZE}) as the data HDD?"; then
        err "Disk selection cancelled. Exiting."
        exit 1
    fi
else
    warn "Multiple non-OS disks found:"
    for d in "${CANDIDATE_DISKS[@]}"; do
        DISK_SIZE=$(lsblk -dpno SIZE "${d}" 2>/dev/null || echo "unknown")
        echo "  ${d}  (${DISK_SIZE})"
    done
    echo ""
    echo -e "${YELLOW}Enter the full device path for the 2TB data disk (e.g. /dev/sdb):${RESET} \c"
    read -r DATA_DISK
    if [[ ! -b "${DATA_DISK}" ]]; then
        err "'${DATA_DISK}' is not a valid block device. Exiting."
        exit 1
    fi
fi

ok "Data disk selected: ${DATA_DISK}"
DATA_PART="${DATA_DISK}1"

# ---------------------------------------------------------------------------
# Step 5 — Partition the data HDD
# ---------------------------------------------------------------------------
header "Step 5 — Partitioning ${DATA_DISK}"

if [[ -b "${DATA_PART}" ]]; then
    ok "Partition ${DATA_PART} already exists, skipping partitioning"
else
    warn "About to create a new GPT partition table and a single ext4 partition on ${DATA_DISK}."
    warn "ALL existing data on ${DATA_DISK} will be destroyed."
    if ! confirm "Proceed with partitioning ${DATA_DISK}?"; then
        err "Partitioning cancelled. Exiting."
        exit 1
    fi
    info "Creating GPT partition table and primary partition on ${DATA_DISK}..."
    sudo parted -s "${DATA_DISK}" mklabel gpt mkpart primary ext4 0% 100%
    # Wait for the kernel to register the new partition
    sudo partprobe "${DATA_DISK}" 2>/dev/null || true
    sleep 2
    ok "Partition ${DATA_PART} created"
fi

# ---------------------------------------------------------------------------
# Step 6 — Format the partition as ext4
# ---------------------------------------------------------------------------
header "Step 6 — Formatting ${DATA_PART} as ext4"

EXISTING_FS=$(sudo blkid -o value -s TYPE "${DATA_PART}" 2>/dev/null || echo "")

if [[ "${EXISTING_FS}" == "ext4" ]]; then
    ok "Partition ${DATA_PART} is already formatted as ext4, skipping"
elif [[ -n "${EXISTING_FS}" ]]; then
    warn "Partition ${DATA_PART} has an existing filesystem: ${EXISTING_FS}"
    warn "About to overwrite it with ext4."
    if ! confirm "Proceed with formatting ${DATA_PART} as ext4?"; then
        err "Formatting cancelled. Exiting."
        exit 1
    fi
    info "Formatting ${DATA_PART} as ext4..."
    sudo mkfs.ext4 -F "${DATA_PART}"
    ok "${DATA_PART} formatted as ext4"
else
    info "Formatting ${DATA_PART} as ext4..."
    sudo mkfs.ext4 "${DATA_PART}"
    ok "${DATA_PART} formatted as ext4"
fi

# ---------------------------------------------------------------------------
# Step 7 — Mount at /mnt/data permanently
# ---------------------------------------------------------------------------
header "Step 7 — Mounting ${DATA_PART} at /mnt/data"

sudo mkdir -p /mnt/data

PART_UUID=$(sudo blkid -s UUID -o value "${DATA_PART}")
info "Partition UUID: ${PART_UUID}"

FSTAB_ENTRY="UUID=${PART_UUID}  /mnt/data  ext4  defaults,nofail  0  2"

if grep -qsF "${PART_UUID}" /etc/fstab; then
    ok "fstab entry for ${DATA_PART} (UUID=${PART_UUID}) already exists, skipping"
else
    warn "About to add the following line to /etc/fstab:"
    echo "  ${FSTAB_ENTRY}"
    if ! confirm "Proceed?"; then
        err "fstab update cancelled. Exiting."
        exit 1
    fi
    echo "${FSTAB_ENTRY}" | sudo tee -a /etc/fstab > /dev/null
    ok "fstab entry added"
fi

info "Running mount -a to mount all fstab entries..."
sudo mount -a
ok "/mnt/data mounted"

info "Verifying mount:"
df -h /mnt/data

# ---------------------------------------------------------------------------
# Step 8 — Create directory structure on /mnt/data
# ---------------------------------------------------------------------------
header "Step 8 — Creating directory structure on /mnt/data"

info "Creating directories..."
sudo mkdir -p /mnt/data/{media/movies,media/shows,media/music,backup/phones,backup/laptops,shared,docker}

info "Setting ownership to angshu:angshu..."
sudo chown -R angshu:angshu /mnt/data

ok "Directory structure created:"
find /mnt/data -maxdepth 2 -type d | sort | sed 's/^/  /'

# ---------------------------------------------------------------------------
# Step 9 — Verify Docker
# ---------------------------------------------------------------------------
header "Step 9 — Verifying Docker"

if docker --version &>/dev/null 2>&1; then
    ok "Docker CLI: $(docker --version)"
else
    warn "Docker installed but you need to log out and back in before running docker commands."
fi

if docker compose version &>/dev/null 2>&1; then
    ok "Docker Compose: $(docker compose version)"
else
    warn "Docker installed but you need to log out and back in before running docker commands."
fi

# ---------------------------------------------------------------------------
# Step 10 — Final summary
# ---------------------------------------------------------------------------
header "Bootstrap Complete — Summary"

echo -e "${GREEN}${BOLD}Completed steps:${RESET}"
echo -e "  ${GREEN}✓${RESET} Sleep/suspend/hibernate disabled permanently"
echo -e "  ${GREEN}✓${RESET} SSH enabled on boot"
echo -e "  ${GREEN}✓${RESET} Docker installed and user 'angshu' added to docker group"
echo -e "  ${GREEN}✓${RESET} Data disk ${DATA_DISK} detected and confirmed"
echo -e "  ${GREEN}✓${RESET} Partition ${DATA_PART} created/verified"
echo -e "  ${GREEN}✓${RESET} ${DATA_PART} formatted as ext4 (UUID: ${PART_UUID})"
echo -e "  ${GREEN}✓${RESET} Mounted at /mnt/data (persistent via /etc/fstab)"
echo -e "  ${GREEN}✓${RESET} Directory structure created on /mnt/data"
echo ""

echo -e "${YELLOW}${BOLD}What to do next:${RESET}"
echo ""
echo -e "  ${YELLOW}1.${RESET} Log out and back in (required for docker group membership):"
echo -e "       ${CYAN}exit${RESET}     # then SSH back in"
echo ""
echo -e "  ${YELLOW}2.${RESET} Start Portainer:"
echo -e "       ${CYAN}docker compose up -d portainer${RESET}"
echo ""
echo -e "  ${YELLOW}3.${RESET} Open Portainer in your browser:"
echo -e "       ${CYAN}http://192.168.1.10:9000${RESET}"
echo ""
echo -e "${BOLD}${GREEN}Bootstrap complete. Log out now to apply docker group changes.${RESET}"
echo ""
