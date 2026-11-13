pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Visual tokens. Claro (blanco, estilo iOS) u oscuro (casi negro, estilo
// Apple). Todo color de la shell sale de acá; los
// cambios de tema los animan los consumidores (~250 ms).
// Sin dependencias a otros singletons: DisplayState empuja `dark` acá.
Singleton {
    id: t
    readonly property bool dark: true
    property bool reduceMotion: false       // accessibility: no UI transitions
    property bool highContrast: false

    // ---- matugen colours ----
    // Read live from the generated Colors.qml in the shell root (the file matugen writes
    // from your wallpaper). Everything below is derived from those six colours.
    property color cBase:   "#131313"
    property color cCard:   "#1f1f1f"
    property color cText:   "#e2e2e2"
    property color cSub:    "#c6c6c6"
    property color cAccent: "#ffffff"
    property color cTrack:  "#353535"

    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    FileView {
        id: colorsFile
        path: Quickshell.shellPath("Colors.qml")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const txt = text()
            const re = /(\w+)\s*:\s*"(#[0-9a-fA-F]{6,8})"/g
            let m
            while ((m = re.exec(txt)) !== null) {
                if (m[1] === "surface") t.cBase = m[2]
                else if (m[1] === "card") t.cCard = m[2]
                else if (m[1] === "text") t.cText = m[2]
                else if (m[1] === "subtext") t.cSub = m[2]
                else if (m[1] === "accent") t.cAccent = m[2]
                else if (m[1] === "track") t.cTrack = m[2]
            }
        }
    }

    // Surfaces
    readonly property color cardSolid: cCard
    readonly property color card: cardSolid                             // island, panels
    readonly property color field: mix(cCard, cText, 0.07)              // fields and rows
    readonly property color surface: cardSolid
    readonly property color surfaceBorder: "transparent"
    readonly property color raised: mix(cCard, cText, 0.12)
    readonly property color subtle: mix(cCard, cText, 0.035)
    readonly property color hover: mix(cCard, cText, 0.14)
    readonly property color track: cTrack
    readonly property color dot: mix(cSub, cCard, 0.35)
    readonly property color scrim: Qt.rgba(cBase.r, cBase.g, cBase.b, 0.5)
    readonly property color wallFallback: cBase
    // Text and accent
    readonly property color textPrimary: cText
    readonly property color textSecondary: highContrast ? cText : cSub
    readonly property color text: textPrimary
    readonly property color textDim: textSecondary
    readonly property color fill: cAccent                               // strong fill (active)
    readonly property color fillHover: mix(cAccent, cCard, 0.2)
    readonly property color onAccent: lum(cAccent) > 0.5 ? cBase : cText  // text/icon on `fill`
    readonly property color onFill: onAccent
    readonly property color danger: "#FF6961"
    readonly property color recording: "#FF453A"
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)

    // Radios por tipo de componente
    readonly property int radiusCard: 28
    readonly property int radiusField: 12
    readonly property int radiusChip: 16
    readonly property int radiusPill: 20
    readonly property int radiusCircle: 999

    // Escala de espaciado (múltiplos de 4)
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int space5: 20
    readonly property int space6: 24
    readonly property int space8: 32
    readonly property int padPanel: 20          // margen interno de paneles de la isla
    readonly property int padSection: 18        // margen de tarjetas en Ajustes
    readonly property int padRow: 16            // filas de ajustes / switches

    // Tipografía
    readonly property string font: "Hack Nerd Font"
    readonly property string emojiFont: "Noto Color Emoji"   // noto-fonts-emoji (install.sh); solo en el selector de emojis
    readonly property int fontTitle: 26
    readonly property int fontHeading: 17
    readonly property int fontBody: 14
    readonly property int fontCaption: 12
    readonly property int fontTiny: 11
    readonly property real lineBody: 1.25
    readonly property real lineCaption: 1.15

    // Iconos
    readonly property int iconSm: 16
    readonly property int iconMd: 22
    readonly property int iconLg: 28
    readonly property int hitMin: 44           // área clicable mínima recomendada

    // Controles equivalentes
    readonly property int controlH: 32
    readonly property int menuBtnSize: 80
    readonly property int menuBtnCircle: 52

    // Animaciones centralizadas
    readonly property int durFast: reduceMotion ? 0 : 160
    readonly property int durHover: 300          // pausa antes de mostrar detalles al pasar el mouse
    readonly property int durNormal: reduceMotion ? 0 : 360
    readonly property int durOpen: reduceMotion ? 0 : 360
    readonly property int durClose: reduceMotion ? 0 : 280
    readonly property int hideDelay: 900   // margen para salir un instante con el puntero sin que la isla se esconda
    readonly property int easeOpen: Easing.OutBack
    readonly property int easeClose: Easing.OutCubic
    readonly property int easeInOut: Easing.InOutCubic
    readonly property real overshootOpen: 0.45
    readonly property real overshootClose: 0.35

    // Tokens de la ronda 2 (aplicados en Ajustes / isla / tipografía compacta)
    readonly property int sidebarW: 200       // barra lateral de Ajustes (ronda 2 P2)
    readonly property color knob: "#FFFFFF"
    readonly property int radiusSection: 20     // tarjetas de sección en Ajustes
    readonly property int fontClock: 15         // reloj de la isla compacta
    readonly property int fontLabel: 13         // etiquetas de filas / metadatos
    readonly property int rowH: 56              // fila de ajustes con control a la derecha
    readonly property int fieldH: 40            // campos y desplegables
    readonly property int durColor: reduceMotion ? 0 : 250   // cambio de tema / color de superficie
    readonly property int durMicro: reduceMotion ? 0 : 120   // microfeedback (hover corto)
    readonly property int durStagger: reduceMotion ? 0 : 45  // escalonado de entrada del menú

    readonly property int compactW: 96
    readonly property int compactH: 36
    readonly property int expandedW: 400
    readonly property int maxExpandedH: 900
    readonly property int topMargin: 8          // separación de la isla con el borde superior
    readonly property int compactPadX: 11       // margen lateral de la isla compacta (proporción previa)
}
