import QtQuick
import "../Common"
import "sections"
import Quickshell.Io

// System status panel (opened by swiping over the island): Internet, Resources, Devices.
// Fetches data only while open.
Item {
    id: root
    property bool open: false
    implicitHeight: col.implicitHeight + Theme.padPanel * 2
    // The island limits the height (Theme.maxExpandedH): if content doesn't fit, it scrolls
    // inside the panel with blurred edges instead of being cut off.
    height: Math.min(implicitHeight, Theme.maxExpandedH)

    onOpenChanged: {
        if (!open) { freeArmed = false; freeDisarm.stop(); freeApps = [] }
        if (open) flick.contentY = 0
        if (open) ppGet.running = true
        open ? SysStatus.acquire() : SysStatus.release()
        if (open) { enterAnim.restart() } else { enterAnim.stop(); enter = 1 }
    }
    // Staggered and smooth entrance: each block appears ~35 ms after the previous one.
    property real enter: 1
    NumberAnimation { id: enterAnim; target: root; property: "enter"; from: 0; to: 1; duration: 520 }
    onEnterChanged: {
        const kids = col.children, n = kids.length
        for (let i = 0; i < n; i++) {
            const t = Math.max(0, Math.min(1, (root.enter * 520 - i * 35) / 220))
            kids[i].opacity = 1 - Math.pow(1 - t, 3)
        }
    }

    // Character mood based on state: no internet → worried; CPU >85% or
    // high temperature (≥85 °C CPU / ≥85 °C GPU) → tired; otherwise, happy.
    readonly property string mood: SysStatus.known && !SysStatus.online ? "worried"
        : (r && (r.cpu > 85 || (r.temp !== null && r.temp !== undefined && r.temp >= 85)))
          || (SysStatus.gpu && SysStatus.gpu.temp >= 85) ? "tired" : ""
    Component.onDestruction: if (open) SysStatus.release()

    // Free memory (Android style): first click arms (persistent black, like Power Off),
    // second click closes all windows except the focused one using normal Hyprland
    // closing (never kills processes). Closing the panel cancels.
    property bool freeArmed: false
    property string freeMsg: ""
    property bool freeDone: false      // brief "Ready" state after freeing
    Timer { id: freeDoneT; interval: 2600; onTriggered: root.freeDone = false }
    function pressFree() {
        if (freeProc.running) return
        if (!freeArmed) {
            freeArmed = true; freeDone = false; freeMsg = ""; freeApps = []; freeCount = -1; freeDisarm.restart()
            freePeek.running = true         // preview what will be closed (without closing anything)
            return
        }
        freeArmed = false; freeDisarm.stop()
        freeMsg = I18n.tr("Freeing…")
        freeProc.running = true
    }
    Timer { id: freeDisarm; interval: 4000; onTriggered: root.freeArmed = false }
    property var freeApps: []          // [{ name, mb }] of the preview
    property int freeCount: -1
    function mb(v) { return v >= 1024 ? (v / 1024).toFixed(1).replace(".", ",") + " GB" : v + " MB" }
    readonly property string freePreview: freeCount < 0 ? I18n.tr("Tap again to close remaining windows")
        : freeApps.slice(0, 3).map(a => a.name + " " + mb(a.mb)).join(" · ") + (freeApps.length > 3 ? " …" : "")
    Process {
        id: freePeek
        command: [Qt.resolvedUrl("../scripts/free-mem.py").toString().replace("file://", ""), "--dry-run"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null
                try { j = JSON.parse(text) } catch (e) {}
                if (!j || !root.freeArmed) return
                if (j.closed === 0) {        // nothing to close: no point in confirming
                    root.freeArmed = false; freeDisarm.stop()
                    root.freeMsg = I18n.tr("No other windows open"); freeMsgClear.restart()
                    return
                }
                root.freeCount = j.closed; root.freeApps = j.apps || []
            }
        }
    }
    Timer { id: freeMsgClear; interval: 5000; onTriggered: root.freeMsg = "" }
    Process {
        id: freeProc
        command: [Qt.resolvedUrl("../scripts/free-mem.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null
                try { j = JSON.parse(text) } catch (e) {}
                if (!j) root.freeMsg = ""
                else if (j.closed === 0) root.freeMsg = I18n.tr("No other windows open")
                else {
                    const parts = []
                    if (j.ram !== null && j.ram > 0) parts.push("RAM " + (j.ram >= 1024 ? (j.ram / 1024).toFixed(1) + " GB" : j.ram + " MB"))
                    if (j.vram !== null && j.vram > 0) parts.push(I18n.tr("Video") + " " + j.vram + " MB")
                    root.freeMsg = I18n.tr("%1 windows closed", j.closed) + (parts.length ? " · " + I18n.tr("Freed: %1", parts.join(", ")) : "")
                }
                freeMsgClear.restart()
                if (j) { root.freeDone = true; freeDoneT.restart() }
            }
        }
    }

    // Power profile (power-profiles-daemon). Read when panel opens; hidden if service is absent.
    property string profile: ""
    Process {
        id: ppGet
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.profile = text.trim() }
    }
    property string ppApplied: ""      // brief confirmation "Mode X activated · Undo"
    property string ppPrev: ""
    Timer { id: ppAppliedT; interval: 4000; onTriggered: root.ppApplied = "" }
    Process {
        id: ppSet
        onExited: {
            ppGet.running = true
            const m = { "power-saver": I18n.tr("Power saver"), "balanced": I18n.tr("Balanced"), "performance": I18n.tr("Performance") }
            root.ppApplied = m[root.profile] || ""; ppAppliedT.restart()
        }
    }

    // Wi-Fi interface speed: /sys counters every 2 s, only with panel open and Wi-Fi.
    property real rxRate: -1
    property real txRate: -1
    property var lastNet: null
    function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1).replace(".", ",") + " MB/s" : Math.round(b / 1024) + " KB/s" }
    Timer { interval: 5000; repeat: true; triggeredOnStart: true; running: root.open && Network.hasWifi && Network.ssid !== ""; onTriggered: if (!netStat.running) netStat.running = true
            onRunningChanged: if (!running) { root.lastNet = null; root.rxRate = -1; root.txRate = -1 } }
    Process {
        id: netStat
        command: ["sh", "-c", "for d in /sys/class/net/*; do [ -d \"$d/wireless\" ] && cat \"$d/statistics/rx_bytes\" \"$d/statistics/tx_bytes\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n").map(Number), t = Date.now()
                if (v.length < 2 || isNaN(v[0])) return
                if (root.lastNet) {
                    const dt = (t - root.lastNet.t) / 1000
                    if (dt > 0) { root.rxRate = Math.max(0, (v[0] - root.lastNet.rx) / dt); root.txRate = Math.max(0, (v[1] - root.lastNet.tx) / dt) }
                }
                root.lastNet = { rx: v[0], tx: v[1], t: t }
            }
        }
    }
    function setProfile(p, undo) {
        if (ppSet.running || p === profile) return
        ppPrev = undo ? "" : profile
        profile = p
        ppSet.command = ["powerprofilesctl", "set", p]
        ppSet.running = true
    }

    // Which apps use most CPU/memory: measured only while mouse is over a ring.
    property bool procWanted: false
    property var topCpu: []
    property var topMem: []
    Timer { interval: 5000; repeat: true; triggeredOnStart: true; running: root.open && root.procWanted; onTriggered: if (!procs.running) procs.running = true }
    Process {
        id: procs
        command: [Qt.resolvedUrl("../scripts/top-procs.sh").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = [], m = []
                for (const l of text.trim().split("\n")) {
                    const f = l.split(" ")
                    if (f.length < 3) continue
                    if (f[0] === "C") c.push(f[1] + " " + f[2] + "%")
                    else if (f[0] === "M") m.push(f[1] + " " + root.mb(Number(f[2])))
                }
                root.topCpu = c; root.topMem = m
            }
        }
    }
    // Brief notice under Resources (e.g. if no system monitor is installed).
    property string toast: Launch.error
    Timer { id: toastT; interval: 3500; onTriggered: root.toast = Qt.binding(() => Launch.error) }
    function showToast(t) { toast = t; toastT.restart() }
    Process {
        id: monProc
        command: [Qt.resolvedUrl("../scripts/open-monitor.sh").toString().replace("file://", "")]
        onExited: code => { if (code !== 0) root.showToast(I18n.tr("No system monitor installed")) }
    }
    function openMonitor() { if (!monProc.running) monProc.running = true }
    // Brings into view whatever receives focus with Tab (if panel is scrolled).
    function ensureVisible(it) {
        if (!it || !flick.interactive) return
        const p = it.mapToItem(flick.contentItem, 0, 0)
        let to = flick.contentY
        if (p.y < flick.contentY + 16) to = p.y - 16
        else if (p.y + it.height > flick.contentY + flick.height - 16) to = p.y + it.height - flick.height + 16
        scrollTo(to)
    }
    function scrollTo(y) {
        scrollAnim.to = Math.max(0, Math.min(flick.contentHeight - flick.height, y)); scrollAnim.restart()
    }

    readonly property var r: SysStatus.res
    readonly property var n: SysStatus.net
    readonly property var d: SysStatus.dev
    readonly property var bat: r ? r.battery : null
    function batText(b) {
        if (!b) return ""
        const t = b.mins === null || b.mins === undefined ? "" : " · " + (b.mins >= 60 ? Math.floor(b.mins / 60) + " h " : "") + (b.mins % 60) + " min"
        return b.pct + "%" + (b.status === "Charging" ? I18n.tr(" · Charging") + t
                            : b.status === "Full" ? I18n.tr(" · Charged")
                            : b.status === "Not charging" ? I18n.tr(" · Plugged in") : t)
    }

    component Title: Text {
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontTiny; font.weight: Font.DemiBold
        font.letterSpacing: 0.2; leftPadding: 16
    }
    component Row2: Item {
        id: rw
        property string icon
        property string label
        property string value
        property color valueColor: Theme.textSecondary
        width: parent ? parent.width : 0; height: 40
        Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: rw.icon; size: 16; tone: "dark" }
        Text {
            x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.5 - 44
            text: rw.label; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.5 - 14; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            text: rw.value; color: rw.valueColor; font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
        }
    }
    component Card: Rectangle {
        default property alias content: inner.children
        width: parent ? parent.width : 0; height: inner.implicitHeight + 8
        radius: 18; color: Theme.surface
        Column { id: inner; y: 4; width: parent.width }
    }
    component Bar: Item {
        id: br
        property real frac: 0
        property bool lowIsBad: false       // battery: red when running low
        readonly property bool bad: lowIsBad ? frac < 0.15 : frac > 0.9
        width: parent ? parent.width - 28 : 0; x: 14; height: 10
        Rectangle {
            anchors.top: parent.top; width: parent.width; height: 4; radius: 2; color: Theme.track
            Rectangle {
                height: parent.height; radius: 2; color: br.bad ? Theme.danger : Theme.fill
                width: parent.width * Math.max(0, Math.min(1, br.frac))
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    // Large ring for main metrics; numbers animate.
    component Gauge: Item {
        id: g
        property real frac: 0
        property bool bad: false
        property string label
        property string detail
        property string hoverDetail
        property string tipTitle
        property string tipPrefix
        property var tipLines: []
        property bool hot: false          // detail after brief pause: doesn't flicker when crossing
        signal activated()
        activeFocusOnTab: true
        Keys.onReturnPressed: g.activated()
        Keys.onSpacePressed: g.activated()
        onActiveFocusChanged: { g.hot = activeFocus; if (activeFocus) root.ensureVisible(g) }
        Timer { id: gHot; interval: Theme.durHover; onTriggered: g.hot = true }
        z: hot ? 5 : 0
        property real shown: Math.max(0, Math.min(1, frac))
        Behavior on shown { NumberAnimation { duration: 900; easing.type: Easing.OutQuart } }   // sliding figures, no jumps
        onShownChanged: cv.requestPaint()
        onBadChanged: cv.requestPaint()
        height: 136
        Item {
            id: ring
            width: 88; height: 88; anchors.horizontalCenter: parent.horizontalCenter; y: 4
            scale: gm.pressed ? 0.97 : gh.hovered ? 1.02 : 1
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            Canvas {
                id: cv
                anchors.fill: parent; renderStrategy: Canvas.Cooperative
                onPaint: {
                    const c = getContext("2d"), w = 6, rr = width / 2 - w / 2
                    c.reset(); c.lineCap = "round"; c.lineWidth = w
                    c.strokeStyle = String(Theme.track)
                    c.beginPath(); c.arc(width / 2, height / 2, rr, 0, 2 * Math.PI); c.stroke()
                    if (g.shown > 0.005) {
                        c.strokeStyle = String(g.bad ? Theme.danger : Theme.fill)
                        c.beginPath(); c.arc(width / 2, height / 2, rr, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * g.shown); c.stroke()
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                Text {
                    text: Math.round(g.shown * 100); color: g.bad ? Theme.danger : Theme.textPrimary
                    font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Medium; font.features: { "tnum": 1 }
                }
                Text {
                    text: "%"; anchors.baseline: parent.children[0].baseline; color: Theme.textSecondary
                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 100
            text: g.label; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 120; width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            // At rest only the name; detail appears on hover or if there's an alert.
            // On hover, on the same line: highest usage right now (no tooltips covering rows).
            text: g.hot ? (g.tipLines.length ? (g.tipPrefix !== "" ? g.tipPrefix + " · " : "") + g.tipLines.slice(0, g.tipPrefix !== "" ? 1 : 2).join(" · ") : g.hoverDetail)
                : g.bad ? g.detail : ""
            opacity: text !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
            color: g.bad ? Theme.danger : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: Theme.fontTiny; font.features: { "tnum": 1 }
        }
        Rectangle {      // keyboard focus
            anchors.fill: ring; anchors.margins: -5; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.fill
            opacity: g.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        // Tooltip with apps using this resource right now.
        Rectangle {
            id: tip
            readonly property bool want: false
            anchors.horizontalCenter: parent.horizontalCenter; y: 128
            width: Math.max(140, tipCol.implicitWidth + 24); height: tipCol.implicitHeight + 16; radius: 12
            color: Theme.fill
            opacity: want ? 1 : 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            Column {
                id: tipCol; x: 12; y: 8; spacing: 2
                Text { text: g.tipTitle; color: Theme.onAccent; opacity: 0.7; font.family: Theme.font; font.pixelSize: Theme.fontTiny }
                Repeater {
                    model: g.tipLines
                    Text { required property var modelData; text: modelData; color: Theme.onAccent; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 } }
                }
                Text { text: I18n.tr("Click: open system monitor"); color: Theme.onAccent; opacity: 0.7; font.family: Theme.font; font.pixelSize: Theme.fontTiny; topPadding: 2 }
            }
        }
        // Only ring and its texts count as "hovered": tooltip does not retain hover.
        Item { width: parent.width; height: 136
        HoverHandler { id: gh; onHoveredChanged: hovered ? gHot.restart() : (gHot.stop(), g.hot = g.activeFocus) } }
        MouseArea { id: gm; anchors.fill: ring; cursorShape: Qt.PointingHandCursor; onClicked: g.activated() }
    }
    // Compact row: icon, name, value and thin bar below. On hover, more detail.
    component MiniRow: Item {
        id: mr
        property string icon
        property string label
        property string value
        property string hoverValue
        property real frac: 0
        property bool lowIsBad: false
        property bool bad: lowIsBad ? frac < 0.15 : frac > 0.9
        property bool clickable: false
        property string hint           // extra text on hover if clickable
        signal activated()
        property bool hot: false
        Timer { id: mHot; interval: Theme.durHover; onTriggered: mr.hot = true }
        activeFocusOnTab: clickable
        Keys.onReturnPressed: mr.activated()
        Keys.onSpacePressed: mr.activated()
        onActiveFocusChanged: { mr.hot = activeFocus; if (activeFocus) root.ensureVisible(mr) }
        width: parent ? parent.width : 0; height: 40
        Rectangle {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; radius: 14
            color: mh.hovered ? Theme.hover : "transparent"
            scale: mrm.pressed ? 0.98 : 1
            border.width: mr.activeFocus ? 2 : 0; border.color: Theme.fill
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
        Icon { x: 16; y: 7; name: mr.icon; size: 16; tone: "dark" }
        Text {
            x: 44; y: 6; text: mr.label; color: Theme.textPrimary
            font.family: Theme.font; font.pixelSize: 13
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 7; width: parent.width - 130
            horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            text: mr.hot && mr.hoverValue !== "" ? mr.hoverValue + (mr.clickable && mr.hint !== "" ? " · " + mr.hint : "") : mr.value
            color: mr.bad ? Theme.danger : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
        }
        Rectangle {
            x: 44; y: 28; width: parent.width - 60; height: 3; radius: 1.5; color: Theme.track
            Rectangle {
                height: parent.height; radius: 2; color: mr.bad ? Theme.danger : Theme.fill
                width: parent.width * Math.max(0, Math.min(1, mr.frac))
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        HoverHandler { id: mh; onHoveredChanged: hovered ? mHot.restart() : (mHot.stop(), mr.hot = mr.activeFocus) }
        MouseArea { id: mrm; anchors.fill: parent; enabled: mr.clickable; cursorShape: Qt.PointingHandCursor; onClicked: mr.activated() }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width; contentHeight: root.implicitHeight
        interactive: contentHeight > height + 1
        clip: true; boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2600; maximumFlickVelocity: 2200
        NumberAnimation { id: scrollAnim; target: flick; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }
        // Mouse wheel: smooth animated steps instead of jumps.
        WheelHandler {
            enabled: flick.interactive
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                const base = scrollAnim.running ? scrollAnim.to : flick.contentY
                const dy = e.pixelDelta.y !== 0 ? -e.pixelDelta.y : -e.angleDelta.y / 120 * 90
                if (e.pixelDelta.y !== 0) { scrollAnim.stop(); flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy)) }
                else root.scrollTo(base + dy)
            }
        }
    Column {
        id: col
        x: Theme.padPanel; y: Theme.padPanel; width: flick.width - Theme.padPanel * 2
        spacing: Theme.space2

        // Internet: connection state and, if wireless card exists, Wi-Fi control with
        // the network list (formerly in island menu) directly below.
        Title { text: "Internet" }
        // With Wi-Fi and everything fine, the Wi-Fi row says it already: status row only appears with
        // Ethernet, offline or with an issue (no internet, captive portal).
        Card {
            visible: !(root.n && root.n.type === "wifi" && Network.hasWifi && SysStatus.online)
            Row2 {
                icon: root.n && root.n.type === "wifi" ? "wifi" : "ethernet"
                label: !root.n || !root.n.type ? I18n.tr("Offline") : (root.n.type === "wifi" ? "Internet" : "Ethernet")
                value: !SysStatus.known ? I18n.tr("Checking…")
                       : SysStatus.online ? I18n.tr("Connected")
                       : SysStatus.connectivity === "portal" ? I18n.tr("Requires sign-in")
                       : SysStatus.connectivity === "limited" ? I18n.tr("No internet (limited network)") : I18n.tr("No internet")
                valueColor: SysStatus.known && !SysStatus.online ? Theme.danger : Theme.textSecondary
            }
        }
        WifiSection { id: wifiSec; width: parent.width; active: root.open }

        // Resources: most important (CPU and memory) in two large rings; disk, battery and
        // GPU in compact rows. Numbers animate; on hover they show more detail.
        Card {
            // Wi-Fi (only if wireless card and connection exist): network, signal and speed.
            // Click → opens the network list above.
            Item {
                id: wr
                visible: Network.hasWifi && Network.wifiEnabled && Network.ssid !== ""
                width: parent.width; height: 40
                activeFocusOnTab: visible
                property bool hot: false
                Timer { id: wHot; interval: Theme.durHover; onTriggered: wr.hot = true }
                onActiveFocusChanged: { wr.hot = activeFocus; if (activeFocus) root.ensureVisible(wr) }
                Keys.onReturnPressed: wr.activate()
                Keys.onSpacePressed: wr.activate()
                function activate() {
                    wifiSec.expanded = true; Network.scan()
                    root.scrollTo(wifiSec.mapToItem(flick.contentItem, 0, 0).y - 40)   // show the list
                }
                readonly property string quality: Network.signal >= 70 ? I18n.tr("Excellent") : Network.signal >= 45 ? I18n.tr("Good")
                                                : Network.signal >= 25 ? I18n.tr("Weak") : I18n.tr("Very weak")
                Rectangle {
                    anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; radius: 14
                    color: wh.hovered ? Theme.hover : "transparent"
                    scale: wm.pressed ? 0.98 : 1
                    border.width: wr.activeFocus ? 2 : 0; border.color: Theme.fill
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Behavior on scale { NumberAnimation { duration: 120 } }
                }
                // Network name is already above: here only traffic (if any) or quality.
                readonly property bool busy: root.rxRate >= 65536 || root.txRate >= 65536
                Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "wifi"; size: 16; tone: "dark" }
                Text {
                    x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; elide: Text.ElideRight
                    text: wr.hot ? I18n.tr("Signal %1% · view networks", Network.signal)
                        : wr.busy ? "↓ " + root.rate(root.rxRate) + "   ↑ " + root.rate(root.txRate) : wr.quality
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
                }
                HoverHandler { id: wh; onHoveredChanged: hovered ? wHot.restart() : (wHot.stop(), wr.hot = wr.activeFocus) }
                MouseArea { id: wm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wr.activate() }
            }
            Item {
                width: parent.width; height: 136
                z: cpuG.hot || memG.hot ? 5 : 0       // tooltip stays above rows
                Row {
                    anchors.centerIn: parent; spacing: 0
                    Gauge {
                        id: cpuG
                        width: (parent.parent.width) / 2
                        frac: root.r ? root.r.cpu / 100 : 0
                        bad: root.r ? (root.r.cpu > 85 || (root.r.temp !== null && root.r.temp !== undefined && root.r.temp >= 85)) : false
                        label: "CPU"
                        // In alert, line explains why it's red.
                        detail: !root.r ? "…" : root.r.cpu > 85 ? I18n.tr("High usage")
                              : root.r.temp !== null && root.r.temp !== undefined && root.r.temp >= 85 ? I18n.tr("Heat: %1 °C", root.r.temp)
                              : root.r.temp !== null && root.r.temp !== undefined ? root.r.temp + " °C" : I18n.tr("In use")
                        hoverDetail: !root.r || root.r.temp === null || root.r.temp === undefined ? I18n.tr("Processor usage")
                                     : root.r.temp >= 85 ? I18n.tr("High temperature") : I18n.tr("Normal temperature")
                        tipTitle: I18n.tr("Highest usage now"); tipLines: root.topCpu
                        tipPrefix: root.r && root.r.temp !== null && root.r.temp !== undefined ? root.r.temp + " °C" : ""
                        onHotChanged: root.procWanted = hot || memG.hot
                        onActivated: root.openMonitor()
                    }
                    Gauge {
                        id: memG
                        width: (parent.parent.width) / 2
                        frac: root.r ? root.r.memUsed / root.r.memTotal : 0
                        bad: root.r ? root.r.memUsed / root.r.memTotal > 0.9 : false
                        tipTitle: I18n.tr("More memory"); tipLines: root.topMem
                        onHotChanged: root.procWanted = hot || cpuG.hot
                        onActivated: root.openMonitor()
                        label: I18n.tr("Memory")
                        detail: !root.r ? "…" : root.r.memUsed / root.r.memTotal > 0.9 ? I18n.tr("Almost full")
                              : I18n.tr("%1 of %2 GB", SysStatus.gib(root.r.memUsed), SysStatus.gib(root.r.memTotal))
                        hoverDetail: root.r ? I18n.tr("%1 GB free", SysStatus.gib(root.r.memTotal - root.r.memUsed)) : "…"
                    }
                }
            }
            // One row per internal disk (falls back to the root filesystem alone).
            Repeater {
                model: root.r ? (root.r.disks && root.r.disks.length > 0 ? root.r.disks
                                 : [{ name: "/", used: root.r.diskUsed, total: root.r.diskTotal }]) : []
                delegate: MiniRow {
                    id: dr
                    required property var modelData
                    required property int index
                    icon: "folder"
                    label: (root.r.disks && root.r.disks.length > 1) ? dr.modelData.name : I18n.tr("Disk")
                    frac: dr.modelData.total > 0 ? dr.modelData.used / dr.modelData.total : 0
                    value: I18n.tr("%1 GB free", SysStatus.gib(dr.modelData.total - dr.modelData.used))
                    hoverValue: I18n.tr("%1 of %2 GB", SysStatus.gib(dr.modelData.used), SysStatus.gib(dr.modelData.total))
                    clickable: true; hint: I18n.tr("open")
                    onActivated: Launch.open("files")
                }
            }
            MiniRow {
                visible: !!root.bat
                icon: "battery"; label: I18n.tr("Battery"); lowIsBad: true
                frac: root.bat ? root.bat.pct / 100 : 0
                value: root.bat ? root.bat.pct + "%" : ""
                hoverValue: root.batText(root.bat)
                bad: !!root.bat && root.bat.pct < 15 && root.bat.status === "Discharging"
            }
            // Low battery: one-touch suggestion to switch to Power Saver (and back with Undo).
            Item {
                id: lowBat
                visible: !!root.bat && root.bat.pct <= 20 && root.bat.status === "Discharging"
                       && root.profile !== "" && (root.profile !== "power-saver" || root.ppApplied !== "")
                readonly property bool done: root.profile === "power-saver"      // lasts a few seconds: no jumps
                width: parent.width; height: 34
                Rectangle {
                    x: 44; anchors.verticalCenter: parent.verticalCenter
                    width: lbT.implicitWidth + 24; height: 26; radius: 13
                    color: lbM.containsMouse ? Theme.fillHover : Theme.fill
                    scale: lbM.pressed ? 0.96 : 1
                    border.width: lowBat.activeFocus ? 2 : 0; border.color: Theme.textSecondary
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Text { id: lbT; anchors.centerIn: parent; text: lowBat.done ? I18n.tr("Power saver enabled") : I18n.tr("Low battery · use Power Saver"); color: Theme.onAccent; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea { id: lbM; anchors.fill: parent; hoverEnabled: true; enabled: !lowBat.done; cursorShape: Qt.PointingHandCursor; onClicked: root.setProfile("power-saver") }
                }
                activeFocusOnTab: visible
                Keys.onReturnPressed: root.setProfile("power-saver")
                Keys.onSpacePressed: root.setProfile("power-saver")
                onActiveFocusChanged: if (activeFocus) root.ensureVisible(lowBat)
            }
            MiniRow {
                visible: !!SysStatus.gpu
                icon: "display"; label: "GPU"
                frac: SysStatus.gpu ? SysStatus.gpu.util / 100 : 0
                value: SysStatus.gpu ? SysStatus.gpu.util + "%" : ""
                hoverValue: SysStatus.gpu ? SysStatus.gpu.temp + " °C" : ""
                bad: !!SysStatus.gpu && SysStatus.gpu.temp >= 85
}
}
}
}
}
