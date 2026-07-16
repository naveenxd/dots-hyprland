import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property string timeFormat: {
        let format = Config.options?.time?.format ?? "hh:mm";
        if (Config.options?.time?.secondPrecision) {
            if (format.includes("ap") || format.includes("AP"))
                return format.replace(/(?=\s*[aA][pP]$)/, ":ss");
            if (!format.includes("ss"))
                return `${format}:ss`;
        }
        return format;
    }
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    SystemClock {
        id: barClock
        precision: Config.options?.time?.secondPrecision ? SystemClock.Seconds : SystemClock.Minutes
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            text: Qt.locale().toString(barClock.date, root.timeFormat)
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: "•"
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: DateTime.longDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        acceptedButtons: Qt.NoButton

        ClockWidgetPopup {
            hoverTarget: mouseArea
        }
    }
}
