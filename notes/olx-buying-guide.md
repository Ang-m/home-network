# OLX Used PC Buying Guide — Bengaluru

## What to Search For

Search terms on OLX / Facebook Marketplace Bengaluru:
- `i5 tower desktop`
- `gaming desktop i5`
- `HP ProDesk tower`
- `Dell OptiPlex tower`
- `i5 8th gen desktop`

## Minimum Acceptable Spec

| Spec | Minimum | Why |
|---|---|---|
| CPU | i5 6th gen (6500/6400) | Enough for all Docker services + iGPU transcoding |
| RAM | 8GB DDR4 | Upgradeable to 16GB for ~₹1,500 used |
| Storage | Any HDD included | Will add 2TB SATA HDD separately |
| Form factor | **Mid-tower** | Needs drive bays + PCIe x16 for future GPU |
| PCIe x16 slot | Must be free | For gaming GPU in Phase 3 |
| Drive bays | 2+ free 3.5" bays | For NAS expansion in Phase 2 |

## Preferred Spec (worth paying ₹2,000–3,000 more)
- i5 8th gen (8400/8500)
- 16GB DDR4
- 256GB SSD (for OS) + HDD (for data)

## Models to Look For
- **Dell OptiPlex 7060 Tower / 5060 Tower** — excellent build, easy to upgrade
- **HP ProDesk 600 G4 Tower** — solid, common in Bengaluru
- **Lenovo ThinkCentre M720 Tower** — reliable, multiple drive bays
- **Custom mid-tower** with B360/H370/B450 motherboard — flexible, check PSU age

## Red Flags — Walk Away
- SFF (Small Form Factor) case — no room for GPU, limited drive bays
- No PSU included — add ₹2,000–3,000 for a replacement
- Yellowed/burnt capacitors visible on motherboard
- Seller can't boot the machine in front of you

## How to Test Before Paying
1. Boot from a USB (bring Ubuntu live USB)
2. Open terminal: `sudo lshw -short` — verify RAM and storage
3. Run: `stress-ng --cpu 4 --timeout 60s` — watch for thermal shutdowns
4. Check PCIe x16 slot is physically empty and accessible
5. Count 3.5" drive bays with doors open
6. Negotiate 10–15% off asking price — always haggle

## Budget Target
- i5 6th/7th gen, 8GB RAM: ₹8,000–10,000
- i5 8th gen, 16GB RAM: ₹12,000–15,000
- Aim for the lower end — RAM is cheap to upgrade yourself
