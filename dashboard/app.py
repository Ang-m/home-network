import os
import subprocess
import time
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from flask import Flask, jsonify, render_template
from oui import get_vendor

app = Flask(__name__)
app.config["TEMPLATES_AUTO_RELOAD"] = True

NETWORK_PREFIX = os.environ.get("NETWORK_PREFIX", "192.168.0")
INTERFACE = os.environ.get("INTERFACE", "eth0")
SCAN_INTERVAL = int(os.environ.get("SCAN_INTERVAL", "5"))

KNOWN_DEVICES = {
    f"{NETWORK_PREFIX}.1":   "Router (Archer C6)",
    f"{NETWORK_PREFIX}.2":   "Work Bedroom AP (RE305)",
    f"{NETWORK_PREFIX}.3":   "Sleep Bedroom AP (WA850RE)",
    f"{NETWORK_PREFIX}.10":  "Home Server",
    f"{NETWORK_PREFIX}.100": "Angshu's Laptop (LAN)",
    f"{NETWORK_PREFIX}.124": "Angshu's Laptop (LAN)",
    f"{NETWORK_PREFIX}.129": "Angshu's Laptop (WiFi)",
    f"{NETWORK_PREFIX}.121": "Angshu's iPhone 16",
    f"{NETWORK_PREFIX}.148": "Wife's Work Laptop",
    f"{NETWORK_PREFIX}.209": "Wife's Motorola Edge 16 Fusion",
    f"{NETWORK_PREFIX}.243": "Switch (TL-SG105E)",
}

_last_seen: dict[str, str] = {}


def _read_net_dev(interface: str) -> tuple[int, int]:
    with open("/proc/net/dev") as f:
        for line in f:
            if interface in line:
                parts = line.split()
                rx_bytes = int(parts[1])
                tx_bytes = int(parts[9])
                return rx_bytes, tx_bytes
    return 0, 0


def get_bandwidth(interface: str) -> dict:
    rx1, tx1 = _read_net_dev(interface)
    time.sleep(1)
    rx2, tx2 = _read_net_dev(interface)
    return {
        "upload_bps": max(0, tx2 - tx1),
        "download_bps": max(0, rx2 - rx1),
    }


def get_arp_table() -> dict[str, str]:
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
    result = subprocess.run(
        ["ping", "-c", "1", "-W", "1", ip],
        capture_output=True
    )
    return result.returncode == 0


def scan_network() -> list[dict]:
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
    app.run(host="0.0.0.0", port=8080, debug=False, threaded=True)
