// Fetches Claude Code usage from the OAuth endpoint (via fetch-usage.sh, using
// the local credentials), caches it, and exposes the parsed model. Zero setup.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Item {
    id: root

    // --- outputs ---
    property var fiveHour: null         // {used_percentage:int, resets_at:int} or null
    property var sevenDay: null
    property int capturedAt: 0
    property bool hasData: fiveHour !== null || sevenDay !== null
    property bool fetchFailed: false    // last fetch failed (e.g. not signed in)
    property int now: Math.floor(Date.now() / 1000)  // ticks every second

    readonly property int refreshSeconds: 300
    readonly property string scriptPath: Qt.resolvedUrl("fetch-usage.sh").toString().replace("file://", "")
    readonly property string cachePath:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/dms-claude-usage.json"

    // Human countdown to a reset epoch, e.g. "5d 14h", "3h 12m", "8m".
    function countdown(reset) {
        let s = reset - now
        if (!reset || s <= 0) return "now"
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return Math.max(1, m) + "m"
    }

    function minutesOld() {
        return capturedAt ? Math.floor((now - capturedAt) / 60) : -1
    }

    function refresh() {
        Proc.runCommand("claudeUsage.fetch", ["sh", scriptPath], function (stdout, exitCode) {
            root.fetchFailed = (exitCode !== 0)
        }, 100)
    }

    Component.onCompleted: refresh()
    Timer { interval: root.refreshSeconds * 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = Math.floor(Date.now() / 1000) }

    FileView {
        id: cacheFile
        path: root.cachePath
        watchChanges: true
        onLoaded: {
            try {
                const o = JSON.parse(cacheFile.text())
                root.capturedAt = o.captured_at || 0
                root.fiveHour = o.five_hour || null
                root.sevenDay = o.seven_day || null
            } catch (e) {
                console.warn("claudeUsage: bad cache:", e)
            }
        }
        onFileChanged: reload()
    }
}
