import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "style"
        title: Translation.tr("Bar Style")

        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: Config.options.bar.style ?? "ii"
            onSelected: newValue => {
                Config.options.bar.style = newValue;
            }
            options: [
                {
                    displayName: Translation.tr("Default (Modular)"),
                    icon: "view_day",
                    value: "ii"
                },
                {
                    displayName: Translation.tr("qs_configs (Compact)"),
                    icon: "space_dashboard",
                    value: "qs_configs"
                }
            ]
        }
    }

    ContentSection {
        icon: "notifications"
        title: Translation.tr("Notifications")

        ConfigSwitch {
            buttonIcon: "counter_2"
            text: Translation.tr("Unread indicator: show count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: {
                Config.options.bar.indicators.notifications.showUnreadCount = checked;
            }
        }

    }

    ContentSection {
        icon: "battery_charging_full"
        title: Translation.tr("Battery")

        ConfigSwitch {
            buttonIcon: "battery_std"
            text: Translation.tr("Show battery indicator")
            checked: Config.options.bar.indicators.showBattery
            onCheckedChanged: {
                Config.options.bar.indicators.showBattery = checked;
            }
        }

    }

    ContentSection {
        icon: "music_note"
        title: Translation.tr("Media")

        ConfigSwitch {
            buttonIcon: "graphic_eq"
            text: Translation.tr("Show waveform visualizer")
            checked: Config.options.bar.media.showVisualizer
            onCheckedChanged: {
                Config.options.bar.media.showVisualizer = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "lyrics"
            text: Translation.tr("Show lyrics widget in bar")
            checked: Config.options.bar.media.showLyrics
            onCheckedChanged: {
                Config.options.bar.media.showLyrics = checked;
            }
        }

    }

    ContentSection {
        icon: "schedule"
        title: Translation.tr("Clock")

        ConfigSwitch {
            buttonIcon: "pace"
            text: Translation.tr("Show seconds in time")
            checked: Config.options.bar.showSeconds
            onCheckedChanged: {
                Config.options.bar.showSeconds = checked;
            }
        }
    }

    ContentSection {
        icon: "view_column"
        title: (Config.options.bar.style === "qs_configs" || Config.options.bar.style === "compact")
            ? Translation.tr("Widget Layout (Compact Style)")
            : Translation.tr("Widget Layout (Default Style)")

        // DEFAULT BAR LAYOUT EDITORS
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: !(Config.options.bar.style === "qs_configs" || Config.options.bar.style === "compact")

            ContentSubsection {
                title: Translation.tr("Left widgets (e.g. activewindow)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layout.left
                    onValueChanged: (newValue) => {
                        Config.options.bar.layout.left = newValue;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Center-Left widgets (e.g. resources, media)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layout.centerLeft
                    onValueChanged: (newValue) => {
                        Config.options.bar.layout.centerLeft = newValue;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Center widgets (e.g. workspaces)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layout.center
                    onValueChanged: (newValue) => {
                        Config.options.bar.layout.center = newValue;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Center-Right widgets (e.g. clock, utils, battery)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layout.centerRight
                    onValueChanged: (newValue) => {
                        Config.options.bar.layout.centerRight = newValue;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Right widgets (e.g. weather)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layout.right
                    onValueChanged: (newValue) => {
                        Config.options.bar.layout.right = newValue;
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Available widgets: activewindow, lyrics, media, resources, workspaces, clock, utils, battery, netspeed, weather. Choose widgets to add or remove them from the bar layout.")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }

        // COMPACT (qs_configs) BAR LAYOUT EDITORS
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: (Config.options.bar.style === "qs_configs" || Config.options.bar.style === "compact")

            ContentSubsection {
                title: Translation.tr("Left section (e.g. media)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layoutQsConfigs.left
                    onValueChanged: (newValue) => {
                        Config.options.bar.layoutQsConfigs.left = newValue;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Center section (e.g. workspaces)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layoutQsConfigs.center
                    onValueChanged: (newValue) => {
                        Config.options.bar.layoutQsConfigs.center = newValue;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Center-Right section (e.g. clock, weather)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layoutQsConfigs.centerRight
                    onValueChanged: (newValue) => {
                        Config.options.bar.layoutQsConfigs.centerRight = newValue;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Right section (e.g. utils, netspeed, resources)")

                WidgetListEditor {
                    Layout.fillWidth: true
                    currentValue: Config.options.bar.layoutQsConfigs.right
                    onValueChanged: (newValue) => {
                        Config.options.bar.layoutQsConfigs.right = newValue;
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Available widgets: media, workspaces, clock, weather, utils, netspeed, resources. Choose widgets to toggle them in the compact bar.")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }

    }

    ContentSection {
        icon: "spoke"
        title: Translation.tr("Positioning")

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar position")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    // bottom: false, vertical: false
                    // bottom: false, vertical: true
                    // bottom: true, vertical: false
                    // bottom: true, vertical: true

                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: (newValue) => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [{
                        "displayName": Translation.tr("Top"),
                        "icon": "arrow_upward",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Left"),
                        "icon": "arrow_back",
                        "value": 2
                    }, {
                        "displayName": Translation.tr("Bottom"),
                        "icon": "arrow_downward",
                        "value": 1
                    }, {
                        "displayName": Translation.tr("Right"),
                        "icon": "arrow_forward",
                        "value": 3
                    }]
                }

            }

            ContentSubsection {
                title: Translation.tr("Automatically hide")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.bar.autoHide.enable
                    onSelected: (newValue) => {
                        Config.options.bar.autoHide.enable = newValue; // Update local copy
                    }
                    options: [{
                        "displayName": Translation.tr("No"),
                        "icon": "close",
                        "value": false
                    }, {
                        "displayName": Translation.tr("Yes"),
                        "icon": "check",
                        "value": true
                    }]
                }

            }

        }

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Corner style")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: (newValue) => {
                        Config.options.bar.cornerStyle = newValue; // Update local copy
                    }
                    options: [{
                        "displayName": Translation.tr("Hug"),
                        "icon": "line_curve",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Float"),
                        "icon": "page_header",
                        "value": 1
                    }, {
                        "displayName": Translation.tr("Rect"),
                        "icon": "toolbar",
                        "value": 2
                    }]
                }

            }

            ContentSubsection {
                title: Translation.tr("Group style")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.bar.borderless
                    onSelected: (newValue) => {
                        Config.options.bar.borderless = newValue; // Update local copy
                    }
                    options: [{
                        "displayName": Translation.tr("Pills"),
                        "icon": "location_chip",
                        "value": false
                    }, {
                        "displayName": Translation.tr("Line-separated"),
                        "icon": "split_scene",
                        "value": true
                    }]
                }

            }

        }

    }

    ContentSection {
        icon: "shelf_auto_hide"
        title: Translation.tr("Tray")

        ConfigSwitch {
            buttonIcon: "keep"
            text: Translation.tr('Make icons pinned by default')
            checked: Config.options.tray.invertPinnedItems
            onCheckedChanged: {
                Config.options.tray.invertPinnedItems = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint icons')
            checked: Config.options.tray.monochromeIcons
            onCheckedChanged: {
                Config.options.tray.monochromeIcons = checked;
            }
        }

    }

    ContentSection {
        icon: "widgets"
        title: Translation.tr("Utility buttons")

        ConfigRow {
            uniform: true

            ConfigSwitch {
                buttonIcon: "content_cut"
                text: Translation.tr("Screen snip")
                checked: Config.options.bar.utilButtons.showScreenSnip
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenSnip = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "colorize"
                text: Translation.tr("Color picker")
                checked: Config.options.bar.utilButtons.showColorPicker
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showColorPicker = checked;
                }
            }

        }

        ConfigRow {
            uniform: true

            ConfigSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Keyboard toggle")
                checked: Config.options.bar.utilButtons.showKeyboardToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showKeyboardToggle = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "mic"
                text: Translation.tr("Mic toggle")
                checked: Config.options.bar.utilButtons.showMicToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showMicToggle = checked;
                }
            }

        }

        ConfigRow {
            uniform: true

            ConfigSwitch {
                buttonIcon: "dark_mode"
                text: Translation.tr("Dark/Light toggle")
                checked: Config.options.bar.utilButtons.showDarkModeToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showDarkModeToggle = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "speed"
                text: Translation.tr("Performance Profile toggle")
                checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showPerformanceProfileToggle = checked;
                }
            }

        }

        ConfigRow {
            uniform: true

            ConfigSwitch {
                buttonIcon: "videocam"
                text: Translation.tr("Record")
                checked: Config.options.bar.utilButtons.showScreenRecord
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenRecord = checked;
                }
            }

        }

    }

    ContentSection {
        icon: "cloud"
        title: Translation.tr("Weather")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.bar.weather.enable
            onCheckedChanged: {
                Config.options.bar.weather.enable = checked;
            }
        }

    }

    ContentSection {
        icon: "workspaces"
        title: Translation.tr("Workspaces")

        ConfigSwitch {
            buttonIcon: "counter_1"
            text: Translation.tr('Always show numbers')
            checked: Config.options.bar.workspaces.alwaysShowNumbers
            onCheckedChanged: {
                Config.options.bar.workspaces.alwaysShowNumbers = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "award_star"
            text: Translation.tr('Show app icons')
            checked: Config.options.bar.workspaces.showAppIcons
            onCheckedChanged: {
                Config.options.bar.workspaces.showAppIcons = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint app icons')
            checked: Config.options.bar.workspaces.monochromeIcons
            onCheckedChanged: {
                Config.options.bar.workspaces.monochromeIcons = checked;
            }
        }

        ConfigSpinBox {
            icon: "view_column"
            text: Translation.tr("Workspaces shown")
            value: Config.options.bar.workspaces.shown
            from: 1
            to: 30
            stepSize: 1
            onValueChanged: {
                Config.options.bar.workspaces.shown = value;
            }
        }

        ConfigSpinBox {
            icon: "touch_long"
            text: Translation.tr("Number show delay when pressing Super (ms)")
            value: Config.options.bar.workspaces.showNumberDelay
            from: 0
            to: 1000
            stepSize: 50
            onValueChanged: {
                Config.options.bar.workspaces.showNumberDelay = value;
            }
        }

        ContentSubsection {
            title: Translation.tr("Number style")

            ConfigSelectionArray {
                currentValue: JSON.stringify(Config.options.bar.workspaces.numberMap)
                onSelected: (newValue) => {
                    Config.options.bar.workspaces.numberMap = JSON.parse(newValue);
                }
                options: [{
                    "displayName": Translation.tr("Normal"),
                    "icon": "timer_10",
                    "value": '[]'
                }, {
                    "displayName": Translation.tr("Han chars"),
                    "icon": "square_dot",
                    "value": '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]'
                }, {
                    "displayName": Translation.tr("Roman"),
                    "icon": "account_balance",
                    "value": '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]'
                }]
            }

        }

    }

    ContentSection {
        icon: "tooltip"
        title: Translation.tr("Tooltips")

        ConfigSwitch {
            buttonIcon: "ads_click"
            text: Translation.tr("Click to show")
            checked: Config.options.bar.tooltips.clickToShow
            onCheckedChanged: {
                Config.options.bar.tooltips.clickToShow = checked;
            }
        }

    }

}
