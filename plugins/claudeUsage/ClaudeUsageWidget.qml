// Claude Code usage limits as a DankBar pill + popout.
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    pluginId: "claudeUsage"

    // Tunables (kept in code to keep the settings UI small).
    readonly property int warnPct: 70    // amber at/above this
    readonly property int critPct: 90    // red at/above this
    readonly property int staleMinutes: 60

    // Settings.
    readonly property string displayStyle: pluginData.displayStyle || "rings"   // "rings" | "numbers"
    readonly property bool showFiveHour: pluginData.showFiveHour !== false
    readonly property bool showWeekly: pluginData.showWeekly !== false

    ClaudeUsageData { id: data }

    // Reach data only through root — inline Components can't resolve a child id.
    readonly property bool hasData: data.hasData
    readonly property bool fetchFailed: data.fetchFailed
    readonly property int tick: data.now
    function countdown(reset) { return data.countdown(reset) }
    function minutesOld() { return data.minutesOld() }

    function color(pct) {
        return pct >= critPct ? Theme.error : pct >= warnPct ? Theme.warning : Theme.primary
    }

    // The limits to display, in order: [{name, pct, reset}, ...].
    function limits() {
        const out = []
        if (showFiveHour && data.fiveHour)
            out.push({name: "5-hour", pct: data.fiveHour.used_percentage, reset: data.fiveHour.resets_at})
        if (showWeekly && data.sevenDay)
            out.push({name: "Weekly", pct: data.sevenDay.used_percentage, reset: data.sevenDay.resets_at})
        return out
    }

    horizontalBarPill: Component {
        StyledRect {
            id: pill
            implicitWidth: row.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    visible: !root.hasData
                    text: "✳ --"
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: root.hasData && root.displayStyle === "rings" ? root.limits() : []
                    delegate: Row {
                        spacing: 5
                        Layout.alignment: Qt.AlignVCenter
                        UsageRing {
                            percentage: modelData.pct
                            ringColor: root.color(modelData.pct)
                            diameter: Math.max(12, Math.min(pill.height - 9, 18))
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: modelData.pct + "%"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                StyledText {
                    visible: root.hasData && root.displayStyle === "numbers"
                    text: "✳ " + root.limits().map(l => l.pct + "%").join(" · ")
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            id: pillV
            width: parent.widgetThickness
            implicitHeight: col.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            ColumnLayout {
                id: col
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    visible: !root.hasData
                    text: "✳"
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: root.hasData ? root.limits() : []
                    delegate: Column {
                        spacing: 1
                        Layout.alignment: Qt.AlignHCenter
                        UsageRing {
                            percentage: modelData.pct
                            ringColor: root.color(modelData.pct)
                            diameter: Math.max(12, Math.min(pillV.width - 8, 18))
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: modelData.pct + "%"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 320
    popoutHeight: 220
    popoutContent: Component {
        PopoutComponent {
            headerText: "Claude Usage"
            showCloseButton: true
            closePopout: function () { root.closePopout() }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Repeater {
                    model: root.limits()
                    delegate: Row {
                        spacing: Theme.spacingM
                        UsageRing {
                            percentage: modelData.pct
                            ringColor: root.color(modelData.pct)
                            diameter: 30
                            thickness: 3.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            StyledText {
                                text: modelData.name
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                            }
                            StyledText {
                                readonly property int t: root.tick   // re-evaluate the countdown each second
                                text: modelData.pct + "% used · resets in " + root.countdown(modelData.reset)
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !root.hasData
                    text: root.fetchFailed
                        ? "Couldn't read Claude usage. Is Claude Code signed in? Run `claude` then `/login`."
                        : "Loading usage…"
                    wrapMode: Text.WordWrap
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }

                StyledText {
                    readonly property int mins: root.hasData ? root.minutesOld() : -1
                    readonly property int t: root.tick
                    visible: mins >= 0
                    text: mins <= root.staleMinutes
                        ? "updated " + (mins <= 0 ? "just now" : mins + "m ago")
                        : "stale (" + mins + "m) — is Claude Code signed in?"
                    color: mins > root.staleMinutes ? Theme.warning : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
