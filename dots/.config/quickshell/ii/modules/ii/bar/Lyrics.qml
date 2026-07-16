import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property bool hasLyrics: LyricsService.currentLyricLine != null
        && LyricsService.currentLyricLine.length > 0
    readonly property bool shouldShow: Config.options.bar.media.showLyrics
        && MprisController.activePlayer != null
        && hasLyrics

    Layout.fillHeight: true
    // Fixed 200px width when visible, collapses to 0 when hidden — never overlaps neighbours
    implicitWidth: shouldShow ? 200 : 0
    implicitHeight: Appearance.sizes.barHeight
    width: implicitWidth
    height: implicitHeight
    clip: true
    visible: implicitWidth > 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Item {
        id: textContainer
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: lyricsText.implicitHeight
        clip: true

        readonly property bool isOverflowing: lyricsText.implicitWidth > textContainer.width + 4

        onIsOverflowingChanged: { if (!isOverflowing) marqueeRow.x = 0; }
        onWidthChanged:         { if (!isOverflowing) marqueeRow.x = 0; }

        Row {
            id: marqueeRow
            spacing: 36
            x: 0

            StyledText {
                id: lyricsText
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                text: LyricsService.currentLyricLine ?? ""
            }
            StyledText {
                visible: textContainer.isOverflowing && marqueeAnim.running
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                text: LyricsService.currentLyricLine ?? ""
            }

            SequentialAnimation on x {
                id: marqueeAnim
                running: textContainer.isOverflowing && root.shouldShow
                loops: Animation.Infinite
                PauseAnimation { duration: 1800 }
                NumberAnimation {
                    from: 0
                    to: -(lyricsText.implicitWidth + marqueeRow.spacing)
                    duration: Math.max(3000, lyricsText.implicitWidth * 25)
                    easing.type: Easing.Linear
                }
            }
        }
    }
}
