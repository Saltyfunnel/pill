pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Notification server (org.freedesktop.Notifications).
// Displays them one by one in the compact island, queued (max 8), ~5s each.
// If the source app is focused, the notice is briefer (2.5s): you're already looking at it.
// "Do Not Disturb": qs ipc call notifs dnd (critical alerts are still shown).
Singleton {
    id: root
    property var queue: []
    readonly property var current: queue.length > 0 ? queue[0] : null
    property bool dnd: false
    // Mouse over some island (one per monitor): timer does not run.
    property int hovers: 0
    readonly property bool paused: hovers > 0

    function readMs(n) {
        const len = ((n.summary || "") + (n.body || "")).length
        return Math.min(10000, 5000 + Math.max(0, len - 40) * 40)
    }
    // Alerts that arrived while "Do Not Disturb" was on: when turning it off, reports how many were silenced.
    property int missed: 0
    function setDnd(on) {
        dnd = on
        if (on) { missed = 0; Laptop.say(I18n.tr("Do Not Disturb enabled"), "info", 1800) }
        else Laptop.say(missed > 0 ? I18n.tr("Do Not Disturb disabled · %1 silenced notifications", missed) : I18n.tr("Do Not Disturb disabled"), "info", 2500)
    }
    function keyOf(n) { return ((n.desktopEntry || n.appName || "") + "").toLowerCase() }
    // Is the notification's app the currently focused window?
    function fromFocused(n) {
        const t = Hyprland.activeToplevel
        const cls = t && t.lastIpcObject ? ((t.lastIpcObject["class"] || "") + "").toLowerCase() : ""
        const k = keyOf(n)
        return k !== "" && cls !== "" && (cls.includes(k) || k.includes(cls))
    }
    function iconOf(n) {
        if (!n) return ""
        if (n.image) return n.image
        const p = Quickshell.iconPath(n.appIcon || n.desktopEntry || "", true)
        if (p !== "") return p
        const e = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : DesktopEntries.heuristicLookup(n.appName || "")
        return e ? Quickshell.iconPath(e.icon, true) : ""
    }

    // Thumbnail (e.g. a screenshot): the notification image if it's a file/custom image
    // (hint image-path or image-data), not an app icon.
    function thumbOf(n) {
        if (!n) return ""
        const h = n.hints || {}
        const p = h["image-path"] || h["image_path"] || ""
        if (typeof p === "string" && (p.startsWith("file://") || p.startsWith("/"))) return p.startsWith("/") ? "file://" + p : p
        return n.image && !n.appIcon && n.image !== "" ? n.image : ""
    }

    // Removes a specific notification from the queue. Never "blindly pop the first one": invoking an
    // action might close the notification (closed -> filter) before we return here, and
    // popping queue[0] afterward would discard the next one without showing it.
    function drop(n) { queue = queue.filter(x => x !== n) }
    // Close it only if still alive: if the app already closed it (e.g. when invoking an action),
    // dismiss() on a destroyed object gives "Cannot close destroyed notification".
    function finish(n) { const live = queue.indexOf(n) >= 0; drop(n); if (live) n.dismiss() }
    // Closes the current one (user dismissed it or time expired).
    function dismiss() { const n = current; if (n) finish(n) }
    // Click on the alert: "default" action if it exists; otherwise, brings the app to front (unminimizes and focuses).
    function activate() {
        const n = current
        if (!n) return
        const def = Array.from(n.actions || []).find(a => a.identifier === "default")
        const open = n.hints ? n.hints["x-island-open"] : ""
        if (n.own) { if (n.action) IslandBus.islandCommand(n.action) }   // custom notice: opens its panel
        else if (typeof open === "string" && open.startsWith("/")) Quickshell.execDetached(["xdg-open", open])   // screenshot: open it
        else if (def) def.invoke()
        else Quickshell.execDetached([Qt.resolvedUrl("../scripts/focus-app.py").toString().replace("file://", ""),
                                      n.desktopEntry || "", n.appName || ""])
        finish(n)
    }
    // Custom notices follow the same path as app notifications:
    // same queue, same screen time, respect "Do Not Disturb". `tag` identifies the notice
    // (one per tag at a time) and `action` is the island command on click.
    function post(o) {
        if (root.dnd) return
        withdraw(o.tag)
        const n = { own: true, tag: o.tag, summary: o.summary || "", body: o.body || "", appName: "Island",
                    appIcon: "", image: "", desktopEntry: "", hints: {}, actions: [], urgency: NotificationUrgency.Normal,
                    action: o.action || "", expire() {}, dismiss() {} }
        let q = root.queue.concat([n])
        while (q.length > 8) { const old = q.splice(1, 1)[0]; old.expire() }
        root.queue = q
    }
    // Withdraws a custom notice that no longer applies.
    function withdraw(tag) { if (tag) root.queue = root.queue.filter(n => !(n.own && n.tag === tag)) }
    function invoke(action) { const n = current; action.invoke(); if (n) finish(n) }

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false
        onNotification: n => {
            const critical = n.urgency === NotificationUrgency.Critical
            if (root.dnd && !critical) { root.missed++; n.expire(); return }
            if (root.queue.indexOf(n) >= 0) return           // replacement of one already in queue: updates itself
            n.tracked = true
            // If the app closes/replaces the notification, it leaves the queue.
            n.closed.connect(() => { root.queue = root.queue.filter(x => x !== n) })
            let q = root.queue.concat([n])
            while (q.length > 8) { const old = q.splice(1, 1)[0]; old.expire() }
            root.queue = q
        }
    }

    Timer {
        id: life
        // Reading time: 5s base + ~1s per 25 characters of text (max. 10s).
        interval: root.current ? (root.current.urgency === NotificationUrgency.Critical ? 9000
                                : root.fromFocused(root.current) ? 2500 : root.readMs(root.current)) : 5000
        running: root.current !== null && !root.paused
        onTriggered: { const n = root.current; if (n) { root.drop(n); n.expire() } }
    }
    onCurrentChanged: if (current) life.restart()

    IpcHandler {
        target: "notifs"
        function dnd(): string { root.setDnd(!root.dnd); return root.dnd ? "do not disturb: yes" : "do not disturb: no" }
        function clear(): void { const q = root.queue; root.queue = []; q.forEach(n => n.dismiss()) }
    }
}
