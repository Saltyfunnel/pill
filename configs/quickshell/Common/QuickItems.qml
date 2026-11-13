pragma Singleton
import QtQuick
import Quickshell
import "pinorder.js" as PinOrder

// Catalog of items that can be pinned in the island menu and pinning rules.
// State (what is pinned, in what order, and custom shortcuts) lives in DisplayState.
Singleton {
    id: root
    readonly property int columns: 4
    readonly property int maxRows: 3
    readonly property int maxButtons: columns * maxRows

    readonly property var builtins: [
        { id: "volume", label: I18n.tr("Volume"), icon: "volume", slider: true },
        { id: "terminal", label: "Terminal", icon: "terminal", slider: false },
        { id: "record", label: I18n.tr("Record screen"), icon: "record", slider: false },
        { id: "capture", label: I18n.tr("Screenshot"), icon: "capture", slider: false },
        { id: "desktops", label: I18n.tr("Desktops"), icon: "desktops", slider: false },
        { id: "clipboard", label: I18n.tr("Clipboard"), icon: "clipboard", slider: false },
        { id: "notes", label: I18n.tr("Notes"), icon: "note", slider: false },
        { id: "emoji", label: I18n.tr("Emojis"), icon: "emoji", slider: false },
        { id: "browser", label: I18n.tr("Browser"), icon: "globe", slider: false },
        { id: "files", label: I18n.tr("Files"), icon: "folder", slider: false },
        // Turns off only the monitor (DPMS): games and apps keep running; returns with mouse or key.
        { id: "screenoff", label: I18n.tr("Turn off display"), icon: "display", slider: false }
    ]

    function isSlider(id) { return id === "volume" }
    function custom(id) { return DisplayState.customItems.find(c => c.id === id) ?? null }
    function exists(id) { return builtins.some(b => b.id === id) || custom(id) !== null }

    // Existing pinned items (ignores deleted custom shortcuts).
    // Order of all elements (catalog + custom); defines the order in the island.
    readonly property var allIds: builtins.map(b => b.id).concat(DisplayState.customItems.map(c => c.id))
    readonly property var order: PinOrder.full(DisplayState.pinOrder, DisplayState.pins, allIds)
    readonly property var orderedPins: PinOrder.sortPins(DisplayState.pins, order)
    readonly property var pinnedSliders: orderedPins.filter(p => isSlider(p))
    readonly property var pinnedButtons: orderedPins.filter(p => !isSlider(p)).slice(0, maxButtons)
    function item(id) { return builtins.find(b => b.id === id) ?? custom(id) }
    function move(id, delta) { DisplayState.setPinOrder(PinOrder.move(order, id, delta)) }
    readonly property bool full: pinnedButtons.length >= maxButtons

    function pinned(id) { return DisplayState.pins.indexOf(id) >= 0 }
    function canPin(id) { return pinned(id) || isSlider(id) || !full }
    function setPinned(id, on) {
        const rest = DisplayState.pins.filter(p => p !== id)
        if (on && !canPin(id)) return
        // Freezes the current order the first time, so reactivating doesn't move it to the end.
        if (DisplayState.pinOrder.length === 0) DisplayState.pinOrder = order.slice()
        DisplayState.setPins(on ? rest.concat([id]) : rest)
    }
    function addCustom(label, cmd) {
        label = label.trim(); cmd = cmd.trim()
        if (!label || !cmd) return false
        const id = "c" + Date.now().toString(36)
        DisplayState.setCustomItems(DisplayState.customItems.concat([{ id: id, label: label, cmd: cmd }]))
        if (!full) setPinned(id, true)
        return true
    }
    function removeCustom(id) {
        DisplayState.setCustomItems(DisplayState.customItems.filter(c => c.id !== id))
        DisplayState.setPins(DisplayState.pins.filter(p => p !== id))
        DisplayState.setPinOrder(DisplayState.pinOrder.filter(p => p !== id))
    }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
}
