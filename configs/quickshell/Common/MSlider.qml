import QtQuick

// Control Center style slider: thick gray track, black fill, icon inside.
Item {
    id: s
    property string icon
    property string label
    property real from: 0
    property real to: 1
    property real value: 0
    property string valueText: Math.round(frac * 100) + "%"
    property bool iconClickable: false
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    signal moved(real v)
    signal iconClicked()

    implicitHeight: 40
    implicitWidth: 320

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.track
        clip: true
        Rectangle {
            id: fillRect
            height: parent.height
            width: Math.max(parent.height, parent.width * s.frac)
            radius: height / 2
            color: Theme.fill
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.leftMargin: s.iconClickable ? 40 : 0
        cursorShape: Qt.PointingHandCursor
        function upd(mx) {
            const f = Math.max(0, Math.min(1, (mx + anchors.leftMargin) / s.width))
            s.moved(s.from + f * (s.to - s.from))
        }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x) }
        // Wheel: 5% per notch. Small touchpad deltas accumulate (don't jump by 5%).
        property real acc: 0
        onWheel: w => {
            acc += w.angleDelta.y
            const steps = acc > 0 ? Math.floor(acc / 120) : Math.ceil(acc / 120)
            if (steps === 0) return
            acc -= steps * 120
            s.moved(Math.max(s.from, Math.min(s.to, s.value + steps * (s.to - s.from) * 0.05)))
        }
    }
    Icon {
        x: 12; anchors.verticalCenter: parent.verticalCenter
        size: 18
        name: s.icon
        tone: fillRect.width > 36 ? "white" : "dark"
        // Clickable icon (mute): fades on hover and sinks on press.
        opacity: iconMouse.pressed ? 0.55 : iconMouse.containsMouse ? 0.75 : 1
        scale: iconMouse.pressed ? 0.9 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        MouseArea {
            id: iconMouse
            anchors.fill: parent; anchors.margins: -10
            enabled: s.iconClickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: s.iconClicked()
        }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        id: valueLabel
        text: s.valueText
        // The color follows the fill: white only when the fill has passed underneath the number
        // (previously it stayed gray on black between ~80% and 90%).
        color: fillRect.width > x + width / 2 ? Theme.onAccent : Theme.textSecondary
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }
}
