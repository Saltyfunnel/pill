// PerformancePanel.qml — the dashboard's Performance tab: ring gauges on top
// (temperatures sit under CPU and GPU), history charts underneath. Data comes from SystemStats.
import QtQuick

DashPanel {
  Column {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 18

    // ----- rings -----
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 56

      RingGauge {
        title: "CPU"
        detail: SystemStats.cpuTemp >= 0 ? SystemStats.cpuTemp + "°C" : ""
        valueText: Math.round(SystemStats.cpu) + "%"
        fraction: SystemStats.cpu / 100
      }
      RingGauge {
        title: "Memory"
        detail: SystemStats.ramUsedGb.toFixed(1) + " / " + SystemStats.ramTotalGb.toFixed(1) + " GB"
        valueText: Math.round(SystemStats.ram) + "%"
        fraction: SystemStats.ram / 100
      }
      RingGauge {
        visible: SystemStats.gpuLoad >= 0
        title: "GPU"
        detail: SystemStats.gpuTemp >= 0 ? SystemStats.gpuTemp + "°C" : ""
        valueText: SystemStats.gpuLoad + "%"
        fraction: SystemStats.gpuLoad / 100
      }
      RingGauge {
        visible: SystemStats.diskTotalGb > 0
        title: "Disk"
        detail: Math.round(SystemStats.diskUsedGb) + " / " + Math.round(SystemStats.diskTotalGb) + " GB"
        valueText: SystemStats.diskTotalGb > 0 ? Math.round(SystemStats.diskUsedGb / SystemStats.diskTotalGb * 100) + "%" : ""
        fraction: SystemStats.diskTotalGb > 0 ? SystemStats.diskUsedGb / SystemStats.diskTotalGb : 0
      }
      RingGauge {
        visible: SystemStats.hasBattery
        title: "Battery"
        detail: SystemStats.charging ? "charging" : ""
        valueText: Math.round(SystemStats.batteryPct) + "%"
        fraction: SystemStats.batteryPct / 100
      }
    }

    // ----- history charts + temperatures -----
    Row {
      width: parent.width
      spacing: 20

      Column {
        width: (parent.width - parent.spacing) / 2
        spacing: 6
        Text { text: "CPU history"; color: Colors.subtext; font.family: Theme.font; font.pixelSize: 12 }
        Sparkline { values: SystemStats.cpuHistory; lineColor: Colors.accent; height: 90 }
      }

      Column {
        width: (parent.width - parent.spacing) / 2
        spacing: 6
        Text { text: "Memory history"; color: Colors.subtext; font.family: Theme.font; font.pixelSize: 12 }
        Sparkline { values: SystemStats.ramHistory; lineColor: Colors.subtext; height: 90 }
      }
    }
  }
}
