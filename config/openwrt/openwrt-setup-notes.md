# Router Setup Notes — TP-Link Archer C6 v4 (OEM Firmware)

> **IMPORTANT:** The Archer C6 v4 uses the TP1900BN SoC with 8MB flash / 32MB RAM.
> OpenWrt requires a minimum of 8MB/64MB — the v4 does not meet this requirement.
> Only Archer C6 v2 and v3 are OpenWrt-compatible. **Use OEM TP-Link firmware.**

---

## 1. First Login

1. Connect laptop directly to a LAN port on Archer C6 via Ethernet
2. Open browser → http://192.168.1.1
3. Default credentials: admin / admin (or printed on label)
4. **Set a strong admin password immediately** under Advanced → System → Administration

---

## 2. Put Airtel ONT in DMZ Mode

Airtel India ONTs often don't support true bridge mode. Use one of these:

**Option A (preferred) — DMZ:**
- Log into Airtel ONT (usually 192.168.1.1 or 192.168.0.1 — check label)
- Note the WAN IP the Archer C6 gets on its WAN port (Advanced → Network → Internet)
- In Airtel ONT: find DMZ / Virtual Server → set DMZ host to the Archer C6 WAN IP
- All inbound traffic forwarded to Archer C6

**Option B — Call Airtel support:**
- Ask for "bridge mode" or "PPPoE passthrough"
- Works on some fibre plans, not all

**Option C — Double NAT (fallback):**
- Don't change Airtel router at all
- Archer C6 gets a private IP on its WAN (e.g. 192.168.0.x)
- Everything still works except port forwarding for WireGuard
- Use Tailscale instead of WireGuard if this is the case (no port forwarding needed)

---

## 3. Basic Router Config (OEM Firmware)

### Set Pi-hole as DNS (do this once server is up)
Advanced → Network → DHCP Server → Primary DNS: `192.168.1.10`

### Assign static IP to server
Advanced → Network → DHCP Server → Address Reservation
→ Add: MAC address of server NIC → 192.168.1.10

### Port forwarding for WireGuard VPN
Advanced → NAT → Virtual Servers
→ Add: Protocol UDP, External port 51820, Internal IP 192.168.1.10, Internal port 51820

### Basic QoS (optional, helps with work calls)
Advanced → QoS → Enable → set total bandwidth to ~90% of actual speed

---

## 4. AP Mode for TP-Link Extender (work bedroom) and TL-WA850 (sleep bedroom)

For EACH access point:
1. Connect laptop directly to the AP via Ethernet (temporarily)
2. Access AP UI at its default IP (usually 192.168.0.1 or 192.168.1.1 — check label)
3. Set mode to **Access Point**
4. Set WiFi SSID: `HomeNet` (same as router)
5. Set WiFi password: same as router
6. Set AP LAN IP to a static address **outside** DHCP range (100–200):
   - Work bedroom extender: `192.168.1.2`
   - Sleep bedroom TL-WA850: `192.168.1.3`
7. **Disable DHCP server** on the AP — router handles all leases
8. Reconnect AP to its switch port (TL-SG105E for work room, EH210 port 1 for sleep bedroom)

Result: phones roam automatically between all 3 APs on the same SSID.

---

## 5. EH210 Setup (sleep bedroom)

The EH210 is a USB-C powered Gigabit Ethernet Splitter (1-in, 2-out):
- **Port IN (rear):** Connect wall port cable
- **Port 1 (front):** Connect TL-WA850 AP
- **Port 2 (front):** Connect sleep bedroom Smart TV
- **USB-C:** Connect to USB power adapter or TV USB port for power

No configuration needed — plug and play.

---

## 6. IoT VLAN — DEFERRED

IoT isolation (Alexa, smart bulbs on separate VLAN) requires a router with VLAN support.
The Archer C6 v4 OEM firmware does **not** support VLANs.

**Options when this matters:**
- Upgrade router to GL.iNet Flint 2 (AX3000, OpenWrt preinstalled, ~₹5,000)
- Or find a used Archer C6 v2/v3 (OpenWrt-compatible)
- The TL-SG105E switch in the work room supports 802.1Q VLANs — ready when router is upgraded

---

## 7. What Was Lost Without OpenWrt

| Feature | OpenWrt plan | OEM workaround |
|---|---|---|
| Custom DNS | DHCP DNS forwarding in LuCI | Advanced → DHCP Server → Primary DNS |
| Static server IP | Static DHCP lease in LuCI | Address Reservation |
| Port forwarding | Firewall rules | Virtual Servers |
| SQM/QoS | fq_codel on WAN | Basic TP-Link QoS (~90% as good) |
| IoT VLAN | VLAN10 in LuCI | **Not possible — deferred to Phase 4** |
