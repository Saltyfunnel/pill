import QtQuick
import "../Common"

// Light gray circular button with line icon and gray label underneath.
// Borderless: the circle is distinguished by icon, label, and hover. Keyboard focus is
// shown with a ring only while focused (Tab), never as a permanent border.
// `armed` can come from outside (ActionsSection state machine) and is respected;
// if `confirm` is true, the button uses its own internal state (`selfArmed`). The click never
// writes `armed`, so it doesn't break the external binding (which turned off confirmation black).
Item {
    id: btn
    property string icon
    property string label
    property bool confirm: false
    property bool armed: false         // armed from outside (binding)
    property bool selfArmed: false     // internal arming (confirm: true)
    readonly property bool isArmed: armed || selfArmed
    property bool active: false        // "on" state: black with white icon
    property string letter: ""         // custom access: initial instead of icon
    signal activated()
    property real lastFire: 0

    width: Theme.menuBtnSize; height: Theme.menuBtnSize
    activeFocusOnTab: true
    // Keyboard: button sinks on press and fires on release (same as with mouse).
    property bool keyDown: false
    Keys.onPressed: e => { if (!e.isAutoRepeat && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { keyDown = true; e.accepted = true } }
    Keys.onReleased: e => { if (!e.isAutoRepeat && keyDown && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { keyDown = false; mouse.fire(); e.accepted = true } }
    onActiveFocusChanged: if (!activeFocus) keyDown = false

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.menuBtnCircle; height: Theme.menuBtnCircle; radius: Theme.menuBtnCircle / 2
        color: (btn.isArmed || btn.active) ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
        scale: (mouse.pressed && mouse.containsMouse) || btn.keyDown ? 0.92 : 1
        Rectangle {       // keyboard focus ring (only when focused)
            anchors.fill: parent; anchors.margins: -4; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.fill
            // Appears smoothly (without "pop") when arriving via Tab.
            opacity: btn.activeFocus ? 1 : 0
            scale: btn.activeFocus ? 1 : 0.94
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durFast + 40; easing.type: Easing.OutCubic } }
        }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: Theme.durMicro; easing.type: Easing.OutQuad } }
        // Optical centering: line icons often look 1 px high.
        Icon { anchors.centerIn: parent; anchors.verticalCenterOffset: 1; name: btn.icon; visible: btn.letter === ""; size: Theme.iconMd; tone: (btn.isArmed || btn.active) ? "white" : "dark" }
        Text {
            anchors.centerIn: parent
            visible: btn.letter !== ""
            text: btn.letter
            color: (btn.isArmed || btn.active) ? Theme.onAccent : Theme.textPrimary
            font.family: Theme.font; font.pixelSize: Theme.fontHeading; font.weight: Font.Medium
        }
    }
    Text {
        anchors.top: circle.bottom; anchors.topMargin: Theme.space2
        anchors.horizontalCenter: parent.horizontalCenter
        width: btn.width - 4
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: btn.isArmed ? I18n.tr("Confirm") : btn.label
        // On hover the label darkens: makes it clear which button will be touched.
        color: (btn.isArmed || btn.active || mouse.containsMouse) ? Theme.textPrimary : Theme.textSecondary
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        font.family: Theme.font; font.pixelSize: Theme.fontTiny; font.weight: (btn.isArmed || btn.active) ? Font.DemiBold : Font.Normal
    }

    Timer { id: disarm; interval: 3000; onTriggered: btn.selfArmed = false }

    MouseArea {
        id: mouse
        // The entire cell (circle + label) is clickable: easier to hit.
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function fire() {
            const now = Date.now()
            if (now - btn.lastFire < 280) return   // prevents double activation from fast clicks
            if (btn.confirm && !btn.selfArmed) { btn.selfArmed = true; disarm.restart(); return }
            btn.selfArmed = false; disarm.stop()
            btn.lastFire = now
            btn.activated()
        }
        // If dragged outside before releasing, it doesn't fire (allows changing mind).
        onClicked: if (containsMouse) fire()
    }
}
