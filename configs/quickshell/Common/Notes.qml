pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "notes.js" as N

// Island notes, in ~/.config/island-shell/notes.json. Atomic writing (FileView writes
// a temp file and renames it); when editing, it saves 500ms after the last keystroke.
Singleton {
    id: root
    property var notes: []              // [{ id, text, updated }] (newest first)
    property bool loaded: false
    readonly property string dir: Quickshell.env("HOME") + "/.config/island-shell"

    function create() { const r = N.add(notes, Date.now()); notes = r.notes; return r.id }
    function get(id) { return notes.find(n => n.id === id) ?? null }
    function edit(id, text) { const next = N.update(notes, id, text, Date.now()); if (next !== notes) { notes = next; saveLater.restart() } }
    function remove(id) { notes = N.remove(notes, id); save() }
    // When closing the editor: removes empty notes and saves immediately.
    function flush() { notes = N.prune(notes); save() }
    function title(text) { return N.title(text) }
    function preview(text) { return N.preview(text) }

    function save() {
        saveLater.stop()
        if (!loaded) return             // never overwrite the file before reading it
        file.setText(N.serialize(N.prune(notes)))
    }
    Timer { id: saveLater; interval: 500; onTriggered: root.save() }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: file.path = root.dir + "/notes.json"
    }
    FileView {
        id: file
        blockLoading: false
        printErrors: false
        atomicWrites: true
        onLoaded: { root.notes = N.parse(text()); root.loaded = true }
        onLoadFailed: root.loaded = true    // doesn't exist yet
    }
}
