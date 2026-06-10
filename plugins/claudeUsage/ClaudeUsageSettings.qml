import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "claudeUsage"

    SelectionSetting {
        settingKey: "displayStyle"
        label: "Display style"
        description: "How limits appear in the bar"
        options: [
            {label: "Rings", value: "rings"},
            {label: "Numbers", value: "numbers"}
        ]
        defaultValue: "rings"
    }

    ToggleSetting {
        settingKey: "showFiveHour"
        label: "Show 5-hour limit"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showWeekly"
        label: "Show weekly limit"
        defaultValue: true
    }
}
