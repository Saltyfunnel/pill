#!/usr/bin/env bash
################################################################################
# install-sddm-theme.sh — a login screen that follows your wallpaper colours.
# Run from the repo folder, AFTER install.sh, as your normal user:
#     bash scripts/install-sddm-theme.sh
# (install.sh also runs it for you.)
#
# Colours are written to /var/cache/wal/colors.json by matugen every time you
# change wallpaper (see the [templates.sddm] block in configs/matugen/config.toml).
################################################################################
set -euo pipefail

THEME_NAME="material-sddm"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SDDM_CONF_DIR="/etc/sddm.conf.d"
COLORS_DIR="/var/cache/wal"
CURRENT_USER="${SUDO_USER:-$USER}"

# Find the repo root. install.sh passes it in; otherwise work it out from where
# this script lives (the repo root itself, or the scripts/ folder inside it).
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ ! -f "$REPO_ROOT/configs/sddm/Main.qml" && -f "$REPO_ROOT/../configs/sddm/Main.qml" ]]; then
    REPO_ROOT="$(cd "$REPO_ROOT/.." && pwd)"
fi

[[ -f "$REPO_ROOT/configs/sddm/Main.qml" ]] || { echo "Missing configs/sddm/Main.qml (looked in $REPO_ROOT)." >&2; exit 1; }

echo "==> Installing packages (login screen toolkit + the icon font it uses)..."
sudo pacman -S --needed --noconfirm sddm qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects ttf-hack-nerd

echo "==> Creating the theme folder and the colours folder..."
sudo mkdir -p "$THEME_DIR" "$COLORS_DIR"
# matugen (running as you) writes colors.json here, and the login screen only reads it
sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$COLORS_DIR"
sudo chmod 755 "$COLORS_DIR"

# Starter colours, only if matugen hasn't written the file yet
if [[ ! -f "$COLORS_DIR/colors.json" ]]; then
    echo '{"special":{"background":"#1e1e2e","foreground":"#cdd6f4"},"colors":{"color0":"#11111b","color4":"#89b4fa"}}' > "$COLORS_DIR/colors.json"
    chown "$CURRENT_USER:$CURRENT_USER" "$COLORS_DIR/colors.json"
fi
chmod 644 "$COLORS_DIR/colors.json"

echo "==> Installing the theme..."
sudo install -m 644 "$REPO_ROOT/configs/sddm/Main.qml" "$THEME_DIR/Main.qml"

sudo tee "$THEME_DIR/metadata.desktop" > /dev/null << META
[SddmGreeterTheme]
Name=${THEME_NAME}
Description=A sleek minimalist theme that imports Material colors dynamically
Author=Custom
Type=sddm-theme
ConfigFile=theme.conf
MainScript=Main.qml
META

echo "==> Telling SDDM to use it..."
sudo mkdir -p "$SDDM_CONF_DIR"
sudo tee "$SDDM_CONF_DIR/theme.conf" > /dev/null << CONF
[Theme]
Current=${THEME_NAME}

[General]
# lets the login screen read /var/cache/wal/colors.json (Qt blocks local file reads by default)
GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1
CONF

sudo systemctl enable sddm.service

echo
echo "Done. The login screen picks up the colours the next time it appears."
echo "Log out or reboot to see it. (This script does not restart SDDM, because"
echo "that would end your current session.)"
