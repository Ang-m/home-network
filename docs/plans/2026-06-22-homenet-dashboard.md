# HomeNet Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a live network dashboard (Flask + Docker) showing all LAN devices with online/offline status, IP, MAC, vendor, and bandwidth — then move all homenet assets to a new GitHub repo `Ang-m/home-network`.

**Architecture:** Flask backend scans the 192.168.0.x subnet every 5s using ARP + parallel ping, reads `/proc/net/dev` for bandwidth, and serves a single HTML dashboard. The frontend polls `/api/scan` every 5 seconds and updates a hybrid layout (SVG topology map + device cards) in-place. Runs as a Docker container with `network_mode: host` alongside the existing stack.

**Tech Stack:** Python 3.11, Flask 3.x, HTML/CSS/JS (no framework), Docker, `concurrent.futures`, `subprocess`, `gh` CLI for GitHub repo creation.

## Global Constraints

- Subnet: `192.168.0.x` (NETWORK_PREFIX env var, default `192.168.0`)
- Server static IP: `192.168.0.10`
- Dashboard port: `8080`
- Docker: `network_mode: host` + `cap_add: NET_RAW` (required for ping + ARP)
- Python dependency: `flask` only (no extra packages)
- Dark theme: background `#0d0d0d`, online green `#00ff41`, offline red `#ff4444`, stale amber `#ffaa00`
- Font: `JetBrains Mono, monospace`
- No authentication
- No database — state in memory only

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `homenet/dashboard/oui.py` | Create | MAC OUI → vendor name lookup (local dict) |
| `homenet/dashboard/app.py` | Create | Flask app, scanner, `/` and `/api/scan` endpoints |
| `homenet/dashboard/templates/index.html` | Create | Dashboard HTML/CSS/JS |
| `homenet/dashboard/requirements.txt` | Create | `flask` dependency |
| `homenet/dashboard/Dockerfile` | Create | Container build |
| `homenet/config/docker/docker-compose.yml` | Modify | Add `homenet-dashboard` service |

---

### Task 1: Create GitHub repo and migrate homenet assets

**Files:**
- Create: new repo `Ang-m/home-network` on GitHub
- Move: all of `aiproject/homenet/` → root of new repo

**Interfaces:**
- Produces: `~/home-network/` local clone with all existing homenet files

- [ ] **Step 1: Create the GitHub repo**

```bash
gh repo create Ang-m/home-network \
  --public \
  --description "Home network configuration, dashboard, and Docker stack" \
  --clone
```

Expected output: `✓ Created repository Ang-m/home-network on GitHub` and a cloned directory at `~/home-network/`.

- [ ] **Step 2: Copy all homenet assets into the new repo**

```bash
cp -r "/home/angshu/Desktop/Data engineering/Data_eng/aiproject/homenet/"* ~/home-network/
```

- [ ] **Step 3: Copy the design spec and plan into the new repo**

```bash
mkdir -p ~/home-network/docs/specs ~/home-network/docs/plans
cp "/home/angshu/Desktop/Data engineering/Data_eng/aiproject/docs/superpowers/specs/2026-06-22-homenet-dashboard-design.md" ~/home-network/docs/specs/
cp "/home/angshu/Desktop/Data engineering/Data_eng/aiproject/docs/superpowers/plans/2026-06-22-homenet-dashboard.md" ~/home-network/docs/plans/
```

- [ ] **Step 4: Create a README**

```bash
cat > ~/home-network/README.md << 'EOF'
# home-network

Home network configuration, live dashboard, and Docker stack for a 2BHK homelab in Bengaluru.

## Structure

- `dashboard/` — Live network dashboard (Flask + Docker)
- `config/docker/` — Docker Compose stack (Pi-hole, Jellyfin, WireGuard, etc.)
- `config/openwrt/` — Router setup notes
- `notes/` — Setup guides and buying notes
- `scripts/` — Bootstrap and verification scripts
- `docs/` — Design specs and implementation plans

## Dashboard

Access at `http://192.168.0.10:8080` (local) or `http://10.0.0.1:8080` (WireGuard).

## Quick Start

```bash
cd config/docker
docker compose up -d
```
EOF
```

- [ ] **Step 5: Initial commit and push**

```bash
cd ~/home-network
git add .
git commit -m "initial commit: migrate homenet assets from aiproject"
git push origin main
```

Expected: all files pushed, visible at `https://github.com/Ang-m/home-network`.

