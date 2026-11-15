#!/bin/sh
# Opens a system monitor: first graphical apps; if none, btop/htop in a terminal.
# Exits with 1 if none is found (the island notifies it).
for a in missioncenter gnome-system-monitor plasma-systemmonitor; do
    command -v "$a" >/dev/null 2>&1 && { setsid -f "$a" >/dev/null 2>&1; exit 0; }
done
m=$(command -v btop || command -v htop) || exit 1
for t in kitty alacritty foot; do
    command -v "$t" >/dev/null 2>&1 || continue
    [ "$t" = foot ] && { setsid -f foot "$m" >/dev/null 2>&1; exit 0; }
    setsid -f "$t" -e "$m" >/dev/null 2>&1; exit 0
done
exit 1
