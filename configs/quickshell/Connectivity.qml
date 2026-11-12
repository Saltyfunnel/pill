// Connectivity.qml — network (nmcli) and Bluetooth (bluetoothctl) state, shared by the dashboard.
// Polls every 5 seconds; scans for Wi-Fi only while the Connectivity tab is showing.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // set by Dashboard.qml: true only while the Connectivity tab is on screen
  property bool scanning: false

  // ---------- network ----------
  property bool connected: false
  property bool isWifi: false
  property string connName: ""
  property string ip: ""
  property bool wifiChecked: false
  property bool hasWifi: false
  property var accessPoints: []     // [{ ssid, signal, secure, active, known }]

  // ---------- bluetooth ----------
  property bool hasAdapter: false
  property bool powered: false
  property var devices: []          // [{ mac, name, connected }]

  Process {
    id: netProc
    command: ["sh", "-c",
      "line=$(nmcli -t -f TYPE,DEVICE,NAME connection show --active | grep -E '^(802-3-ethernet|802-11-wireless|ethernet|wifi):' | head -1); "
      + "[ ${#line} -eq 0 ] && exit 0; "
      + "type=${line%%:*}; rest=${line#*:}; dev=${rest%%:*}; name=${rest#*:}; "
      + "echo type $type; echo name $name; "
      + "echo ip $(nmcli -g IP4.ADDRESS device show $dev | head -1)"]

    stdout: StdioCollector {
      onStreamFinished: {
        let c = false, wifi = false, name = "", ip = ""
        for (const raw of text.split("\n")) {
          const line = raw.trim()
          const i = line.indexOf(" ")
          const key = i < 0 ? line : line.slice(0, i)
          const val = i < 0 ? "" : line.slice(i + 1).trim()
          if (key === "type") { c = true; wifi = (val === "802-11-wireless" || val === "wifi") }
          if (key === "name") name = val
          if (key === "ip")   ip = val
        }
        root.connected = c
        root.isWifi = wifi
        root.connName = name
        root.ip = ip
      }
    }
  }

  Process {
    id: wifiProc
    command: ["sh", "-c",
      "nmcli device wifi rescan >/dev/null 2>&1; "
      + "echo haswifi $(nmcli -t -f TYPE device | grep -c '^wifi$'); "
      + "nmcli -t -f NAME connection show | sed 's/^/known /'; "
      + "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null | sed 's/^/ap /'"]

    stdout: StdioCollector {
      onStreamFinished: {
        let hasWifi = false
        const known = {}
        const best = {}
        for (const raw of text.split("\n")) {
          if (raw.startsWith("haswifi ")) hasWifi = Number(raw.slice(8)) > 0
          else if (raw.startsWith("known ")) known[raw.slice(6).trim()] = true
          else if (raw.startsWith("ap ")) {
            // fields: IN-USE : SIGNAL : SECURITY : SSID  (the SSID is last, and may contain colons)
            const p = raw.slice(3).split(":")
            const ssid = p.slice(3).join(":").replace(/\\:/g, ":").trim()
            if (ssid === "") continue
            const ap = {
              ssid: ssid,
              signal: Number(p[1]),
              secure: (p[2] || "") !== "" && p[2] !== "--",
              active: p[0] === "*",
              known: false
            }
            const cur = best[ssid]
            if (!cur || (!cur.active && (ap.active || ap.signal > cur.signal))) best[ssid] = ap
          }
        }
        const list = Object.values(best)
        for (const a of list) a.known = known[a.ssid] === true
        list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))

        root.hasWifi = hasWifi
        root.accessPoints = list.slice(0, 7)
        root.wifiChecked = true
      }
    }
  }

  Process {
    id: btProc
    command: ["sh", "-c",
      "echo adapter $(bluetoothctl show 2>/dev/null | grep -c Controller); "
      + "echo powered $(bluetoothctl show 2>/dev/null | grep -c 'Powered: yes'); "
      + "bluetoothctl devices Paired 2>/dev/null | sed 's/^Device /paired /'; "
      + "bluetoothctl devices Connected 2>/dev/null | sed 's/^Device /connected /'"]

    stdout: StdioCollector {
      onStreamFinished: {
        let adapter = false, powered = false
        const names = {}
        const paired = []
        const connected = {}
        for (const raw of text.split("\n")) {
          const line = raw.trim()
          const parts = line.split(" ")
          if (parts[0] === "adapter") adapter = Number(parts[1]) > 0
          else if (parts[0] === "powered") powered = Number(parts[1]) > 0
          else if (parts[0] === "paired" || parts[0] === "connected") {
            const mac = parts[1]
            const name = parts.slice(2).join(" ") || mac
            if (parts[0] === "paired") { paired.push(mac); names[mac] = name }
            else connected[mac] = true
          }
        }
        root.hasAdapter = adapter
        root.powered = powered
        root.devices = paired.map(m => ({ mac: m, name: names[m], connected: connected[m] === true }))
      }
    }
  }

  Timer {
    running: true; interval: 5000; repeat: true; triggeredOnStart: true
    onTriggered: { netProc.running = true; btProc.running = true }
  }
  // Wi-Fi scan: once at start (to learn if there is Wi-Fi), then only while the tab is showing
  Timer {
    running: true; interval: 10000; repeat: true; triggeredOnStart: true
    onTriggered: if (!root.wifiChecked || (root.hasWifi && root.scanning)) wifiProc.running = true
  }
  // Re-check shortly after you click something
  Timer {
    id: afterAction
    interval: 3500
    onTriggered: { netProc.running = true; wifiProc.running = true; btProc.running = true }
  }

  onScanningChanged: if (scanning) { netProc.running = true; btProc.running = true; if (hasWifi) wifiProc.running = true }

  function connectTo(ap) {
    if (ap.active) return
    if (ap.known) {
      Quickshell.execDetached(["nmcli", "connection", "up", "id", ap.ssid])
    } else if (!ap.secure) {
      Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ap.ssid])
    } else {
      // new password-protected network: let nmtui-connect ask for the password
      Quickshell.execDetached(["kitty", "-e", "nmtui-connect", ap.ssid])
    }
    afterAction.restart()
  }

  function runBt(args) {
    Quickshell.execDetached(args)
    afterAction.restart()
  }
}
