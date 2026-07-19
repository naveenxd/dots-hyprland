pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.widgets

// ─────────────────────────────────────────────────────────────
// NetSpeedIndicator
// Reads /proc/net/dev every second.
// Click to cycle:
//   mode 0 → live speeds       ↓ 2.3KB/s  ↑ 0.8MB/s
//   mode 1 → session totals    ↓ 234MB    ↑ 12MB
//   mode 2 → both              ↓ 234MB · 2.3KB/s  ↑ 12MB · 0.8MB/s
// ─────────────────────────────────────────────────────────────
Item {
    id: root

    Layout.fillHeight: true
    implicitWidth: contentRow.implicitWidth + 16
    implicitHeight: contentRow.implicitHeight

    // ── Config ──────────────────────────────────────────────
    property string iface: "wlan0"

    // ── State ───────────────────────────────────────────────
    property int mode: 0          // 0 = live | 1 = totals | 2 = both

    property real rxBps: 0
    property real txBps: 0
    property real sessionRx: 0
    property real sessionTx: 0

    property real _prevRx: -1
    property real _prevTx: -1
    property real _prevTime: 0

    // ── Formatters ───────────────────────────────────────────
    function fmtSpeed(bps) {
        if (bps < 1024)         return bps.toFixed(0)       + " B/s"
        if (bps < 1048576)      return (bps / 1024).toFixed(1)    + " KB/s"
        if (bps < 1073741824)   return (bps / 1048576).toFixed(1) + " MB/s"
        return                         (bps / 1073741824).toFixed(2) + " GB/s"
    }

    function fmtTotal(b) {
        if (b < 1024)           return b.toFixed(0)         + "B"
        if (b < 1048576)        return (b / 1024).toFixed(1)    + "KB"
        if (b < 1073741824)     return (b / 1048576).toFixed(1) + "MB"
        return                         (b / 1073741824).toFixed(2) + "GB"
    }

    function rxText() {
        if (mode === 1) return fmtTotal(sessionRx)
        if (mode === 2) return fmtTotal(sessionRx) + "·" + fmtSpeed(rxBps)
        return fmtSpeed(rxBps)
    }

    // Fixed a potential typo where txText was returning sessionRx instead of sessionTx
    function txText() {
        if (mode === 1) return fmtTotal(sessionTx)
        if (mode === 2) return fmtTotal(sessionTx) + "·" + fmtSpeed(txBps)
        return fmtSpeed(txBps)
    }

    // ── /proc/net/dev reader ─────────────────────────────────
    Process {
        id: netProc
        command: ["cat", "/proc/net/dev"]
        running: false

        stdout: SplitParser {
            // default splitMarker="\n" → onRead gets one line at a time
            onRead: line => {
                var l = line.trim()
                if (!l.startsWith(root.iface + ":")) return

                // columns after "iface:":
                // [0] rx_bytes  [1] rx_pkts ... [8] tx_bytes
                var parts = l.slice(l.indexOf(":") + 1).trim().split(/\s+/)
                if (parts.length < 9) return

                var rx = parseFloat(parts[0])
                var tx = parseFloat(parts[8])
                var now = Date.now() / 1000.0

                if (root._prevRx >= 0) {
                    var dt = now - root._prevTime
                    if (dt > 0.01) {
                        var drx = Math.max(0, rx - root._prevRx)
                        var dtx = Math.max(0, tx - root._prevTx)
                        root.rxBps      = drx / dt
                        root.txBps      = dtx / dt
                        root.sessionRx += drx
                        root.sessionTx += dtx
                    }
                }

                root._prevRx   = rx
                root._prevTx   = tx
                root._prevTime = now
            }
        }
    }

    Timer {
        id: sampleTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!netProc.running)
                netProc.running = true
        }
    }

    // ── Interaction ──────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.mode = (root.mode + 1) % 3

        // Subtle hover highlight (same pattern as rest of bar)
        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: parent.containsMouse
                ? Appearance.colors.colLayer1Hover
                : "transparent"
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        // ── Content ──────────────────────────────────────────
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 10

            // ─ RX ─
            RowLayout {
                spacing: 3

                MaterialSymbol {
                    text: "arrow_downward"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.5
                }

                Text {
                    text: root.rxText()
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.mono
                    color: Appearance.colors.colOnLayer0

                    Behavior on text {
                        // instant swap keeps it snappy — remove if you want no animation
                    }
                }
            }

            // thin vertical divider
            Rectangle {
                width: 1
                height: Appearance.font.pixelSize.small + 2
                color: Appearance.colors.colOutlineVariant
                opacity: 0.4
            }

            // ─ TX ─
            RowLayout {
                spacing: 3

                MaterialSymbol {
                    text: "arrow_upward"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.5
                }

                Text {
                    text: root.txText()
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.mono
                    color: Appearance.colors.colOnLayer0
                }
            }
        }
    }
}
