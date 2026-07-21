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
    property string iface: Config.options?.networking?.iface ?? ""
    readonly property string activeIface: getActiveInterface()

    function getActiveInterface() {
        if (root.iface && root.iface.length > 0) return root.iface

        // 1. Check default route in /proc/net/route
        fileRoute.reload()
        const text = fileRoute.text()
        if (text) {
            const lines = text.split("\n")
            for (let i = 1; i < lines.length; i++) {
                const parts = lines[i].trim().split(/\s+/)
                if (parts.length >= 2 && parts[1] === "00000000" && parts[0] !== "lo") {
                    return parts[0]
                }
            }
        }

        // 2. Fallback to first non-loopback non-virtual interface in /proc/net/dev
        fileDev.reload()
        const devText = fileDev.text()
        if (devText) {
            const devLines = devText.split("\n")
            for (let i = 2; i < devLines.length; i++) {
                const line = devLines[i].trim()
                if (!line || !line.includes(":")) continue
                const name = line.split(":")[0].trim()
                if (name !== "lo" && !name.startsWith("veth") && !name.startsWith("docker") && !name.startsWith("br-") && !name.startsWith("virbr") && !name.startsWith("waydroid") && !name.startsWith("tun") && !name.startsWith("tap")) {
                    return name
                }
            }
        }

        return ""
    }

    onActiveIfaceChanged: {
        root._prevRx = -1
        root._prevTx = -1
        if (!vnstatProc.running)
            vnstatProc.running = true
    }

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

    // ── /proc/net reader (Live Speed) ───────────────────
    FileView { id: fileRoute; path: "/proc/net/route" }
    FileView { id: fileDev; path: "/proc/net/dev" }

    function updateLiveSpeed() {
        const target = root.activeIface
        fileDev.reload()
        const text = fileDev.text()
        if (!text) return

        const lines = text.split("\n")
        let rx = -1
        let tx = -1

        for (let i = 2; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line || !line.includes(":")) continue

            const parts = line.split(":")
            const ifName = parts[0].trim()

            if (target !== "") {
                if (ifName !== target) continue
            } else {
                if (ifName === "lo" || ifName.startsWith("veth") || ifName.startsWith("docker") || ifName.startsWith("br-") || ifName.startsWith("virbr") || ifName.startsWith("waydroid") || ifName.startsWith("tun") || ifName.startsWith("tap")) continue
            }

            const stats = parts[1].trim().split(/\s+/)
            if (stats.length < 9) continue

            const devRx = parseFloat(stats[0])
            const devTx = parseFloat(stats[8])

            if (target !== "") {
                rx = devRx
                tx = devTx
                break
            } else {
                if (rx < 0) { rx = 0; tx = 0; }
                rx += devRx
                tx += devTx
            }
        }

        if (rx < 0 || tx < 0) return

        const now = Date.now() / 1000.0
        if (root._prevRx >= 0 && root._prevTx >= 0) {
            const dt = now - root._prevTime
            if (dt > 0.01) {
                const drx = Math.max(0, rx - root._prevRx)
                const dtx = Math.max(0, tx - root._prevTx)
                root.rxBps = drx / dt
                root.txBps = dtx / dt
            }
        }

        root._prevRx = rx
        root._prevTx = tx
        root._prevTime = now
    }

    Timer {
        id: liveTimer
        interval: 1000
        running: root.mode === 0 || root.mode === 2 // Only run when live speeds are visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.updateLiveSpeed()
        }
    }

    // ── vnstat reader (Daily Totals) ────────────────────────
    Process {
        id: vnstatProc
        command: root.activeIface !== ""
            ? ["vnstat", "-i", root.activeIface, "--oneline"]
            : ["vnstat", "--oneline"]
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

        stderr: SplitParser {
            onRead: errLine => {
                if (root.activeIface !== "" && (errLine.includes("Error") || errLine.includes("Unable"))) {
                    fallbackVnstatProc.running = true
                }
            }
        }
    }

    Process {
        id: fallbackVnstatProc
        command: ["vnstat", "--oneline"]
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
