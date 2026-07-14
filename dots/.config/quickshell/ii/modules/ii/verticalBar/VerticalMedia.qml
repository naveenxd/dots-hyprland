import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

import qs.modules.ii.bar as Bar

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: activePlayer != null && (root.isPlaying || (StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || "") !== "")
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.fillHeight: true
    implicitHeight: mediaCircProg.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    onPressed: (event) => {
        if (event.button === Qt.MiddleButton) {
            if (root.hasMedia && activePlayer) activePlayer.togglePlaying();
        } else if (event.button === Qt.BackButton) {
            if (root.hasMedia && activePlayer) activePlayer.previous();
        } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
            if (root.hasMedia && activePlayer) activePlayer.next();
        } else if (event.button === Qt.LeftButton) {
            if (root.hasMedia) GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            else GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }
    }

    ClippedFilledCircularProgress {
        id: mediaCircProg
        anchors.centerIn: parent
        implicitSize: 20

        lineWidth: Appearance.rounding.unsharpen
        value: activePlayer?.position / activePlayer?.length
        colPrimary: Appearance.colors.colOnSecondaryContainer
        enableAnimation: false

        Item {
            anchors.centerIn: parent
            width: mediaCircProg.implicitSize
            height: mediaCircProg.implicitSize
            
            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: activePlayer?.isPlaying ? "pause" : (root.hasMedia ? "play_arrow" : "auto_awesome")
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }
    }

    Bar.StyledPopup {
        hoverTarget: root
        active: GlobalStates.mediaControlsOpen ? false : root.containsMouse

        Column {
            anchors.centerIn: parent
            spacing: 4

            Bar.StyledPopupHeaderRow {
                icon: root.hasMedia ? "music_note" : "auto_awesome"
                label: root.hasMedia ? Translation.tr("Media") : Translation.tr("Quote")
            }

            StyledText {
                color: Appearance.colors.colOnSurfaceVariant
                text: root.hasMedia ? `${cleanedTitle}${activePlayer?.trackArtist ? '\n' + activePlayer.trackArtist : ''}` : GlobalStates.randomQuote
            }
        }
    }

}
