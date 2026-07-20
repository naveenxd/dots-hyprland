pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

Item { // Player instance
    id: root
    required property MprisPlayer player
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 850 // Max value in the data points
    property int visualizerSmoothing: 1 // Number of points to average for smoothing
    property real radius
    property real lastKnownPosition: 0
    property real lastKnownTimestamp: 0
    property real interpolatedPosition: root.player?.position || 0

    Connections {
        target: root.player
        function onPositionChanged() {
            root.lastKnownPosition = root.player?.position || 0;
            root.lastKnownTimestamp = Date.now();
            root.interpolatedPosition = root.lastKnownPosition;
        }
        function onPlaybackStateChanged() {
            root.lastKnownPosition = root.player?.position || 0;
            root.lastKnownTimestamp = Date.now();
            root.interpolatedPosition = root.lastKnownPosition;
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.player?.isPlaying && root.visible
        onTriggered: {
            let pos = root.player?.position || 0;
            let elapsedSec = (Date.now() - root.lastKnownTimestamp) / 1000.0;
            if (Math.abs(pos - (root.lastKnownPosition + elapsedSec)) > 1.5) {
                root.lastKnownPosition = pos;
                root.lastKnownTimestamp = Date.now();
                elapsedSec = 0;
            }
            root.interpolatedPosition = Math.min(root.player?.length || 0, root.lastKnownPosition + elapsedSec);
        }
    }

    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    component TrackChangeButton: RippleButton {
        implicitWidth: 32
        implicitHeight: 32

        property var iconName
        buttonRadius: 16
        colBackground: ColorUtils.applyAlpha(blendedColors.colSecondaryContainer, 0.6)
        colBackgroundHover: blendedColors.colSecondaryContainerHover
        colRipple: blendedColors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            iconSize: 20
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: blendedColors.colOnSecondaryContainer
            text: iconName

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    Timer { // Force update for revision
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: {
            root.player.positionChanged()
        }
    }

    onArtFilePathChanged: {
        if (root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            return;
        }

        // Binding does not work in Process
        coverArtDownloader.targetFile = root.artUrl
        coverArtDownloader.artFilePath = root.artFilePath
        // Download
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: [ "bash", "-c", `[ -f ${artFilePath} ] || curl -4 -sSL '${targetFile}' -o '${artFilePath}'` ]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    // Outer Ambient Color Glow Aura
    Rectangle {
        id: ambientGlow
        anchors.centerIn: parent
        width: parent.width - 16
        height: parent.height - 16
        radius: root.radius + 8
        color: blendedColors.colPrimary
        opacity: root.player?.isPlaying ? 0.30 : 0.12
        scale: root.player?.isPlaying ? 1.03 : 0.98

        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 28
            blur: 1.0
        }
    }

    StyledRectangularShadow {
        target: background
    }

    Rectangle { // Main Glassmorphic Container
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 0.82)
        radius: root.radius
        border.width: 1
        border.color: ColorUtils.applyAlpha(blendedColors.colOnLayer0, 0.14)

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        // Blurred Artwork Background with Subtle Gradient Vignette
        StyledImage {
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true
            opacity: 0.35

            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(blendedColors.colLayer0, 0.65) }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(blendedColors.colLayer0, 0.92) }
                }
            }
        }

        // Waveform Visualizer Layer
        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            live: root.player?.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            // Floating Album Art Container with Ambient Art Shadow
            Item {
                id: artContainer
                Layout.fillHeight: true
                implicitWidth: height

                // Soft art glow shadow matching cover art dominant color
                Rectangle {
                    id: artGlow
                    anchors.centerIn: artBackground
                    width: artBackground.width * 0.92
                    height: artBackground.height * 0.92
                    radius: artBackground.radius
                    color: root.artDominantColor
                    opacity: root.player?.isPlaying ? 0.45 : 0.15

                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 16
                        blur: 0.8
                    }
                }

                Rectangle {
                    id: artBackground
                    anchors.fill: parent
                    radius: 14
                    color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)
                    scale: root.player?.isPlaying ? 1.0 : 0.94
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(blendedColors.colOnLayer0, 0.12)

                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artBackground.width
                            height: artBackground.height
                            radius: artBackground.radius
                        }
                    }

                    StyledImage {
                        id: mediaArt
                        property int size: parent.height
                        anchors.fill: parent

                        source: root.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true

                        width: size
                        height: size
                    }

                    // Glass App Icon Badge
                    Rectangle {
                        id: appIconBadge
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 22
                        height: 22
                        radius: Appearance.rounding.full
                        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 0.90)
                        border.width: 1
                        border.color: ColorUtils.applyAlpha(blendedColors.colOnLayer0, 0.15)
                        visible: appIconImage.status === Image.Ready && appIconImage.source != ""

                        IconImage {
                            id: appIconImage
                            anchors.centerIn: parent
                            implicitSize: 13
                            asynchronous: true
                            source: {
                                let entry = root.player?.desktopEntry || root.player?.identity || "";
                                return Quickshell.iconPath(AppSearch.guessIcon(entry), "");
                            }
                        }
                    }
                }
            }

            // Main Info & Controls Column
            ColumnLayout {
                Layout.fillHeight: true
                spacing: 3

                // Top Status Header: Animated Equalizer & Player Identity
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Row {
                        id: soundwaveIndicator
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.player?.isPlaying ?? false

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                width: 3
                                height: root.player?.isPlaying ? eqHeights[index] : 4
                                radius: 1.5
                                color: blendedColors.colPrimary

                                property var eqHeights: [10, 14, 8]

                                SequentialAnimation on height {
                                    running: root.player?.isPlaying ?? false
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 14 - (index * 3); duration: 260 + (index * 90); easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 4 + (index * 2); duration: 260 + (index * 90); easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }

                    StyledText {
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: blendedColors.colPrimary
                        text: (root.player?.identity || "MEDIA PLAYER").toUpperCase()
                        font.letterSpacing: 1.2
                        opacity: 0.85
                    }

                    Item { Layout.fillWidth: true }

                    // Lyrics Indicator Tag if active
                    Rectangle {
                        visible: LyricsService.lyricLines.length > 0 && root.player === LyricsService.activePlayer
                        radius: Appearance.rounding.full
                        color: ColorUtils.applyAlpha(blendedColors.colPrimary, 0.14)
                        border.width: 1
                        border.color: ColorUtils.applyAlpha(blendedColors.colPrimary, 0.28)
                        implicitHeight: 16
                        implicitWidth: lyricsPillRow.implicitWidth + 10

                        RowLayout {
                            id: lyricsPillRow
                            anchors.centerIn: parent
                            spacing: 3
                            MaterialSymbol {
                                text: "music_note"
                                iconSize: 11
                                color: blendedColors.colPrimary
                            }
                            StyledText {
                                text: "LYRICS"
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: blendedColors.colPrimary
                            }
                        }
                    }
                }

                // Track Title Marquee
                Item {
                    id: titleMarqueeContainer
                    Layout.fillWidth: true
                    implicitHeight: trackTitleText.implicitHeight
                    clip: true

                    readonly property bool isOverflowing: width > 0 && trackTitleText.implicitWidth > width + 5
                    readonly property string rawTitle: root.player?.trackTitle || "Untitled"

                    onRawTitleChanged: {
                        marqueeAnim.stop();
                        marqueeRow.x = 0;
                        if (isOverflowing)
                            marqueeAnim.start();
                    }
                    onIsOverflowingChanged: {
                        if (!isOverflowing) {
                            marqueeAnim.stop();
                            marqueeRow.x = 0;
                        } else {
                            marqueeAnim.restart();
                        }
                    }

                    Row {
                        id: marqueeRow
                        spacing: 40
                        x: 0

                        StyledText {
                            id: trackTitleText
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: blendedColors.colOnLayer0
                            textFormat: Text.PlainText
                            text: titleMarqueeContainer.rawTitle
                        }

                        StyledText {
                            visible: titleMarqueeContainer.isOverflowing && marqueeAnim.running
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: blendedColors.colOnLayer0
                            textFormat: Text.PlainText
                            text: titleMarqueeContainer.rawTitle
                        }

                        SequentialAnimation on x {
                            id: marqueeAnim
                            loops: Animation.Infinite
                            PauseAnimation { duration: 1800 }
                            NumberAnimation {
                                from: 0
                                to: -(trackTitleText.implicitWidth + marqueeRow.spacing)
                                duration: Math.max(3000, trackTitleText.implicitWidth * 28)
                            }
                        }
                    }
                }

                // Artist & Album Marquee
                Item {
                    id: artistMarqueeContainer
                    Layout.fillWidth: true
                    implicitHeight: trackArtistText.implicitHeight
                    clip: true

                    readonly property bool isOverflowing: width > 0 && trackArtistText.implicitWidth > width + 5
                    readonly property string rawSubtitle: {
                        let artist = root.player?.trackArtist || "";
                        let album = root.player?.trackAlbum || "";
                        let title = root.player?.trackTitle || "";
                        if (artist && album && album !== title && !title.includes(album) && artist !== album && !artist.includes(album)) {
                            return `${artist} • ${album}`;
                        }
                        return artist || album || "Unknown Artist";
                    }

                    onRawSubtitleChanged: {
                        artistMarqueeAnim.stop();
                        artistMarqueeRow.x = 0;
                        if (isOverflowing)
                            artistMarqueeAnim.start();
                    }
                    onIsOverflowingChanged: {
                        if (!isOverflowing) {
                            artistMarqueeAnim.stop();
                            artistMarqueeRow.x = 0;
                        } else {
                            artistMarqueeAnim.restart();
                        }
                    }

                    Row {
                        id: artistMarqueeRow
                        spacing: 40
                        x: 0

                        StyledText {
                            id: trackArtistText
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: blendedColors.colSubtext
                            textFormat: Text.PlainText
                            text: artistMarqueeContainer.rawSubtitle
                        }

                        StyledText {
                            visible: artistMarqueeContainer.isOverflowing && artistMarqueeAnim.running
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: blendedColors.colSubtext
                            textFormat: Text.PlainText
                            text: artistMarqueeContainer.rawSubtitle
                        }

                        SequentialAnimation on x {
                            id: artistMarqueeAnim
                            loops: Animation.Infinite
                            PauseAnimation { duration: 2200 }
                            NumberAnimation {
                                from: 0
                                to: -(trackArtistText.implicitWidth + artistMarqueeRow.spacing)
                                duration: Math.max(3000, trackArtistText.implicitWidth * 28)
                            }
                        }
                    }
                }

                // Live Lyric Preview Line
                StyledText {
                    id: popupNextLyric
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.italic: true
                    color: blendedColors.colPrimary
                    opacity: 0.9
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text !== ""
                    text: {
                        if (root.player !== LyricsService.activePlayer) return "";
                        if (!LyricsService.isSupportedPlayer(root.player)) return "";
                        if (LyricsService.lyricLines.length > 0) return LyricsService.nextLyricLine;
                        if (LyricsService.loading) return "Fetching lyrics…";
                        return "";
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                // Bottom Section: Progress Bar & Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Time Stamps & Wavy Progress Bar Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            id: trackTimeLeft
                            font.pixelSize: 10
                            color: blendedColors.colSubtext
                            font.family: Appearance.font.family.monospace
                            text: StringUtils.friendlyTimeForSeconds(root.interpolatedPosition)
                        }

                        Item {
                            id: progressBarContainer
                            Layout.fillWidth: true
                            implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)

                            Loader {
                                id: sliderLoader
                                anchors.fill: parent
                                active: root.player?.canSeek ?? false
                                sourceComponent: StyledSlider {
                                    configuration: StyledSlider.Configuration.Wavy
                                    highlightColor: blendedColors.colPrimary
                                    trackColor: ColorUtils.applyAlpha(blendedColors.colSecondaryContainer, 0.6)
                                    handleColor: blendedColors.colPrimary
                                    value: (root.player?.length || 0) > 0 ? root.interpolatedPosition / root.player.length : 0
                                    onMoved: {
                                        let newPos = value * root.player.length;
                                        root.player.position = newPos;
                                        root.lastKnownPosition = newPos;
                                        root.lastKnownTimestamp = Date.now();
                                        root.interpolatedPosition = newPos;
                                    }
                                }
                            }

                            Loader {
                                id: progressBarLoader
                                anchors {
                                    verticalCenter: parent.verticalCenter
                                    left: parent.left
                                    right: parent.right
                                }
                                active: !(root.player?.canSeek ?? false)
                                sourceComponent: StyledProgressBar {
                                    wavy: root.player?.isPlaying
                                    highlightColor: blendedColors.colPrimary
                                    trackColor: ColorUtils.applyAlpha(blendedColors.colSecondaryContainer, 0.6)
                                    value: (root.player?.length || 0) > 0 ? root.interpolatedPosition / root.player.length : 0
                                }
                            }
                        }

                        StyledText {
                            id: trackTimeRight
                            font.pixelSize: 10
                            color: blendedColors.colSubtext
                            font.family: Appearance.font.family.monospace
                            text: StringUtils.friendlyTimeForSeconds(root.player?.length)
                        }
                    }

                    // Action Buttons Row (Prev - Hero Play/Pause - Next)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        TrackChangeButton {
                            iconName: "skip_previous"
                            downAction: () => root.player?.previous()
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Central Hero Play/Pause Button
                        Item {
                            implicitWidth: 44
                            implicitHeight: 44
                            Layout.alignment: Qt.AlignVCenter

                            // Pulsing Aura Ring
                            Rectangle {
                                id: playAura
                                anchors.centerIn: parent
                                width: parent.width + 6
                                height: parent.height + 6
                                radius: Appearance.rounding.full
                                color: blendedColors.colPrimary
                                opacity: root.player?.isPlaying ? 0.35 : 0.0

                                SequentialAnimation on scale {
                                    running: root.player?.isPlaying ?? false
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.94; to: 1.10; duration: 1100; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.10; to: 0.94; duration: 1100; easing.type: Easing.InOutSine }
                                }
                            }

                            RippleButton {
                                id: playPauseButton
                                anchors.fill: parent
                                downAction: () => root.player.togglePlaying();

                                buttonRadius: root.player?.isPlaying ? 14 : 22
                                colBackground: root.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                                colBackgroundHover: root.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                                colRipple: root.player?.isPlaying ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive

                                contentItem: MaterialSymbol {
                                    iconSize: Appearance.font.pixelSize.huge
                                    fill: 1
                                    horizontalAlignment: Text.AlignHCenter
                                    color: root.player?.isPlaying ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                                    text: root.player?.isPlaying ? "pause" : "play_arrow"

                                    Behavior on color {
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }

                                Behavior on buttonRadius {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutBack }
                                }
                            }
                        }

                        TrackChangeButton {
                            iconName: "skip_next"
                            downAction: () => root.player?.next()
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
