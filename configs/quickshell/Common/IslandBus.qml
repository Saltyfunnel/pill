pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// External control of the island:
//   qs ipc call island open | close | reveal | dismiss | status | apps | clipboard
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
    }
}
