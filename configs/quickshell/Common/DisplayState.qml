pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent island settings in ~/.config/island-shell/state.json
Singleton {
    id: root
    property bool loaded: false
    property bool islandAutoHide: false     // hide the island automatically
    property bool islandSmartHide: false    // hide only when the desktop has windows
    property bool reduceMotion: false
    property bool highContrast: false
    property int emojiTone: 0               // 0 = yellow, 1..5 = light..dark
    property string language: "en"
    // Island menu: pinned items (in order) and custom shortcuts { id, label, cmd }.
    property var pins: ["volume", "terminal", "record", "capture", "desktops", "notes", "browser", "files", "screenoff"]
    property var customItems: []
    property var pinOrder: []

    onReduceMotionChanged: Theme.reduceMotion = reduceMotion
    onHighContrastChanged: Theme.highContrast = highContrast

    function setIslandAutoHide(v) { islandAutoHide = v; if (v) islandSmartHide = false; save() }
    function setIslandSmartHide(v) { islandSmartHide = v; if (v) islandAutoHide = false; save() }
    function setReduceMotion(v) { reduceMotion = v; save() }
    function setHighContrast(v) { highContrast = v; save() }
    function setEmojiTone(v) { emojiTone = v; save() }
    function setLanguage(v) { language = v === "en" ? "en" : "es"; save() }
    function setPins(list) { pins = list; save() }
    function setPinOrder(list) { pinOrder = list; save() }
    function setCustomItems(list) { customItems = list; save() }

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/island-shell"

    function save() {
        file.setText(JSON.stringify({ islandAutoHide: root.islandAutoHide, islandSmartHide: root.islandSmartHide,
                                      reduceMotion: root.reduceMotion, highContrast: root.highContrast,
                                      emojiTone: root.emojiTone, language: root.language,
                                      pins: root.pins, pinOrder: root.pinOrder, customItems: root.customItems }, null, 2))
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
        onExited: file.path = root.stateDir + "/state.json"
    }

    FileView {
        id: file
        blockLoading: false
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                root.islandAutoHide = s.islandAutoHide ?? false
                root.islandSmartHide = (s.islandSmartHide ?? false) && !root.islandAutoHide
                root.reduceMotion = s.reduceMotion ?? false
                root.highContrast = s.highContrast ?? false
                root.emojiTone = Math.max(0, Math.min(5, Math.round(Number(s.emojiTone) || 0)))
                if (s.language === "es" || s.language === "en") root.language = s.language
                if (Array.isArray(s.pins)) root.pins = s.pins.filter(p => typeof p === "string" && p !== "brightness" && p !== "vibrance")
                if (Array.isArray(s.pinOrder)) root.pinOrder = s.pinOrder.filter(p => typeof p === "string")
                if (Array.isArray(s.customItems)) root.customItems = s.customItems.filter(c => c && c.id && c.label && c.cmd)
            } catch (e) {}
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
}
