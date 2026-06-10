import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    pluginId: "claudeUsage"

    readonly property string displayStyle: pluginData.displayStyle || "filledRing"
    readonly property bool showFiveHour: pluginData.showFiveHour !== undefined ? pluginData.showFiveHour : true
    readonly property bool showWeekly: pluginData.showWeekly !== undefined ? pluginData.showWeekly : true
    readonly property bool showSonnetWeekly: pluginData.showSonnetWeekly !== undefined ? pluginData.showSonnetWeekly : false
    readonly property int warningThreshold: pluginData.warningThreshold !== undefined ? parseInt(pluginData.warningThreshold) : 70
    readonly property int criticalThreshold: pluginData.criticalThreshold !== undefined ? parseInt(pluginData.criticalThreshold) : 90
    readonly property bool pulseOnCritical: pluginData.pulseOnCritical !== undefined ? pluginData.pulseOnCritical : true
    readonly property int staleMinutes: pluginData.staleMinutes !== undefined ? parseInt(pluginData.staleMinutes) : 60
    readonly property int refreshSeconds: pluginData.refreshInterval !== undefined ? parseInt(pluginData.refreshInterval) : 300
    readonly property string cachePathOverride: pluginData.cachePath || ""

    ClaudeUsageData {
        id: data
        cachePath: root.cachePathOverride
        refreshMs: root.refreshSeconds * 1000
    }

    // Accessors so the inline bar/popout Components never reference the `data`
    // child id directly (it isn't reliably in their binding scope across DMS
    // versions); everything is reached through `root`, which always resolves.
    readonly property bool hasData: data.hasData
    readonly property bool fetchFailed: data.fetchFailed
    readonly property int nowTick: data.nowEpoch
    readonly property bool anyCritical:
        (showFiveHour && data.fiveHour && isCritical(data.fiveHour.used_percentage))
        || (showWeekly && data.sevenDay && isCritical(data.sevenDay.used_percentage))
    function countdown(resetEpoch) { return data.countdown(resetEpoch) }
    function minutesSinceCapture() { return data.minutesSinceCapture() }

    function rampColor(pct) {
        if (pct >= root.criticalThreshold) return Theme.error
        if (pct >= root.warningThreshold) return Theme.warning
        return Theme.primary
    }

    function isCritical(pct) {
        return pct >= root.criticalThreshold
    }

    function _shownLimits() {
        const out = []
        if (root.showFiveHour && data.fiveHour)
            out.push({name: "5-hour", short: "5h", pct: data.fiveHour.used_percentage, reset: data.fiveHour.resets_at})
        if (root.showWeekly && data.sevenDay)
            out.push({name: "Weekly", short: "7d", pct: data.sevenDay.used_percentage, reset: data.sevenDay.resets_at})
        if (root.showSonnetWeekly && data.sevenDaySonnet)
            out.push({name: "Weekly (Sonnet)", short: "7dS", pct: data.sevenDaySonnet.used_percentage, reset: data.sevenDaySonnet.resets_at})
        return out
    }

    function _numbersText() {
        return "✳ " + root._shownLimits().map(l => l.pct + "%").join(" · ")
    }

    horizontalBarPill: Component {
        StyledRect {
            id: pill
            implicitWidth: rowH.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            SequentialAnimation on opacity {
                running: root.pulseOnCritical && root.anyCritical
                loops: Animation.Infinite
                NumberAnimation { to: 0.55; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }

            RowLayout {
                id: rowH
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    visible: !root.hasData
                    text: "✳ --"
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: root.hasData && (root.displayStyle === "filledRing" || root.displayStyle === "hollowRing")
                           ? root._shownLimits() : []
                    delegate: UsageRing {
                        percentage: modelData.pct
                        ringColor: root.rampColor(modelData.pct)
                        hollow: root.displayStyle === "hollowRing"
                        diameter: Math.max(12, Math.min(pill.height - 8, 22))
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                StyledText {
                    visible: root.hasData && root.displayStyle === "numbers"
                    text: root._numbersText()
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: root.hasData && root.displayStyle === "bar" ? root._shownLimits() : []
                    delegate: Row {
                        spacing: 4
                        Rectangle {
                            width: 34
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.surfaceVariant
                            Rectangle {
                                width: parent.width * Math.min(1, modelData.pct / 100)
                                height: parent.height
                                radius: 3
                                color: root.rampColor(modelData.pct)
                            }
                        }
                        StyledText {
                            text: modelData.pct + "%"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            id: pillV
            implicitHeight: colV.implicitHeight + Theme.spacingM * 2
            width: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            ColumnLayout {
                id: colV
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    visible: !root.hasData
                    text: "✳"
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: root.hasData ? root._shownLimits() : []
                    delegate: UsageRing {
                        percentage: modelData.pct
                        ringColor: root.rampColor(modelData.pct)
                        hollow: root.displayStyle === "hollowRing"
                        diameter: Math.max(12, Math.min(pillV.width - 8, 20))
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    popoutWidth: 320
    popoutHeight: 240

    popoutContent: Component {
        PopoutComponent {
            id: popoutInner
            headerText: "Claude Usage"
            showCloseButton: true
            closePopout: function() { root.closePopout() }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Repeater {
                    model: root._shownLimits()
                    delegate: Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        UsageRing {
                            percentage: modelData.pct
                            ringColor: root.rampColor(modelData.pct)
                            diameter: 34
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
                                property int _nowEpoch: root.nowTick
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
                        ? "Couldn't read Claude usage. Is Claude Code signed in? Run `claude` and `/login`, then reopen."
                        : "Loading usage…"
                    wrapMode: Text.WordWrap
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }

                StyledText {
                    width: parent.width
                    visible: root.hasData
                    property int mins: root.minutesSinceCapture()
                    property int _nowEpoch: root.nowTick
                    text: mins < 0 ? "" : (mins <= root.staleMinutes
                        ? "updated " + (mins <= 0 ? "just now" : mins + "m ago")
                        : "data may be stale (" + mins + "m) — open a Claude Code session to refresh.")
                    color: mins > root.staleMinutes ? Theme.warning : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
