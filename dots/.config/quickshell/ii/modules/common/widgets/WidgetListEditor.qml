import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string currentValue: ""
    // Reactive list of currently active widgets
    readonly property var widgetList: {
        if (!currentValue)
            return [];

        return currentValue.split(",").map((item) => {
            return item.trim();
        }).filter((item) => {
            return item.length > 0;
        });
    }
    // List of available widgets with display names and icons
    readonly property var availableWidgets: [{
        "value": "activewindow",
        "displayName": Translation.tr("Active Window"),
        "icon": "visibility"
    }, {
        "value": "lyrics",
        "displayName": Translation.tr("Lyrics"),
        "icon": "lyrics"
    }, {
        "value": "media",
        "displayName": Translation.tr("Media"),
        "icon": "music_note"
    }, {
        "value": "resources",
        "displayName": Translation.tr("Resources"),
        "icon": "memory"
    }, {
        "value": "workspaces",
        "displayName": Translation.tr("Workspaces"),
        "icon": "workspaces"
    }, {
        "value": "clock",
        "displayName": Translation.tr("Clock"),
        "icon": "schedule"
    }, {
        "value": "utils",
        "displayName": Translation.tr("Utils"),
        "icon": "construction"
    }, {
        "value": "battery",
        "displayName": Translation.tr("Battery"),
        "icon": "battery_charging_full"
    }]

    signal valueChanged(string newValue)

    function addWidget(widgetName) {
        var list = widgetList.slice();
        list.push(widgetName);
        var newValue = list.join(", ");
        root.valueChanged(newValue);
    }

    function removeWidget(index) {
        var list = widgetList.slice();
        list.splice(index, 1);
        var newValue = list.join(", ");
        root.valueChanged(newValue);
    }

    function moveWidget(index, direction) {
        var list = widgetList.slice();
        var targetIndex = index + direction;
        if (targetIndex >= 0 && targetIndex < list.length) {
            var temp = list[index];
            list[index] = list[targetIndex];
            list[targetIndex] = temp;
            var newValue = list.join(", ");
            root.valueChanged(newValue);
        }
    }

    implicitHeight: mainLayout.implicitHeight

    ColumnLayout {
        id: mainLayout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Flow {
            id: flowLayout

            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.widgetList

                delegate: Rectangle {
                    id: pill

                    required property string modelData
                    required property int index
                    // Find widget metadata for display name and icon
                    readonly property var widgetMeta: {
                        for (var i = 0; i < root.availableWidgets.length; i++) {
                            if (root.availableWidgets[i].value === modelData)
                                return root.availableWidgets[i];

                        }
                        return {
                            "value": modelData,
                            "displayName": modelData,
                            "icon": "widgets"
                        };
                    }

                    implicitWidth: pillContent.implicitWidth + 24
                    implicitHeight: 32
                    radius: height / 2
                    color: Appearance.colors.colSecondaryContainer
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(Appearance.colors.colOnSecondaryContainer, 0.15)

                    RowLayout {
                        id: pillContent

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 6

                        // Move Left button (if not first)
                        Loader {
                            active: pill.index > 0
                            visible: active

                            sourceComponent: MouseArea {
                                id: moveLeftBtn

                                implicitWidth: 16
                                implicitHeight: 16
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.moveWidget(pill.index, -1)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "chevron_left"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: moveLeftBtn.containsMouse ? 1 : 0.6
                                }

                            }

                        }

                        // Widget Icon
                        MaterialSymbol {
                            text: pill.widgetMeta.icon
                            iconSize: Appearance.font.pixelSize.medium
                            color: Appearance.colors.colOnSecondaryContainer
                        }

                        // Widget Name
                        StyledText {
                            text: pill.widgetMeta.displayName
                            color: Appearance.colors.colOnSecondaryContainer
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: true
                        }

                        // Move Right button (if not last)
                        Loader {
                            active: pill.index < root.widgetList.length - 1
                            visible: active

                            sourceComponent: MouseArea {
                                id: moveRightBtn

                                implicitWidth: 16
                                implicitHeight: 16
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.moveWidget(pill.index, 1)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "chevron_right"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: moveRightBtn.containsMouse ? 1 : 0.6
                                }

                            }

                        }

                        // Remove button
                        MouseArea {
                            id: removeBtn

                            implicitWidth: 18
                            implicitHeight: 18
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.removeWidget(pill.index)

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: removeBtn.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.colOnSecondaryContainer, 0.1) : "transparent"
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                        }

                    }

                }

            }

            // Dropdown selection to add widget
            StyledComboBox {
                id: addCombo

                Layout.fillWidth: false
                implicitWidth: 140
                implicitHeight: 32
                buttonRadius: height / 2
                buttonIcon: "add"
                displayText: Translation.tr("Add Widget")
                textRole: "displayName"
                currentIndex: -1
                model: root.availableWidgets
                onActivated: (index) => {
                    if (index >= 0 && index < model.length)
                        root.addWidget(model[index].value);

                    currentIndex = -1;
                }
            }

        }

    }

}