- [ ] **Step 6: Verify repo on GitHub**

```bash
gh repo view Ang-m/home-network
```

Expected output shows repo description, file list including `config/`, `notes/`, `scripts/`.

---

### Task 2: MAC OUI vendor lookup module

**Files:**
- Create: `~/home-network/dashboard/oui.py`

**Interfaces:**
- Produces: `get_vendor(mac: str) -> str` — returns vendor name string or `"Unknown"`

- [ ] **Step 1: Create `oui.py` with a local OUI prefix table**

Create `~/home-network/dashboard/oui.py`:

```python
# MAC OUI prefix → vendor name (first 3 octets, uppercase, colon-separated)
_OUI_TABLE = {
    "20:E1:5D": "TP-Link",
    "3C:6A:D2": "TP-Link",
    "0C:EF:15": "TP-Link",
    "50:C7:BF": "TP-Link",
    "B0:BE:76": "TP-Link",
    "B4:45:06": "Intel",
    "8C:85:90": "Intel",
    "00:1A:2B": "Cisco",
    "FC:EC:DA": "Cisco",
    "B8:27:EB": "Raspberry Pi",
    "DC:A6:32": "Raspberry Pi",
    "E4:5F:01": "Raspberry Pi",
    "00:50:56": "VMware",
    "52:54:00": "QEMU/KVM",
    "18:31:BF": "Amazon",
    "40:A3:6B": "Apple",
    "3C:06:30": "Apple",
    "AC:BC:32": "Apple",
    "F0:B3:EC": "Samsung",
    "CC:32:E5": "Samsung",
    "28:DB:A1": "Google",
    "F4:F5:D8": "Google",
    "10:40:F3": "Motorola",
    "7C:1C:4E": "Motorola",
    "00:E0:4C": "Realtek",
    "00:1B:21": "Intel",
    "00:23:14": "Intel",
}


def get_vendor(mac: str) -> str:
    """Return vendor name for a MAC address, or 'Unknown'."""
    if not mac or mac == "--:--:--:--:--:--":
        return "Unknown"
    prefix = mac.upper()[:8]
    return _OUI_TABLE.get(prefix, "Unknown")
```

- [ ] **Step 2: Verify manually**

```bash
cd ~/home-network/dashboard
python3 -c "from oui import get_vendor; print(get_vendor('20:e1:5d:40:01:50')); print(get_vendor('ff:ff:ff:ff:ff:ff'))"
```

Expected output:
```
TP-Link
Unknown
```

- [ ] **Step 3: Commit**

```bash
cd ~/home-network
git add dashboard/oui.py
git commit -m "feat: add MAC OUI vendor lookup module"
```

---

### Task 3: Network scanner + Flask backend

**Files:**
- Create: `~/home-network/dashboard/app.py`
- Create: `~/home-network/dashboard/requirements.txt`

**Interfaces:**
- Consumes: `from oui import get_vendor` (Task 2)
- Produces:
  - `GET /` → renders `templates/index.html`
  - `GET /api/scan` → JSON matching schema:
    ```json
    {
      "scanned_at": "ISO8601 string",
      "interface": "eth0",
      "bandwidth": {"upload_bps": int, "download_bps": int},
      "devices": [{"ip": str, "mac": str, "vendor": str, "name": str, "status": str, "last_seen": str}]
    }
    ```

- [ ] **Step 1: Create `requirements.txt`**

```
flask>=3.0
```

- [ ] **Step 2: Create `app.py`**

Create `~/home-network/dashboard/app.py`:

