import QtQuick
import "../Common"

// Tiny equalizer for the resting pill. Fed by Cava (8 bars, 0-100); four bars
// are shown, each the average of two neighbours. Grows in and out smoothly.
Item {
    id: root
    property bool on: false

    readonly property int barW: 3
    readonly property int gap: 3
    readonly property int maxH: 14
    readonly property int fullW: 4 * barW + 3 * gap

    width: on ? fullW : 0
    height: maxH
    visible: width > 0
    opacity: on ? 1 : 0
    clip: true
    Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

    Row {
        spacing: root.gap
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                // Average of two neighbouring cava bars (0-100)
                readonly property real level: ((Cava.bars[index * 2] || 0) + (Cava.bars[index * 2 + 1] || 0)) / 2
                width: root.barW
                radius: root.barW / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fill
                // With reduced motion the bars stay at a fixed, calm height
                height: Theme.reduceMotion ? 8 : Math.max(3, root.maxH * level / 100)
                Behavior on height { NumberAnimation { duration: Theme.reduceMotion ? 0 : 70 } }
            }
        }
    }
}
