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
// Mode 0: Live Speed (from /proc/net/dev, updates every 1s)
// Mode 1: Today's Totals (from vnstat, updates every 10s)
// Mode 2: Both Combined
//
// Left Click: Refresh daily stats and toggle/open the popup.
// Right Click: Cycle display modes (0 -> 1 -> 2).
// ─────────────────────────────────────────────────────────────
Item {
    id: root

    Layout.fillHeight: true
    implicitWidth: contentRow.implicitWidth + 16
    implicitHeight: contentRow.implicitHeight

    // ── Config ──────────────────────────────────────────────
    property string iface: "wlan0"

    // ── State ───────────────────────────────────────────────
    property int mode: 0          // 0 = live | 1 = today's totals | 2 = both

    property real rxBps: 0
    property real txBps: 0
    property real _prevRx: -1
    property real _prevTx: -1
    property real _prevTime: 0

    property string downloadToday: "-"
    property string uploadToday: "-"
    property string totalToday: "-"
    property string avgSpeedToday: "-"

    // ── Formatters ───────────────────────────────────────────
    function fmtSpeed(bps) {
        if (bps < 1024)         return bps.toFixed(0)       + " B/s"
        if (bps < 1048576)      return (bps / 1024).toFixed(1)    + " KB/s"
        if (bps < 1073741824)   return (bps / 1048576).toFixed(1) + " MB/s"
        return                         (bps / 1073741824).toFixed(2) + " GB/s"
    }

    function rxText() {
        if (root.mode === 1) return root.downloadToday
        if (root.mode === 2) return root.downloadToday + " · " + fmtSpeed(root.rxBps)
        return fmtSpeed(root.rxBps)
    }

    function txText() {
        if (root.mode === 1) return root.uploadToday
        if (root.mode === 2) return root.uploadToday + " · " + fmtSpeed(root.txBps)
        return fmtSpeed(root.txBps)
    }

    // ── /proc/net/dev reader (Live Speed) ───────────────────
    Process {
        id: netProc
        command: ["cat", "/proc/net/dev"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                var l = line.trim()
                if (!l.startsWith(root.iface + ":")) return

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
                        root.rxBps = drx / dt
                        root.txBps = dtx / dt
                    }
                }

                root._prevRx   = rx
                root._prevTx   = tx
                root._prevTime = now
            }
        }
    }

    Timer {
        id: liveTimer
        interval: 1000
        running: root.mode === 0 || root.mode === 2 // Only run when live speeds are visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!netProc.running)
                netProc.running = true
        }
    }

    // ── vnstat reader (Daily Totals) ────────────────────────
    Process {
        id: vnstatProc
        command: ["vnstat", "-i", root.iface, "--oneline"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(";")
                if (parts.length >= 7) {
                    root.downloadToday = parts[3].trim()
                    root.uploadToday = parts[4].trim()
                    root.totalToday = parts[5].trim()
                    root.avgSpeedToday = parts[6].trim()
                }
            }
        }
    }

    Timer {
        id: dailyTimer
        interval: 10000 // Refresh vnstat every 10 seconds
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!vnstatProc.running)
                vnstatProc.running = true
        }
    }

    // ── Interaction ──────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: event => {
            if (event.button === Qt.RightButton) {
                root.mode = (root.mode + 1) % 3;
            } else if (event.button === Qt.LeftButton) {
                if (!vnstatProc.running)
                    vnstatProc.running = true;
            }
        }

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

    // ── Popup ───────────────────────────────────────────────
    NetSpeedPopup {
        hoverTarget: mouseArea
        downloadToday: root.downloadToday
        uploadToday: root.uploadToday
        totalToday: root.totalToday
        avgSpeedToday: root.avgSpeedToday
    }
}
