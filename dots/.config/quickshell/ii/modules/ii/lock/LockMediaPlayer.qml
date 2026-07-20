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

Item {
    id: root

    required property MprisPlayer player
    property list<real> visualizerPoints: []

    // Art
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl ?? "")
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property bool artDownloaded: false
    property string displayedArtFilePath: artDownloaded ? Qt.resolvedUrl(artFilePath) : ""

    // Position interpolation
    property real lastKnownPosition: 0
    property real lastKnownTimestamp: 0
    property real interpolatedPosition: player?.position || 0

    // Adaptive color
    property color artDominantColor: ColorUtils.mix(
        (colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary),
        Appearance.colors.colPrimaryContainer, 0.75
    ) || Appearance.m3colors.m3secondaryContainer
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artDominantColor }

    implicitWidth: 480
    implicitHeight: 560

    // ── Art download ──────────────────────────────────────────────────────────
    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            return
        }
        coverArtDownloader.targetFile = root.artUrl
        coverArtDownloader.artFilePath = root.artFilePath
        root.artDownloaded = false
        coverArtDownloader.running = true
    }

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl ?? ""
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -4 -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: root.artDownloaded = true
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    // ── Position timer ────────────────────────────────────────────────────────
    Connections {
        target: root.player
        function onPositionChanged() {
            root.lastKnownPosition = root.player?.position || 0
            root.lastKnownTimestamp = Date.now()
            root.interpolatedPosition = root.lastKnownPosition
        }
        function onPlaybackStateChanged() {
            root.lastKnownPosition = root.player?.position || 0
            root.lastKnownTimestamp = Date.now()
            root.interpolatedPosition = root.lastKnownPosition
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.player?.isPlaying ?? false
        onTriggered: {
            let pos = root.player?.position || 0
            let elapsed = (Date.now() - root.lastKnownTimestamp) / 1000.0
            if (Math.abs(pos - (root.lastKnownPosition + elapsed)) > 1.5) {
                root.lastKnownPosition = pos
                root.lastKnownTimestamp = Date.now()
                elapsed = 0
            }
            root.interpolatedPosition = Math.min(root.player?.length || 0, root.lastKnownPosition + elapsed)
        }
    }

    Timer {
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    // ── Outer ambient glow ────────────────────────────────────────────────────
    Rectangle {
        id: outerGlow
        anchors.centerIn: parent
        width: parent.width + 40
        height: parent.height + 40
        radius: 48
        color: root.blendedColors.colPrimary
        opacity: root.player?.isPlaying ? 0.22 : 0.08
        scale: root.player?.isPlaying ? 1.04 : 0.96

        Behavior on color    { ColorAnimation  { duration: 800; easing.type: Easing.OutCubic } }
        Behavior on opacity  { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        Behavior on scale    { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 48
            blur: 1.0
        }
    }

    // ── Main card ─────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 36
        color: ColorUtils.applyAlpha(root.blendedColors.colLayer0, 0.78)
        border.width: 1.5
        border.color: ColorUtils.applyAlpha(root.blendedColors.colOnLayer0, 0.10)

        Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: card.width; height: card.height; radius: card.radius
            }
        }

        // Blurred wallpaper-art background
        StyledImage {
            id: bgArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true
            opacity: 0.30

            Behavior on opacity { NumberAnimation { duration: 600 } }

            layer.enabled: true
            layer.effect: StyledBlurEffect { source: bgArt }
        }

        // Dark gradient overlay
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorUtils.applyAlpha(root.blendedColors.colLayer0, 0.45) }
                GradientStop { position: 0.55; color: ColorUtils.applyAlpha(root.blendedColors.colLayer0, 0.72) }
                GradientStop { position: 1.0; color: ColorUtils.applyAlpha(root.blendedColors.colLayer0, 0.92) }
            }
        }

        // Waveform visualizer (bottom strip)
        WaveVisualizer {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
            }
            height: 64
            live: root.player?.isPlaying ?? false
            points: root.visualizerPoints
            maxVisualizerValue: 850
            smoothing: 1
            color: ColorUtils.applyAlpha(root.blendedColors.colPrimary, 0.30)
            opacity: root.player?.isPlaying ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500 } }
        }

        // ── Content ───────────────────────────────────────────────────────────
        ColumnLayout {
            anchors {
                fill: parent
                margins: 28
            }
            spacing: 0

            // Player identity row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Animated equalizer bars
                Row {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.player?.isPlaying ?? false

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 2.5
                            height: 12
                            radius: 2
                            color: root.blendedColors.colPrimary
                            opacity: 0.7

                            SequentialAnimation on height {
                                running: root.player?.isPlaying ?? false
                                loops: Animation.Infinite
                                NumberAnimation { to: 16 - index * 2; duration: 240 + index * 80; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 4 + index * 2;  duration: 240 + index * 80; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                StyledText {
                    text: (root.player?.identity || "Media Player").toUpperCase()
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.8
                    color: root.blendedColors.colPrimary
                    opacity: 0.75
                }

                Item { Layout.fillWidth: true }

                // Lyrics badge
                Rectangle {
                    visible: LyricsService.lyricLines.length > 0 && root.player === LyricsService.activePlayer
                    radius: Appearance.rounding.full
                    color: ColorUtils.applyAlpha(root.blendedColors.colPrimary, 0.15)
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(root.blendedColors.colPrimary, 0.30)
                    implicitHeight: 18
                    implicitWidth: lyricsRow.implicitWidth + 12

                    RowLayout {
                        id: lyricsRow
                        anchors.centerIn: parent
                        spacing: 3

                        MaterialSymbol {
                            text: "music_note"
                            iconSize: 10
                            color: root.blendedColors.colPrimary
                        }
                        StyledText {
                            text: "LYRICS"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: root.blendedColors.colPrimary
                        }
                    }
                }
            }

            Item { implicitHeight: 20 }

            // ── Album art ─────────────────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 220
                implicitHeight: 220

                // Art glow
                Rectangle {
                    anchors.centerIn: artFrame
                    width: artFrame.width * 0.9
                    height: artFrame.height * 0.9
                    radius: artFrame.radius
                    color: root.artDominantColor
                    opacity: root.player?.isPlaying ? 0.55 : 0.18
                    scale: root.player?.isPlaying ? 1.08 : 0.95

                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 500; easing.type: Easing.OutBack  } }
                    Behavior on color   { ColorAnimation  { duration: 600 } }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 24
                        blur: 1.0
                    }
                }

                Rectangle {
                    id: artFrame
                    anchors.fill: parent
                    radius: 24
                    color: ColorUtils.applyAlpha(root.blendedColors.colLayer1, 0.6)
                    border.width: 1.5
                    border.color: ColorUtils.applyAlpha(root.blendedColors.colOnLayer0, 0.14)
                    scale: root.player?.isPlaying ? 1.0 : 0.95

                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artFrame.width; height: artFrame.height; radius: artFrame.radius
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        source: root.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        asynchronous: true
                    }

                    // App icon badge (bottom-right)
                    Rectangle {
                        anchors { bottom: parent.bottom; right: parent.right; margins: 8 }
                        width: 26; height: 26
                        radius: Appearance.rounding.full
                        color: ColorUtils.applyAlpha(root.blendedColors.colLayer0, 0.90)
                        border.width: 1
                        border.color: ColorUtils.applyAlpha(root.blendedColors.colOnLayer0, 0.15)
                        visible: appIcon.status === Image.Ready && appIcon.source != ""

                        IconImage {
                            id: appIcon
                            anchors.centerIn: parent
                            implicitSize: 14
                            asynchronous: true
                            source: {
                                let entry = root.player?.desktopEntry || root.player?.identity || ""
                                return Quickshell.iconPath(AppSearch.guessIcon(entry), "")
                            }
                        }
                    }
                }
            }

            Item { implicitHeight: 24 }

            // ── Track info ────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: titleText.implicitHeight
                clip: true

                readonly property bool isOverflowing: width > 0 && titleText.implicitWidth > width + 5

                Row {
                    id: titleMarquee
                    spacing: 48
                    x: 0

                    StyledText {
                        id: titleText
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Bold
                        color: root.blendedColors.colOnLayer0
                        text: root.player?.trackTitle || "Untitled"
                        textFormat: Text.PlainText
                    }
                    StyledText {
                        visible: parent.parent.isOverflowing && titleMarqueeAnim.running
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Bold
                        color: root.blendedColors.colOnLayer0
                        text: root.player?.trackTitle || "Untitled"
                        textFormat: Text.PlainText
                    }

                    SequentialAnimation on x {
                        id: titleMarqueeAnim
                        running: titleText.parent.parent.isOverflowing
                        loops: Animation.Infinite
                        PauseAnimation { duration: 2000 }
                        NumberAnimation {
                            from: 0
                            to: -(titleText.implicitWidth + titleMarquee.spacing)
                            duration: Math.max(3000, titleText.implicitWidth * 28)
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            Item { implicitHeight: 4 }

            // Artist • Album
            Item {
                Layout.fillWidth: true
                implicitHeight: artistText.implicitHeight
                clip: true

                readonly property bool isOverflowing: width > 0 && artistText.implicitWidth > width + 5
                readonly property string subtitle: {
                    let a = root.player?.trackArtist || ""
                    let al = root.player?.trackAlbum || ""
                    let t = root.player?.trackTitle || ""
                    if (a && al && al !== t && !t.includes(al) && a !== al)
                        return `${a} • ${al}`
                    return a || al || "Unknown Artist"
                }

                Row {
                    id: artistMarquee
                    spacing: 48
                    x: 0

                    StyledText {
                        id: artistText
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: root.blendedColors.colSubtext
                        text: parent.parent.subtitle
                        textFormat: Text.PlainText
                    }
                    StyledText {
                        visible: parent.parent.isOverflowing && artistMarqueeAnim.running
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: root.blendedColors.colSubtext
                        text: artistText.parent.parent.subtitle
                        textFormat: Text.PlainText
                    }

                    SequentialAnimation on x {
                        id: artistMarqueeAnim
                        running: artistText.parent.parent.isOverflowing
                        loops: Animation.Infinite
                        PauseAnimation { duration: 2400 }
                        NumberAnimation {
                            from: 0
                            to: -(artistText.implicitWidth + artistMarquee.spacing)
                            duration: Math.max(3000, artistText.implicitWidth * 28)
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            // Lyric preview
            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.small
                font.italic: true
                color: root.blendedColors.colPrimary
                opacity: 0.85
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text !== ""
                text: {
                    if (root.player !== LyricsService.activePlayer) return ""
                    if (!LyricsService.isSupportedPlayer(root.player)) return ""
                    if (LyricsService.lyricLines.length > 0) return LyricsService.nextLyricLine
                    if (LyricsService.loading) return "Fetching lyrics…"
                    return ""
                }
            }

            Item { implicitHeight: 16 }

            // ── Progress ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledText {
                    font.pixelSize: 11
                    color: root.blendedColors.colSubtext
                    font.family: Appearance.font.family.monospace
                    text: StringUtils.friendlyTimeForSeconds(root.interpolatedPosition)
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(sliderLdr.implicitHeight, progressLdr.implicitHeight)

                    Loader {
                        id: sliderLdr
                        anchors.fill: parent
                        active: root.player?.canSeek ?? false
                        sourceComponent: StyledSlider {
                            configuration: StyledSlider.Configuration.Wavy
                            highlightColor: root.blendedColors.colPrimary
                            trackColor: ColorUtils.applyAlpha(root.blendedColors.colSecondaryContainer, 0.5)
                            handleColor: root.blendedColors.colPrimary
                            value: (root.player?.length || 0) > 0 ? root.interpolatedPosition / root.player.length : 0
                            onMoved: {
                                let np = value * root.player.length
                                root.player.position = np
                                root.lastKnownPosition = np
                                root.lastKnownTimestamp = Date.now()
                                root.interpolatedPosition = np
                            }
                        }
                    }

                    Loader {
                        id: progressLdr
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
                        active: !(root.player?.canSeek ?? false)
                        sourceComponent: StyledProgressBar {
                            wavy: root.player?.isPlaying ?? false
                            highlightColor: root.blendedColors.colPrimary
                            trackColor: ColorUtils.applyAlpha(root.blendedColors.colSecondaryContainer, 0.5)
                            value: (root.player?.length || 0) > 0 ? root.interpolatedPosition / root.player.length : 0
                        }
                    }
                }

                StyledText {
                    font.pixelSize: 11
                    color: root.blendedColors.colSubtext
                    font.family: Appearance.font.family.monospace
                    text: StringUtils.friendlyTimeForSeconds(root.player?.length)
                }
            }

            Item { implicitHeight: 12 }

            // ── Controls ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                // Prev
                RippleButton {
                    implicitWidth: 40; implicitHeight: 40
                    buttonRadius: 20
                    colBackground: ColorUtils.applyAlpha(root.blendedColors.colSecondaryContainer, 0.55)
                    colBackgroundHover: root.blendedColors.colSecondaryContainerHover
                    colRipple: root.blendedColors.colSecondaryContainerActive
                    downAction: () => root.player?.previous()
                    contentItem: MaterialSymbol {
                        iconSize: 22; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.blendedColors.colOnSecondaryContainer
                        text: "skip_previous"
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }
                }

                // Hero play/pause
                Item {
                    implicitWidth: 60; implicitHeight: 60
                    Layout.alignment: Qt.AlignVCenter

                    // Pulsing aura
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 12; height: parent.height + 12
                        radius: Appearance.rounding.full
                        color: root.blendedColors.colPrimary
                        opacity: root.player?.isPlaying ? 0.32 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 500 } }

                        SequentialAnimation on scale {
                            running: root.player?.isPlaying ?? false
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.92; to: 1.12; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.12; to: 0.92; duration: 1200; easing.type: Easing.InOutSine }
                        }
                    }

                    RippleButton {
                        anchors.fill: parent
                        downAction: () => root.player?.togglePlaying()
                        buttonRadius: root.player?.isPlaying ? 18 : 30
                        colBackground: root.player?.isPlaying ? root.blendedColors.colPrimary : root.blendedColors.colSecondaryContainer
                        colBackgroundHover: root.player?.isPlaying ? root.blendedColors.colPrimaryHover : root.blendedColors.colSecondaryContainerHover
                        colRipple: root.player?.isPlaying ? root.blendedColors.colPrimaryActive : root.blendedColors.colSecondaryContainerActive

                        Behavior on buttonRadius { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                        contentItem: MaterialSymbol {
                            iconSize: 28; fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: root.player?.isPlaying ? root.blendedColors.colOnPrimary : root.blendedColors.colOnSecondaryContainer
                            text: root.player?.isPlaying ? "pause" : "play_arrow"
                            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                        }
                    }
                }

                // Next
                RippleButton {
                    implicitWidth: 40; implicitHeight: 40
                    buttonRadius: 20
                    colBackground: ColorUtils.applyAlpha(root.blendedColors.colSecondaryContainer, 0.55)
                    colBackgroundHover: root.blendedColors.colSecondaryContainerHover
                    colRipple: root.blendedColors.colSecondaryContainerActive
                    downAction: () => root.player?.next()
                    contentItem: MaterialSymbol {
                        iconSize: 22; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.blendedColors.colOnSecondaryContainer
                        text: "skip_next"
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }
                }
            }
        }
    }
}
