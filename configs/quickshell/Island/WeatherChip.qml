import QtQuick
import Quickshell.Io
import "../Common"

// Compact weather readout for the expanded island header (data from wttr.in).
// Self-contained: no singleton or qmldir entry needed.
Item {
    id: root

    // Leave empty to auto-detect by IP, or set a town, e.g. "Edinburgh".
    property string town: ""

    property string temp: ""
    property string desc: ""
    property string icon: ""
    readonly property bool ready: temp !== ""
    readonly property string url: "https://wttr.in/" + encodeURIComponent(town) + "?format=j1"

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: ready

    // Map wttr.in weather codes to an emoji.
    function iconFor(code) {
        if (code === 113) return "☀️"
        if (code === 116) return "⛅"
        if (code === 119 || code === 122) return "☁️"
        if ([143, 248, 260].indexOf(code) >= 0) return "🌫️"
        if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return "⛈️"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(code) >= 0) return "❄️"
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(code) >= 0) return "🌨️"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(code) >= 0) return "🌧️"
        return "🌡️"
    }

    function parse(raw) {
        try {
            const c = JSON.parse(raw).current_condition[0]
            temp = c.temp_C + "°"
            desc = c.weatherDesc[0].value
            icon = iconFor(parseInt(c.weatherCode))
        } catch (e) {
            // Keep the previous values if the request or parsing fails.
        }
    }

    Process {
        id: fetcher
        command: ["curl", "-sf", "--max-time", "10", root.url]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // Refresh every 30 min; retry every minute until the first success.
    Timer {
        interval: root.ready ? 1800000 : 60000
        running: true
        repeat: true
        onTriggered: if (!fetcher.running) fetcher.running = true
    }

    Row {
        id: row
        spacing: Theme.space4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.pixelSize: 26
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: root.temp
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Medium
            }
            Text {
                text: root.desc
                width: Math.min(implicitWidth, 130)
                elide: Text.ElideRight
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
