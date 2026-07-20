import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: 8

        StyledPopupHeaderRow {
            icon: "lan"
            label: (Network.networkName && Network.networkName.length > 0) ? Network.networkName : Translation.tr("Network Traffic")
        }

        Column {
            spacing: 4
            StyledPopupValueRow {
                icon: "arrow_downward"
                label: Translation.tr("Download Speed:")
                value: ResourceUsage.formatNetworkSpeed(ResourceUsage.networkRxSpeed)
            }
            StyledPopupValueRow {
                icon: "arrow_upward"
                label: Translation.tr("Upload Speed:")
                value: ResourceUsage.formatNetworkSpeed(ResourceUsage.networkTxSpeed)
            }
            StyledPopupValueRow {
                icon: "download"
                label: Translation.tr("Total Downloaded:")
                value: ResourceUsage.formatNetworkTotal(ResourceUsage.networkTotalRxBytes)
            }
            StyledPopupValueRow {
                icon: "upload"
                label: Translation.tr("Total Uploaded:")
                value: ResourceUsage.formatNetworkTotal(ResourceUsage.networkTotalTxBytes)
            }
        }
    }
}