```python
import os
import subprocess
import time
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from flask import Flask, jsonify, render_template
from oui import get_vendor

app = Flask(__name__)

NETWORK_PREFIX = os.environ.get("NETWORK_PREFIX", "192.168.0")
INTERFACE = os.environ.get("INTERFACE", "eth0")
SCAN_INTERVAL = int(os.environ.get("SCAN_INTERVAL", "5"))

KNOWN_DEVICES = {
    f"{NETWORK_PREFIX}.1":   "Router (Archer C6)",
    f"{NETWORK_PREFIX}.2":   "Work Bedroom AP (RE305)",
    f"{NETWORK_PREFIX}.3":   "Sleep Bedroom AP (WA850RE)",
    f"{NETWORK_PREFIX}.10":  "Home Server",
}

# In-memory state: ip -> last_seen timestamp
_last_seen: dict[str, str] = {}


def _read_net_dev(interface: str) -> tuple[int, int]:
    """Read rx_bytes and tx_bytes for interface from /proc/net/dev."""
    with open("/proc/net/dev") as f:
        for line in f:
            if interface in line:
                parts = line.split()
                rx_bytes = int(parts[1])
                tx_bytes = int(parts[9])
                return rx_bytes, tx_bytes
    return 0, 0


def get_bandwidth(interface: str) -> dict:
    """Return upload/download bytes-per-second for the interface."""
    rx1, tx1 = _read_net_dev(interface)
    time.sleep(1)
    rx2, tx2 = _read_net_dev(interface)
    return {
        "upload_bps": max(0, tx2 - tx1),
        "download_bps": max(0, rx2 - rx1),
    }


def get_arp_table() -> dict[str, str]:
    """Return {ip: mac} from the ARP table via `ip neigh show`."""
    result = subprocess.run(
        ["ip", "neigh", "show"],
        capture_output=True, text=True
    )
    arp = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 5 and parts[3] == "lladdr":
            ip, mac = parts[0], parts[4]
            arp[ip] = mac
    return arp


def ping_host(ip: str) -> bool:
    """Return True if host responds to a single ping within 1 second."""
    result = subprocess.run(
        ["ping", "-c", "1", "-W", "1", ip],
        capture_output=True
    )
    return result.returncode == 0


def scan_network() -> list[dict]:
    """Ping sweep 192.168.0.1-254, merge with ARP table, return device list."""
    arp = get_arp_table()
    ips = [f"{NETWORK_PREFIX}.{i}" for i in range(1, 255)]

    online_ips: set[str] = set()
    with ThreadPoolExecutor(max_workers=64) as executor:
        futures = {executor.submit(ping_host, ip): ip for ip in ips}
        for future in as_completed(futures):
            ip = futures[future]
            if future.result():
                online_ips.add(ip)

    now = datetime.now().isoformat(timespec="seconds")
    devices = []

    seen_ips = online_ips | set(arp.keys())
    for ip in sorted(seen_ips, key=lambda x: int(x.split(".")[-1])):
        mac = arp.get(ip, "--:--:--:--:--:--")
        is_online = ip in online_ips

        if is_online:
            _last_seen[ip] = now

        devices.append({
            "ip": ip,
            "mac": mac,
            "vendor": get_vendor(mac),
            "name": KNOWN_DEVICES.get(ip, "Unknown Device"),
            "status": "online" if is_online else ("stale" if mac != "--:--:--:--:--:--" else "offline"),
            "last_seen": _last_seen.get(ip, "never"),
        })

    return devices


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/scan")
def api_scan():
    devices = scan_network()
    bandwidth = get_bandwidth(INTERFACE)
    return jsonify({
        "scanned_at": datetime.now().isoformat(timespec="seconds"),
        "interface": INTERFACE,
        "bandwidth": bandwidth,
        "devices": devices,
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
```

- [ ] **Step 3: Smoke test the scanner functions (no Flask needed)**

```bash
cd ~/home-network/dashboard
pip3 install flask --quiet
python3 -c "
from app import get_arp_table, get_bandwidth
print('ARP:', get_arp_table())
print('Bandwidth:', get_bandwidth('$(ip route | grep default | awk \"{print \$5}\" | head -1)'))
"
```

Expected: ARP dict with at least `192.168.0.1`, bandwidth dict with two int values.

- [ ] **Step 4: Commit**

```bash
cd ~/home-network
git add dashboard/app.py dashboard/requirements.txt
git commit -m "feat: add Flask backend with ARP scanner and ping sweep"
```

---

### Task 4: Dashboard HTML/CSS/JS

**Files:**
- Create: `~/home-network/dashboard/templates/index.html`

**Interfaces:**
- Consumes: `GET /api/scan` JSON (Task 3)
- Produces: rendered dashboard at `http://localhost:8080`

- [ ] **Step 1: Create `templates/` directory**

```bash
mkdir -p ~/home-network/dashboard/templates
```

- [ ] **Step 2: Create `index.html`**

