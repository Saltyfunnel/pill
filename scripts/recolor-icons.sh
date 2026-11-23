#!/usr/bin/env bash
# Recolour Colloid folder icons to the wallpaper accent.   usage: recolor-icons.sh '#rrggbb'
set -uo pipefail
ICON_DIR="$HOME/.local/share/icons/Colloid-Dynamic-Dark"
STATE="$HOME/.cache/folder_accent"
new="${1:?usage: recolor-icons.sh '#rrggbb'}"
new="${new,,}"

[[ -d "$ICON_DIR/places" ]] || { echo "recolor-icons: $ICON_DIR/places not found" >&2; exit 1; }

# Find the colour the folders really have now, instead of trusting the state file
sample=$(find "$ICON_DIR/places" -type f -name 'folder.svg' | head -n1)
old=""
if [[ -n "$sample" ]]; then
    # ignore the neutral colours Colloid uses for shading; what is left is the folder colour
    old=$(grep -oiE '#[0-9a-f]{6}' "$sample" | tr 'A-F' 'a-f' \
        | grep -vxE '#(ffffff|000000|333333|363636|dedede)' \
        | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')
fi
[[ -n "$old" ]] || old=$(cat "$STATE" 2>/dev/null || echo "#60c0f0")

if [[ "$old" == "$new" ]]; then
    echo "recolor-icons: already $new"
    exit 0
fi

# -type f skips symlinks, so sed can't turn them into copies
find "$ICON_DIR/places" -type f -name '*.svg' -exec sed -i "s/${old}/${new}/Ig" {} +
echo "$new" > "$STATE"
echo "recolor-icons: $old -> $new"
gtk-update-icon-cache -f -t "$ICON_DIR" >/dev/null 2>&1 || true
