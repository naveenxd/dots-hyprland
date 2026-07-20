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

    readonly property list<string> fallbackQuotes: [
        "Everything happens for a reason",
        "Silence is also music",
        "Make today worth remembering",
        "Keep moving forward",
        "Create your own sunshine",
        "Focus on the good",
        "Dream big, stay humble",
        "Peace over perfection",
        "Life is a canvas, paint it bright",
        "Enjoy the little things",
        "Simplicity is the key to elegance",
        "Stay curious, stay inspired",
        "Trust the timing of your life"
    ]
    property int currentQuoteIndex: Math.floor(Math.random() * fallbackQuotes.length)

    onHasMediaChanged: {
        if (!hasMedia) {
            currentQuoteIndex = Math.floor(Math.random() * fallbackQuotes.length);
        }
    }

    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: activePlayer != null && (isPlaying || (StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || "") !== "")

    onWidthChanged: {
        if (root.width > 100) GlobalStates.topBarMediaWidth = root.width;
        updateGlobalX();
    }
    onXChanged: updateGlobalX()
    Component.onCompleted: {
        if (root.width > 100) GlobalStates.topBarMediaWidth = root.width;
        updateGlobalX();
        GlobalStates.topBarMediaItem = root;
    }
    Component.onDestruction: {
        if (GlobalStates.topBarMediaItem === root) {
            GlobalStates.topBarMediaItem = null;
        }
    }

    function updateGlobalX() {
        var glob = mapToItem(null, 0, 0);
        if (glob) {
            GlobalStates.topBarMediaX = glob.x;
        }
    }

    Layout.fillHeight: true
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: Appearance.sizes.barHeight

    Timer {
        running: root.isPlaying
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    // Pill background with waveform visualizer (naveenxd feature, kept)
    Rectangle {
        id: bgContainer
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            topMargin: 4
            bottomMargin: 4
        }
        radius: Appearance.rounding.small
        color: Config.options?.bar.borderless
            ? "transparent"
            : (hoverArea.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1)
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Waveform visualizer background
        Item {
            id: visualizerContainer
            anchors.fill: parent
            visible: Config.options.bar.media.showVisualizer
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: visualizerContainer.width
                    height: visualizerContainer.height
                    radius: bgContainer.radius
                }
            }
            WaveVisualizer {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    bottomMargin: -12
                }
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

    // Exactly like original — direct click, no timer delay
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                if (root.hasMedia && activePlayer) activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                if (root.hasMedia && activePlayer) activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                if (root.hasMedia && activePlayer) activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            }
        }
    }

    RowLayout {
        id: rowLayout
        spacing: 4
        anchors {
            left: bgContainer.left
            right: bgContainer.right
            top: bgContainer.top
            bottom: bgContainer.bottom
            leftMargin: 10
            rightMargin: 14
        }

        // Progress ring with play/pause icon — exactly like original
        ClippedFilledCircularProgress {
            id: mediaCircProg
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            implicitSize: 20
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: root.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        // Title • Artist with horizontal marquee on overflow
        Item {
            id: topBarTextContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            clip: true

            readonly property string displayText: {
                if (!root.hasMedia) return root.fallbackQuotes[root.currentQuoteIndex] || "Everything happens for a reason";
                let rawTitle = activePlayer?.trackTitle || "";
                let rawArtist = activePlayer?.trackArtist || "";
                let isPlaceholder = LyricsService.isPlaceholderTitle(rawTitle);

                let displayTitle = isPlaceholder ? (StringUtils.cleanMusicTitle(LyricsService.currentTrackName) || cleanedTitle) : cleanedTitle;
                let displayArtist = isPlaceholder ? (LyricsService.currentArtistName || rawArtist) : rawArtist;
                let baseInfo = `${displayTitle}${displayArtist ? ' • ' + displayArtist : ''}`;

                if (LyricsService.currentLyricLine && LyricsService.currentLyricLine.length > 0) {
                    return LyricsService.currentLyricLine;
                }
                return baseInfo;
            }

            readonly property bool isOverflowing: width > 0 && topBarMusicText.implicitWidth > width + 5
            onDisplayTextChanged: topBarMarqueeRow.x = 0;
            onIsOverflowingChanged: { if (!isOverflowing) topBarMarqueeRow.x = 0; }

            Row {
                id: topBarMarqueeRow
                spacing: 36
                x: 0
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: topBarMusicText
                    renderType: Text.QtRendering
                    textFormat: Text.PlainText
                    color: Appearance.colors.colOnLayer1
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: topBarTextContainer.displayText
                }
                StyledText {
                    visible: topBarTextContainer.isOverflowing && topBarMarqueeAnim.running
                    renderType: Text.QtRendering
                    textFormat: Text.PlainText
                    color: Appearance.colors.colOnLayer1
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
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
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }
}
