pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color textColor: Appearance.colors.colOnPrimaryContainer
    property color activeColor: Appearance.colors.colPrimary
    property color dimColor: Appearance.colors.colSubtext
    property color indicatorColor: Appearance.colors.colPrimary
    property color indicatorShapeColor: Appearance.colors.colOnPrimary
    property int textAlignment: Text.AlignHCenter

    implicitWidth: 200
    implicitHeight: 200

    // Loading State
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        visible: LyricsService.loading

        MaterialLoadingIndicator {
            Layout.alignment: Qt.AlignHCenter
            loading: true
            colBg: root.indicatorColor
            colShape: root.indicatorShapeColor
            implicitSize: 36
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: LyricsService.loadingStatus || Translation.tr("Fetching lyrics…")
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.dimColor
        }
    }

    // No Lyrics State
    StyledText {
        anchors.centerIn: parent
        visible: !LyricsService.loading && LyricsService.lyricLines.length === 0
        text: Translation.tr("No lyrics available")
        font.pixelSize: Appearance.font.pixelSize.normal
        color: root.dimColor
    }

    // Multi-line Active Lyrics List (5-slot centered layout)
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 6
        visible: !LyricsService.loading && LyricsService.lyricLines.length > 0

        Repeater {
            model: 5
            delegate: StyledText {
                id: slotText
                required property int index
                readonly property int lineOffset: index - 2 // -2, -1, 0 (active), +1, +2
                readonly property int targetIndex: LyricsService.activeLineIndex + lineOffset
                readonly property bool isValidIndex: targetIndex >= 0 && targetIndex < LyricsService.lyricLines.length

                Layout.fillWidth: true
                horizontalAlignment: root.textAlignment
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: lineOffset === 0 ? 3 : 2

                text: isValidIndex ? (LyricsService.lyricLines[targetIndex]?.text ?? "") : ""

                font.pixelSize: lineOffset === 0
                    ? Appearance.font.pixelSize.large
                    : (Math.abs(lineOffset) === 1 ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small)
                font.weight: lineOffset === 0 ? Font.Bold : Font.Normal

                color: lineOffset === 0 ? root.activeColor : root.textColor

                opacity: {
                    if (!isValidIndex || text === "") return 0.0
                    if (lineOffset === 0) return 1.0
                    if (Math.abs(lineOffset) === 1) return 0.55
                    return 0.3
                }

                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }
    }
}
