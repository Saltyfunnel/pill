pragma Singleton
import QtQuick
import Quickshell

// Installed applications search, shared by the island and the launcher.
Singleton {
    // Returns up to `limit` sorted DesktopEntries: starts with > contains > generic/keywords.
    function search(query, limit) {
        const q = (query || "").trim().toLowerCase()
        if (q === "") return []
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
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

    function iconFor(entry) {
        const p = Quickshell.iconPath(entry ? entry.icon : "", true)
        return p !== "" ? p : Qt.resolvedUrl("../assets/icons/gray/apps.svg")
    }
}
