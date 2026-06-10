import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string cachePath: ""

    property int capturedAt: 0
    property var fiveHour: null
    property var sevenDay: null
    property var sevenDaySonnet: null
    property bool hasData: fiveHour !== null || sevenDay !== null
    property int nowEpoch: Math.floor(Date.now() / 1000)

    // Whether the statusline writer is wired into Claude Code's settings.
    property bool writerInstalled: false
    readonly property string _claudeSettingsPath:
        (Quickshell.env("HOME") || "") + "/.claude/settings.json"

    readonly property string _defaultPath:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/dms-claude-usage.json"
    readonly property string _resolvedPath: cachePath !== "" ? cachePath : _defaultPath

    function _parse(txt) {
        try {
            const o = JSON.parse(txt)
            capturedAt = o.captured_at || 0
            fiveHour = o.five_hour || null
            sevenDay = o.seven_day || null
            sevenDaySonnet = o.seven_day_sonnet || null
        } catch (e) {
            console.warn("claudeUsage: cache parse failed:", e)
        }
    }

    function countdown(resetEpoch) {
        if (!resetEpoch) return "—"
        let s = resetEpoch - nowEpoch
        if (s <= 0) return "resetting…"
        const h = Math.floor(s / 3600)
        s -= h * 3600
        const m = Math.floor(s / 60)
        if (h > 0) return h + "h " + m + "m"
        if (m > 0) return m + "m"
        return "<1m"
    }

    function minutesSinceCapture() {
        if (!capturedAt) return -1
        return Math.floor((nowEpoch - capturedAt) / 60)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.nowEpoch = Math.floor(Date.now() / 1000)
    }

    FileView {
        id: cacheFile
        path: root._resolvedPath
        blockLoading: false
        watchChanges: true
        onLoaded: root._parse(cacheFile.text())
        onFileChanged: reload()
        onLoadFailed: error => {
            console.log("claudeUsage: cache not loaded:", error)
        }
    }

    FileView {
        id: claudeSettingsFile
        path: root._claudeSettingsPath
        blockLoading: false
        watchChanges: true
        onLoaded: {
            try {
                const cmd = (JSON.parse(claudeSettingsFile.text())
                    .statusLine || {}).command || ""
                root.writerInstalled = cmd.indexOf("claude-usage-writer.sh") !== -1
            } catch (e) {
                root.writerInstalled = false
            }
        }
        onFileChanged: reload()
        onLoadFailed: error => { root.writerInstalled = false }
    }
}
