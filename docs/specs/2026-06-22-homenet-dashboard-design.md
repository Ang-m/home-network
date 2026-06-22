# HomeNet Dashboard — Design Spec
**Date:** 2026-06-22  
**Status:** Approved  

---

## Overview

A live network dashboard that runs as a Docker container on the home server, showing all connected devices with online/offline status, IP, MAC address, vendor, and bandwidth. Accessible locally and remotely via WireGuard VPN.

---

## Goals

- See all devices on 192.168.0.x at a glance — online, offline, stale
- Show IP, MAC, vendor, last-seen timestamp per device
- Show live upload/download bandwidth for the server's network interface
- Auto-refresh every 5 seconds, no page reload
- Visually distinct: dark background, glowing status indicators, hybrid layout (mini topology map + device cards)
- Always-on: runs as Docker container alongside Pi-hole, Jellyfin, etc.

---

## Non-Goals

- Per-device bandwidth (only interface-level totals)
- Historical graphs or time-series data
- Authentication / login
- Mobile app

---

## Architecture

```
Browser (any device on LAN or WireGuard)
    │
    │  HTTP GET /         → dashboard HTML
    │  HTTP GET /api/scan → JSON device list (every 5s)
    ▼
Flask app (port 8080, network_mode: host)
    │
    ├── ip neigh show          → ARP table (IP + MAC)
    ├── ping sweep             → online/offline per device
    ├── /proc/net/dev          → interface bandwidth (↑↓)
    └── oui.py                 → MAC → vendor name (local lookup)
```

Single Docker container. No database. State held in memory (last-seen timestamps reset on container restart).

---

## File Structure

```
homenet/
└── dashboard/
    ├── app.py                 ← Flask app + scanner
    ├── templates/
    │   └── index.html         ← Dashboard HTML/CSS/JS
    ├── oui.py                 ← MAC OUI vendor lookup (local, no API)
    ├── Dockerfile
    └── requirements.txt       ← flask (only dependency)
```

---

## Backend: `app.py`

### Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/` | GET | Serves `index.html` |
| `/api/scan` | GET | Returns JSON: device list + bandwidth |

### `/api/scan` response shape

```json
{
  "scanned_at": "2026-06-22T14:30:00",
  "interface": "eth0",
  "bandwidth": {
    "upload_bps": 1240000,
    "download_bps": 4870000
  },
  "devices": [
    {
      "ip": "192.168.0.1",
      "mac": "20:e1:5d:40:01:50",
      "vendor": "TP-Link",
      "name": "Router (Archer C6)",
      "status": "online",
      "last_seen": "2026-06-22T14:30:00"
    }
  ]
}
```

### Scanner logic

1. **ARP table:** `ip neigh show` — parses all entries, extracts IP + MAC + state (REACHABLE / STALE / FAILED)
2. **Ping sweep:** Parallel ping of 192.168.0.1–254 using `concurrent.futures.ThreadPoolExecutor`. 1-second timeout per device. Updates online/offline status.
3. **Bandwidth:** Read `/proc/net/dev` twice, 1 second apart. Calculate bytes-per-second delta for the primary interface.
4. **Known devices:** Dict in `app.py` maps IP → friendly name. Falls back to "Unknown Device".

```python
KNOWN_DEVICES = {
    "192.168.0.1":   "Router (Archer C6)",
    "192.168.0.2":   "Work Bedroom AP (RE305)",
    "192.168.0.3":   "Sleep Bedroom AP (WA850RE)",
    "192.168.0.10":  "Home Server",
}
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `SCAN_INTERVAL` | `5` | Seconds between background scans |
| `NETWORK_PREFIX` | `192.168.0` | Subnet prefix to sweep |
| `INTERFACE` | `eth0` | Interface to read bandwidth from |

---

## Frontend: `index.html`

### Layout

```
┌─────────────────────────────────────────────────────────┐
│  🌐 HomeNet Dashboard    ↑ 1.24 MB/s  ↓ 4.87 MB/s  ●LIVE│
├─────────────────────────────────────────────────────────┤
│  Topology mini-map (ASCII-style SVG)                    │
│  [ONT]──●[Router]──●[Work AP]──●[Sleep AP]              │
│                 └──○[Server]──●[Laptop]                 │
├─────────────────────────────────────────────────────────┤
│  DEVICES  (5 online · 1 offline)                        │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ ● Router     │  │ ● Work AP    │  │ ○ Server     │  │
│  │ 192.168.0.1  │  │ 192.168.0.2  │  │ 192.168.0.10 │  │
│  │ TP-Link      │  │ TP-Link      │  │ --           │  │
│  │ ↑1.2 ↓4.8   │  │ ↑0.4 ↓1.2   │  │ Last: never  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Visual design

- Background: `#0d0d0d`
- Text: `#e0e0e0`
- Online glow: `#00ff41` (matrix green) with CSS `box-shadow` glow effect
- Offline: `#ff4444` (red), dimmed card
- Stale: `#ffaa00` (amber)
- Font: `JetBrains Mono, monospace`
- Cards: `border: 1px solid #1a1a1a`, rounded corners, glow on hover

### Topology map

SVG rendered inline. Nodes positioned based on `KNOWN_DEVICES` config. Lines connect devices according to network hierarchy (ONT → Router → APs → Server → clients). Status colour applied to each node circle.

### Auto-refresh

```javascript
setInterval(() => {
  fetch('/api/scan')
    .then(r => r.json())
    .then(data => updateDashboard(data));
}, 5000);
```

Cards update in-place. Cards flash green briefly on come-online, red on go-offline (CSS transition).

---

## Docker Integration

Added to existing `docker-compose.yml`:

```yaml
homenet-dashboard:
  build: ./dashboard
  container_name: homenet-dashboard
  restart: unless-stopped
  network_mode: host
  cap_add:
    - NET_RAW
  environment:
    - SCAN_INTERVAL=5
    - NETWORK_PREFIX=192.168.0
    - INTERFACE=eth0
```

`network_mode: host` is required so the container shares the host's network namespace — necessary for ARP table access and ICMP ping.

---

## GitHub Repo

New repo: `Ang-m/home-network`  
All contents of `aiproject/homenet/` move to the new repo root.  
The `aiproject/homenet/` folder is removed from the main repo.

Repo structure:
```
home-network/
├── dashboard/          ← new (this project)
├── config/
│   ├── docker/
│   └── openwrt/
├── diagrams/
├── notes/
├── planning/
└── scripts/
```

---

## Access

| Context | URL |
|---|---|
| Local network | `http://192.168.0.10:8080` |
| WireGuard remote | `http://10.0.0.1:8080` |

No authentication required — accessible only to devices on the LAN or connected via WireGuard.

---

## Out of Scope (Future)

- Per-device bandwidth tracking
- Historical graphs (Grafana + InfluxDB)
- Push notifications when a device goes offline
- Authentication
