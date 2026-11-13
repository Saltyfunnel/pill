#!/bin/sh
# Screenshot: screenshot.sh area | full
# Saves in ~/Pictures/Screenshots (name with milliseconds: two consecutive screenshots never overwrite each other)
# and leaves it in the clipboard as image/png (wl-copy keeps serving it in the background).
d="$HOME/Pictures/Screenshots"
mkdir -p "$d" || exit 1
f="$d/screenshot-$(date +%Y%m%d-%H%M%S-%3N).png"
case "$1" in
    area) g=$(slurp) || exit 0; grim -g "$g" "$f" || exit 1 ;;
    *) grim "$f" || exit 1 ;;
esac
[ -s "$f" ] || exit 1
wl-copy --type image/png < "$f"

# Notice with thumbnail (only if the screenshot succeeded). gdbus comes with glib2: no new dependencies.
# image-path = the screenshot; x-island-open = file opened by clicking the notification.
q=$(printf '%s' "$f" | sed "s/'/\\\\'/g")
# Language (Settings › Personalization › Language, in ~/.config/island-shell/state.json).
if grep -q '"language": *"es"' "$HOME/.config/island-shell/state.json" 2>/dev/null; then
    t1="Captura guardada"; t2="Copiada al portapapeles"
else
    t1="Screenshot saved"; t2="Copied to the clipboard"
fi
gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify "Screenshots" 0 "" "$t1" "$t2" "[]" \
    "{'image-path': <'file://$q'>, 'x-island-open': <'$q'>}" 4000 >/dev/null 2>&1 || true
