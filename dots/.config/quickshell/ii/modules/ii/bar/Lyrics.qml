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
    // Preferred min width when visible (will stretch to fill remaining space)
    implicitWidth: shouldShow ? 50 : 0
    implicitHeight: Appearance.sizes.barHeight
    width: implicitWidth
    height: implicitHeight
    clip: true
    visible: implicitWidth > 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    property string activeText: LyricsService.currentLyricLine ?? ""
    property bool showSlide1: true

    onActiveTextChanged: {
        if (activeText === "") return;
        if (showSlide1) {
            if (slideText1.text === activeText) return;
            slideText2.text = activeText;
            slideAnim1.start();
            showSlide1 = false;
        } else {
            if (slideText2.text === activeText) return;
            slideText1.text = activeText;
            slideAnim2.start();
            showSlide1 = true;
        }
    }

    // Component initialization: seed first slide
    Component.onCompleted: {
        slideText1.text = activeText;
        slide1.opacity = 1;
        slide1.y = 0;
        slide2.opacity = 0;
        slide2.y = 15;
    }

    // Slide 1 Container
    Item {
        id: slide1
        anchors.fill: parent
        opacity: 1
        y: 0
        clip: true

        readonly property bool isOverflowing: slideText1.implicitWidth > width + 4
        onIsOverflowingChanged: { if (!isOverflowing) marqueeRow1.x = 0; }
        onWidthChanged:         { if (!isOverflowing) marqueeRow1.x = 0; }

        Row {
            id: marqueeRow1
            spacing: 36
            x: 0
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                id: slideText1
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                visible: slide1.isOverflowing && marqueeAnim1.running
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                text: slideText1.text
            }

            SequentialAnimation on x {
                id: marqueeAnim1
                running: slide1.isOverflowing && root.shouldShow && slide1.opacity > 0.5
                loops: Animation.Infinite
                PauseAnimation { duration: 1800 }
                NumberAnimation {
                    from: 0
                    to: -(slideText1.implicitWidth + marqueeRow1.spacing)
                    duration: Math.max(3000, slideText1.implicitWidth * 25)
                    easing.type: Easing.Linear
                }
            }
        }
    }

    // Slide 2 Container
    Item {
        id: slide2
        anchors.fill: parent
        opacity: 0
        y: 15
        clip: true

        readonly property bool isOverflowing: slideText2.implicitWidth > width + 4
        onIsOverflowingChanged: { if (!isOverflowing) marqueeRow2.x = 0; }
        onWidthChanged:         { if (!isOverflowing) marqueeRow2.x = 0; }

        Row {
            id: marqueeRow2
            spacing: 36
            x: 0
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                id: slideText2
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                visible: slide2.isOverflowing && marqueeAnim2.running
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                text: slideText2.text
            }

            SequentialAnimation on x {
                id: marqueeAnim2
                running: slide2.isOverflowing && root.shouldShow && slide2.opacity > 0.5
                loops: Animation.Infinite
                PauseAnimation { duration: 1800 }
                NumberAnimation {
                    from: 0
                    to: -(slideText2.implicitWidth + marqueeRow2.spacing)
                    duration: Math.max(3000, slideText2.implicitWidth * 25)
                    easing.type: Easing.Linear
                }
            }
        }
    }

    ParallelAnimation {
        id: slideAnim1
        // slide1 (visible) -> slide up and fade out
        NumberAnimation { target: slide1; property: "y"; to: -15; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide1; property: "opacity"; to: 0; duration: 250 }

        // slide2 (hidden) -> reset position to bottom, then slide up and fade in
        PropertyAction { target: slide2; property: "y"; value: 15 }
        NumberAnimation { target: slide2; property: "y"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide2; property: "opacity"; to: 1; duration: 300 }
    }

    ParallelAnimation {
        id: slideAnim2
        // slide2 (visible) -> slide up and fade out
        NumberAnimation { target: slide2; property: "y"; to: -15; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide2; property: "opacity"; to: 0; duration: 250 }

        // slide1 (hidden) -> reset position to bottom, then slide up and fade in
        PropertyAction { target: slide1; property: "y"; value: 15 }
        NumberAnimation { target: slide1; property: "y"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide1; property: "opacity"; to: 1; duration: 300 }
    }
}
