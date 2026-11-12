// Weather.qml — current weather and a 3-day forecast from wttr.in, for the town in Config.qml.
// Refreshes every 30 minutes (and retries every 2 minutes if the network was down).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property bool loaded: false
  property bool failed: false

  property int tempC: 0
  property int feelsC: 0
  property string desc: ""
  property int code: 113
  property int humidity: 0
  property int windMph: 0
  property string windDir: ""
  property int pressure: 0
  property int uv: 0
  property real precipMm: 0
  property bool night: false
  property var forecast: []          // [{ label, maxC, minC, code }]

  readonly property string icon: iconFor(code, night)

  // weather code -> Material Design weather glyph
  function iconFor(c, isNight) {
    const n = Number(c)
    if (n === 113) return isNight ? "\udb81\udd94" : "\udb81\udd99"             // clear
    if (n === 116) return "\udb81\udd95"                                         // partly cloudy
    if ([143, 248, 260].includes(n)) return "\udb81\udd91"                       // fog
    if ([200, 386, 389, 392, 395].includes(n)) return "\udb81\udd93"             // thunder
    if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338,
         350, 362, 365, 368, 371, 374, 377].includes(n)) return "\udb81\udd98"  // snow / sleet
    if ([302, 308, 359].includes(n)) return "\udb81\udd96"                       // heavy rain
    if ([176, 263, 266, 281, 284, 293, 296, 299, 305, 311, 314,
         353, 356].includes(n)) return "\udb81\udd97"                            // rain
    return "\udb81\udd90"                                                        // cloudy / overcast
  }

  // "07:12 AM" -> minutes since midnight (-1 if it can't be read)
  function toMinutes(s) {
    const m = /(\d+):(\d+)\s*(AM|PM)/i.exec(s || "")
    if (!m) return -1
    let h = Number(m[1]) % 12
    if (m[3].toUpperCase() === "PM") h += 12
    return h * 60 + Number(m[2])
  }

  Process {
    id: fetch
    command: ["curl", "-sf", "--max-time", "10",
              "https://wttr.in/" + encodeURIComponent(Config.weatherTown) + "?format=j1"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text)
          const c = j.current_condition[0]

          root.tempC = Number(c.temp_C)
          root.feelsC = Number(c.FeelsLikeC)
          root.desc = c.weatherDesc[0].value
          root.code = Number(c.weatherCode)
          root.humidity = Number(c.humidity)
          root.windMph = Number(c.windspeedMiles)
          root.windDir = c.winddir16Point
          root.pressure = Number(c.pressure)
          root.uv = Number(c.uvIndex)
          root.precipMm = Number(c.precipMM)

          // day or night, from today's sunrise and sunset
          const now = new Date()
          const mins = now.getHours() * 60 + now.getMinutes()
          const astro = j.weather[0].astronomy[0]
          const sr = root.toMinutes(astro.sunrise)
          const ss = root.toMinutes(astro.sunset)
          root.night = (sr >= 0 && ss >= 0) ? (mins < sr || mins >= ss)
                                           : (now.getHours() >= 20 || now.getHours() < 7)

          // forecast: one icon per day, taken from the midday reading
          root.forecast = j.weather.slice(0, 3).map((d, i) => ({
            label: i === 0 ? "Today" : Qt.formatDate(new Date(d.date + "T12:00:00"), "dddd"),
            maxC: Number(d.maxtempC),
            minC: Number(d.mintempC),
            code: Number(d.hourly[4].weatherCode)
          }))

          root.loaded = true
          root.failed = false
        } catch (e) {
          root.failed = true       // offline or bad reply: keep whatever we had
        }
      }
    }
  }

  Timer {
    running: true
    interval: 1800000
    repeat: true
    triggeredOnStart: true
    onTriggered: fetch.running = true
  }
  Timer {
    running: root.failed
    interval: 120000
    repeat: true
    onTriggered: fetch.running = true
  }
}
