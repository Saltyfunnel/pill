pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property int bars: 30
  property bool active: false
  property var values: new Array(bars).fill(0)

  onActiveChanged: if (!active) values = new Array(bars).fill(0)

  Process {
    running: root.active
    command: ["sh", "-c",
      "printf '[general]\\nbars=" + root.bars + "\\nframerate=30\\n" +
      "[input]\\nmethod=pipewire\\nsource=auto\\n" +
      "[output]\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\n" +
      "ascii_max_range=100\\nbar_delimiter=59\\nframe_delimiter=10\\n' > /tmp/qs-cava.conf && exec cava -p /tmp/qs-cava.conf"]

    stdout: SplitParser {
      onRead: line => {
        const p = line.split(";")
        const v = []
        for (let i = 0; i < root.bars; i++)
          v.push((parseInt(p[i]) || 0) / 100)
        root.values = v
      }
    }
  }
}
