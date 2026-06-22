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
    if not mac or mac == "--:--:--:--:--:--":
        return "Unknown"
    prefix = mac.upper()[:8]
    return _OUI_TABLE.get(prefix, "Unknown")
