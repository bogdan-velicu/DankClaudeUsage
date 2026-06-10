// ClaudeUsageData.qml — non-visual: fetches usage from the Claude Code OAuth
// endpoint (via fetch-usage.sh, using the local credentials), caches it, and
// exposes the parsed model + a countdown clock. Zero setup.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Item {
    id: root

    property string cachePath: ""      // blank => default path
    property int refreshMs: 300000     // poll interval

    property int capturedAt: 0
    property var fiveHour: null         // {used_percentage:int, resets_at:int} or null
    property var sevenDay: null
    property var sevenDaySonnet: null
    property bool hasData: fiveHour !== null || sevenDay !== null
    property bool fetchFailed: false    // last fetch failed (e.g. not logged in / token expired)
    property int nowEpoch: Math.floor(Date.now() / 1000)

    readonly property string _scriptPath:
        Qt.resolvedUrl("fetch-usage.sh").toString().replace("file://", "")
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

    // Run fetch-usage.sh; it writes the cache, which the FileView below picks up.
    function refresh() {
        const cmd = cachePath !== ""
            ? ["sh", "-c", "CACHE_FILE='" + cachePath + "' sh '" + _scriptPath + "'"]
            : ["sh", _scriptPath]
        Proc.runCommand("claudeUsage.fetch", cmd, function (stdout, exitCode) {
            root.fetchFailed = (exitCode !== 0)
        }, 100)
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

    Component.onCompleted: root.refresh()

    Timer {
        interval: root.refreshMs
        running: true
        repeat: true
        onTriggered: root.refresh()
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
            // No cache yet — the first refresh() will create it.
        }
    }
}
