#!/bin/sh
# Opens the default browser or file manager.
#   open-default.sh browser | files
# Exits with 0 if launched; otherwise, with 1 and a short message to stderr (displayed by the island).
set -u
launch_desktop() {   # $1 = .desktop file, rest = arguments
    id=${1%.desktop}; shift
    [ -n "$id" ] && command -v gtk-launch >/dev/null 2>&1 && gtk-launch "$id" "$@" >/dev/null 2>&1
}
case "${1:-}" in
    browser)
        b=$(xdg-settings get default-web-browser 2>/dev/null || true)
        launch_desktop "$b" && exit 0
        command -v xdg-open >/dev/null 2>&1 && xdg-open "https://duckduckgo.com" >/dev/null 2>&1 && exit 0
        echo "Could not open the browser." >&2; exit 1 ;;
    files)
        f=$(xdg-mime query default inode/directory 2>/dev/null || true)
        launch_desktop "$f" "$HOME" && exit 0
        command -v xdg-open >/dev/null 2>&1 && xdg-open "$HOME" >/dev/null 2>&1 && exit 0
        echo "Could not open the file manager." >&2; exit 1 ;;
    *) echo "usage: open-default.sh browser|files" >&2; exit 2 ;;
esac
