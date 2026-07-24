import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool barOpen: true
    property real topBarMediaWidth: 440
    property real topBarMediaX: 0
    property Item topBarMediaItem: null
    property string randomQuote: "Everything happens for a reason"
    readonly property var quotesList: [
        "Everything happens for a reason",
        "Believe you can and you're halfway there",
        "Collect moments, not things",
        "Keep moving forward",
        "Make today count",
        "Simplicity is the ultimate sophistication",
        "Dream big. Start small. Act now.",
        "Be here now",
        "Stay hungry, stay foolish",
        "Yesterday you said tomorrow"
    ]

    Component.onCompleted: {
        root.randomQuote = root.quotesList[Math.floor(Math.random() * root.quotesList.length)];
    }

    property bool settingsOpen: false
    property string settingsPage: ""
    property Item currentPageInstance: null
    property bool desktopWidgetKeyboardFocus: false
    property bool crosshairOpen: false
    property bool desktopMenuOpen: false
    property var desktopMenuScreen: null
    property real desktopMenuX: 0
    property real desktopMenuY: 0
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"

        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }
}