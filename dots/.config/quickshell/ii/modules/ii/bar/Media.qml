import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property list<real> visualizerPoints: CavaService.points

    readonly property bool isCompact: Config.options.bar.media.size === "compact"
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: activePlayer != null && (root.isPlaying || (StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || "") !== "")
    // Only show lyrics when available AND in wide mode — no placeholders ever
    readonly property bool showLyrics: !root.isCompact && root.isPlaying
        && Config.options.bar.media.showLyrics
        && LyricsService.currentLyricLine
        && LyricsService.currentLyricLine.length > 0

    onWidthChanged: {
        if (root.width > 100) GlobalStates.topBarMediaWidth = root.width;
    }
    Component.onCompleted: {
        if (root.width > 100) GlobalStates.topBarMediaWidth = root.width;
    }

    // Compact: content-driven narrow pill. Wide: fill left section.
    Layout.fillHeight: true
    implicitWidth: root.isCompact
        ? (rowLayout.implicitWidth + 20)
        : (parent?.width ?? 520)
    implicitHeight: Appearance.sizes.barHeight

    Timer {
        running: root.isPlaying
        interval: 1000
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    // Background pill — only visible in wide mode (compact is borderless/transparent)
    Rectangle {
        id: bgContainer
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        width: root.isCompact ? rowLayout.implicitWidth + 20 : parent.width
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        radius: Appearance.rounding.small
        color: root.isCompact
            ? "transparent"
            : (Config.options?.bar.borderless ? "transparent" : (hoverArea.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1))
        border.width: 0
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Waveform visualizer — wide mode only
        Item {
            id: visualizerContainer
            anchors.fill: parent
            visible: !root.isCompact
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: visualizerContainer.width
                    height: visualizerContainer.height
                    radius: bgContainer.radius
                }
            }
            WaveVisualizer {
                id: visualizerBg
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -12
                layer.enabled: false
                visible: opacity > 0
                opacity: (root.isPlaying && !GlobalStates.mediaControlsOpen && root.visualizerPoints.length > 0) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                live: root.isPlaying && !GlobalStates.mediaControlsOpen
                points: root.visualizerPoints
                maxVisualizerValue: 850
                smoothing: 1
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)
            }
        }
    }

    Timer {
        id: singleClickTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.hasMedia) GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            else GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onDoubleClicked: (event) => {
            if (event.button === Qt.LeftButton) {
                singleClickTimer.stop();
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
            }
        }
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                if (root.hasMedia && activePlayer) activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                if (root.hasMedia && activePlayer) activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                if (root.hasMedia && activePlayer) activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
                singleClickTimer.restart();
            }
        }
    }

    RowLayout {
        id: rowLayout
        spacing: root.isCompact ? 4 : 10
        anchors.left: bgContainer.left
        anchors.right: bgContainer.right
        anchors.top: bgContainer.top
        anchors.bottom: bgContainer.bottom
        anchors.leftMargin: root.isCompact ? 0 : 10
        anchors.rightMargin: root.isCompact ? 0 : 14

        // Icon: progress ring with play/pause
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 20
            implicitHeight: 20

            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: "auto_awesome"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
                visible: !root.hasMedia
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            ClippedFilledCircularProgress {
                id: mediaCircProg
                anchors.centerIn: parent
                visible: root.hasMedia
                opacity: visible ? 1 : 0
                lineWidth: Appearance.rounding.unsharpen
                value: activePlayer?.position / activePlayer?.length
                implicitSize: 20
                colPrimary: Appearance.colors.colOnLayer1
                enableAnimation: false
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                Item {
                    anchors.centerIn: parent
                    width: mediaCircProg.implicitSize
                    height: mediaCircProg.implicitSize
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: root.isPlaying ? "pause" : "play_arrow"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        // Text: title • artist | lyrics (wide only, no placeholders)
        Item {
            id: topBarTextContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: topBarMusicText.implicitHeight
            clip: true

            readonly property string displayText: {
                if (!root.hasMedia) return root.isCompact ? GlobalStates.randomQuote : GlobalStates.randomQuote;
                // Wide + lyrics available: show lyrics
                if (root.showLyrics) return LyricsService.currentLyricLine;
                // Otherwise: title • artist (no "No lyrics" / "Fetching" placeholders)
                let artistStr = activePlayer?.trackArtist || "";
                return `${cleanedTitle}${artistStr ? ' • ' + artistStr : ''}`;
            }

            readonly property bool isOverflowing: width > 0 && topBarMusicText.implicitWidth > width + 5
            onDisplayTextChanged: topBarMarqueeRow.x = 0;
            onIsOverflowingChanged: { if (!isOverflowing) topBarMarqueeRow.x = 0; }

            Row {
                id: topBarMarqueeRow
                spacing: 36
                x: 0

                StyledText {
                    id: topBarMusicText
                    textFormat: Text.PlainText
                    color: Appearance.colors.colOnLayer1
                    text: topBarTextContainer.displayText
                }
                StyledText {
                    visible: topBarTextContainer.isOverflowing && topBarMarqueeAnim.running
                    textFormat: Text.PlainText
                    color: Appearance.colors.colOnLayer1
                    text: topBarTextContainer.displayText
                }

                SequentialAnimation on x {
                    id: topBarMarqueeAnim
                    running: topBarTextContainer.isOverflowing
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1800 }
                    NumberAnimation {
                        from: 0
                        to: -(topBarMusicText.implicitWidth + topBarMarqueeRow.spacing)
                        duration: Math.max(3000, topBarMusicText.implicitWidth * 25)
                    }
                }
            }
        }

        // Time — wide mode only
        StyledText {
            id: trackTimeText
            readonly property string timeDisplay: Config.options.bar.media.timeDisplay
            visible: !root.isCompact && root.hasMedia && (activePlayer?.length || 0) > 0 && timeDisplay !== "off"
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: {
                let pos = Math.max(0, activePlayer?.position || 0);
                let len = Math.max(0, activePlayer?.length || 0);
                let rem = Math.max(0, len - pos);
                if (timeDisplay === "played") return StringUtils.friendlyTimeForSeconds(pos);
                if (timeDisplay === "both") return `${StringUtils.friendlyTimeForSeconds(pos)}/${StringUtils.friendlyTimeForSeconds(len)}`;
                return `-${StringUtils.friendlyTimeForSeconds(rem)}`;
            }
        }
    }
}