Create `~/home-network/dashboard/templates/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>HomeNet Dashboard</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      background: #0d0d0d;
      color: #e0e0e0;
      font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
      min-height: 100vh;
      padding: 20px;
    }

    /* ── Header ── */
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border: 1px solid #1e1e1e;
      border-radius: 8px;
      padding: 14px 20px;
      margin-bottom: 16px;
      background: #111;
    }
    .header-title { font-size: 1.2rem; color: #00ff41; letter-spacing: 2px; }
    .header-stats { display: flex; gap: 24px; font-size: 0.85rem; color: #aaa; }
    .bw-up { color: #00ff41; }
    .bw-down { color: #4af; }
    .live-dot {
      display: inline-block; width: 8px; height: 8px;
      background: #00ff41; border-radius: 50%;
      margin-right: 6px;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.3; }
    }

    /* ── Topology map ── */
    .topology {
      border: 1px solid #1e1e1e;
      border-radius: 8px;
      background: #111;
      padding: 16px 20px;
      margin-bottom: 16px;
      overflow-x: auto;
    }
    .topology svg { display: block; margin: 0 auto; }
    .topo-label { font-size: 11px; fill: #aaa; font-family: monospace; }
    .topo-line { stroke: #333; stroke-width: 1.5; }
    .topo-node { stroke-width: 2; }
    .topo-node.online  { fill: #00ff41; stroke: #00ff41; filter: drop-shadow(0 0 4px #00ff41); }
    .topo-node.offline { fill: #ff4444; stroke: #ff4444; }
    .topo-node.stale   { fill: #ffaa00; stroke: #ffaa00; }
    .topo-node.unknown { fill: #444; stroke: #666; }

    /* ── Device count bar ── */
    .device-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 20px;
      background: #111;
      border: 1px solid #1e1e1e;
      border-radius: 8px;
      margin-bottom: 16px;
      font-size: 0.8rem;
      color: #aaa;
      letter-spacing: 1px;
    }
    .device-bar span.online-count { color: #00ff41; font-weight: bold; }
    .device-bar span.offline-count { color: #ff4444; }

    /* ── Device cards ── */
    .cards {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 12px;
    }
    .card {
      border: 1px solid #1e1e1e;
      border-radius: 8px;
      padding: 14px 16px;
      background: #111;
      transition: box-shadow 0.3s, border-color 0.3s;
      position: relative;
      overflow: hidden;
    }
    .card:hover { border-color: #333; }
    .card.online  {
      border-color: #00ff4122;
      box-shadow: 0 0 12px #00ff4115;
    }
    .card.offline { border-color: #ff444422; opacity: 0.7; }
    .card.stale   { border-color: #ffaa0022; }

    .card.flash-on  { animation: flash-green 0.6s ease; }
    .card.flash-off { animation: flash-red 0.6s ease; }
    @keyframes flash-green {
      0% { background: #00ff4133; }
      100% { background: #111; }
    }
    @keyframes flash-red {
      0% { background: #ff444433; }
      100% { background: #111; }
    }

    .card-status {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;
    }
    .status-dot {
      width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0;
    }
    .status-dot.online  { background: #00ff41; box-shadow: 0 0 6px #00ff41; }
    .status-dot.offline { background: #ff4444; }
    .status-dot.stale   { background: #ffaa00; }
    .status-label { font-size: 0.7rem; letter-spacing: 1px; text-transform: uppercase; }
    .status-label.online  { color: #00ff41; }
    .status-label.offline { color: #ff4444; }
    .status-label.stale   { color: #ffaa00; }

    .card-name { font-size: 0.95rem; color: #fff; margin-bottom: 8px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .card-detail { font-size: 0.75rem; color: #666; margin-bottom: 3px; }
    .card-detail span { color: #aaa; }
    .card-bw { margin-top: 8px; font-size: 0.75rem; }
    .card-bw .up { color: #00ff41; margin-right: 12px; }
    .card-bw .down { color: #4af; }

    .last-scan { text-align: right; margin-top: 16px; font-size: 0.7rem; color: #444; letter-spacing: 1px; }
  </style>
</head>
<body>

  <!-- Header -->
  <div class="header">
    <div class="header-title">🌐 HomeNet Dashboard</div>
    <div class="header-stats">
      <span>↑ <span class="bw-up" id="bw-up">--</span></span>
      <span>↓ <span class="bw-down" id="bw-down">--</span></span>
      <span><span class="live-dot"></span>LIVE</span>
    </div>
  </div>

  <!-- Topology map -->
  <div class="topology">
    <svg id="topo-svg" width="680" height="100" viewBox="0 0 680 100"></svg>
  </div>

  <!-- Device count -->
  <div class="device-bar">
    <span>DEVICES</span>
    <span>
      <span class="online-count" id="count-online">0</span> online &nbsp;·&nbsp;
      <span class="offline-count" id="count-offline">0</span> offline
    </span>
  </div>

  <!-- Cards -->
  <div class="cards" id="cards"></div>

  <div class="last-scan">Last scan: <span id="last-scan">--</span></div>

<script>
  // Known topology — static layout for the SVG map
  // Each node: id (matches IP suffix), label, x, y
  // Edges: [from_id, to_id]
  const TOPO_NODES = [
    { id: "ont",  label: "ONT",      x: 40,  y: 50 },
    { id: "0.1",  label: "Router",   x: 150, y: 50 },
    { id: "0.2",  label: "Work AP",  x: 280, y: 25 },
    { id: "0.3",  label: "Sleep AP", x: 400, y: 25 },
    { id: "0.10", label: "Server",   x: 280, y: 75 },
    { id: "0.100",label: "Laptop",   x: 400, y: 75 },
  ];
  const TOPO_EDGES = [
    ["ont","0.1"], ["0.1","0.2"], ["0.1","0.3"], ["0.1","0.10"], ["0.10","0.100"]
  ];

  let prevStatuses = {};

  function fmtBytes(bps) {
    if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s";
    if (bps >= 1024)    return (bps / 1024).toFixed(0) + " KB/s";
    return bps + " B/s";
  }

  function timeSince(isoStr) {
    if (!isoStr || isoStr === "never") return "never";
    const diff = Math.floor((Date.now() - new Date(isoStr)) / 1000);
    if (diff < 10) return "just now";
    if (diff < 60) return diff + "s ago";
    return Math.floor(diff / 60) + "m ago";
  }

  function buildTopo(devices) {
    const svg = document.getElementById("topo-svg");
    const statusMap = {};
    devices.forEach(d => {
      const suffix = d.ip.split(".").slice(2).join(".");
      statusMap[suffix] = d.status;
    });

    svg.innerHTML = "";

    // Draw edges first
    TOPO_EDGES.forEach(([a, b]) => {
      const na = TOPO_NODES.find(n => n.id === a);
      const nb = TOPO_NODES.find(n => n.id === b);
      if (!na || !nb) return;
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", na.x); line.setAttribute("y1", na.y);
      line.setAttribute("x2", nb.x); line.setAttribute("y2", nb.y);
      line.setAttribute("class", "topo-line");
      svg.appendChild(line);
    });

    // Draw nodes
    TOPO_NODES.forEach(node => {
      const status = node.id === "ont" ? "online" : (statusMap[node.id] || "unknown");
      const g = document.createElementNS("http://www.w3.org/2000/svg", "g");

      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
      circle.setAttribute("cx", node.x); circle.setAttribute("cy", node.y);
      circle.setAttribute("r", 7);
      circle.setAttribute("class", `topo-node ${status}`);
      g.appendChild(circle);

      const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
      text.setAttribute("x", node.x); text.setAttribute("y", node.y + 20);
      text.setAttribute("text-anchor", "middle");
      text.setAttribute("class", "topo-label");
      text.textContent = node.label;
      g.appendChild(text);

      svg.appendChild(g);
    });
  }

  function updateDashboard(data) {
    // Bandwidth
    document.getElementById("bw-up").textContent = fmtBytes(data.bandwidth.upload_bps);
    document.getElementById("bw-down").textContent = fmtBytes(data.bandwidth.download_bps);
    document.getElementById("last-scan").textContent = new Date(data.scanned_at).toLocaleTimeString();

    // Counts
    const online = data.devices.filter(d => d.status === "online").length;
    const offline = data.devices.filter(d => d.status !== "online").length;
    document.getElementById("count-online").textContent = online;
    document.getElementById("count-offline").textContent = offline;

    // Topology
    buildTopo(data.devices);

    // Cards
    const container = document.getElementById("cards");
    const existingCards = {};
    container.querySelectorAll(".card[data-ip]").forEach(el => {
      existingCards[el.dataset.ip] = el;
    });

    data.devices.forEach(device => {
      const prev = prevStatuses[device.ip];
      const card = existingCards[device.ip] || document.createElement("div");

      if (!card.dataset.ip) {
        card.dataset.ip = device.ip;
        container.appendChild(card);
      }

      // Flash on status change
      if (prev && prev !== device.status) {
        card.classList.remove("flash-on", "flash-off");
        void card.offsetWidth; // reflow
        if (device.status === "online") card.classList.add("flash-on");
        else card.classList.add("flash-off");
      }

      card.className = `card ${device.status}`;
      card.innerHTML = `
        <div class="card-status">
          <div class="status-dot ${device.status}"></div>
          <span class="status-label ${device.status}">${device.status}</span>
        </div>
        <div class="card-name">${device.name}</div>
        <div class="card-detail">IP: <span>${device.ip}</span></div>
        <div class="card-detail">MAC: <span>${device.mac}</span></div>
        <div class="card-detail">Vendor: <span>${device.vendor}</span></div>
        <div class="card-detail">Last seen: <span>${timeSince(device.last_seen)}</span></div>
      `;

      prevStatuses[device.ip] = device.status;
    });
  }

  function poll() {
    fetch("/api/scan")
      .then(r => r.json())
      .then(data => updateDashboard(data))
      .catch(err => console.error("Scan failed:", err));
  }

  poll();
  setInterval(poll, 5000);
</script>
</body>
</html>
```

