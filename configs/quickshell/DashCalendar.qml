// DashCalendar.qml — month calendar (weeks start on Monday). Arrows change month.
import Quickshell
import QtQuick

DashPanel {
  id: root

  property date shown: new Date()           // the month being displayed
  function reset() { shown = new Date() }

  SystemClock { id: clk; precision: SystemClock.Minutes }

  readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                     "July", "August", "September", "October", "November", "December"]
  readonly property var dayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

  // 42 cells (6 weeks), starting on the Monday on or before the 1st
  property var cells: {
    const y = shown.getFullYear()
    const m = shown.getMonth()
    const offset = (new Date(y, m, 1).getDay() + 6) % 7
    const t = clk.date
    const out = []
    for (let i = 0; i < 42; i++) {
      const d = new Date(y, m, 1 - offset + i)
      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === m,
        today: d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate()
      })
    }
    return out
  }

  function step(n) { shown = new Date(shown.getFullYear(), shown.getMonth() + n, 1) }

  Column {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 4

    readonly property real cellW: width / 7

    // month + arrows
    Item {
      width: parent.width
      height: 26

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "‹"
        color: Colors.accent
        font.pixelSize: 20
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.step(-1) }
      }
      Text {
        anchors.centerIn: parent
        text: root.monthNames[root.shown.getMonth()] + " " + root.shown.getFullYear()
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: 13
        font.bold: true
      }
      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        color: Colors.accent
        font.pixelSize: 20
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.step(1) }
      }
    }

    // weekday names
    Row {
      Repeater {
        model: root.dayNames
        Text {
          required property string modelData
          width: parent.parent.cellW
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 11
        }
      }
    }

    // the days
    Grid {
      columns: 7
      Repeater {
        model: root.cells
        Item {
          required property var modelData
          width: parent.parent.cellW
          height: 28

          Rectangle {
            anchors.centerIn: parent
            width: 24
            height: 24
            radius: 12
            color: modelData.today ? Colors.accent : "transparent"
          }
          Text {
            anchors.centerIn: parent
            text: modelData.day
            color: modelData.today ? Colors.surface : (modelData.inMonth ? Colors.text : Colors.subtext)
            opacity: modelData.inMonth || modelData.today ? 1 : 0.45
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: modelData.today
          }
        }
      }
    }
  }
}
