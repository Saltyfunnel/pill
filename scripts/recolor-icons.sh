#!/usr/bin/env bash
# Recolour Colloid folder icons to the wallpaper accent.   usage: recolor-icons.sh '#rrggbb'
set -euo pipefail
ICON_DIR="$HOME/.local/share/icons/Colloid-Dynamic-Dark"
STATE="$HOME/.cache/folder_accent"
new="${1:?usage: recolor-icons.sh '#rrggbb'}"
old=$(cat "$STATE" 2>/dev/null || echo "#60c0f0")

[[ "${new,,}" == "${old,,}" ]] && exit 0

# -type f skips symlinks, so sed can't turn them into copies
find "$ICON_DIR/places" -type f -name '*.svg' -exec sed -i "s/${old}/${new}/Ig" {} +
echo "$new" > "$STATE"
gtk-update-icon-cache -f -t "$ICON_DIR" >/dev/null 2>&1 || true
