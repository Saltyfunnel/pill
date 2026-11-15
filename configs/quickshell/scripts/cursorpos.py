#!/usr/bin/env python3
# Cursor position for the character, without launching hyprctl: a single process that queries
# the Hyprland IPC socket. ~20 Hz while the mouse moves, ~3 Hz if still >1 s and
# ~1.5 Hz if still >10 s (by then the character has stopped following: looks straight ahead).
# Prints "x,y" only when it changes. Exits if the shell closes the output.
import os, socket, sys, time

def sock_path():
    rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        if not os.path.isdir(os.path.join(rt, "hypr")):
            sys.exit(1)                          # without Hyprland: the shell retries
        ds = sorted(os.listdir(os.path.join(rt, "hypr")), key=lambda d: os.path.getmtime(os.path.join(rt, "hypr", d)))
        sig = ds[-1]
    return os.path.join(rt, "hypr", sig, ".socket.sock")

def query(path):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        s.connect(path)
        s.sendall(b"cursorpos")
        data = b""
        while True:
            chunk = s.recv(256)
            if not chunk: break
            data += chunk
    return data.decode(errors="ignore").strip()

path, last, still_since, fails = sock_path(), None, time.monotonic(), 0
while True:
    try:
        pos = query(path); fails = 0
    except OSError:
        fails += 1
        if fails > 20: sys.exit(1)          # Hyprland does not respond: the shell relaunches the process
        time.sleep(0.5); path = sock_path(); continue
    now = time.monotonic()
    if pos != last:
        last, still_since = pos, now
        try:
            print(pos, flush=True)
        except BrokenPipeError:
            sys.exit(0)
    still = now - still_since
    time.sleep(0.05 if still < 1.0 else 0.33 if still < 10.0 else 0.66)
