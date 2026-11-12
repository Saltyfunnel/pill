// SystemStats.qml — CPU / memory / disk / temperatures / battery readings, shared by the dashboard.
// Samples every 2 seconds and keeps the last ~2 minutes of CPU and memory for the charts.
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Singleton {
  id: root

  property real cpu: 0
  property real ram: 0
  property real ramUsedGb: 0
  property real ramTotalGb: 0
  property real diskUsedGb: 0
  property real diskTotalGb: 0
  property int cpuTemp: -1          // -1 = no sensor, so that row stays hidden
  property int gpuTemp: -1
  property int gpuLoad: -1
  property real lastTotal: 0
  property real lastIdle: 0

  readonly property int historyLength: 60
  property var cpuHistory: []
  property var ramHistory: []

  readonly property bool hasBattery: UPower.displayDevice?.isLaptopBattery ?? false
  readonly property real batteryPct: (UPower.displayDevice?.percentage ?? 0) * 100
  readonly property bool charging: UPower.displayDevice?.state === UPowerDeviceState.Charging

  FileView {
    id: statFile
    path: "/proc/stat"
    onLoaded: {
      const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
      const idle = f[3] + f[4]
      const total = f.slice(0, 8).reduce((a, b) => a + b, 0)
      if (root.lastTotal > 0) {
        const dt = total - root.lastTotal
        const di = idle - root.lastIdle
        root.cpu = dt > 0 ? 100 * (1 - di / dt) : 0
        root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-root.historyLength)
      }
      root.lastTotal = total
      root.lastIdle = idle
    }
  }

  FileView {
    id: memFile
    path: "/proc/meminfo"
    onLoaded: {
      const t = text()
      const total = Number(t.match(/MemTotal:\s+(\d+)/)[1])
      const avail = Number(t.match(/MemAvailable:\s+(\d+)/)[1])
      root.ram = 100 * (1 - avail / total)
      root.ramTotalGb = total / 1048576
      root.ramUsedGb = (total - avail) / 1048576
      root.ramHistory = root.ramHistory.concat([root.ram]).slice(-root.historyLength)
    }
  }

  // Sensors are found by NAME, not number (hwmon numbers differ between machines)
  Process {
    id: slowProc
    command: ["sh", "-c",
      "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); case $n in k10temp|coretemp|zenpower) echo cpu $(cat $d/temp1_input);; amdgpu|nouveau) echo gpu $(cat $d/temp1_input);; esac; done; "
      + "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r $f ] && echo gpuload $(cat $f) && break; done; "
      + "set -- $(df -B1 --output=used,size / | tail -1); echo disk $1 $2"]
    stdout: StdioCollector {
      onStreamFinished: {
        let c = -1, g = -1, gl = -1
        for (const line of text.split("\n")) {
          const p = line.trim().split(" ")
          if (p[0] === "cpu") c = Math.round(Number(p[1]) / 1000)
          if (p[0] === "gpu") g = Math.round(Number(p[1]) / 1000)
          if (p[0] === "gpuload") gl = Number(p[1])
          if (p[0] === "disk") {
            root.diskUsedGb = Number(p[1]) / 1e9
            root.diskTotalGb = Number(p[2]) / 1e9
          }
        }
        root.cpuTemp = c
        root.gpuTemp = g
        root.gpuLoad = gl
      }
    }
  }

  Timer {
    running: true
    interval: 2000
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      statFile.reload()
      memFile.reload()
      slowProc.running = true
    }
  }
}
