import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Effects
import "../Common"

// Island window: layer-shell at top, overlay, non-exclusive space reservation.
// A single hover zone (hoverZone) in the input mask: when the island is
// hidden it is a 3px strip; when shown it grows to cover the island.
PanelWindow {
    id: win

    property bool expanded: false
    property bool panel: false             // sliding panel open
    // Which panel: left→right = "status" (resources), right→left = "apps" (background apps).
    // Downwards opens the normal menu (same as a click).
    property string panelKind: "status"
    readonly property bool open: expanded || panel
    // While dragging, the pointer may leave the zone: still counts as hovered
    // (otherwise, auto-hide would hide the island mid-gesture and clip it).
    readonly property bool hovered: hoverZone.containsMouse || hoverZone.pressed
    property bool shown: true
    // Smart hide: there are windows on the active workspace of THIS island's monitor.
    // Evaluated only with option active; special workspaces (id < 0) do not count.
    readonly property var monitorWs: DisplayState.islandSmartHide ? (Hyprland.monitorFor(win.screen)?.activeWorkspace ?? null) : null
    readonly property int wsWindows: monitorWs && monitorWs.id > 0 ? monitorWs.toplevels.values.length : 0
    readonly property bool occupied: wsWindows > 0
    readonly property bool hideWanted: DisplayState.islandAutoHide || (DisplayState.islandSmartHide && occupied && !Recorder.recording)

    anchors { top: true; left: true; right: true; bottom: win.open }
    implicitHeight: Theme.maxExpandedH + Theme.topMargin + 8
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { x: win.open ? 0 : hoverZone.x; y: 0; width: win.open ? win.width : hoverZone.width; height: win.open ? win.height : hoverZone.height }

    function collapse() { expanded = false; panel = false }

    // Auto-hide
    Timer {
        id: hideTimer
        interval: Theme.hideDelay
        onTriggered: if (win.hideWanted && !win.hovered && !win.open && !menu.searchFocused && Recorder.notice === "" && Laptop.notice === "" && Notifs.current === null) win.shown = false
    }
    onHoveredChanged: {
        Notifs.hovers = Math.max(0, Notifs.hovers + (hovered ? 1 : -1))
        if (hovered) { hideTimer.stop(); shown = true }
        else if (!open) hideTimer.restart()
    }
    onPanelChanged: {
        pill.forceActiveFocus()
        if (panel) { hideTimer.stop(); shown = true }
        else if (!hovered) hideTimer.restart()
    }
    onExpandedChanged: {
        // On open and close, focus goes to the pill (not the search bar), so the "|" cursor
        // doesn't keep blinking. The search bar only activates on click.
        menu.opened(); pill.forceActiveFocus(); unfocusLater.restart()
        if (expanded) { hideTimer.stop(); shown = true }
        else if (!hovered) hideTimer.restart()
    }
    Timer { id: unfocusLater; interval: 150; onTriggered: { menu.opened(); pill.forceActiveFocus() } }
    Component.onCompleted: hideTimer.restart()
    // If auto-hide is disabled, the island remains always visible.
    Connections {
        target: DisplayState
        function onIslandAutoHideChanged() { win.syncHide() }
        function onIslandSmartHideChanged() { win.syncHide() }
    }
    // Reactive to opening/closing/moving windows and switching workspaces (Hyprland events).
    onHideWantedChanged: syncHide()
    // After closing/moving windows, the toplevels list refreshes (single event, no polling).
    Connections {
        target: Hyprland
        enabled: DisplayState.islandSmartHide
        function onRawEvent(ev) {
            const n = ev.name
            if (n === "closewindow" || n === "movewindowv2" || n === "openwindow") toplevelsLater.restart()
        }
    }
    // Single update per event burst, outside the Hyprland event handler.
    Timer { id: toplevelsLater; interval: 120; onTriggered: Hyprland.refreshToplevels() }
    function syncHide() {
        if (!hideWanted) { hideTimer.stop(); shown = true }
        else if (!hovered && !open) hideTimer.restart()
    }

    // Recorder messages: keep island shown while notice lasts.
    Connections {
        target: Recorder
        function onNoticeChanged() {
            if (Recorder.notice !== "") { win.shown = true; hideTimer.stop() }
            else if (!win.hovered && !win.open) hideTimer.restart()
        }
    }

    // Battery, volume, and brightness notices: hidden island appears while they last.
    Connections {
        target: Laptop
        function onNoticeChanged() {
            if (Laptop.notice !== "") { win.shown = true; hideTimer.stop() }
            else if (!win.hovered && !win.open) hideTimer.restart()
        }
    }
    // Notifications: island appears while one is on screen; mouse over pauses timer.
    Connections {
        target: Notifs
        function onCurrentChanged() {
            if (Notifs.current !== null) { win.shown = true; hideTimer.stop() }
            else if (!win.hovered && !win.open) hideTimer.restart()
        }
    }
    // Each island adds/subtracts its hover (doesn't conflict across multiple monitors).
    Component.onDestruction: if (hovered) Notifs.hovers = Math.max(0, Notifs.hovers - 1)

    // Click outside the expanded island: collapses on release (not press),
    // so a drag starting outside and entering doesn't trigger an accidental half-close.
    MouseArea {
        anchors.fill: parent
        enabled: win.open
        acceptedButtons: Qt.LeftButton
        onClicked: win.collapse()
    }

    // Single hover/input region. Never replaced by another item.
    // Also the ONLY click receiver for the compact island (covers the entire pill and
    // top margin, with its final size even while the pill animates).
    MouseArea {
        id: hoverZone
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: win.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor
        // Extra margin around the pill: a click/drag starting right at the edge
        // doesn't "escape" to the window below (which would select its text).
        readonly property int pad: 8
        x: win.shown ? pill.x - pad : 0
        y: 0
        width: win.shown ? pill.width + pad * 2 : win.width
        height: win.shown ? Theme.topMargin + pill.height + pad : 3

        preventStealing: true
        // Click → menu (on release). Horizontal drag (>8px) → system status panel;
        // with panel open, swiping again closes it. Pill follows finger (elastic).
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false
        property bool pulling: false       // downward drag (menu)
        property real dragDy: 0
        property real dragDx: 0
        // Velocity (px/ms, smoothed) to decide with a quick, short gesture.
        property real vel: 0
        property real velY: 0
        property real lastY: 0
        property real lastX: 0
        property real lastT: 0
        // Window coordinates: zone moves with the pill while dragging.
        onPressed: m => { const p = mapToItem(null, m.x, m.y); pressX = p.x; pressY = p.y; dragging = false; pulling = false; dragDx = 0; dragDy = 0; vel = 0; velY = 0; lastX = pressX; lastY = pressY; lastT = Date.now() }
        onPositionChanged: m => {
            if (!pressed || win.expanded) return
            const p = mapToItem(null, m.x, m.y), now = Date.now()
            if (now > lastT) {
                vel = vel * 0.6 + 0.4 * (p.x - lastX) / (now - lastT)
                velY = velY * 0.6 + 0.4 * (p.y - lastY) / (now - lastT)
                lastX = p.x; lastY = p.y; lastT = now
            }
            const dx = p.x - pressX, dy = p.y - pressY
            // Direction decided once, by dominant axis, past 6px:
            // horizontal → panels; downwards → menu (upwards does nothing).
            if (!dragging && !pulling && Math.hypot(dx, dy) > 6) {
                if (Math.abs(dx) > Math.abs(dy)) dragging = true
                else if (dy > 0 && !win.panel) pulling = true
            }
            if (dragging) dragDx = dx
            if (pulling) dragDy = Math.max(0, dy)
        }
        onReleased: m => {
            // With a notification: click = open app, right click = dismiss.
            if (!dragging && !pulling && !win.open && Notifs.current !== null) {
                if (m.button === Qt.RightButton) Notifs.dismiss(); else Notifs.activate()
                dragging = false; dragDx = 0; return
            }
            if (m.button === Qt.RightButton) return
            if (pulling) {
                if (Date.now() - lastT > 80) velY = 0
                // Downwards: normal menu (same result as a click).
                if (dragDy > 24 || (velY > 0.5 && dragDy > 10)) win.expanded = true
                pulling = false; dragDy = 0; return
            }
            if (dragging) {
                if (Date.now() - lastT > 80) vel = 0          // stopped before release: not a fling
                const fling = Math.abs(vel) > 0.6 && Math.abs(dragDx) > 16
                if (Math.abs(dragDx) > 40 || fling) {
                    if (win.panel) win.panel = false          // open: sliding either way closes
                    else { win.panelKind = (fling ? vel : dragDx) > 0 ? "status" : "apps"; win.panel = true }
                }
            } else if (!win.open) win.expanded = true
            dragging = false; dragDx = 0
        }
        onCanceled: { dragging = false; dragDx = 0; pulling = false; dragDy = 0 }
        // Wheel over compact island: previous/next workspace.
        onWheel: w => { if (!win.open) Workspaces.wheel(w.angleDelta.y) }
    }


    // Soft, diffuse shadow behind the card (does not clip, does not receive input).
    Rectangle {
        id: shadowSrc
        x: pill.x; y:
