import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "io.github.taiku666.net-speed"

  readonly property string ifaceSetting: String(setting("interface", "auto"))
  readonly property bool useBits: String(setting("unit", "bytes")) === "bits"
  readonly property int pollIntervalMs: Math.max(500, Number(setting("pollIntervalMs", 1000)))

  property string activeIface: ""
  property real downRate: 0
  property real upRate: 0

  // Last counter sample: rx/tx bytes plus the time it was taken.
  property real lastRx: -1
  property real lastTx: -1
  property real lastTime: 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Interface carrying the default route, read from /proc/net/route
  // (destination 00000000). The lowest metric wins when there are several.
  function defaultIface() {
    routeFile.reload()
    var lines = routeFile.text().split("\n")
    var best = ""
    var bestMetric = Infinity
    for (var i = 1; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f.length < 7 || f[1] !== "00000000") continue
      var metric = Number(f[6])
      if (metric < bestMetric) {
        bestMetric = metric
        best = f[0]
      }
    }
    return best
  }

  // Sum rx/tx bytes from /proc/net/dev for one interface, or every
  // interface except lo when iface is "all".
  function readCounters(iface) {
    devFile.reload()
    var lines = devFile.text().split("\n")
    var rx = 0, tx = 0, found = false
    for (var i = 2; i < lines.length; i++) {
      var colon = lines[i].indexOf(":")
      if (colon < 0) continue
      var name = lines[i].slice(0, colon).trim()
      if (iface === "all" ? name === "lo" : name !== iface) continue
      var f = lines[i].slice(colon + 1).trim().split(/\s+/)
      rx += Number(f[0])
      tx += Number(f[8])
      found = true
    }
    return found ? { rx: rx, tx: tx } : null
  }

  function sample() {
    var iface = (ifaceSetting === "" || ifaceSetting === "auto") ? defaultIface() : ifaceSetting
    var now = Date.now()
    var c = iface !== "" ? readCounters(iface) : null

    // Interface switched (e.g. wifi -> ethernet) or vanished: restart the
    // baseline so the switch doesn't show up as a huge spike.
    if (!c || iface !== root.activeIface) {
      root.activeIface = iface
      root.downRate = 0
      root.upRate = 0
      root.lastRx = c ? c.rx : -1
      root.lastTx = c ? c.tx : -1
      root.lastTime = now
      return
    }

    var dt = (now - root.lastTime) / 1000
    if (root.lastRx >= 0 && dt > 0) {
      // Counters reset when an interface goes down and up again.
      root.downRate = Math.max(0, (c.rx - root.lastRx) / dt)
      root.upRate = Math.max(0, (c.tx - root.lastTx) / dt)
    }
    root.lastRx = c.rx
    root.lastTx = c.tx
    root.lastTime = now
  }

  // Bytes/s to a short label with 3 significant digits, e.g. 1.23 MB/s.
  function format(bytesPerSec) {
    var v = root.useBits ? bytesPerSec * 8 : bytesPerSec
    var units = root.useBits ? ["bit/s", "kbit/s", "Mbit/s", "Gbit/s"] : ["B/s", "KB/s", "MB/s", "GB/s"]
    var i = 0
    while (v >= 1000 && i < units.length - 1) {
      v /= 1000
      i++
    }
    var num = i === 0 ? Math.round(v).toString() : (v < 10 ? v.toFixed(2) : v < 100 ? v.toFixed(1) : Math.round(v).toString())
    return num + " " + units[i]
  }

  readonly property string downText: format(downRate)
  readonly property string upText: format(upRate)

  readonly property real valueFontSize: Style.font.caption
  readonly property real arrowFontSize: Math.round(Style.font.caption * 1.4)
  readonly property color textColor: root.bar ? root.bar.barForeground : Color.foreground

  // Widest value the current unit can produce. Each value gets this fixed
  // width so the rest of the bar doesn't shift every tick.
  TextMetrics {
    id: widest
    font.family: button.fontFamily
    font.pixelSize: root.valueFontSize
    text: "8.88 " + (root.useBits ? "Mbit/s" : "MB/s")
  }

  FileView { id: devFile; path: "/proc/net/dev"; blockAllReads: true; printErrors: false }
  FileView { id: routeFile; path: "/proc/net/route"; blockAllReads: true; printErrors: false }

  Timer {
    interval: root.pollIntervalMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.sample()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 6
    fixedWidth: root.vertical ? -1 : Math.ceil(readings.implicitWidth + button.scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.ceil(readings.implicitHeight + button.scaledVerticalPadding * 2) : -1
    pressable: false
    tooltipText: root.activeIface !== ""
      ? ("Interface: " + root.activeIface)
      : "No active network interface"

    Grid {
      id: readings
      anchors.centerIn: parent
      columns: root.vertical ? 1 : 2
      columnSpacing: 10
      rowSpacing: 2

      Repeater {
        model: [
          { arrow: "↓", value: root.downText },
          { arrow: "↑", value: root.upText }
        ]

        Row {
          required property var modelData
          spacing: 4

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.arrow
            color: root.textColor
            font.family: button.fontFamily
            font.pixelSize: root.arrowFontSize
            font.bold: true
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(widest.advanceWidth)
            horizontalAlignment: Text.AlignLeft
            text: modelData.value
            color: root.textColor
            font.family: button.fontFamily
            font.pixelSize: root.valueFontSize
          }
        }
      }
    }
  }
}
