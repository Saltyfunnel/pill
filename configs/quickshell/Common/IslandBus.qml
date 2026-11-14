pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// External control of the island:
//   qs ipc call island open | close | reveal | dismiss | status | apps | clipboard | wallpaper
//   qs ipc call WallpaperPicker toggle | open | close
Singleton {
    id: root
    signal islandCommand(string cmd)

    IpcHandler {
        target: "island"
        function reveal(): void { root.islandCommand("show") }
        function dismiss(): void { root.islandCommand("hide") }
        function open(): void { root.islandCommand("open") }
        function close(): void { root.islandCommand("close") }
        function toggle(): void { root.islandCommand("toggle") }
        function status(): void { root.islandCommand("status") }
        function apps(): void { root.islandCommand("apps") }
        function clipboard(): void { root.islandCommand("clipboard") }
        function wallpaper(): void { root.islandCommand("wallpaper") }
    }

    // Super+D (qs ipc call launcher toggle)
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.islandCommand("launcher") }
        function open(): void { root.islandCommand("launcher-open") }
        function close(): void { root.islandCommand("close") }
    }

    // Same target as the old standalone picker, so the Super+W bind
    // (qs ipc call WallpaperPicker toggle) keeps working.
    IpcHandler {
        target: "WallpaperPicker"
        function toggle(): void { root.islandCommand("wallpaper") }
        function open(): void { root.islandCommand("wallpaper-open") }
        function close(): void { root.islandCommand("close") }
    }
}
