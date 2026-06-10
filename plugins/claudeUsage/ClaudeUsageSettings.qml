import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "claudeUsage"

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
}
