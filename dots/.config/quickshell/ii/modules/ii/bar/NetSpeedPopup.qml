import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    property string downloadToday: "-"
    property string uploadToday: "-"
    property string totalToday: "-"
    property string avgSpeedToday: "-"

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "arrow_downward"
                label: Translation.tr("Download")
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "calendar_today"
                    label: Translation.tr("Today:")
                    value: root.downloadToday
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "arrow_upward"
                label: Translation.tr("Upload")
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "calendar_today"
                    label: Translation.tr("Today:")
                    value: root.uploadToday
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "speed"
                label: Translation.tr("Traffic")
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Total Today:")
                    value: root.totalToday
                }
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Avg Speed:")
                    value: root.avgSpeedToday
                }
            }
        }
    }
}
