pragma Singleton
import QtQuick
import Quickshell
import "i18n.js" as D

// Interface language (Spanish / English). Usage: I18n.tr("Spanish text", arg1, ...).
// Since `tr` reads `lang`, bindings reevaluate automatically when the language changes.
// User content (notes, shortcut names, window titles...) does not pass through here.
Singleton {
    id: root
    readonly property string lang: DisplayState.language
    readonly property var languages: D.languages
    readonly property var locale: Qt.locale(D.localeName(lang))

    function tr(s) { return D.translate(root.lang, s, Array.prototype.slice.call(arguments, 1)) }
    // "Thursday, October 15" / "Thursday, October 15"
    function longDate(d) {
        const t = d.toLocaleDateString(root.locale, root.lang === "en" ? "dddd, MMMM d" : "dddd d 'de' MMMM")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }
}
