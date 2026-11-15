pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Laptop functions: battery (warnings at 20% and 5%, plug/unplug), brightness keys,
// and lid. On startup it makes ONE reading; the event watcher (upower --monitor)
// only runs if there is battery, so on a desktop PC it costs nothing.
// Simulator: scripts/fake-laptop.sh (file ~/.cache/island-shell/fake-battery.json).
Singleton {
    id: root
    readonly property string script: Qt.resolvedUrl("../scripts/battery.py").toString().replace("file://", "")
    property var bat: null                   // { pct, status, mins, fake? } | null
    readonly property bool present: bat !== null
    readonly property bool simulated: !!(bat && bat.fake)
    readonly property bool discharging: present && bat.status === "Discharging"
    readonly property bool charging: present && bat.status === "Charging"
    readonly property bool low: discharging && bat.pct <= 20
    readonly property bool critical: discharging && bat.pct <= 5
    property bool backlight: false
    property string notice: ""               // brief notice in the compact island
    property string noticeKind: ""           // "low" | "critical" | "charging" | "unplugged" | "info"
    property real chargedAt: 0               // for the charging animation
    // One warning per discharge cycle: re-armed when plugged in.
    property bool warnedLow: false
    property bool warnedCritical: false

    property real level: -1                  // OSD: level 0–1 (volume/brightness) as a bar; -1 = no bar
    function say(msg, kind, ms, lvl) {
        notice = msg; noticeKind = kind; level = lvl === undefined ? -1 : Math.max(0, Math.min(1, lvl))
        noticeTimer.interval = ms || 3500; noticeTimer.restart()
    }
    Timer { id: noticeTimer; onTriggered: { root.notice = ""; root.noticeKind = ""; root.level = -1 } }

    // Volume OSD: the shortcut already changed the volume with wpctl (works even if the shell
    // isn't running); here we just read the value once and show it in the island with a bar.
    property string volTarget: "@DEFAULT_AUDIO_SINK@"
    function volume(which) { volTarget = which === "mic" ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@"; volRead.running = false; volRead.running = true }
    Process {
        id: volRead
        command: ["wpctl", "get-volume", root.volTarget]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /Volume:\s*([\d.]+)/.exec(text)
                if (!m) return
                const v = parseFloat(m[1]), muted = text.indexOf("MUTED") >= 0, mic = root.volTarget.indexOf("SOURCE") >= 0
                if (mic) root.say(muted ? I18n.tr("Microphone muted") : I18n.tr("Microphone active"), "info", 1400)
                else root.say(muted ? I18n.tr("Muted") : I18n.tr("Volume %1%", Math.round(v * 100)), "info", 1400, muted ? undefined : v)
            }
        }
    }
    // Real brightness: brightnessctl -m → "dev,class,actual,pct%,max"
    Process {
        id: briRead
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /,(\d+)%,/.exec(text)
                if (m) root.say(I18n.tr("Brightness %1%", m[1]), "info", 1400, parseInt(m[1]) / 100)
            }
        }
    }

    function update(b) {
        const prev = bat
        bat = b
        if (!b) { watcher.running = false; return }
        if (b.status !== "Discharging") { warnedLow = false; warnedCritical = false }
        if (prev && prev.status === "Discharging" && (b.status === "Charging" || b.status === "Full")) {
            chargedAt = Date.now(); say(I18n.tr("Charging · %1%", b.pct), "charging")
        } else if (prev && prev.status !== "Discharging" && b.status === "Discharging") {
            say(I18n.tr("Charger disconnected · %1%", b.pct), "unplugged")
        }
        if (b.status === "Discharging") {
            if (b.pct <= 5 && !warnedCritical) { warnedCritical = true; warnedLow = true; say(I18n.tr("Critical battery · %1% · plug in the charger", b.pct), "critical", 8000) }
            else if (b.pct <= 20 && !warnedLow) { warnedLow = true; say(I18n.tr("Low battery · %1%", b.pct), "low", 6000) }
        }
        if (!watcher.running) watcher.running = true
    }

    function rescan() { watcher.running = false; once.running = true }
    Process {
        id: once
        command: [root.script, "once"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { const j = JSON.parse(text); root.backlight = j.backlight; root.update(j.battery) } catch (e) {} }
        }
    }
    Process {
        id: watcher
        command: [root.script, "watch"]
        stdout: SplitParser { onRead: line => { try { root.update(JSON.parse(line)) } catch (e) {} } }
    }

    // Brightness: with real backlight uses brightnessctl; otherwise, shader brightness.
    function brightness(dir) {
        const up = dir === "up"
        if (backlight) {
            briSet.command = ["brightnessctl", "-q", "set", up ? "5%+" : "5%-"]
            briSet.running = true               // upon completion, reads actual percentage
        } else {
            // no backlight (desktop monitor): nothing to adjust
        }
    }
    Process { id: briSet; onExited: briRead.running = true }

    // Lid. With external monitor: turns off the internal screen. Without it: locks with hyprlock
    // if installed (suspension is handled by systemd as usual). In simulation it only
    // shows the notice: never actually locks or suspends.
    readonly property var internal: Hyprland.monitors.values.filter(m => /^(eDP|LVDS|DSI)/.test(m.name))
    function lid(state) {
        const closed = state === "close"
        const external = Hyprland.monitors.values.some(m => !/^(eDP|LVDS|DSI)/.test(m.name))
        if (simulated || internal.length === 0) {
            say(closed ? (external ? I18n.tr("Lid closed (simulation): internal screen would turn off")
                                   : I18n.tr("Lid closed (simulation): screen would lock"))
                       : I18n.tr("Lid open (simulation)"), "info", 4000)
            console.log("laptop: lid " + state + " (simulation, no changes)")
            return
        }
        if (closed && external)
            internal.forEach(m => Quickshell.execDetached(["hyprctl", "eval", 'hl.monitor({ output = "' + m.name + '", disabled = true })']))
        else if (closed)
            Quickshell.execDetached(["sh", "-c", "command -v hyprlock >/dev/null && (pidof hyprlock || hyprlock) >/dev/null 2>&1 &"])
        else
            Quickshell.execDetached(["hyprctl", "reload"])   // re-enables internal screen
    }

    IpcHandler {
        target: "laptop"
        function rescan(): void { root.rescan() }
        function brightness(dir: string): void { root.brightness(dir) }
        function lid(state: string): void { root.lid(state) }
        function volume(which: string): void { root.volume(which) }
        function state(): string { return JSON.stringify({ battery: root.bat, backlight: root.backlight, notice: root.notice }) }
    }
}
