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
    readonly property string cachePathOverride: pluginData.cachePath || ""

    ClaudeUsageData {
        id: data
        cachePath: root.cachePathOverride
    }

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

            property bool anyCritical: (root.showFiveHour && data.fiveHour && root.isCritical(data.fiveHour.used_percentage))
                || (root.showWeekly && data.sevenDay && root.isCritical(data.sevenDay.used_percentage))

            SequentialAnimation on opacity {
                running: root.pulseOnCritical && pill.anyCritical
                loops: Animation.Infinite
                NumberAnimation { to: 0.55; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }

            RowLayout {
                id: rowH
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    visible: !data.hasData
                    text: "✳ --"
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: data.hasData && (root.displayStyle === "filledRing" || root.displayStyle === "hollowRing")
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
                    visible: data.hasData && root.displayStyle === "numbers"
                    text: root._numbersText()
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: data.hasData && root.displayStyle === "bar" ? root._shownLimits() : []
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
                    visible: !data.hasData
                    text: "✳"
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: data.hasData ? root._shownLimits() : []
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
                                property int _nowEpoch: data.nowEpoch
                                text: modelData.pct + "% used · resets in " + data.countdown(modelData.reset)
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !data.hasData
                    text: "No data yet. Install the writer and open a Claude Code session."
                    wrapMode: Text.WordWrap
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }

                StyledText {
                    width: parent.width
                    visible: data.hasData
                    property int mins: data.minutesSinceCapture()
                    property int _nowEpoch: data.nowEpoch
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