- [ ] **Step 3: Test the full app locally**

```bash
cd ~/home-network/dashboard
pip3 install flask --quiet
python3 app.py &
sleep 3
curl -s http://localhost:8080/api/scan | python3 -m json.tool | head -30
```

Expected: JSON with `scanned_at`, `interface`, `bandwidth`, and `devices` array. At least one device (router at .0.1) should appear as `"status": "online"`.

Open `http://localhost:8080` in a browser — verify the header, topology map, and device cards render.

Kill the test server:
```bash
pkill -f "python3 app.py"
```

- [ ] **Step 4: Commit**

```bash
cd ~/home-network
git add dashboard/templates/index.html
git commit -m "feat: add hybrid dashboard UI with topology map and device cards"
```

---

### Task 5: Dockerfile and docker-compose integration

**Files:**
- Create: `~/home-network/dashboard/Dockerfile`
- Modify: `~/home-network/config/docker/docker-compose.yml`

**Interfaces:**
- Consumes: `dashboard/app.py`, `dashboard/requirements.txt` (Tasks 2–4)
- Produces: `homenet-dashboard` Docker service accessible at port `8080`

- [ ] **Step 1: Create Dockerfile**

Create `~/home-network/dashboard/Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system deps for ping and ip commands
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["python3", "app.py"]
```

