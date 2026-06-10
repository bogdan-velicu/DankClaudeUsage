import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "claudeUsage"

    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")

    SelectionSetting {
        settingKey: "displayStyle"
        label: "Display Style"
        description: "How limits appear in the bar"
        options: [
            {label: "Filled ring", value: "filledRing"},
            {label: "Hollow ring", value: "hollowRing"},
            {label: "Numbers only", value: "numbers"},
            {label: "Mini bar", value: "bar"}
        ]
        defaultValue: "filledRing"
    }

    ToggleSetting {
        settingKey: "showFiveHour"
        label: "Show 5-hour limit"
        description: "Display the rolling 5-hour window"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showWeekly"
        label: "Show weekly limit"
        description: "Display the rolling 7-day window"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showSonnetWeekly"
        label: "Show weekly Sonnet limit"
        description: "Display the Sonnet-specific weekly quota when available"
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "warningThreshold"
        label: "Warning threshold"
        description: "Switch to the warning color at this %"
        options: [
            {label: "60%", value: "60"},
            {label: "70%", value: "70"},
            {label: "80%", value: "80"}
        ]
        defaultValue: "70"
    }

    SelectionSetting {
        settingKey: "criticalThreshold"
        label: "Critical threshold"
        description: "Switch to the error color (and pulse) at this %"
        options: [
            {label: "85%", value: "85"},
            {label: "90%", value: "90"},
            {label: "95%", value: "95"}
        ]
        defaultValue: "90"
    }

    ToggleSetting {
        settingKey: "pulseOnCritical"
        label: "Pulse when critical"
        description: "Animate the pill when a limit is critical"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "staleMinutes"
        label: "Stale after"
        description: "Flag the data as stale in the popout after this long"
        options: [
            {label: "30 min", value: "30"},
            {label: "1 hour", value: "60"},
            {label: "3 hours", value: "180"}
        ]
        defaultValue: "60"
    }

    StringSetting {
        settingKey: "cachePath"
        label: "Cache path override"
        description: "Leave blank for the default ($XDG_CACHE_HOME/dms-claude-usage.json)"
        placeholder: ""
        defaultValue: ""
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Live updates"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Wraps your Claude Code statusline (backed up first) so usage data refreshes automatically. Remove to restore your original statusline."
            wrapMode: Text.WordWrap
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        Row {
            spacing: Theme.spacingM

            DankButton {
                text: "Set up live updates"
                iconName: "bolt"
                onClicked: {
                    Quickshell.execDetached(["sh", root.pluginDir + "install.sh"])
                    ToastService.showInfo("Claude Usage: live updates enabled",
                        "Open or continue a Claude Code session to populate the data.")
                }
            }

            DankButton {
                text: "Remove"
                iconName: "delete"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                onClicked: {
                    Quickshell.execDetached(["sh", root.pluginDir + "uninstall.sh"])
                    ToastService.showInfo("Claude Usage: live updates disabled")
                }
            }
        }
    }
}
