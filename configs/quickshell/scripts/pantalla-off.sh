#!/bin/sh
# Turn off screen without disconnecting it: software DPMS. The monitor stays "connected" for
# Hyprland, so windows, workspaces, and games stay exactly where they are.
# It turns back on by moving the mouse or pressing a key (misc.*_enables_dpms).
# Waits ~1 s so that the click or releasing the shortcut doesn't wake it up instantly.
# Never suspends or locks the PC.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/island-screen-off.lock"
# Only one shutdown at a time (double click or repeated shortcut).
exec 9>"$LOCK"
flock -n 9 || exit 0
sleep "${ISLAND_DPMS_DELAY:-1}"
exec hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
