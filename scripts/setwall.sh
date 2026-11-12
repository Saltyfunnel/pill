#!/usr/bin/env bash
# setwall.sh — set the wallpaper AND recolour the whole desktop from it.
#   setwall.sh /path/to/image.jpg   use this image
#   setwall.sh --random             random image from ~/Pictures/Wallpapers
#   setwall.sh --restore            re-apply the last one (run this at login)
set -euo pipefail
export PATH="$PATH:$HOME/.cargo/bin"

# Debug logging to catch environment issues
exec >> /tmp/setwall_debug.log 2>&1
echo "--- RUN AT $(date) ---"
echo "Arguments received: $*"
echo "HYPRLAND_INSTANCE_SIGNATURE: ${HYPRLAND_INSTANCE_SIGNATURE:-NOT_SET}"

WALL_DIR="$HOME/Pictures/Wallpapers"
STATE="$HOME/.cache/current_wallpaper"
mkdir -p "$(dirname "$STATE")"

random_wall() {
    find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1
}

case "${1:-}" in
    --restore) sleep 1; wall=$(cat "$STATE" 2>/dev/null || true); [[ -n "$wall" ]] || wall=$(random_wall) ;;
    --random|"") wall=$(random_wall) ;;
    *) wall="$1" ;;
esac

[[ -f "$wall" ]] || { echo "No wallpaper found: '$wall'" >&2; exit 1; }
echo "$wall" > "$STATE"

# 1. Show the wallpaper (hyprpaper)
hyprctl hyprpaper wallpaper ",$wall" >/dev/null 2>&1 \
    || echo "warning: hyprpaper call failed (is hyprpaper running?)" >&2

# 2. Recolour everything from it
#    Grey wallpapers get a monochrome scheme (matugen would otherwise fall back to its default blue seed).
#    Colourful ones get a scheme that spreads hues across primary/secondary/tertiary.
sat=$(magick "$wall" -resize 64x64 -colorspace HSL -channel G -separate +channel \
      -format '%[fx:mean]' info: 2>/dev/null) || sat=1

if awk "BEGIN { exit !($sat < 0.08) }"; then
    scheme="scheme-monochrome"
else
    scheme="scheme-content"
fi
echo "saturation=$sat scheme=$scheme"

matugen image "$wall" -m dark -t "$scheme" --prefer saturation
# 3. Recolour the folder icons to match
"$HOME/.config/scripts/recolor-icons.sh" "$(cat "$HOME/.cache/accent_color")"

# Sync colors to global cache for SDDM access
if [ -f "$HOME/.cache/wal/colors.json" ]; then
    cp -f "$HOME/.cache/wal/colors.json" /var/cache/wal/colors.json 2>/dev/null || true
    chmod 644 /var/cache/wal/colors.json 2>/dev/null || true
fi

# Thunar only reads its CSS at launch, so drop the daemon and let it restart with the new colours
pkill -x thunar 2>/dev/null || true

# File dialogs (Zed, Firefox, uploads) are drawn by this portal, which also only reads its CSS at launch
systemctl --user restart xdg-desktop-portal-gtk 2>/dev/null || true
