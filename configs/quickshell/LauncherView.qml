// LauncherView.qml — minimal app launcher, hosted inside the morphing pill.
//   Type to search. Up / Down to move, Enter to launch, Esc to close.
//   Ctrl+H hides the selected app, Ctrl+R brings all hidden apps back.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  signal closeRequested()
  signal launched(string name)

  // most-recent-first list, owned by shell.qml so it outlives this view
  property var recentApps: []

  implicitWidth: 360
  implicitHeight: 332

  property string query: ""

  // Hidden apps persist on disk
  property var hiddenApps: []
  property string hiddenConfigPath: Quickshell.env("HOME") + "/.cache/quickshell_hidden_apps.json"

  Component.onCompleted: {
    hiddenLoadProc.running = true
    Qt.callLater(searchField.forceActiveFocus)
  }

  Process {
    id: hiddenLoadProc
    command: ["sh", "-c", "cat " + root.hiddenConfigPath + " 2>/dev/null || echo '[]'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        try {
          const parsed = JSON.parse(data.trim())
          if (Array.isArray(parsed)) root.hiddenApps = parsed
        } catch (e) {
          root.hiddenApps = []
        }
      }
    }
  }

  function saveHiddenApps() {
    const jsonStr = JSON.stringify(root.hiddenApps)
    hiddenSaveProc.command = ["sh", "-c", "echo '" + jsonStr + "' > " + root.hiddenConfigPath]
    hiddenSaveProc.running = true
  }

  Process {
    id: hiddenSaveProc
    running: false
  }

  // Installed apps that match the search, hidden apps filtered, MRU first
  property var results: {
    const q = root.query.trim().toLowerCase()
    const hidden = root.hiddenApps
    const recents = root.recentApps
    const apps = DesktopEntries.applications.values
    const out = []

    for (let i = 0; i < apps.length; i++) {
      const e = apps[i]
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
      if (q === "") {
        const aIndex = recents.indexOf(a.name)
        const bIndex = recents.indexOf(b.name)
        if (aIndex !== -1 && bIndex !== -1) return aIndex - bIndex
        if (aIndex !== -1) return -1
        if (bIndex !== -1) return 1
      }

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

    // Run first, then close: closing unloads this view
    entry.execute()
    root.launched(appName)
    root.closeRequested()
  }

  function hideCurrentApp() {
    if (list.currentIndex < 0 || list.currentIndex >= root.results.length) return
    const appName = root.results[list.currentIndex].name

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

  Column {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    // ---------- search ----------
    Rectangle {
      width: parent.width
      height: 38
      radius: 19
      color: Colors.card
      border.color: searchField.activeFocus ? Colors.accent : "transparent"
      border.width: 1

      Row {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        Text {
          text: "󰍉"
          color: Colors.accent
          font.family: "Hack Nerd Font"
          font.pixelSize: 15
          anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
          id: searchField
          width: parent.width - 30
          height: parent.height
          verticalAlignment: TextInput.AlignVCenter
          color: Colors.text
          font.family: "Hack Nerd Font"
          font.pixelSize: 13
          clip: true

          onTextChanged: {
            root.query = text
            list.currentIndex = 0
          }
          Keys.onEscapePressed: root.closeRequested()
          Keys.onDownPressed: list.incrementCurrentIndex()
          Keys.onUpPressed: list.decrementCurrentIndex()
          Keys.onReturnPressed: root.launch(list.currentIndex)
          Keys.onEnterPressed: root.launch(list.currentIndex)
          Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_H) {
              root.hideCurrentApp()
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_R) {
              root.resetHiddenApps()
              event.accepted = true
            }
          }

          Text {
            text: "Search"
            color: Colors.subtext
            opacity: 0.5
            font.family: "Hack Nerd Font"
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            visible: searchField.text === ""
          }
        }
      }
    }

    // ---------- results ----------
    ListView {
      id: list
      width: parent.width
      height: parent.height - 38 - 10
      clip: true
      model: root.results
      currentIndex: 0
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: 0

      delegate: Rectangle {
        required property var modelData
        required property int index

        width: list.width
        height: 38
        radius: 19
        color: list.currentIndex === index ? Qt.alpha(Colors.accent, 0.18) : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        Row {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 12

          Image {
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
            sourceSize: Qt.size(22, 22)
            fillMode: Image.PreserveAspectFit
          }

          Text {
            text: modelData.name
            color: list.currentIndex === index ? Colors.accent : Colors.text
            font.family: "Hack Nerd Font"
            font.pixelSize: 13
            elide: Text.ElideRight
            width: parent.width - 34
            anchors.verticalCenter: parent.verticalCenter
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
