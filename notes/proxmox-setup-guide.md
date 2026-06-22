# Proxmox VE Setup Guide — Gaming PC Server
**Hardware:** i5-9400F | GTX 1660 Ti 6GB | 32GB DDR4 | 230GB NVMe + 470GB SSD + 1TB HDD

---

## Overview

```
Proxmox VE (installed on 230GB NVMe)
├── Wife's VM — Windows 11 + GTX 1660 Ti passthrough → her monitor/keyboard/mouse
├── Your VM — Ubuntu (RDP from your laptop)
└── Docker LXC — Pi-hole, Jellyfin, WireGuard, Home Assistant, etc.
```

Proxmox is managed headlessly via browser at `https://192.168.0.10:8006` — no monitor needed on the server after setup.

---

## Phase 0 — Before You Start

### What to download on your laptop (before 23rd)

| File | Where |
|---|---|
| Proxmox VE ISO (latest 8.x) | https://www.proxmox.com/en/downloads |
| Balena Etcher (flash USB) | https://etcher.balena.io |
| VirtIO drivers ISO | https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso |
| Windows 11 ISO | https://www.microsoft.com/software-download/windows11 |

Flash Proxmox ISO to a USB drive (8GB+) using Balena Etcher.

---

## Phase 1 — BIOS Setup (Day 1, ~15 mins)

Boot into BIOS (Del or F2 on startup). Enable these — they may be under **Advanced** or **CPU Configuration**:

| Setting | Value | Why |
|---|---|---|
| Intel Virtualization Technology (VT-x) | Enabled | Required for VMs |
| Intel VT-d | Enabled | Required for GPU passthrough (IOMMU) |
| Above 4G Decoding | Enabled | Required for GPU passthrough |
| Resizable BAR / Smart Access Memory | Disabled | Can cause GPU passthrough issues |
| Secure Boot | Disabled | Proxmox doesn't need it |
| Fast Boot | Disabled | Easier debugging if needed |
| SATA mode | AHCI | For the HDD |

Save and exit.

---

## Phase 2 — Install Proxmox VE (Day 1, ~20 mins)

1. Plug in USB, boot from it (press F12 or F8 for boot menu)
2. Select **Install Proxmox VE (Graphical)**
3. On disk selection: choose the **230GB NVMe** (e.g. `/dev/nvme0n1`)
4. Country: India | Timezone: Asia/Kolkata | Keyboard: en-us
5. Set a strong root password, use your email `angshuman_mazumdar@hotmail.com`
6. Network config:
   - Management interface: the ethernet port (usually `enp3s0` or similar)
   - Hostname: `pve.local`
   - IP: `192.168.0.10/24`
   - Gateway: `192.168.0.1`
   - DNS: `192.168.0.1`
7. Install → reboot → remove USB

After reboot, open your laptop browser and go to:
**`https://192.168.0.10:8006`** (accept the self-signed cert warning)
Login: `root` / your password

---

## Phase 3 — Post-Install Configuration (Day 1, ~20 mins)

Open the Proxmox shell (top right → Shell) and run:

### Fix repositories (remove paid enterprise repo)
```bash
# Remove enterprise repo
rm /etc/apt/sources.list.d/pve-enterprise.list

# Add free no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update
apt update && apt full-upgrade -y
```

