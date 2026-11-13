#!/usr/bin/env python3
# "Free memory": closes with Hyprland's normal close (like Super+Q) all
# windows except the focused one. It never kills processes: each app can save or prompt.
# Tray apps (Steam, Discord) are not windows and remain open.
# Usage: free-mem.py [--dry-run]. Prints JSON: { closed, ram, vram } (freed MiB or null).
import json, shutil, subprocess, sys, time

def hypr(*a):
    return subprocess.run(["hyprctl", *a], capture_output=True, text=True, timeout=5).stdout

def ram_avail():
    try:
        for l in open("/proc/meminfo"):
            if l.startswith("MemAvailable:"): return int(l.split()[1]) // 1024
    except OSError: pass
    return None

def rss(pid):
    try:
        for l in open("/proc/%d/status" % pid):
            if l.startswith("VmRSS:"): return int(l.split()[1]) // 1024
    except (OSError, ValueError, TypeError): pass
    return 0

def vram_used():
    if not shutil.which("nvidia-smi"): return None
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=3).stdout
        return sum(int(x) for x in out.split() if x.isdigit())
    except Exception: return None

def main():
    dry = "--dry-run" in sys.argv
    active = (json.loads(hypr("activewindow", "-j") or "{}") or {}).get("address", "")
    clients = [c for c in json.loads(hypr("clients", "-j") or "[]")
               if c.get("mapped", True) and c.get("address") != active]
    targets = [c["address"] for c in clients]
    if dry:
        # For panel confirmation: which apps are closed and how much RAM each uses.
        apps = {}
        for c in clients:
            name = c.get("class") or c.get("title") or "?"
            apps.setdefault(name, set()).add(c.get("pid", 0))
        out = sorted(({"name": k, "mb": sum(rss(p) for p in v)} for k, v in apps.items()), key=lambda a: -a["mb"])
        print(json.dumps({"closed": len(targets), "ram": None, "vram": None, "dry": True, "targets": targets, "apps": out})); return
    r0, v0 = ram_avail(), vram_used()
    for a in targets:
        hypr("dispatch", 'hl.dsp.window.close({ window = "address:%s" })' % a)
    if targets: time.sleep(2.5)          # give apps time to finish closing
    r1, v1 = ram_avail(), vram_used()
    ram = max(0, r1 - r0) if r0 is not None and r1 is not None else None
    vram = max(0, v0 - v1) if v0 is not None and v1 is not None else None
    print(json.dumps({"closed": len(targets), "ram": ram, "vram": vram}))

if __name__ == "__main__":
    main()