- [ ] **Step 2: Test Docker build**

```bash
cd ~/home-network/dashboard
docker build -t homenet-dashboard:test .
```

Expected: `Successfully built` with no errors.

- [ ] **Step 3: Test Docker run**

```bash
docker run --rm --network host --cap-add NET_RAW \
  -e NETWORK_PREFIX=192.168.0 \
  -e INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1) \
  homenet-dashboard:test &
sleep 5
curl -s http://localhost:8080/api/scan | python3 -m json.tool | grep -E '"status"|"ip"' | head -10
```

Expected: JSON with at least one `"status": "online"` device.

```bash
docker stop $(docker ps -q --filter ancestor=homenet-dashboard:test)
```

- [ ] **Step 4: Add service to docker-compose.yml**

Open `~/home-network/config/docker/docker-compose.yml` and add before the final closing line:

```yaml
  # ── HomeNet Dashboard ────────────────────────────────────────────
  homenet-dashboard:
    build: ../../dashboard
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

- [ ] **Step 5: Validate compose file**

```bash
cd ~/home-network/config/docker
docker compose config --quiet && echo "Compose file valid"
```

Expected: `Compose file valid`

- [ ] **Step 6: Commit and push**

```bash
cd ~/home-network
git add dashboard/Dockerfile config/docker/docker-compose.yml
git commit -m "feat: add Dockerfile and docker-compose service for homenet-dashboard"
git push origin main
```

---

### Task 6: Final verification

- [ ] **Step 1: Verify GitHub repo is complete**

```bash
gh repo view Ang-m/home-network --web
```

Confirm in browser: all folders visible (`dashboard/`, `config/`, `notes/`, `scripts/`, `diagrams/`, `docs/`).

- [ ] **Step 2: Record local clone path in memory**

The working directory for the homenet project is now `~/home-network/`. The old `aiproject/homenet/` folder can be archived or left in place — it is no longer the source of truth.

- [ ] **Step 3: Note server deployment instructions**

When the server arrives (2026-06-23), deploy with:

```bash
# On the server after Proxmox + Docker LXC is set up:
git clone https://github.com/Ang-m/home-network.git ~/home-network
cd ~/home-network/config/docker
docker compose up -d homenet-dashboard
```

Access at: `http://192.168.0.10:8080`
