#!/bin/sh
# Screenshot: screenshot.sh area | window | screen | delay
#   area    pick a region with slurp
#   window  the focused window
#   screen  everything, right now
#   delay   everything, after a 3 second countdown
# Saves in ~/Pictures/Screenshots (name with milliseconds: two consecutive screenshots never overwrite each other)
# and leaves it in the clipboard as image/png (wl-copy keeps serving it in the background).
d="$HOME/Pictures/Screenshots"
f="$d/screenshot-$(date +%Y%m%d-%H%M%S-%3N).png"

if grep -q '"language": *"es"' "$HOME/.config/island-shell/state.json" 2>/dev/null; then
    t1="Captura guardada"; t2="Copiada al portapapeles"; tf="No se pudo hacer la captura"
else
    t1="Screenshot saved"; t2="Copied to the clipboard"; tf="Screenshot failed"
fi

fail() {
    command -v notify-send >/dev/null 2>&1 && notify-send -u critical "$tf" "$1"
    echo "screenshot: $1" >&2
    exit 1
}

for tool in grim wl-copy; do
    command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed"
done
mkdir -p "$d" || fail "cannot create $d"

case "${1:-area}" in
    area)
        command -v slurp >/dev/null 2>&1 || fail "slurp is not installed"
        g=$(slurp) || exit 0                       # Esc / right click: cancelled, not an error
        [ -n "$g" ] || exit 0
        grim -g "$g" "$f" || fail "grim could not capture the area"
        ;;
    window)
        g=$(hyprctl -j activewindow 2>/dev/null | python3 -c '
import json, sys
try:
    w = json.load(sys.stdin)
    print("%d,%d %dx%d" % (w["at"][0], w["at"][1], w["size"][0], w["size"][1]))
except Exception:
    pass')
        [ -n "$g" ] || fail "no focused window"
        grim -g "$g" "$f" || fail "grim could not capture the window"
        ;;
    delay)
        for i in 3 2 1; do
            command -v notify-send >/dev/null 2>&1 && notify-send -u critical -t 950 "Screenshot in $i..."
            sleep 1
        done
        grim "$f" || fail "grim could not capture the screen"
        ;;
    screen)
        grim "$f" || fail "grim could not capture the screen"
        ;;
    *)
        fail "usage: screenshot.sh area|window|screen|delay"
        ;;
esac
[ -s "$f" ] || fail "the screenshot is empty"
wl-copy --type image/png < "$f"

# Notice with thumbnail (only if the screenshot succeeded). gdbus comes with glib2: no new dependencies.
# image-path = the screenshot; x-island-open = file opened by clicking the notification.
q=$(printf '%s' "$f" | sed "s/'/\\\\'/g")
gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify "Screenshots" 0 "" "$t1" "$t2" "[]" \
    "{'image-path': <'file://$q'>, 'x-island-open': <'$q'>}" 4000 >/dev/null 2>&1 || true
