#!/bin/bash
################################################################################
# Saltyfunnels Shell installer — Arch Linux + Hyprland + Quickshell + matugen theming
# Login screen: SDDM (matugen-themed).  Lock screen: hyprlock.
# Run from the repo folder:   sudo bash install.sh
################################################################################

set -Eeuo pipefail

################################################################################
# LOOK & FEEL
################################################################################

# A fresh install usually runs in the bare Linux console (TERM=linux): 16 colours,
# and no braille or box-drawing glyphs. So pick a glyph set that always renders.
if [[ "${TERM:-}" != "linux" && "${LC_ALL:-${LANG:-}}" == *[Uu][Tt][Ff]*8* ]]; then
    G_OK="✓"; G_ERR="✗"; G_WARN="!"; G_DOT="·"
    G_FULL="█"; G_EMPTY="░"; G_HR="─"
    SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
else
    G_OK="+"; G_ERR="x"; G_WARN="!"; G_DOT="-"
    G_FULL="#"; G_EMPTY="-"; G_HR="-"
    SPIN=('|' '/' '-' '\')
fi

# Plain 16-colour codes only, so they work everywhere
RST="\e[0m"; BLD="\e[1m"; DIM="\e[2m"
WHT="\e[37m"; BBLK="\e[90m"; BRED="\e[91m"; BGRN="\e[92m"
BYLW="\e[93m"; BMAG="\e[95m"; BCYN="\e[96m"; BWHT="\e[97m"

IS_TTY=0; [[ -t 1 ]] && IS_TTY=1
STEP=0
TOTAL_STEPS=10
IN_RUN=0
WARNINGS=()
START_TIME=$SECONDS
LOG_DIR="/tmp/saltyfunnels-shell-install-logs"
mkdir -p "$LOG_DIR"

_cols() { tput cols 2>/dev/null || echo 80; }

repeat() {  # repeat <char> <count>
    local out="" i
    for (( i = 0; i < $2; i++ )); do out+="$1"; done
    printf '%s' "$out"
}

fmt_time() {  # fmt_time <seconds>
    local s=$1
    if (( s >= 60 )); then printf '%dm%02ds' $(( s / 60 )) $(( s % 60 )); else printf '%ds' "$s"; fi
}

hr() { echo -e "${BBLK}$(repeat "$G_HR" "$(( $(_cols) > 60 ? 60 : $(_cols) ))")${RST}"; }

# Animated line with a live elapsed timer. The timer alone shows it hasn't hung,
# even if a console font renders the spinner glyph badly.
spinner() {
    local pid=$1 msg="$2" start=$SECONDS i=0
    (( IS_TTY )) || return 0
    msg="${msg:0:$(( $(_cols) - 24 ))}"
    printf '\e[?25l'
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r\e[K    %b%s%b  %s  %b%s%b' "$BCYN" "${SPIN[$i]}" "$RST" "$msg" "$BBLK" "$(fmt_time $(( SECONDS - start )))" "$RST"
        i=$(( (i + 1) % ${#SPIN[@]} ))
        sleep 0.1
    done
    printf '\r\e[K\e[?25h'
}

# Status lines are transient: in a terminal they overwrite the current line, so
# only what's happening right now is visible. Without a TTY (piped/logged) they
# print as normal lines instead.
status() {
    if (( IS_TTY )); then printf '\r\e[K%b' "$1"; else printf '%b\n' "$1"; fi
}

print_phase() {
    STEP=$((STEP + 1))
    local width=30
    local pct=$(( STEP * 100 / TOTAL_STEPS )); [[ $pct -gt 100 ]] && pct=100
    local full=$(( STEP * width / TOTAL_STEPS )); [[ $full -gt $width ]] && full=$width
    local bar="${BCYN}$(repeat "$G_FULL" "$full")${RST}${BBLK}$(repeat "$G_EMPTY" $(( width - full )))${RST}"
    if (( IS_TTY )); then clear; fi
    echo ""
    echo -e "    ${BLD}${BCYN}Saltyfunnels Shell${RST}  ${BBLK}installer${RST}"
    echo ""
    hr
    echo -e "    ${bar}  ${BBLK}$(printf '%3d%%' "$pct")  step ${STEP}/${TOTAL_STEPS}${RST}"
    echo -e "    ${BLD}${BWHT}$1${RST}"
    hr
    echo ""
}

print_ok() {  # print_ok <msg> [seconds]
    local t=""
    [[ -n "${2:-}" && "${2:-0}" -ge 2 ]] && t="  ${BBLK}$(fmt_time "$2")${RST}"
    status "    ${BGRN}${G_OK}${RST}  $1${t}"
}
print_warn() { WARNINGS+=("$1"); status "    ${BYLW}${G_WARN}${RST}  $1"; }
print_info() { status "    ${BBLK}${G_DOT}  $1${RST}"; }
print_err()  { printf '\r\e[K' >&2; echo -e "\n    ${BRED}${G_ERR}  ${BLD}$1${RST}\n" >&2; exit 1; }

# Run a command as your normal user (not root), with your HOME set.
as_user() { sudo -u "$USER_NAME" -H "$@"; }

# Run a command with a live spinner. On success the line is simply replaced by
# the next task; on failure the end of the log is shown and the script stops.
run_command() {
    local cmd="$1" desc="$2" start=$SECONDS
    local slug; slug=$(echo "$desc" | tr -c 'a-zA-Z0-9\n' '_' | cut -c1-60)
    local log="$LOG_DIR/${slug}.log"

    IN_RUN=1
    eval "$cmd" > "$log" 2>&1 &
    local pid=$!
    spinner "$pid" "$desc"
    if ! wait "$pid"; then
        echo -e "    ${BRED}${G_ERR}${RST}  ${desc}" >&2
        echo -e "\n    ${BRED}Last lines of the log:${RST}" >&2
        tail -n 15 "$log" | sed 's/^/      /' >&2
        print_err "Failed: $desc  ->  $log"
    fi
    IN_RUN=0
    print_ok "$desc" "$(( SECONDS - start ))"
}

# Copy a folder or a file from the repo into ~/.config if it exists.
deploy() {  # deploy <repo path> <destination> <label>
    local src="$1" dest="$2" label="$3"
    if [[ -d "$src" ]]; then
        as_user mkdir -p "$dest"
        run_command "as_user cp -rf '$src/.' '$dest/'" "$label"
    elif [[ -f "$src" ]]; then
        as_user mkdir -p "$(dirname "$dest")"
        run_command "as_user cp -f '$src' '$dest'" "$label"
    else
        print_info "skipped $label (not in the repo)"
    fi
}

# Install LocalSend from the latest GitHub release tarball (no AUR, no Flatpak),
# and write a .desktop entry whose Icon= points at the real logo file.
# Runs as root, so everything it creates is handed back to your user at the end.
install_localsend() {
    local dir="$USER_HOME/.local/share/localsend" tmp url bin icon
    url=$(curl -fsS https://api.github.com/repos/localsend/localsend/releases/latest \
        | jq -r '.assets[].browser_download_url | select(test("linux-x86-64\\.tar\\.gz$"))' \
        | head -n1)
    [[ -n "$url" ]] || { echo "Could not find a LocalSend linux x86-64 tarball in the latest release"; return 1; }

    tmp=$(mktemp -d)
    curl -fsSL "$url" -o "$tmp/localsend.tar.gz"
    rm -rf "$dir"; mkdir -p "$dir"
    tar -xzf "$tmp/localsend.tar.gz" -C "$dir"
    rm -rf "$tmp"

    # Don't assume the layout: find the binary and a logo wherever they landed
    bin=$(find "$dir" -maxdepth 3 -type f -name localsend_app | head -n1)
    [[ -n "$bin" ]] || { echo "localsend_app not found after extracting"; return 1; }
    chmod +x "$bin"

    icon=$(find "$dir" -type f -iname 'logo-512.png' | head -n1)
    [[ -n "$icon" ]] || icon=$(find "$dir" -type f -iname '*logo*.png' | head -n1)
    [[ -n "$icon" ]] || icon="applications-internet"

    mkdir -p "$USER_HOME/.local/share/applications"
    cat > "$USER_HOME/.local/share/applications/localsend.desktop" << EOF
[Desktop Entry]
Name=LocalSend
Comment=Share files to nearby devices
Exec=$bin
Icon=$icon
Terminal=false
Type=Application
Categories=Network;FileTransfer;
EOF

    # Safety net: never leave root-owned files inside the user's ~/.local
    chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.local"
}

cleanup() { printf '\e[?25h' 2>/dev/null || true; echo ""; }
trap cleanup EXIT
trap '(( IN_RUN )) || echo -e "\n    ${BRED}${G_ERR}  Error on line $LINENO${RST}" >&2' ERR

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

[[ "$EUID" -eq 0 ]] || { echo "Run as root  →  sudo bash $0" >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "This installer is for Arch Linux only." >&2; exit 1; }

USER_NAME="${SUDO_USER:-}"
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
    echo "Run with sudo from your normal user account (not a root login)." >&2
    exit 1
fi
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[[ -d "$USER_HOME" ]] || { echo "Home directory for $USER_NAME not found." >&2; exit 1; }

CONFIG_DIR="$USER_HOME/.config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_SRC="$REPO_ROOT/configs"
SCRIPTS_SRC="$REPO_ROOT/scripts"
WALLPAPERS_REPO="https://github.com/Saltyfunnel/Wallpapers.git"
CARGO_PATH="/usr/local/bin:/usr/bin:/bin:$USER_HOME/.cargo/bin"

# Make sure the user's own directories exist and belong to the user BEFORE any
# step runs as root. Otherwise root can create ~/.local (etc.) first, and later
# `as_user mkdir` calls fail with "permission denied". The chown also repairs
# anything left root-owned by an earlier failed run.
[[ -e "$USER_HOME/.local" ]] && chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.local"
[[ -e "$USER_HOME/.cache" ]] && chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.cache"
[[ -e "$CONFIG_DIR" ]]       && chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR"
as_user mkdir -p "$CONFIG_DIR" "$USER_HOME/.cache" \
    "$USER_HOME/.local/share/applications" "$USER_HOME/.local/share/icons"

clear
echo ""
echo -e "    ${BLD}${BCYN}Saltyfunnels Shell${RST}"
echo -e "    ${BBLK}served salty ${G_DOT} hyprland ${G_DOT} quickshell ${G_DOT} matugen${RST}"
echo ""
hr
echo -e "    ${BBLK}user${RST}  ${WHT}${USER_NAME}${RST}"
echo -e "    ${BBLK}repo${RST}  ${WHT}${REPO_ROOT}${RST}"
echo -e "    ${BBLK}logs${RST}  ${WHT}${LOG_DIR}${RST}"
hr
echo ""

curl -fsS --max-time 10 -o /dev/null https://archlinux.org || print_err "No network connection"
print_ok "Network reachable"

################################################################################
# 1. PACMAN CONFIG
################################################################################

print_phase "Configuring pacman"

sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
if grep -q "^#ILoveCandy" /etc/pacman.conf; then
    sed -i 's/^#ILoveCandy/ILoveCandy/' /etc/pacman.conf
elif ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi
# multilib is needed for Steam
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
grep -q '^\[multilib\]' /etc/pacman.conf || print_err "Could not enable [multilib] in /etc/pacman.conf"
print_ok "pacman.conf updated (multilib, Color, ParallelDownloads)"

################################################################################
# 2. SYSTEM UPDATE & GPU DRIVERS
################################################################################

print_phase "System update & graphics drivers"

run_command "pacman -Syu --noconfirm" "Updating the system"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    print_info "NVIDIA GPU detected"
    run_command "pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" \
        "Installing NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    print_info "AMD GPU detected"
    run_command "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon" \
        "Installing AMD drivers"
elif echo "$GPU_INFO" | grep -qi intel; then
    print_info "Intel GPU detected"
    run_command "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel" \
        "Installing Intel drivers"
else
    print_warn "No known GPU found, skipping drivers"
fi

################################################################################
# 3. PACKAGES
################################################################################

print_phase "Installing packages"

CORE=(hyprland hyprpaper xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
      polkit-kde-agent qt6-5compat qt6-declarative qt6-svg qt5-wayland qt6-wayland python-pyqt6
      mako)
LOGIN=(sddm hyprlock)
AUDIO=(pipewire pipewire-pulse pipewire-alsa wireplumber playerctl pavucontrol)
TERMINAL=(kitty fish starship fastfetch btop)
UTILITY=(grim slurp wl-clipboard brightnessctl pacman-contrib wf-recorder upower libnotify
         bluez bluez-utils blueman networkmanager udisks2 udiskie gvfs
         gtk3 libayatana-appindicator)
FILES=(thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer file-roller trash-cli)
MEDIA=(mpv imv imagemagick ffmpeg yt-dlp cava)
SETTINGS=(dconf gsettings-desktop-schemas)
APPS=(firefox spotify-launcher qbittorrent gnome-disk-utility zed)
GAMING=(steam gamemode lib32-gamemode mangohud lib32-mangohud)
DEV=(git base-devel curl wget nano jq rust)
FONTS=(ttf-hack-nerd noto-fonts noto-fonts-emoji)
DISK=(ntfs-3g dosfstools unzip p7zip unrar)

ALL_PACKAGES=("${CORE[@]}" "${LOGIN[@]}" "${AUDIO[@]}" "${TERMINAL[@]}" "${UTILITY[@]}" "${FILES[@]}"
              "${MEDIA[@]}" "${SETTINGS[@]}" "${APPS[@]}" "${GAMING[@]}" "${DEV[@]}" "${FONTS[@]}" "${DISK[@]}")

run_command "pacman -S --noconfirm --needed ${ALL_PACKAGES[*]}" \
    "Installing ${#ALL_PACKAGES[@]} packages"

run_command "fc-cache -f" "Refreshing font cache"

################################################################################
# 4. QUICKSHELL, MATUGEN & LOCALSEND
################################################################################

print_phase "Quickshell, matugen & LocalSend"

if pacman -Si quickshell >/dev/null 2>&1; then
    run_command "pacman -S --noconfirm --needed quickshell" "Installing Quickshell"
else
    print_warn "quickshell is not in the official repos. After this script finishes run:  yay -S quickshell"
fi

if pacman -Si matugen >/dev/null 2>&1; then
    run_command "pacman -S --noconfirm --needed matugen" "Installing matugen"
else
    print_info "matugen not in the repos, building with cargo (takes a few minutes)"
    run_command "as_user env PATH='$CARGO_PATH' cargo install matugen --locked" "Building matugen"
fi

# LocalSend from the GitHub release tarball. run_command exits on failure, so it
# runs in a subshell here: a failure only warns and doesn't abort the install.
if ! ( run_command "install_localsend" "Installing LocalSend" ) 2>/dev/null; then
    IN_RUN=0
    print_warn "LocalSend install failed, see $LOG_DIR/Installing_LocalSend.log"
fi

################################################################################
# 5. FOLDERS
################################################################################

print_phase "Creating folders"

for d in hypr kitty fish fish/conf.d mako scripts quickshell matugen/templates gtk-3.0 gtk-4.0 Thunar fastfetch zed/themes; do
    as_user mkdir -p "$CONFIG_DIR/$d"
done
as_user mkdir -p "$USER_HOME/Pictures/Wallpapers" "$USER_HOME/.local/share/icons" "$USER_HOME/.cache"
print_ok "Folders created"

################################################################################
# 6. CONFIG FILES (copied from this repo)
################################################################################

print_phase "Deploying config files"

deploy "$CONFIGS_SRC/hypr"        "$CONFIG_DIR/hypr"        "Hyprland config (incl. hyprlock)"
deploy "$CONFIGS_SRC/quickshell"  "$CONFIG_DIR/quickshell"  "Quickshell bar"
deploy "$CONFIGS_SRC/matugen"     "$CONFIG_DIR/matugen"     "matugen config & templates"
deploy "$CONFIGS_SRC/kitty"       "$CONFIG_DIR/kitty"       "Kitty config"
deploy "$CONFIGS_SRC/fish"        "$CONFIG_DIR/fish"        "Fish config"
deploy "$CONFIGS_SRC/mako"        "$CONFIG_DIR/mako"        "Mako config"
deploy "$CONFIGS_SRC/fastfetch"   "$CONFIG_DIR/fastfetch"   "Fastfetch config"
deploy "$CONFIGS_SRC/starship"    "$CONFIG_DIR"             "Starship config"
deploy "$CONFIGS_SRC/gtk-3.0"     "$CONFIG_DIR/gtk-3.0"     "GTK 3 config"
deploy "$CONFIGS_SRC/gtk-4.0"     "$CONFIG_DIR/gtk-4.0"     "GTK 4 config"
deploy "$CONFIGS_SRC/Thunar"      "$CONFIG_DIR/Thunar"      "Thunar config"
deploy "$SCRIPTS_SRC"             "$CONFIG_DIR/scripts"     "User scripts"
as_user find "$CONFIG_DIR/scripts" -type f -exec chmod +x {} + 2>/dev/null || true
as_user touch "$CONFIG_DIR/kitty/colors.conf"

# cava: terminal config + matugen theme (the Quickshell equalizer uses its own config)
as_user mkdir -p "$CONFIG_DIR/cava/themes"
if [[ ! -f "$CONFIG_DIR/cava/config" ]]; then
    as_user tee "$CONFIG_DIR/cava/config" > /dev/null << 'EOF'
[general]
framerate = 60

[color]
theme = 'matugen'
EOF
fi
# placeholder theme so cava starts before matugen has generated the real one
if [[ ! -f "$CONFIG_DIR/cava/themes/matugen" ]]; then
    as_user tee "$CONFIG_DIR/cava/themes/matugen" > /dev/null << 'EOF'
[color]
gradient = 1
gradient_color_1 = '#94e2d5'
gradient_color_2 = '#89b4fa'
gradient_color_3 = '#cba6f7'
EOF
fi
print_ok "cava configured (theme follows matugen)"

# GPU environment file (hyprland.lua loads this at startup, so it must exist)
GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.lua"
if echo "$GPU_INFO" | grep -qi nvidia; then
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  LIBVA_DRIVER_NAME         = "nvidia",
  XDG_SESSION_TYPE          = "wayland",
  __GLX_VENDOR_LIBRARY_NAME = "nvidia",
  GBM_BACKEND               = "nvidia-drm",
  WLR_NO_HARDWARE_CURSORS   = "1",
  __GL_GSYNC_ALLOWED        = "1",
  __GL_VRR_ALLOWED          = "1",
  QT_QPA_PLATFORM           = "wayland",
}
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  LIBVA_DRIVER_NAME = "radeonsi",
  XDG_SESSION_TYPE  = "wayland",
  QT_QPA_PLATFORM   = "wayland",
}
EOF
elif echo "$GPU_INFO" | grep -qi intel; then
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  LIBVA_DRIVER_NAME = "iHD",
  XDG_SESSION_TYPE  = "wayland",
  QT_QPA_PLATFORM   = "wayland",
}
EOF
else
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  XDG_SESSION_TYPE = "wayland",
  QT_QPA_PLATFORM  = "wayland",
}
EOF
fi
print_ok "GPU environment written  →  hypr/gpu-env.lua"

# Default fonts: Hack Nerd Font for monospace and sans-serif
as_user mkdir -p "$CONFIG_DIR/fontconfig"
cat > "$CONFIG_DIR/fontconfig/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>monospace</family>
    <prefer><family>Hack Nerd Font Mono</family></prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Hack Nerd Font</family></prefer>
  </alias>
</fontconfig>
EOF
chown "$USER_NAME:$USER_NAME" "$CONFIG_DIR/fontconfig/fonts.conf"
print_ok "Default fonts set  →  Hack Nerd Font"

################################################################################
# 7. WALLPAPERS & DEFAULT SHELL
################################################################################

print_phase "Wallpapers & fish shell"

WALLPAPER_TMP="/tmp/wallpapers-src"
rm -rf "$WALLPAPER_TMP"
run_command "as_user git clone --depth 1 '$WALLPAPERS_REPO' '$WALLPAPER_TMP'" "Cloning wallpapers"
run_command "as_user cp -rf '$WALLPAPER_TMP/.' '$USER_HOME/Pictures/Wallpapers/' && rm -rf '$USER_HOME/Pictures/Wallpapers/.git'" \
    "Copying wallpapers to ~/Pictures/Wallpapers"
rm -rf "$WALLPAPER_TMP"

if chsh -s /usr/bin/fish "$USER_NAME"; then
    print_ok "fish set as your default shell"
else
    print_warn "Could not change shell. Run later:  chsh -s /usr/bin/fish"
fi

################################################################################
# 8. ICONS
################################################################################

print_phase "Colloid icon theme"

COLLOID_SRC="$CONFIG_DIR/colloid-src"
if [[ ! -d "$COLLOID_SRC" ]]; then
    run_command "as_user git clone --depth 1 https://github.com/Saltyfunnel/colloid.git '$COLLOID_SRC'" \
        "Cloning Colloid icon theme"
fi
run_command "cd '$COLLOID_SRC' && as_user ./install.sh -d '$USER_HOME/.local/share/icons' -n Colloid-Dynamic -s default" \
    "Installing Colloid-Dynamic icons"
rm -f "$USER_HOME/.cache/folder_accent"

as_user dbus-run-session -- gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Dynamic-Dark' \
    > "$LOG_DIR/gsettings.log" 2>&1 \
    && print_ok "Icon theme set for GTK apps" \
    || print_warn "Could not set icon theme now (hyprland.lua sets it at login)"

as_user dbus-run-session -- gsettings set org.gnome.desktop.interface font-name 'Hack Nerd Font 11' >/dev/null 2>&1 || true
as_user dbus-run-session -- gsettings set org.gnome.desktop.interface monospace-font-name 'Hack Nerd Font Mono 11' >/dev/null 2>&1 || true

################################################################################
# 9. SERVICES & SDDM LOGIN SCREEN
################################################################################

print_phase "Services & SDDM"

for svc in bluetooth NetworkManager; do
    if systemctl enable "${svc}.service" > "$LOG_DIR/enable-${svc}.log" 2>&1; then
        print_ok "${svc} enabled"
    else
        print_warn "Could not enable ${svc}  →  $LOG_DIR/enable-${svc}.log"
    fi
done

# Clean up the old tty1 auto-login setup from earlier versions of this installer,
# otherwise it would fight SDDM for the session.
GETTY_OVERRIDE_DIR="/etc/systemd/system/getty@tty1.service.d"
if [[ -f "$GETTY_OVERRIDE_DIR/override.conf" ]]; then
    rm -f "$GETTY_OVERRIDE_DIR/override.conf"
    rmdir "$GETTY_OVERRIDE_DIR" 2>/dev/null || true
    print_ok "Removed old tty1 auto-login override"
fi
if [[ -f "$CONFIG_DIR/fish/conf.d/10-hyprland-autostart.fish" ]]; then
    rm -f "$CONFIG_DIR/fish/conf.d/10-hyprland-autostart.fish"
    print_ok "Removed old fish Hyprland autostart"
fi

# matugen writes the login-screen colours here (sddm-colors.json template), so
# your user must be able to write to it and SDDM must be able to read it.
mkdir -p /var/cache/wal
chown "$USER_NAME:$USER_NAME" /var/cache/wal
chmod 755 /var/cache/wal
print_ok "/var/cache/wal ready for matugen's SDDM colours"

# Install the SDDM theme (script + Main.qml live in the repo)
SDDM_SCRIPT=""
for candidate in "$SCRIPTS_SRC/install-sddm-theme.sh" "$SCRIPTS_SRC/sddmtheme.sh" \
                 "$REPO_ROOT/install-sddm-theme.sh"; do
    [[ -f "$candidate" ]] && { SDDM_SCRIPT="$candidate"; break; }
done
if [[ ! -f "$REPO_ROOT/configs/sddm/Main.qml" ]]; then
    print_warn "configs/sddm/Main.qml is missing from the repo, skipping the SDDM theme (default theme will be used)"
elif [[ -n "$SDDM_SCRIPT" ]]; then
    run_command "env REPO_ROOT='$REPO_ROOT' bash '$SDDM_SCRIPT'" "Installing the SDDM theme"
else
    print_warn "SDDM theme script not found in scripts/. SDDM will use its default theme."
fi

if systemctl enable sddm.service > "$LOG_DIR/enable-sddm.log" 2>&1; then
    print_ok "SDDM enabled"
else
    print_warn "Could not enable SDDM  →  $LOG_DIR/enable-sddm.log"
fi

################################################################################
# 10. WRAP UP
################################################################################

print_phase "Finalizing installation"

# Hand ownership of your files back to you
for p in "$CONFIG_DIR" "$USER_HOME/.cache" "$USER_HOME/Pictures" "$USER_HOME/.local"; do
    [[ -e "$p" ]] && chown -R "$USER_NAME:$USER_NAME" "$p"
done
print_ok "Ownership set"

################################################################################
# DONE
################################################################################

if (( IS_TTY )); then clear; fi
echo ""
hr
echo ""
echo -e "    ${BLD}${BGRN}${G_OK}  Install complete${RST}  ${BBLK}in $(fmt_time $(( SECONDS - START_TIME )))${RST}"
echo ""
echo -e "    ${BWHT}Next${RST}"
echo -e "    ${BBLK}${G_DOT}${RST}  Reboot, then pick the ${BCYN}Hyprland${RST} session at the login screen"
echo -e "    ${BBLK}${G_DOT}${RST}  Colours and wallpaper are generated at first login"
echo -e "    ${BBLK}${G_DOT}${RST}  Lock screen is hyprlock (bind it in your Hyprland config)"
echo -e "    ${BBLK}${G_DOT}${RST}  If something goes wrong: ${BCYN}Ctrl+Alt+F2${RST}, then log in"

if (( ${#WARNINGS[@]} > 0 )); then
    echo ""
    echo -e "    ${BYLW}${G_WARN}  ${#WARNINGS[@]} thing(s) to look at${RST}"
    for w in "${WARNINGS[@]}"; do
        echo -e "      ${BBLK}${G_DOT}${RST} $w"
    done
fi

echo ""
echo -e "    ${BBLK}logs: ${LOG_DIR}${RST}"
echo ""
hr
echo ""

read -r -p "    $(echo -e "${BCYN}Reboot now? [Y/n]:${RST} ")" REBOOT_CHOICE
REBOOT_CHOICE=${REBOOT_CHOICE:-Y}
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    reboot
fi
