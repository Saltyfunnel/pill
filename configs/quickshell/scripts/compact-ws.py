#!/usr/bin/env python3
# Compacts workspaces: if a gap remains (e.g., 1 and 3 have windows), windows from 3
# move to 2, etc. If you are on an empty workspace it does nothing (it compacts upon
# leaving). Run by Hyprland events (no polling). Usage: compact-ws.py [--dry-run]
import json, subprocess, sys

def hypr(*a):
    return subprocess.run(["hyprctl", *a], capture_output=True, text=True, timeout=5).stdout

def main():
    dry = "--dry-run" in sys.argv
    active = (json.loads(hypr("activeworkspace", "-j") or "{}") or {}).get("id", -1)
    by_ws = {}
    for c in json.loads(hypr("clients", "-j") or "[]"):
        wid = (c.get("workspace") or {}).get("id", -1)
        if wid > 0 and c.get("mapped", True):
            by_ws.setdefault(wid, []).append(c["address"])
    if active > 0 and active not in by_ws:
        return                     # the user is on an empty workspace
    occ = sorted(by_ws)
    moves = [(src, i + 1) for i, src in enumerate(occ) if src != i + 1]
    if not moves: return
    if dry: print(json.dumps(moves)); return
    for src, dst in moves:
        for a in by_ws[src]:
            hypr("dispatch", 'hl.dsp.window.move({ workspace = "%d", follow = false, window = "address:%s" })' % (dst, a))
    if active in occ and active != occ.index(active) + 1:
        hypr("dispatch", 'hl.dsp.focus({ workspace = "%d" })' % (occ.index(active) + 1))

if __name__ == "__main__":
    main()
