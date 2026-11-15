pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Installed applications search, shared by the island and the launcher.
// Also keeps launch counts (for "Most used") and a list of hidden apps,
// saved to ~/.local/state/island/apps.json so they survive restarts.
Singleton {
    id: root

    // Launch count per desktop entry id, and ids hidden from the launcher.
    property var counts: ({})
    property var hidden: []

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/island"
    readonly property string stateFile: stateDir + "/apps.json"

    function isHidden(e) { return !!e && root.hidden.indexOf(e.id) >= 0 }

    // Hidden apps are skipped unless `showHidden` is true.
    function allowed(e, showHidden) { return !e.noDisplay && (showHidden || !root.isHidden(e)) }

    // Returns up to `limit` sorted DesktopEntries: starts with > contains > generic/keywords.
    function search(query, limit, showHidden) {
        const q = (query || "").trim().toLowerCase()
        if (q === "") return []
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (!root.allowed(e, showHidden)) continue
            const name = (e.name || "").toLowerCase()
            let score = -1
            if (name.startsWith(q)) score = 0
            else if (name.includes(q)) score = 1
            else if ((e.genericName || "").toLowerCase().includes(q) || (e.keywords || []).join(" ").toLowerCase().includes(q)) score = 2
            if (score >= 0) out.push({ e: e, s: score, n: name })
        }
        out.sort((a, b) => a.s - b.s || a.n.localeCompare(b.n))
        return out.slice(0, limit || 5).map(o => o.e)
    }

    // First `limit` visible apps, alphabetical (launcher with an empty search).
    function list(limit, showHidden) {
        const out = DesktopEntries.applications.values.filter(e => root.allowed(e, showHidden))
        out.sort((a, b) => (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()))
        return out.slice(0, limit || 8)
    }

    // Most launched apps (never hidden ones), highest count first.
    function top(limit) {
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay || root.isHidden(e)) continue
            const n = root.counts[e.id] || 0
            if (n > 0) out.push({ e: e, n: n })
        }
        out.sort((a, b) => b.n - a.n || (a.e.name || "").localeCompare(b.e.name || ""))
        return out.slice(0, limit || 4).map(o => o.e)
    }

    function recordLaunch(e) {
        if (!e || !e.id) return
        const c = Object.assign({}, root.counts)
        c[e.id] = (c[e.id] || 0) + 1
        root.counts = c
        root.save()
    }

    function toggleHidden(e) {
        if (!e || !e.id) return
        const h = root.hidden.slice()
        const i = h.indexOf(e.id)
        if (i >= 0) h.splice(i, 1)
        else h.push(e.id)
        root.hidden = h
        root.save()
    }

    function save() {
        file.setText(JSON.stringify({ counts: root.counts, hidden: root.hidden }, null, 1))
    }

    function iconFor(entry) {
        const p = Quickshell.iconPath(entry ? entry.icon : "", true)
        return p !== "" ? p : Quickshell.iconPath("application-x-executable", true)
    }

    // Make sure the state folder exists before the first save.
    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: file
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.counts = d.counts || {}
                root.hidden = d.hidden || []
            } catch (e) {
                // Ignore a missing or corrupt state file: start empty.
            }
        }
    }
}
