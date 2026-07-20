import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitWidth: columnLayout.implicitWidth + columnLayout.anchors.leftMargin + columnLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    TextMetrics {
        id: speedTextMetrics
        text: "88.8 MB/s"
        font.pixelSize: Appearance.font.pixelSize.smallest
    }

    ColumnLayout {
        id: columnLayout
        spacing: 0
        anchors.centerIn: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6

        // Download speed
        RowLayout {
            spacing: 3
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

            MaterialSymbol {
                text: "arrow_downward"
                iconSize: Appearance.font.pixelSize.smaller
                color: ResourceUsage.networkRxSpeed > 1024 ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            }

            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: speedTextMetrics.width
                implicitHeight: speedTextMetrics.height

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    text: ResourceUsage.formatNetworkSpeed(ResourceUsage.networkRxSpeed)
                }
            }
        }

        // Upload speed
        RowLayout {
            spacing: 3
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

            MaterialSymbol {
                text: "arrow_upward"
                iconSize: Appearance.font.pixelSize.smaller
                color: ResourceUsage.networkTxSpeed > 1024 ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            }

            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: speedTextMetrics.width
                implicitHeight: speedTextMetrics.height

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    text: ResourceUsage.formatNetworkSpeed(ResourceUsage.networkTxSpeed)
                }
            }
        }
    }

    NetworkSpeedPopup {
        hoverTarget: root
    }
}
