import QtQuick
import Quickshell.Widgets
import Quickshell
import "../Common"

// Compact state: clock (HH:mm) plus status items.
Item {
    id: root
    property bool active: true
    // With a freshly taken screenshot the island grows downwards with a large preview
    // (the pill animates width/height through its Behavior; the top row stays the same).
    readonly property bool hasShot: shot.ready && root.notif !== null && Recorder.notice === ""
    implicitWidth: Math.max(row.implicitWidth, hasShot ? shot.boxW + 2 * shot.side - Theme.compactPadX * 2 : 0)
    implicitHeight: Theme.compactH + (hasShot ? shot.boxH + shot.side : 0)

    // Current notification (the island shows it in the compact row).
    readonly property var notif: Notifs.current   // queue lives in Common/Notifs.qml
    readonly property bool notifQuiet: notif !== null && Notifs.fromFocused(notif)
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Theme.compactH - height) / 2
        spacing: 10
        Text {
            visible: !root.notif
            enabled: false              // decorative text: no interaction or selection
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontClock
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
        // Screenshot countdown (3, 2, 1) next to the clock.
        Rectangle {
            visible: Recorder.countdown > 0 && Recorder.notice === "" && !root.notif
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 11
            color: Theme.fill
            Text {
                enabled: false
                anchors.centerIn: parent
                text: Recorder.countdown
                color: Theme.card
                font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        // Battery (only if present): small bar with the level; red only when critical.
        // When plugged in, the fill pulses for a few seconds (charging animation).
        Row {
            id: batInd
            visible: Laptop.present && !root.notif && Recorder.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space1 + 1
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 10; radius: 5; color: Theme.track; clip: true
                Rectangle {
                    id: batFill
                    height: parent.height; radius: 5
                    width: Math.max(height, parent.width * (Laptop.present ? Laptop.bat.pct / 100 : 0))
                    color: Laptop.critical ? Theme.danger : Theme.fill
                    Behavior on width { NumberAnimation { duration: Theme.durColor + 150; easing.type: Easing.OutCubic } }
                    SequentialAnimation on opacity {
                        id: chargePulse
                        running: false
                        loops: 3
                        NumberAnimation { to: 0.3; duration: Theme.reduceMotion ? 0 : 450; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Theme.reduceMotion ? 0 : 450; easing.type: Easing.InOutSine }
                    }
                }
                Connections { target: Laptop; function onChargedAtChanged() { if (root.active && !Theme.reduceMotion) chargePulse.restart() } }
            }
            Text {
                enabled: false
                anchors.verticalCenter: parent.verticalCenter
                text: Laptop.present ? Laptop.bat.pct + "%" : ""
                color: Laptop.critical ? Theme.danger : Theme.textSecondary
                font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.weight: Font.Medium; font.features: { "tnum": 1 }
            }
        }
        // Volume/brightness OSD: thin bar with the level, next to the notice text.
        Rectangle {
            visible: Laptop.notice !== "" && Laptop.level >= 0 && Recorder.notice === "" && !root.notif
            anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 6; radius: 3; color: Theme.track
            Rectangle {
                height: parent.height; radius: 3; color: Theme.fill
                width: Math.max(height, parent.width * Math.max(0, Laptop.level))
                Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            }
        }
        // Battery / brightness / lid notice (critical in red).
        Text {
            enabled: false
            visible: Laptop.notice !== "" && Recorder.notice === "" && !root.notif
            anchors.verticalCenter: parent.verticalCenter
            text: Laptop.notice
            color: Laptop.noticeKind === "critical" ? Theme.danger : Laptop.noticeKind === "low" ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: Theme.fontCaption
            font.weight: Laptop.noticeKind === "critical" || Laptop.noticeKind === "low" ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 260)
        }
        // Recording: pulsing red dot + elapsed time.
        Row {
            visible: Recorder.recording && Recorder.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space2 - 2
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: Theme.recording
                SequentialAnimation on opacity {
                    // With reduceMotion the dot stays fixed (no continuous pulse, less CPU).
                    running: Recorder.recording && root.active && !Theme.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Text {
                enabled: false              // decorative text: no interaction or selection
                anchors.verticalCenter: parent.verticalCenter
                text: Recorder.elapsedText
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontLabel
                font.features: { "tnum": 1 }
            }
        }
        // Short message (Saved / Install wf-recorder).
        Text {
            enabled: false              // decorative text: no interaction or selection
            visible: Recorder.notice !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Recorder.notice
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, 230)
        }
        // Notification toast: icon (or Nerd Font glyph fallback), text and action pills.
        Row {
            id: toast
            visible: root.notif !== null && Recorder.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; sourceSize: Qt.size(36, 36)
                source: Notifs.thumbOf(root.notif) === "" ? Notifs.iconOf(root.notif) : ""
                visible: status === Image.Ready
                asynchronous: true; smooth: true
            }
            // Glyph fallback when no real icon resolves (e.g. USB sticks).
            Text {
                enabled: false
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: Notifs.glyphOf(root.notif)
                color: root.notifQuiet ? Theme.textSecondary : Theme.textPrimary
                font.family: "Hack Nerd Font"
                font.pixelSize: 16
            }
            Text {
                enabled: false
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.notifQuiet ? 200 : 300)
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: !root.notif ? "" : (root.notif.summary || root.notif.appName)
                      + (!root.notifQuiet && root.notif.body ? "  ·  " + root.notif.body.replace(/\s+/g, " ") : "")
                color: root.notifQuiet ? Theme.textSecondary : Theme.textPrimary
                font.family: Theme.font; font.pixelSize: Theme.fontLabel; font.weight: root.notifQuiet ? Font.Normal : Font.Medium
            }
            Repeater {
                // Up to 2 actions as pills (the "default" one is the click on the notification).
                model: root.notif && !root.notifQuiet ? Array.from(root.notif.actions || []).filter(a => a.identifier !== "default").slice(0, 2) : []
                delegate: Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: at.implicitWidth + 20; height: 24; radius: 12
                    color: am.containsMouse ? Theme.hover : Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.durMicro } }
                    Text { id: at; anchors.centerIn: parent; text: modelData.text; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.weight: Font.Medium }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.invoke(modelData) }
                }
            }
        }
        // More notifications queued: discreet "+2" (they show one at a time, so you know there are more).
        Text {
            enabled: false
            visible: root.notif !== null && Recorder.notice === "" && Notifs.queue.length > 1
            anchors.verticalCenter: parent.verticalCenter
            text: "+" + (Notifs.queue.length - 1)
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.features: { "tnum": 1 }
        }
        // Do Not Disturb active: small moon (so you know why no alerts show up).
        Icon {
            visible: Notifs.dnd && !root.notif && Recorder.notice === "" && Laptop.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            name: "moon"; size: 14; tone: "gray"
        }
        // No internet: fixed red dot (swipe over the island for details).
        Rectangle {
            visible: SysStatus.known && !SysStatus.online
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: Theme.recording
        }
        WorkspaceDots { anchors.verticalCenter: parent.verticalCenter }
    }

    // Screenshot preview: 440 px wide (height follows the aspect ratio, max 300 px).
    // Decoded scaled (sourceSize) and released when the notification goes away (source = "").
    Item {
        id: shot
        readonly property string src: Notifs.thumbOf(root.notif)
        readonly property bool ready: src !== "" && img.status === Image.Ready && img.implicitWidth > 0
        readonly property real aspect: ready ? img.implicitWidth / img.implicitHeight : 16 / 9
        readonly property int side: 10                       // bottom and side margin
        readonly property real boxW: Math.round(Math.min(440, 300 * aspect))
        readonly property real boxH: Math.round(boxW / aspect)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.compactH
        width: boxW; height: boxH
        opacity: root.hasShot ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
        ClippingRectangle {
            anchors.fill: parent
            radius: Theme.radiusCard - shot.side             // concentric with the island
            color: Theme.field
            Image {
                id: img
                anchors.fill: parent
                source: shot.src
                sourceSize.width: 880                        // 2x for HiDPI screens, never the full screenshot
                fillMode: Image.PreserveAspectFit
                asynchronous: true; cache: false; smooth: true; mipmap: false
            }
        }
    }

}
