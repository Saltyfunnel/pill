import QtQuick

// Monochrome icon drawn with a Hack Nerd Font glyph (Font Awesome set), so it takes its
// colour from the theme (matugen) like any other text.
//   tone "dark"  → primary text colour (default)
//   tone "gray"  → secondary text colour
//   tone "white" → colour for use on top of an accent fill (Theme.onAccent)
// A caller can still override `color` directly.
Text {
    id: root
    property string name
    property string tone: "dark"
    property int size: 20

    readonly property var glyphs: ({
        "apps": "\uf00a", "arrow-right": "\uf061", "back": "\uf053", "battery": "\uf242",
        "bluetooth": "\uf293", "brush": "\uf1fc", "capture": "\uf030", "check": "\uf00c",
        "chevron": "\uf078", "chip": "\uf2db", "clock": "\uf017", "clipboard": "\uf0ea", "desktops": "\uf24d",
        "display": "\uf108", "dismiss": "\uf00d", "drop": "\uf043", "emoji": "\uf118",
        "ethernet": "\uf0e8", "external": "\uf08e", "eye": "\uf06e", "eye-off": "\uf070",
        "folder": "\uf07b", "gesture": "\uf256", "globe": "\uf0ac", "info": "\uf05a",
        "keyboard": "\uf11c", "lock": "\uf023", "logout": "\uf08b", "moon": "\uf186",
        "mouse": "\uf245", "music": "\uf001", "mute": "\uf026", "next": "\uf051",
        "note": "\uf249", "pause": "\uf04c", "pin": "\uf08d", "play": "\uf04b",
        "plus": "\uf067", "power": "\uf011", "prev": "\uf048", "record": "\uf111",
        "restart": "\uf021", "search": "\uf002", "settings": "\uf013", "stop": "\uf04d",
        "sun": "\uf185", "terminal": "\uf120", "usb": "\uf287", "update": "\uf0aa",
        "volume": "\uf028", "wifi": "\uf1eb"
    })

    width: size; height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: glyphs[name] ?? ""
    font.family: Theme.font
    font.pixelSize: Math.round(size * 0.85)
    color: tone === "white" ? Theme.onAccent : tone === "gray" ? Theme.textSecondary : Theme.textPrimary
}