### Add storage for 470GB SSD and 1TB HDD
In the Proxmox web UI:
1. **Datacenter → Storage → Add → Directory**
2. Add the 470GB SSD:
   - ID: `ssd-storage`
   - Directory: `/mnt/ssd` (you'll mount it first — see below)
3. Add the 1TB HDD similarly as `hdd-storage`

Mount the drives:
```bash
# Find drive names
lsblk

# Format and mount 470GB SSD (replace sdX with actual device, e.g. sda)
mkfs.ext4 /dev/sdX
mkdir -p /mnt/ssd
echo "/dev/sdX /mnt/ssd ext4 defaults 0 2" >> /etc/fstab
mount -a

# Format and mount 1TB HDD (replace sdY with actual device)
mkfs.ext4 /dev/sdY
mkdir -p /mnt/hdd
echo "/dev/sdY /mnt/hdd ext4 defaults 0 2" >> /etc/fstab
mount -a
```

---

## Phase 4 — GPU Passthrough Setup (Day 2, ~45 mins)

This gives wife's VM full GTX 1660 Ti access.

### Step 1 — Enable IOMMU in GRUB
```bash
nano /etc/default/grub
```
Find the line: `GRUB_CMDLINE_LINUX_DEFAULT="quiet"`
Change it to:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```
Save (Ctrl+O, Enter, Ctrl+X), then:
```bash
update-grub
```

### Step 2 — Load VFIO modules
```bash
echo "vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd" >> /etc/modules

update-initramfs -u -k all
reboot
```

After reboot, verify IOMMU is active:
```bash
dmesg | grep -e DMAR -e IOMMU
# Should show: "DMAR: IOMMU enabled"
```

### Step 3 — Find GTX 1660 Ti PCI IDs
```bash
lspci -nn | grep -i nvidia
```
Output will look like:
```
01:00.0 VGA compatible controller [0300]: NVIDIA GTX 1660 Ti [10de:2182]
01:00.1 Audio device [0403]: NVIDIA [10de:1aeb]
```
Note the IDs in brackets — `10de:2182` and `10de:1aeb` (yours may differ).

### Step 4 — Blacklist NVIDIA drivers on host
```bash
echo "blacklist nouveau
blacklist nvidia
blacklist nvidiafb
options vfio-pci ids=10de:2182,10de:1aeb" > /etc/modprobe.d/vfio.conf
# Replace the IDs above with YOUR actual IDs from Step 3

update-initramfs -u -k all
reboot
```

Verify GPU is bound to VFIO:
```bash
lspci -nnk | grep -A3 NVIDIA
# Should show: Kernel driver in use: vfio-pci
```

---

## Phase 5 — Wife's Windows 11 VM (Day 2, ~30 mins)

### Create the VM in Proxmox web UI
1. Click **Create VM** (top right)
2. **General:** Name: `wife-win11`, VM ID: 101
3. **OS:** Select Windows 11 ISO, Guest OS: Microsoft Windows, Version: 11/2022
4. **System:**
   - Machine: **Q35**
   - BIOS: **OVMF (UEFI)**
   - Add EFI Disk: ✅
   - TPM: ✅ (v2.0) — Windows 11 requires this
5. **Disks:** 80GB on `ssd-storage` (or local-lvm), VirtIO SCSI
6. **CPU:** 4 cores, Type: **host**
7. **Memory:** 12288 MB (12GB)
8. **Network:** VirtIO, bridge: vmbr0

### Add GPU passthrough to the VM
After creating the VM, go to VM → **Hardware → Add → PCI Device**:
- Select your GTX 1660 Ti
- Enable: **All Functions** ✅
- Enable: **Primary GPU** ✅
- Enable: **ROM-Bar** ✅
- Enable: **PCI-Express** ✅

Add the NVIDIA audio device too (second PCI device).

### Add USB passthrough (wife's keyboard + mouse)
VM → Hardware → Add → USB Device:
- Select her keyboard USB ID
- Repeat for mouse

### Hide hypervisor from NVIDIA (prevents Error 43)
VM → **Options → CPU Flags**. In the Proxmox shell:
```bash
# Add to VM config (replace 101 with your VM ID)
echo "args: -cpu 'host,+kvm_pv_unhalt,+kvm_pv_eoi,hv_vendor_id=NvidiaFTW,kvm=off'" >> /etc/pve/qemu-server/101.conf
```

### Install Windows 11
1. Start VM → Console (noVNC in browser for initial setup)
2. Boot from Windows 11 ISO
3. When asked for storage driver, load VirtIO drivers from the second ISO (attach virtio-win.iso as second CD drive)
4. Install Windows normally
5. After install: install VirtIO guest tools from the ISO
6. Install NVIDIA drivers (download from nvidia.com inside the VM)
7. Connect wife's monitor to GTX 1660 Ti output — she now has her own full Windows 11 desktop

---

## Phase 6 — Your Ubuntu VM (Day 3, ~20 mins)

### Create VM
1. **Create VM:** Name: `angshu-ubuntu`, VM ID: 102
2. **OS:** Ubuntu 26.04 ISO
3. **System:** Machine Q35, BIOS: SeaBIOS (no UEFI needed)
4. **Disk:** 60GB on `ssd-storage`
5. **CPU:** 2 cores, Type: host
6. **Memory:** 8192 MB (8GB)
7. **Network:** VirtIO

### Enable RDP access
After Ubuntu install, inside the VM:
```bash
sudo apt install xrdp -y
sudo systemctl enable xrdp
sudo systemctl start xrdp
# Note the VM's IP from Proxmox (e.g. 192.168.0.11)
```

From your laptop:
```bash
# Install RDP client
sudo apt install remmina -y
# Connect to 192.168.0.11, user/pass of VM
```

---

## Phase 7 — Docker LXC for Services (Day 3, ~30 mins)

LXC containers are lighter than full VMs — perfect for always-on services.

### Create the LXC
1. Download Ubuntu template: **Proxmox → local → CT Templates → Download → ubuntu-24.04**
2. **Create CT:** Name: `docker-services`, ID: 200
3. Storage: 40GB on `ssd-storage`
4. CPU: 2 cores | Memory: 4096 MB | Swap: 1024 MB
5. Network: Static IP `192.168.0.10` (or assign via DHCP and set static lease on router)

⚠️ In LXC Options, enable: **Nesting** ✅ (required for Docker inside LXC)

### Install Docker inside LXC
```bash
apt update && apt install -y curl
curl -fsSL https://get.docker.com | sh
systemctl enable docker
```

### Deploy your Docker stack
Copy the existing `docker-compose.yml` from `aiproject/homenet/config/docker/` to the LXC and run:
```bash
docker compose up -d
```

---

## Phase 8 — Router DNS Update (After Pi-hole is running)

On Archer C6 web UI → Advanced → Network → DHCP Server:
- Primary DNS: `192.168.0.10` (Pi-hole)
- Secondary DNS: `192.168.0.1` (router fallback)

Port forward for WireGuard:
- External port: UDP 51820
- Internal IP: 192.168.0.10
- Internal port: 51820

---

## Storage Layout (Final)

| Drive | Size | Used for |
|---|---|---|
| 230GB NVMe | ~50GB | Proxmox OS + VM disks (wife + yours) |
| 470GB SSD | ~400GB | Docker LXC + overflow VM storage |
| 1TB HDD | ~1TB | Jellyfin media library + Samba NAS |

---

## Anti-Cheat Warning

These games **will not run** in a VM even with GPU passthrough:
- Valorant (Vanguard)
- PUBG (BattlEye in kernel mode)
- Some EA titles (Easy Anti-Cheat)

These work fine in a VM:
- CS2, GTA V, FIFA, most Steam games, Minecraft, indie games

If wife needs to play an anti-cheat game, she'd boot into Windows directly (dual boot on the server) rather than via VM.

---

## Troubleshooting Quick Reference

| Problem | Fix |
|---|---|
| NVIDIA Error 43 in VM | Add `kvm=off` to CPU args (Phase 5) |
| GPU not in VFIO group | Check IOMMU groups: `find /sys/kernel/iommu_groups/ -type l` |
| Windows 11 won't install (no drive) | Load VirtIO storage driver during install |
| Proxmox web UI not loading | Check IP: `ip a` in Proxmox shell |
| VM can't see internet | Check bridge vmbr0 is attached to correct NIC |
| HDD not detected | Check SATA mode is AHCI in BIOS |
