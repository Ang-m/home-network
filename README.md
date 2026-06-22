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
