pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import ".."

// Power and Settings. Logout / Reboot / Power off require confirmation with a SINGLE
// state machine (Common/confirm.js): only one can be armed; the second click
// executes once and subsequent clicks are ignored for 2s.
Row {
    id: root
    signal done()

    readonly property var commands: ({
        logout: "hyprctl dispatch 'hl.dsp.exit()'",
        reboot: "systemctl reboot",
        poweroff: "systemctl poweroff"
    })
    property var st: Confirm.initial()
    readonly property string armed: st.armed

    function press(id) {
        const r = Confirm.press(st, id, Date.now(), 3000, 2000)
        st = r.state
        if (r.state.armed !== "") disarm.restart()
        if (r.run !== "") { Quickshell.execDetached(["sh", "-c", commands[r.run]]); root.done() }
    }
    function reset() { disarm.stop(); st = Confirm.disarm(st) }
    Timer { id: disarm; interval: 3000; onTriggered: root.st = Confirm.disarm(root.st) }

    MenuButton { icon: "logout"; label: I18n.tr("Log out"); armed: root.armed === "logout"; onActivated: root.press("logout") }
    MenuButton { icon: "restart"; label: I18n.tr("Reboot"); armed: root.armed === "reboot"; onActivated: root.press("reboot") }
    MenuButton { icon: "power"; label: I18n.tr("Shut down"); armed: root.armed === "poweroff"; onActivated: root.press("poweroff") }
}
