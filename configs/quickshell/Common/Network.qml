pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Network status via NetworkManager (nmcli). Only queries while someone is using it
// (acquire/release, e.g. island menu open): every 5s, no permanent processes.
// The Wi-Fi section is shown only if there is a Wi-Fi card and NO Ethernet connected.
Singleton {
    id: root
    property int users: 0
    function acquire() { users++; if (users === 1) refresh() }
    function release() { users = Math.max(0, users - 1) }

    property bool hasNmcli: true
    property bool hasWifi: false            // a Wi-Fi device exists
    property bool wired: false              // an active Ethernet connection exists
    property bool wifiEnabled: false
    property string ssid: ""                // current network ("" = disconnected)
    property int signal: 0                  // 0..100
    property var networks: []               // [{ ssid, signal, secure, active, known }]
    property var known: []                  // names of saved Wi-Fi connections
    readonly property bool showWifi: hasNmcli && hasWifi && !wired

    property string connecting: ""          // SSID in progress
    property string error: ""               // last error (short text)

    // nmcli -t separates with ":" and escapes ":" inside values as "\:".
    function fields(line) {
        const out = []; let cur = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (ch === ":") { out.push(cur); cur = ""; continue }
            cur += ch
        }
        out.push(cur); return out
    }

    function refresh() { if (!devs.running) devs.running = true }
    function scan() { if (!list.running) { list.rescan = true; list.running = true } }

    Timer { running: root.users > 0; interval: 8000; repeat: true; onTriggered: root.refresh() }

    // 1) Devices: Wi-Fi? Connected Ethernet? + radio.
    Process {
        id: devs
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE dev && echo RADIO:$(nmcli radio wifi) && nmcli -t -f NAME,TYPE con show | grep ':802-11-wireless$' | sed 's/^/KNOWN:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let wifi = false, wired = false, en = false, known = []
                for (const l of text.split("\n")) {
                    if (l.startsWith("RADIO:")) { en = l.slice(6).trim() === "enabled"; continue }
                    if (l.startsWith("KNOWN:")) { known.push(root.fields(l.slice(6))[0]); continue }
                    const f = root.fields(l)
                    if (f[0] === "wifi") wifi = true
                    if (f[0] === "ethernet" && f[1] === "connected") wired = true
                }
                root.hasWifi = wifi; root.wired = wired; root.wifiEnabled = en; root.known = known
                if (root.showWifi) { list.rescan = false; list.running = true }
            }
        }
        onExited: code => { if (code === 127) root.hasNmcli = false }
    }

    // 2) Nearby networks (NM cache; `scan()` forces a rescan).
    Process {
        id: list
        property bool rescan: false
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", rescan ? "yes" : "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {}
                let cur = "", sig = 0
                for (const l of text.split("\n")) {
                    if (!l) continue
                    const f = root.fields(l)
                    const name = f[1]; if (!name) continue
                    const n = { ssid: name, signal: parseInt(f[2]) || 0, secure: !!f[3] && f[3] !== "--",
                                active: f[0] === "*", known: root.known.indexOf(name) >= 0 }
                    if (n.active) { cur = name; sig = n.signal }
                    if (!best[name] || best[name].signal < n.signal || n.active) best[name] = n
                }
                root.ssid = cur; root.signal = sig
                root.networks = Object.values(best).sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            }
        }
    }

    function setEnabled(on) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
        wifiEnabled = on
        later.restart()
    }
    Timer { id: later; interval: 1500; onTriggered: root.refresh() }

    // Connect: saved -> `con up`; open -> direct; with password -> `dev wifi connect … password`.
    function connect(ssid, password) {
        error = ""; connecting = ssid
        const isKnown = known.indexOf(ssid) >= 0
        if (isKnown && !password) conn.command = ["nmcli", "con", "up", "id", ssid]
        else if (password) conn.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
        else conn.command = ["nmcli", "dev", "wifi", "connect", ssid]
        conn.running = true
    }
    function disconnect() {
        Quickshell.execDetached(["sh", "-c", "nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | xargs -r -n1 nmcli dev disconnect"])
        later.restart()
    }
    Process {
        id: conn
        stderr: StdioCollector { id: connErr }
        onExited: code => {
            if (code !== 0) {
                const t = connErr.text.toLowerCase()
                root.error = (t.includes("secrets") || t.includes("password") || t.includes("802-11-wireless-security"))
                    ? I18n.tr("Incorrect password") : I18n.tr("Could not connect")
            }
            root.connecting = ""
            root.refresh()
        }
    }
}
