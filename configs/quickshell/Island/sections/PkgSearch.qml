import QtQuick
import Quickshell
import Quickshell.Io

// Searches the official pacman repos for packages that are NOT installed yet, and installs
// one in a kitty window (sudo asks for the password there). Non-visual helper, used by the
// island search bar and the launcher.
//   query    text to search (2+ letters; the search starts after a short pause in typing)
//   limit    max number of results
//   results  [{ repo, name, ver, desc, icon }], best name matches first
//            (icon = file:// path of an icon named like the package, found in the GTK icon
//            theme or hicolor; "" until found or when there is none)
Item {
    id: root
    visible: false
    property string query: ""
    property int limit: 8
    property var results: []
    property bool pending: false         // a newer search is waiting for the running one
    property bool iconPending: false

    // The text actually searched: regex characters pacman would choke on are dropped.
    readonly property string clean: query.trim().replace(/[\[\]\(\)\{\}\|\^\$\*\?\\]/g, "").replace(/^-+/, "")

    function reset() { debounce.stop(); results = []; pending = false }

    function install(p) {
        if (!p) return
        Quickshell.execDetached(["kitty", "-e", "sh", "-c",
            'sudo pacman -S --needed "$1"; printf "\\nPress Enter to close..."; read _', "sh", p.name])
    }

    function run() {
        if (clean.length < 2) return
        if (proc.running) { pending = true; return }
        proc.command = ["sh", "-c", 'pacman -Ss "$1" 2>/dev/null', "sh", clean]
        proc.running = true
    }

    // "repo/name version [group] [installed]" followed by an indented description line.
    function parse(text, q) {
        const out = []
        let cur = null
        for (const line of text.split("\n")) {
            if (line === "") continue
            if (line[0] !== " " && line[0] !== "\t") {
                const m = line.match(/^(\S+)\/(\S+)\s+(\S+)(.*)$/)
                cur = m && m[4].indexOf("[installed") < 0 ? { repo: m[1], name: m[2], ver: m[3], desc: "", icon: "", i: out.length } : null
                if (cur) out.push(cur)
            } else if (cur) {
                cur.desc = line.trim()
            }
        }
        const ql = q.toLowerCase()
        const score = p => {
            const n = p.name.toLowerCase()
            return n === ql ? 0 : n.indexOf(ql) === 0 ? 1 : n.indexOf(ql) > 0 ? 2 : 3
        }
        out.sort((a, b) => (score(a) - score(b)) || (a.i - b.i))
        return out.slice(0, limit)
    }

    // Qt's own icon lookup only knows the Qt icon theme (usually plain hicolor), so icons of
    // packages that are not installed are searched on disk instead: GTK icon theme first
    // (the one set with gsettings), then hicolor. Prints "name path" for every hit.
    readonly property string iconScript: `
t=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
[ -n "$t" ] || t=Colloid-Dynamic-Dark
for n in "$@"; do
  for b in "$HOME/.local/share/icons/$t" "/usr/share/icons/$t" /usr/share/icons/hicolor; do
    for s in apps/scalable scalable/apps apps/48 48x48/apps apps/64 apps/22 apps/32 apps/128 apps/256 256x256/apps; do
      for e in svg png; do
        f="$b/$s/$n.$e"
        [ -f "$f" ] && { echo "$n $f"; break 3; }
      done
    done
  done
done`
    function findIcons() {
        if (results.length === 0) return
        if (iconProc.running) { iconPending = true; return }
        iconProc.command = ["sh", "-c", iconScript, "sh"].concat(results.map(p => p.name))
        iconProc.running = true
    }

    onQueryChanged: {
        if (clean.length < 2) { debounce.stop(); results = []; return }
        debounce.restart()
    }

    Timer { id: debounce; interval: 350; onTriggered: root.run() }
    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: { root.results = root.parse(text, root.clean); root.findIcons() } }
        onExited: if (root.pending) { root.pending = false; root.run() }
    }
    Process {
        id: iconProc
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                for (const l of text.split("\n")) {
                    const i = l.indexOf(" ")
                    if (i > 0) map[l.slice(0, i)] = "file://" + l.slice(i + 1)
                }
                root.results = root.results.map(p => Object.assign({}, p, { icon: map[p.name] || "" }))
            }
        }
        onExited: if (root.iconPending) { root.iconPending = false; root.findIcons() }
    }
}
