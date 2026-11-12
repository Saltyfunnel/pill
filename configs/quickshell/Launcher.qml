import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: root

  property string popupName: "launcher"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card

  property string query: ""
  property string wallpaperPath: ""

  // Dynamic lists tracked during the session
  property var hiddenApps: []
  property var recentApps: [] // Most recently launched apps appear first

  // Persistent storage path for hidden apps
  property string hiddenConfigPath: Quickshell.env("HOME") + "/.cache/quickshell_hidden_apps.json"

  // Load hidden apps from disk on startup
  Component.onCompleted: {
    hiddenLoadProc.running = true
  }

  Process {
    id: hiddenLoadProc
    command: ["sh", "-c", "cat " + root.hiddenConfigPath + " 2>/dev/null || echo '[]'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        try {
          const parsed = JSON.parse(data.trim())
          if (Array.isArray(parsed)) {
            root.hiddenApps = parsed
          }
        } catch (e) {
          root.hiddenApps = []
        }
      }
    }
  }

  // Save hidden apps to disk whenever the list changes
  function saveHiddenApps() {
    const jsonStr = JSON.stringify(root.hiddenApps)
    hiddenSaveProc.command = ["sh", "-c", "echo '" + jsonStr + "' > " + root.hiddenConfigPath]
    hiddenSaveProc.running = true
  }

  Process {
    id: hiddenSaveProc
    running: false
  }

  // Automatically fetch the active wallpaper path from common config/cache locations
  Process {
    id: wallpaperProc
    command: ["sh", "-c", "if [ -f \"$HOME/.config/hypr/wallpaper.png\" ]; then echo -n \"$HOME/.config/hypr/wallpaper.png\"; elif [ -f \"$HOME/.cache/current_wallpaper\" ]; then cat \"$HOME/.cache/current_wallpaper\"; else echo -n \"$HOME/.config/hypr/hyprpaper.conf\"; fi"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const cleaned = data.trim()
        if (cleaned !== "") {
          root.wallpaperPath = "file://" + cleaned
        }
      }
    }
  }

  // Installed apps that match search, filtering hidden apps and sorting MRU first
  property var results: {
    const q = root.query.trim().toLowerCase()
    const hidden = root.hiddenApps
    const recents = root.recentApps
    const list = DesktopEntries.applications.values
    const out = []

    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (e.noDisplay) continue

      const appName = (e.name ?? "").toLowerCase()
      const fileName = (e.id ?? e.desktopFilePath ?? "").toLowerCase()

      let isHidden = false
      for (let h = 0; h < hidden.length; h++) {
        const hid = hidden[h].toLowerCase()
        if (fileName.includes(hid) || appName === hid) {
          isHidden = true
          break
        }
      }
      if (isHidden) continue

      const generic = (e.genericName ?? "").toLowerCase()
      if (q === "" || appName.includes(q) || generic.includes(q)) out.push(e)
    }

    out.sort((a, b) => {
      // If there's no active search query, sort by Most Recently Used (MRU) first
      if (q === "") {
        const aIndex = recents.indexOf(a.name)
        const bIndex = recents.indexOf(b.name)
        if (aIndex !== -1 && bIndex !== -1) return aIndex - bIndex
        if (aIndex !== -1) return -1
        if (bIndex !== -1) return 1
      }

      // Standard prefix & alphabetical fallback sorting
      const as = q !== "" && a.name.toLowerCase().startsWith(q)
      const bs = q !== "" && b.name.toLowerCase().startsWith(q)
      if (as !== bs) return as ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    return out
  }

  function launch(i) {
    if (i < 0 || i >= root.results.length) return
    const entry = root.results[i]
    const appName = entry.name

    // Update recent apps list (bubble launched app to the front)
    let updatedRecents = [appName, ...root.recentApps.filter(name => name !== appName)]
    if (updatedRecents.length > 20) updatedRecents.pop() // keep last 20
    root.recentApps = updatedRecents

    root.toggle(root.popupName)
    entry.execute()
  }

  function hideCurrentApp() {
    if (list.currentIndex < 0 || list.currentIndex >= root.results.length) return
    const entry = root.results[list.currentIndex]
    const appName = entry.name

    if (!root.hiddenApps.includes(appName)) {
      root.hiddenApps = [...root.hiddenApps, appName]
      saveHiddenApps()
      list.currentIndex = Math.max(0, list.currentIndex - 1)
    }
  }

  function resetHiddenApps() {
    root.hiddenApps = []
    saveHiddenApps()
    list.currentIndex = 0
  }

  OverlayCard {
    id: card
    shown: root.openPopup === root.popupName
    cardWidth: 900
    cardHeight: 480
    onDismissed: root.toggle(root.popupName)

    onVisibleChanged: {
      if (visible) {
        searchField.text = ""
        root.query = ""
        list.currentIndex = 0
        searchField.forceActiveFocus()
        wallpaperProc.running = true
      }
    }

    Row {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 16

      // ==========================================
      // LEFT PANE: Mini Wallpaper Preview & Details (52%)
      // ==========================================
      Rectangle {
        width: Math.floor(parent.width * 0.52) - 8
        height: parent.height
        radius: 16
        clip: true
        color: Qt.alpha(Colors.card, 0.25)
        border.color: Qt.alpha(Colors.text, 0.08)
        border.width: 1

        // Actual Mini Wallpaper Image Copied Inside
        Image {
          id: miniWallpaper
          anchors.fill: parent
          source: root.wallpaperPath
          fillMode: Image.PreserveAspectCrop
          opacity: 0.65
        }

        // Much Lighter Dark Overlay Tint (reduced to 0.15 for high clarity)
        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, 0.15)
        }

        // Active Application Metadata Display
        Item {
          anchors.fill: parent
          anchors.margins: 16

          property var activeEntry: root.results.length > 0 && list.currentIndex >= 0 && list.currentIndex < root.results.length
            ? root.results[list.currentIndex]
            : null

          // Centered Content (Icon, Title, Description)
          Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 12
            visible: parent.activeEntry !== null

            Image {
              width: 76
              height: 76
              anchors.horizontalCenter: parent.horizontalCenter
              source: parent.parent.activeEntry ? Quickshell.iconPath(parent.parent.activeEntry.icon, "application-x-executable") : ""
              sourceSize: Qt.size(76, 76)
              fillMode: Image.PreserveAspectFit
            }

            Column {
              width: parent.width
              spacing: 4

              Text {
                text: parent.parent.parent.activeEntry ? parent.parent.parent.activeEntry.name : ""
                color: Colors.text
                font.family: "Hack Nerd Font"
                font.pixelSize: 18
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                elide: Text.ElideRight
              }

              Text {
                text: parent.parent.parent.activeEntry ? (parent.parent.parent.activeEntry.comment ?? parent.parent.parent.activeEntry.genericName ?? "Application") : ""
                color: Colors.subtext
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                opacity: 0.85
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }
          }
        }

        // Bottom Action Row (Pinned to bottom of the left panel)
        Row {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottomMargin: 16
          spacing: 8

          // Hide App Button
          Rectangle {
            height: 28
            width: 100
            radius: 8
            color: hideMouse.containsMouse ? Qt.alpha(Colors.accent, 0.25) : Qt.alpha(Colors.card, 0.4)
            border.color: Qt.alpha(Colors.accent, 0.4)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
              anchors.centerIn: parent
              spacing: 5
              Text {
                text: "󰜺"
                color: Colors.accent
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
              }
              Text {
                text: "Hide"
                color: Colors.accent
                font.family: "Hack Nerd Font"
                font.pixelSize: 11
                font.weight: Font.Bold
              }
            }

            MouseArea {
              id: hideMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.hideCurrentApp()
            }
          }

          // Reset Hidden Apps Button (Only visible if apps are currently hidden)
          Rectangle {
            height: 28
            width: 100
            radius: 8
            visible: root.hiddenApps.length > 0
            color: resetMouse.containsMouse ? Qt.alpha(Colors.text, 0.2) : Qt.alpha(Colors.card, 0.4)
            border.color: Qt.alpha(Colors.text, 0.3)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
              anchors.centerIn: parent
              spacing: 5
              Text {
                text: "󰃨"
                color: Colors.text
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
              }
              Text {
                text: "Reset (" + root.hiddenApps.length + ")"
                color: Colors.text
                font.family: "Hack Nerd Font"
                font.pixelSize: 11
                font.weight: Font.Bold
              }
            }

            MouseArea {
              id: resetMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.resetHiddenApps()
            }
          }
        }
      }

      // ==========================================
      // RIGHT PANE: Search Bar & Application List (48%)
      // ==========================================
      Column {
        width: Math.floor(parent.width * 0.48) - 8
        height: parent.height
        spacing: 14

        // Search Header Field
        Rectangle {
          width: parent.width
          height: 48
          radius: 12
          color: Qt.alpha(Colors.card, 0.3)
          border.color: searchField.activeFocus ? Colors.accent : Qt.alpha(Colors.text, 0.1)
          border.width: searchField.activeFocus ? 2 : 1

          Behavior on border.color { ColorAnimation { duration: 120 } }

          Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
              text: "󰍉"
              color: Colors.accent
              font.family: "Hack Nerd Font"
              font.pixelSize: 18
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: searchField
              width: parent.width - 40
              height: parent.height
              verticalAlignment: TextInput.AlignVCenter
              color: Colors.text
              font.family: "Hack Nerd Font"
              font.pixelSize: 15
              clip: true

              onTextChanged: {
                root.query = text
                list.currentIndex = 0
              }
              Keys.onEscapePressed: root.toggle(root.popupName)
              Keys.onDownPressed: list.incrementCurrentIndex()
              Keys.onUpPressed: list.decrementCurrentIndex()
              Keys.onReturnPressed: root.launch(list.currentIndex)
              Keys.onEnterPressed: root.launch(list.currentIndex)

              Text {
                text: "Search apps..."
                color: Colors.subtext
                opacity: 0.4
                font.family: "Hack Nerd Font"
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text === ""
              }
            }
          }
        }

        // App List
        ListView {
          id: list
          width: parent.width
          height: parent.height - 48 - 14
          clip: true
          model: root.results
          currentIndex: 0
          spacing: 4
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: list.width
            height: 46
            radius: 10
            color: list.currentIndex === index ? Qt.alpha(Colors.accent, 0.22) : "transparent"
            border.color: list.currentIndex === index ? Qt.alpha(Colors.accent, 0.4) : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              Image {
                width: 26
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                sourceSize: Qt.size(26, 26)
                fillMode: Image.PreserveAspectFit
              }

              Text {
                text: modelData.name
                color: list.currentIndex === index ? Colors.accent : Colors.text
                font.family: "Hack Nerd Font"
                font.pixelSize: 14
                font.weight: list.currentIndex === index ? Font.Bold : Font.Normal
                elide: Text.ElideRight
                width: parent.width - 70
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "󰌑"
                color: Colors.accent
                font.family: "Hack Nerd Font"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: list.currentIndex === index
                opacity: 0.7
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: list.currentIndex = index
              onClicked: root.launch(index)
            }
          }
        }
      }
    }
  }
}
