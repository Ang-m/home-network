# Setup Order — Home Network Build

Follow this sequence. Each step builds on the previous.

## Day 1: Network First

> **Hardware status:** All network hardware purchased. Devices connected except the Archer C6 router.
> **Note:** Archer C6 v4 does NOT support OpenWrt (TP1900BN chip). Using OEM firmware.

1. **Connect Archer C6 v4** — plug WAN port into Airtel ONT LAN port
2. **Log into Archer C6 OEM UI** at 192.168.1.1 (admin / admin default, change immediately)
3. **Test internet** works through Archer C6 before making any further changes
4. **Put Airtel ONT in DMZ mode** — see config/openwrt/openwrt-setup-notes.md for steps
5. **Configure OEM DHCP** — see config/openwrt/openwrt-setup-notes.md for DNS + lease reservation steps
6. **Work bedroom already connected** — TL-SG105E switch with existing TP-Link extender in AP mode
   - Access extender UI → set mode to Access Point → SSID "HomeNet" → same password → LAN IP 192.168.1.2 → DHCP OFF
7. **Configure TL-WA850 in AP mode** (sleep bedroom) — SSID "HomeNet" → same password → LAN IP 192.168.1.3 → DHCP OFF
8. **Wire hall Smart TV** into Archer C6 LAN1 via patch cable
9. **Wire sleep bedroom TV** into EH210 port 2 (AP on port 1)
10. **Verify WiFi** in all rooms — test with phone, make a WiFi call

## Day 2: Server Setup

10. **Install Ubuntu 22.04 LTS** on the used PC (server)
    - Download: https://ubuntu.com/download/server
    - Disable sleep: `sudo systemctl mask sleep.target suspend.target`
11. **Install Docker + Docker Compose**
    ```bash
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    ```
12. **Mount the 2TB HDD**
    ```bash
    sudo mkfs.ext4 /dev/sdb1        # replace sdb1 with actual device
    sudo mkdir -p /mnt/data
    echo '/dev/sdb1 /mnt/data ext4 defaults 0 2' | sudo tee -a /etc/fstab
    sudo mount -a
    sudo mkdir -p /mnt/data/{media,backup,shared,docker}
    ```
13. **Clone this repo** (or copy docker-compose.yml to server)
14. **Start Pi-hole first**
    ```bash
    docker compose up -d pihole
    ```
    Then set 192.168.1.10 as DNS in OpenWrt (see openwrt-setup-notes.md)
    Verify: open pihole dashboard at http://192.168.1.10/admin

## Day 3: Services

15. **Start Portainer** → http://192.168.1.10:9000 (manage all containers via browser)
16. **Start Jellyfin** → http://192.168.1.10:8096 — add /mnt/data/media as library
17. **Start Home Assistant** → http://192.168.1.10:8123 — add Alexa + smart bulb integrations
18. **Set up DuckDNS** (free dynamic DNS) → https://www.duckdns.org — create a subdomain (e.g. `yourhome.duckdns.org`), set `WG_HOST` in docker-compose.yml to this hostname, install duckdns updater so it tracks your Airtel public IP
    **Start wg-easy** → http://192.168.1.10:51821 — create VPN profiles for phones
19. **Start Samba** → map \\192.168.1.10\data as network drive on Windows laptops
20. **Start Syncthing** → http://192.168.1.10:8384 — install Syncthing app on phones

## Day 4: AI + Polish

21. **Start Ollama + Open-WebUI** → http://192.168.1.10:3000
    Pull a model: `docker exec -it ollama ollama pull phi3:mini`
22. **Test everything end-to-end**:
    - Stream from Jellyfin to both TVs
    - Connect to VPN from phone on 4G (test remote access)
    - Check Pi-hole dashboard shows blocked queries
    - Open Home Assistant — control a smart bulb
    - Chat with Phi-3 in Open-WebUI
