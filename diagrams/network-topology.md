# Network Topology — 2BHK Home Network

## Full Diagram

```
INTERNET (Airtel Fibre 200Mbps)
    │
    ▼
┌─────────────────────────┐
│  Airtel ONT/Modem       │  ← Bridge mode (Airtel routes, we control DNS/DHCP)
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│  MAIN HALL                                          │
│                                                     │
│  ┌──────────────────────────────────────┐           │
│  │  TP-Link Archer C6  (OpenWrt)        │           │
│  │  IP: 192.168.1.1                     │           │
│  │  DHCP: 192.168.1.100–200             │           │
│  │  DNS → 192.168.1.10 (Pi-hole)        │           │
│  │  WiFi: "HomeNet" 2.4GHz + 5GHz      │           │
│  └───┬──────────────┬────────────┬──────┘           │
│      │              │            │                   │
│    LAN1           LAN2         LAN3                  │
│      │         (in-wall)    (in-wall)                │
│      │                                              │
│  📺 Hall Smart TV                                    │
│     (3m patch cable)                                │
│                                                     │
│  📱 Phones  🔊 Alexa  💡 Smart Bulbs  (WiFi)        │
└─────────────────────────────────────────────────────┘
                    │                    │
            ════════╪════════    ════════╪════════
            WORK BEDROOM         SLEEP BEDROOM
            ════════════════    ═════════════════
            │                    │
            ▼                    ▼
      ┌──────────────┐     ┌──────────────┐
      │ 5-port Switch│     │ 5-port Switch│
      │ TP-Link      │     │ TP-Link      │
      └──┬───────────┘     └──┬───────────┘
         │                    │
         ├── TP-Link Extender  ├── TP-Link TL-WA801N
         │   (existing)       │   (new, ~₹1,000)
         │   AP mode          │   AP mode
         │   📡 WiFi           │   📡 WiFi
         │                    │
         ├── Used PC (Server)  └── 📺 Sleep TV (wired)
         │   192.168.1.10
         │   [Pi-hole, WireGuard, Jellyfin,
         │    Home Assistant, Samba, Syncthing,
         │    Ollama, Open-WebUI, Portainer]
         │   Storage: 2TB HDD (/mnt/data)
         │   Future: GPU + more HDDs
         │
         ├── Your WFH laptop (wired)
         └── Wife's WFH laptop (wired)
```

## IP Address Reference

| Device | IP | Type |
|---|---|---|
| Archer C6 router | 192.168.1.1 | Static |
| Work bedroom extender | 192.168.1.2 | Static (manual on device) |
| Sleep bedroom AP (WA801N) | 192.168.1.3 | Static (manual on device) |
| Used PC (server) | 192.168.1.10 | Static (DHCP reservation in OpenWrt) |
| All other devices | 192.168.1.100–200 | DHCP |
| IoT VLAN (future) | 192.168.10.0/24 | Separate subnet |

## Service Port Map

| Service | URL | Port |
|---|---|---|
| Pi-hole dashboard | http://192.168.1.10/admin | :80 |
| Portainer | http://192.168.1.10:9000 | :9000 |
| Jellyfin | http://192.168.1.10:8096 | :8096 |
| Home Assistant | http://192.168.1.10:8123 | :8123 |
| WireGuard UI | http://192.168.1.10:51821 | :51821 |
| Syncthing | http://192.168.1.10:8384 | :8384 |
| Open-WebUI (LLMs) | http://192.168.1.10:3000 | :3000 |
| Ollama API | http://192.168.1.10:11434 | :11434 |
