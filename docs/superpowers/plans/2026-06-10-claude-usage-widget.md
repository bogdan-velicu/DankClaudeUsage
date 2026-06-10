# Claude Usage DankBar Widget — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `DankClaudeUsage`, a DankMaterialShell plugin that shows Claude Code's 5-hour and weekly subscription limits in the bar, fed by a statusline writer through a cache file.

**Architecture:** Three units with one file contract. A shell **writer** consumes the `rate_limits` object Claude Code emits on statusline stdin and atomically writes `~/.cache/dms-claude-usage.json`. A QML **plugin** (pure consumer) reads that cache via `FileView`, renders one of four theme-colored pill styles plus a popout with live reset countdowns. An **installer** wraps the user's existing Claude statusline (with backup).

**Tech Stack:** POSIX shell + `jq` (writer/installer), QML/Quickshell + DMS plugin API (`PluginComponent`, `PluginSettings`, `FileView`, `Canvas`, `Theme`).

---

## File Structure

```
~/Projects/DankClaudeUsage/
├── LICENSE                              # MIT
├── README.md                           # usage, install, screenshots
├── .gitignore
├── plugins/claudeUsage/                # the DMS plugin (symlinked into config)
│   ├── plugin.json                     # manifest
│   ├── ClaudeUsageData.qml             # FileView reader + parsed model + countdown clock
│   ├── UsageRing.qml                   # one Canvas ring (track + arc + center text)
│   ├── ClaudeUsageWidget.qml           # PluginComponent: pills + popout
│   └── ClaudeUsageSettings.qml         # PluginSettings UI
├── writer/
│   ├── claude-usage-writer.sh          # stdin -> cache, passthrough to wrapped cmd
│   ├── install.sh                      # wrap statusline (backup first)
│   └── uninstall.sh                    # restore backup
├── fixtures/                           # sample cache + stdin files for testing
│   ├── stdin-normal.json
│   ├── stdin-iso-resets.json
│   ├── stdin-no-ratelimits.json
│   ├── cache-low.json
│   ├── cache-critical.json
│   └── cache-stale.json
└── tests/
    ├── test-writer.sh                  # asserts writer output for each stdin fixture
    └── test-manifest.sh               # validates plugin.json against the DMS schema
```

Responsibilities: `ClaudeUsageData.qml` owns all data/parse/time logic (no visuals); `UsageRing.qml` owns ring drawing (no data logic); `ClaudeUsageWidget.qml` composes pills + popout; settings are isolated in `ClaudeUsageSettings.qml`. Writer logic is isolated from installer plumbing.

---

## Task 1: Repo scaffold

**Files:**
- Create: `LICENSE`, `.gitignore`, `README.md`, dirs `plugins/claudeUsage/`, `writer/`, `fixtures/`, `tests/`

- [ ] **Step 1: Create directories and .gitignore**

```bash
cd ~/Projects/DankClaudeUsage
mkdir -p plugins/claudeUsage writer fixtures tests
cat > .gitignore <<'EOF'
*.tmp
*.tmp.*
*.bak
.DS_Store
EOF
```

- [ ] **Step 2: Create MIT LICENSE**

```bash
cd ~/Projects/DankClaudeUsage
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Bogdan Velicu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

- [ ] **Step 3: Create README placeholder (filled in Task 11)**

```bash
cd ~/Projects/DankClaudeUsage
printf '# DankClaudeUsage\n\nClaude Code usage limits widget for DankMaterialShell.\n\nSee `docs/superpowers/specs/` for the design.\n' > README.md
```

- [ ] **Step 4: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add -A
git commit -m "chore: scaffold repo (license, dirs, gitignore)"
```

---

## Task 2: Test fixtures

**Files:**
- Create: `fixtures/stdin-normal.json`, `fixtures/stdin-iso-resets.json`, `fixtures/stdin-no-ratelimits.json`

These are minimal Claude Code statusline stdin samples used to drive the writer tests.

- [ ] **Step 1: Create normal stdin fixture (epoch resets, like CC 2.1.170)**

```bash
cd ~/Projects/DankClaudeUsage
cat > fixtures/stdin-normal.json <<'EOF'
{
  "model": {"display_name": "Opus 4.8"},
  "workspace": {"current_dir": "/home/user/proj"},
  "context_window": {"used_percentage": 42.0},
  "rate_limits": {
    "five_hour": {"used_percentage": 15, "resets_at": 1781091000},
    "seven_day": {"used_percentage": 4, "resets_at": 1781575200}
  }
}
EOF
```

- [ ] **Step 2: Create ISO-resets fixture (older format + sonnet block)**

```bash
cd ~/Projects/DankClaudeUsage
cat > fixtures/stdin-iso-resets.json <<'EOF'
{
  "rate_limits": {
    "five_hour": {"used_percentage": 88, "resets_at": "2026-06-10T18:00:00+00:00"},
    "seven_day": {"used_percentage": 67, "resets_at": "2026-06-15T00:00:00+00:00"},
    "seven_day_sonnet": {"used_percentage": 51, "resets_at": "2026-06-15T00:00:00+00:00"}
  }
}
EOF
```

- [ ] **Step 3: Create no-rate-limits fixture (non-Pro/Max or older CC)**

```bash
cd ~/Projects/DankClaudeUsage
cat > fixtures/stdin-no-ratelimits.json <<'EOF'
{
  "model": {"display_name": "Opus 4.8"},
  "context_window": {"used_percentage": 10.0}
}
EOF
```

- [ ] **Step 4: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add fixtures/
git commit -m "test: add statusline stdin fixtures"
```

---

## Task 3: Writer script (TDD)

**Files:**
- Create: `writer/claude-usage-writer.sh`
- Test: `tests/test-writer.sh`

- [ ] **Step 1: Write the failing test**

```bash
cd ~/Projects/DankClaudeUsage
cat > tests/test-writer.sh <<'EOF'
#!/bin/sh
# Test claude-usage-writer.sh against fixtures. Exit non-zero on any failure.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WRITER="$ROOT/writer/claude-usage-writer.sh"
TMPCACHE=$(mktemp)
fail() { echo "FAIL: $1"; exit 1; }

# Case 1: normal payload -> cache has captured_at + both blocks, epoch resets preserved
XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" < "$ROOT/fixtures/stdin-normal.json" >/dev/null
jq -e '.five_hour.used_percentage == 15' "$TMPCACHE" >/dev/null || fail "5h pct"
jq -e '.five_hour.resets_at == 1781091000' "$TMPCACHE" >/dev/null || fail "5h reset epoch"
jq -e '.seven_day.used_percentage == 4' "$TMPCACHE" >/dev/null || fail "7d pct"
jq -e '.captured_at | type == "number"' "$TMPCACHE" >/dev/null || fail "captured_at"

# Case 2: ISO resets -> normalized to epoch; sonnet block present
XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" < "$ROOT/fixtures/stdin-iso-resets.json" >/dev/null
jq -e '.five_hour.resets_at == 1781460000' "$TMPCACHE" >/dev/null || fail "iso->epoch (2026-06-10T18:00Z)"
jq -e '.seven_day_sonnet.used_percentage == 51' "$TMPCACHE" >/dev/null || fail "sonnet block"

# Case 3: no rate_limits -> cache left UNCHANGED (still case-2 content)
XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" < "$ROOT/fixtures/stdin-no-ratelimits.json" >/dev/null
jq -e '.seven_day_sonnet.used_percentage == 51' "$TMPCACHE" >/dev/null || fail "cache should be untouched when no rate_limits"

# Case 4: passthrough -> wrapped command receives stdin and its stdout is printed
OUT=$(XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" cat < "$ROOT/fixtures/stdin-normal.json")
echo "$OUT" | jq -e '.rate_limits.five_hour.used_percentage == 15' >/dev/null || fail "passthrough stdin"

rm -f "$TMPCACHE"
echo "ALL WRITER TESTS PASSED"
EOF
chmod +x tests/test-writer.sh
```

Note: `1781460000` is the epoch for `2026-06-10T18:00:00+00:00` — verify with `date -u -d @1781460000` during implementation and correct the constant if the fixture date differs.

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/test-writer.sh`
Expected: FAIL (writer does not exist yet) — error about missing `writer/claude-usage-writer.sh`.

- [ ] **Step 3: Write the writer**

```bash
cd ~/Projects/DankClaudeUsage
cat > writer/claude-usage-writer.sh <<'EOF'
#!/bin/sh
# claude-usage-writer.sh
# Reads Claude Code statusline JSON on stdin, writes the usage cache atomically,
# and (if extra args are given) execs them as a wrapped statusline command with
# the same stdin so this can chain into an existing statusline.
#
# Cache path: $CACHE_FILE, else $XDG_CACHE_HOME/dms-claude-usage.json,
# else $HOME/.cache/dms-claude-usage.json
set -u
input=$(cat)
cache="${CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/dms-claude-usage.json}"
mkdir -p "$(dirname "$cache")" 2>/dev/null
now=$(date +%s)
tmp="$cache.tmp.$$"

printf '%s' "$input" | jq --argjson now "$now" '
  def norm(b):
    if b == null then null
    else { used_percentage: b.used_percentage,
           resets_at: (b.resets_at | if type=="string" then fromdateiso8601 else . end) }
    end;
  .rate_limits as $rl
  | if ($rl|not) or ($rl == {}) then empty
    else { captured_at: $now,
           five_hour: norm($rl.five_hour),
           seven_day: norm($rl.seven_day) }
         + (if $rl.seven_day_sonnet then {seven_day_sonnet: norm($rl.seven_day_sonnet)} else {} end)
    end
' > "$tmp" 2>/dev/null

if [ -s "$tmp" ] && jq -e . "$tmp" >/dev/null 2>&1; then
  mv -f "$tmp" "$cache"
else
  rm -f "$tmp"
fi

if [ "$#" -gt 0 ]; then
  printf '%s' "$input" | "$@"
fi
EOF
chmod +x writer/claude-usage-writer.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh tests/test-writer.sh`
Expected: `ALL WRITER TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add writer/claude-usage-writer.sh tests/test-writer.sh
git commit -m "feat(writer): statusline->cache writer with iso/epoch normalization"
```

---

## Task 4: Installer / uninstaller (TDD)

**Files:**
- Create: `writer/install.sh`, `writer/uninstall.sh`
- Test: append cases to `tests/test-writer.sh` via a new `tests/test-install.sh`

The installer edits Claude Code's `~/.claude/settings.json` `.statusLine.command`, wrapping the existing command so the writer runs first. It backs up `settings.json` (timestamped) before editing. A `CLAUDE_SETTINGS` env override makes it testable against a temp file.

- [ ] **Step 1: Write the failing test**

```bash
cd ~/Projects/DankClaudeUsage
cat > tests/test-install.sh <<'EOF'
#!/bin/sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
SET="$WORK/settings.json"
fail() { echo "FAIL: $1"; exit 1; }
WRITER="$ROOT/writer/claude-usage-writer.sh"

# Case A: existing command gets wrapped, backup created
cat > "$SET" <<JSON
{"statusLine":{"type":"command","command":"bash /home/u/statusline.sh"}}
JSON
CLAUDE_SETTINGS="$SET" sh "$ROOT/writer/install.sh" >/dev/null || fail "install exit"
jq -e --arg w "$WRITER" '.statusLine.command | startswith("sh " + $w)' "$SET" >/dev/null \
  || fail "command not wrapped with writer"
jq -e '.statusLine.command | contains("bash /home/u/statusline.sh")' "$SET" >/dev/null \
  || fail "original command not preserved"
ls "$SET".bak.* >/dev/null 2>&1 || fail "no backup created"

# Case B: idempotent — second install does not double-wrap
CLAUDE_SETTINGS="$SET" sh "$ROOT/writer/install.sh" >/dev/null
COUNT=$(jq -r '.statusLine.command' "$SET" | grep -o "claude-usage-writer.sh" | wc -l)
[ "$COUNT" -eq 1 ] || fail "double-wrapped (count=$COUNT)"

# Case C: uninstall restores original command
CLAUDE_SETTINGS="$SET" sh "$ROOT/writer/uninstall.sh" >/dev/null || fail "uninstall exit"
jq -e '.statusLine.command == "bash /home/u/statusline.sh"' "$SET" >/dev/null \
  || fail "uninstall did not restore original"

# Case D: no statusLine at all -> installer sets writer as the statusline command
echo '{}' > "$SET"
CLAUDE_SETTINGS="$SET" sh "$ROOT/writer/install.sh" >/dev/null
jq -e --arg w "$WRITER" '.statusLine.command == ("sh " + $w)' "$SET" >/dev/null \
  || fail "no-statusline case"

rm -rf "$WORK"
echo "ALL INSTALL TESTS PASSED"
EOF
chmod +x tests/test-install.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/test-install.sh`
Expected: FAIL — `writer/install.sh` missing.

- [ ] **Step 3: Write install.sh**

```bash
cd ~/Projects/DankClaudeUsage
cat > writer/install.sh <<'EOF'
#!/bin/sh
# install.sh — wrap the user's Claude Code statusline so the usage writer runs
# first. Backs up settings.json before editing. Idempotent.
set -u
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WRITER="$SCRIPT_DIR/claude-usage-writer.sh"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
WRAP="sh $WRITER"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

current=$(jq -r '.statusLine.command // ""' "$SETTINGS")

case "$current" in
  *claude-usage-writer.sh*)
    echo "Already installed: writer is present in statusLine.command."
    exit 0
    ;;
esac

backup="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$backup"
echo "Backed up settings to $backup"

if [ -z "$current" ]; then
  newcmd="$WRAP"
else
  newcmd="$WRAP $current"
fi

tmp="$SETTINGS.tmp.$$"
jq --arg cmd "$newcmd" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS" > "$tmp" \
  && mv -f "$tmp" "$SETTINGS"
echo "Installed. statusLine.command is now: $newcmd"
EOF
chmod +x writer/install.sh
```

- [ ] **Step 4: Write uninstall.sh**

```bash
cd ~/Projects/DankClaudeUsage
cat > writer/uninstall.sh <<'EOF'
#!/bin/sh
# uninstall.sh — remove the writer prefix from statusLine.command, restoring the
# original wrapped command. Falls back to the most recent backup if needed.
set -u
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

current=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null)
case "$current" in
  *claude-usage-writer.sh*)
    # Strip leading "sh <writer> " prefix to recover the wrapped command.
    stripped=$(printf '%s' "$current" | sed -E 's#^sh [^ ]*claude-usage-writer\.sh ?##')
    tmp="$SETTINGS.tmp.$$"
    if [ -z "$stripped" ]; then
      jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv -f "$tmp" "$SETTINGS"
      echo "Removed statusLine (writer had no wrapped command)."
    else
      jq --arg cmd "$stripped" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS" > "$tmp" \
        && mv -f "$tmp" "$SETTINGS"
      echo "Restored statusLine.command to: $stripped"
    fi
    ;;
  *)
    echo "Writer not found in statusLine.command; nothing to do."
    ;;
esac
EOF
chmod +x writer/uninstall.sh
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `sh tests/test-install.sh`
Expected: `ALL INSTALL TESTS PASSED`

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add writer/install.sh writer/uninstall.sh tests/test-install.sh
git commit -m "feat(writer): idempotent install/uninstall with settings backup"
```

---

## Task 5: Plugin manifest + schema validation (TDD)

**Files:**
- Create: `plugins/claudeUsage/plugin.json`
- Test: `tests/test-manifest.sh`

- [ ] **Step 1: Write the failing test**

```bash
cd ~/Projects/DankClaudeUsage
cat > tests/test-manifest.sh <<'EOF'
#!/bin/sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
M="$ROOT/plugins/claudeUsage/plugin.json"
fail() { echo "FAIL: $1"; exit 1; }
jq -e . "$M" >/dev/null 2>&1 || fail "plugin.json is not valid JSON"
for k in id name description version author type capabilities component; do
  jq -e "has(\"$k\")" "$M" >/dev/null || fail "missing required key: $k"
done
jq -e '.id == "claudeUsage"' "$M" >/dev/null || fail "id must be claudeUsage"
jq -e '.type == "widget"' "$M" >/dev/null || fail "type must be widget"
jq -e '.component | test("^\\./.*\\.qml$")' "$M" >/dev/null || fail "component path"
jq -e '.id | test("^[a-zA-Z][a-zA-Z0-9]*$")' "$M" >/dev/null || fail "id pattern"
jq -e '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+")' "$M" >/dev/null || fail "semver"
echo "MANIFEST OK"
EOF
chmod +x tests/test-manifest.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/test-manifest.sh`
Expected: FAIL — plugin.json missing.

- [ ] **Step 3: Write the manifest**

```bash
cd ~/Projects/DankClaudeUsage
cat > plugins/claudeUsage/plugin.json <<'EOF'
{
  "id": "claudeUsage",
  "name": "Claude Usage",
  "description": "Claude Code 5-hour and weekly subscription limits in the bar.",
  "version": "0.1.0",
  "author": "Bogdan Velicu",
  "type": "widget",
  "capabilities": ["dankbar-widget"],
  "component": "./ClaudeUsageWidget.qml",
  "settings": "./ClaudeUsageSettings.qml",
  "icon": "speed",
  "requires_dms": ">=0.1.0",
  "requires": ["jq"],
  "permissions": ["settings_read", "settings_write"]
}
EOF
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh tests/test-manifest.sh`
Expected: `MANIFEST OK`

- [ ] **Step 5: Validate against the official DMS schema (if available locally)**

Run:
```bash
SCHEMA=~/Projects/DankMaterialShell/quickshell/PLUGINS/plugin-schema.json
[ -f "$SCHEMA" ] && jq -e . "$SCHEMA" >/dev/null && echo "schema present (manual cross-check of required fields done in test)"
```
Expected: prints "schema present…". (We assert required fields in the test rather than pulling a JSON-Schema validator dependency.)

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add plugins/claudeUsage/plugin.json tests/test-manifest.sh
git commit -m "feat(plugin): add manifest with schema-field test"
```

---

## Task 6: Cache fixtures for visual states

**Files:**
- Create: `fixtures/cache-low.json`, `fixtures/cache-critical.json`, `fixtures/cache-stale.json`

These let us load each color/stale state at runtime without burning real usage, by pointing the widget's `cachePath` setting at a fixture.

- [ ] **Step 1: Create the three cache fixtures**

```bash
cd ~/Projects/DankClaudeUsage
cat > fixtures/cache-low.json <<'EOF'
{"captured_at": 1781090000,
 "five_hour": {"used_percentage": 15, "resets_at": 1781091000},
 "seven_day": {"used_percentage": 4, "resets_at": 1781575200}}
EOF
cat > fixtures/cache-critical.json <<'EOF'
{"captured_at": 1781090000,
 "five_hour": {"used_percentage": 96, "resets_at": 1781091000},
 "seven_day": {"used_percentage": 73, "resets_at": 1781575200},
 "seven_day_sonnet": {"used_percentage": 60, "resets_at": 1781575200}}
EOF
cat > fixtures/cache-stale.json <<'EOF'
{"captured_at": 1700000000,
 "five_hour": {"used_percentage": 30, "resets_at": 1781091000},
 "seven_day": {"used_percentage": 12, "resets_at": 1781575200}}
EOF
```

- [ ] **Step 2: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add fixtures/cache-*.json
git commit -m "test: add cache fixtures for low/critical/stale states"
```

---

## Task 7: Data component (`ClaudeUsageData.qml`)

**Files:**
- Create: `plugins/claudeUsage/ClaudeUsageData.qml`

This is the non-visual core: reads the cache via `FileView`, exposes parsed properties, and ticks a clock for countdowns. No unit-test harness exists for QML here, so verification is by loading it in a tiny test harness QML and checking `console.log` output in a nested session (Step 4).

- [ ] **Step 1: Write the data component**

```qml
// ClaudeUsageData.qml — non-visual: reads cache, exposes parsed model + clock.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Inputs
    property string cachePath: ""   // blank => default path

    // Outputs (read by the widget)
    property int capturedAt: 0
    property var fiveHour: null      // {used_percentage:int, resets_at:int} or null
    property var sevenDay: null
    property var sevenDaySonnet: null
    property bool hasData: fiveHour !== null || sevenDay !== null
    property int nowEpoch: Math.floor(Date.now() / 1000)  // ticks every second

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
            // keep last good values on parse error
            console.warn("claudeUsage: cache parse failed:", e)
        }
    }

    // Returns "3h 12m", "5m", or "now" for a future epoch; "—" if missing.
    function countdown(resetEpoch) {
        if (!resetEpoch) return "—"
        let s = resetEpoch - nowEpoch
        if (s <= 0) return "resetting…"
        const h = Math.floor(s / 3600); s -= h * 3600
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
        interval: 1000; running: true; repeat: true
        onTriggered: root.nowEpoch = Math.floor(Date.now() / 1000)
    }

    FileView {
        id: cacheFile
        path: root._resolvedPath
        blockLoading: false
        watchChanges: true
        onLoaded: root._parse(cacheFile.text())
        onFileChanged: reload()
        onLoadFailed: function(error) {
            // No cache yet — leave hasData false so the widget shows placeholder.
            console.log("claudeUsage: cache not loaded:", error)
        }
    }
}
```

Note for implementer: confirm `Quickshell.Io` is the correct import providing `FileView` in the pinned build (grep `import Quickshell.Io` in `~/Projects/DankMaterialShell/quickshell/Common/CacheData.qml`). Also confirm `onFileChanged`/`reload()` exist; if the build instead auto-reloads on `watchChanges`, drop the `onFileChanged` handler.

- [ ] **Step 2: Create a temporary harness to verify parsing**

```bash
cd ~/Projects/DankClaudeUsage
cat > /tmp/claudeUsageHarness.qml <<'EOF'
import QtQuick
import "plugins/claudeUsage" as P
Item {
    P.ClaudeUsageData {
        id: d
        cachePath: Qt.resolvedUrl("fixtures/cache-critical.json").toString().replace("file://","")
        Component.onCompleted: console.log("loaded later via onLoaded")
        onHasDataChanged: {
            console.log("hasData:", hasData,
                        "5h:", JSON.stringify(fiveHour),
                        "countdown:", countdown(fiveHour ? fiveHour.resets_at : 0),
                        "staleMin:", minutesSinceCapture())
        }
    }
}
EOF
```

- [ ] **Step 3: Run the harness**

Run: `qs -p /tmp/claudeUsageHarness.qml` (Ctrl+C after the log line appears; this needs a Wayland session — use the nested-niri test flow).
Expected: a log line showing `hasData: true 5h: {"used_percentage":96,...} countdown: ... staleMin: ...`.

- [ ] **Step 4: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add plugins/claudeUsage/ClaudeUsageData.qml
git commit -m "feat(plugin): cache reader + parsed model + countdown clock"
```

---

## Task 8: Ring component (`UsageRing.qml`)

**Files:**
- Create: `plugins/claudeUsage/UsageRing.qml`

A self-contained `Canvas` ring: track + progress arc + centered percentage text. Used by the `filledRing` and `hollowRing` display styles. Color is passed in (ramp computed by the widget).

- [ ] **Step 1: Write the ring component**

```qml
// UsageRing.qml — one circular progress ring with centered text.
import QtQuick
import qs.Common

Item {
    id: root
    property int percentage: 0          // 0..100
    property color ringColor: Theme.primary
    property color trackColor: Theme.surfaceVariant
    property bool hollow: false         // hollow => text below ring instead of centered
    property string label: ""           // e.g. "5h"
    property real thickness: 3
    property int diameter: 22

    implicitWidth: diameter
    implicitHeight: hollow ? diameter + labelText.implicitHeight + 2 : diameter

    Canvas {
        id: canvas
        width: root.diameter
        height: root.diameter
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2, cy = height / 2
            const r = (Math.min(width, height) - root.thickness) / 2
            const start = -Math.PI / 2
            const frac = Math.max(0, Math.min(1, root.percentage / 100))
            // track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.lineWidth = root.thickness
            ctx.strokeStyle = root.trackColor
            ctx.stroke()
            // progress
            if (frac > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + frac * 2 * Math.PI)
                ctx.lineWidth = root.thickness
                ctx.lineCap = "round"
                ctx.strokeStyle = root.ringColor
                ctx.stroke()
            }
        }
        Connections {
            target: root
            function onPercentageChanged() { canvas.requestPaint() }
            function onRingColorChanged() { canvas.requestPaint() }
            function onTrackColorChanged() { canvas.requestPaint() }
        }
    }

    StyledText {
        id: centerText
        visible: !root.hollow
        anchors.centerIn: canvas
        text: root.percentage + "%"
        font.pixelSize: Math.round(root.diameter * 0.34)
        color: Theme.surfaceText
    }

    StyledText {
        id: labelText
        visible: root.hollow
        anchors.top: canvas.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: canvas.horizontalCenter
        text: root.percentage + "%"
        font.pixelSize: Math.round(root.diameter * 0.32)
        color: Theme.surfaceText
    }
}
```

Note: `StyledText` and `Theme` come from DMS (`import qs.Common`). When running standalone (outside DMS) these imports fail — the ring is only verified inside the full plugin under DMS (Task 11 runtime check), not via the standalone harness.

- [ ] **Step 2: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add plugins/claudeUsage/UsageRing.qml
git commit -m "feat(plugin): Canvas usage ring (filled/hollow)"
```

---

## Task 9: Widget component (`ClaudeUsageWidget.qml`)

**Files:**
- Create: `plugins/claudeUsage/ClaudeUsageWidget.qml`

Composes the data component, the color ramp, all four pill styles, and the popout. Reads settings via `PluginService.loadPluginData` (matching the plugin-system docs).

- [ ] **Step 1: Write the widget**

```qml
// ClaudeUsageWidget.qml — pill(s) + popout for Claude usage limits.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ---- settings (loaded with defaults) ----
    property string displayStyle: PluginService.loadPluginData("claudeUsage", "displayStyle", "filledRing")
    property bool showFiveHour: PluginService.loadPluginData("claudeUsage", "showFiveHour", true)
    property bool showWeekly: PluginService.loadPluginData("claudeUsage", "showWeekly", true)
    property bool showSonnetWeekly: PluginService.loadPluginData("claudeUsage", "showSonnetWeekly", false)
    property int warningThreshold: parseInt(PluginService.loadPluginData("claudeUsage", "warningThreshold", "70"))
    property int criticalThreshold: parseInt(PluginService.loadPluginData("claudeUsage", "criticalThreshold", "90"))
    property bool pulseOnCritical: PluginService.loadPluginData("claudeUsage", "pulseOnCritical", true)
    property int staleMinutes: parseInt(PluginService.loadPluginData("claudeUsage", "staleMinutes", "60"))
    property string cachePath: PluginService.loadPluginData("claudeUsage", "cachePath", "")

    // Re-read settings when they change in the settings UI.
    Connections {
        target: PluginService
        function onGlobalVarChanged(pluginId, varName) {
            if (pluginId !== "claudeUsage") return
            root.displayStyle = PluginService.loadPluginData("claudeUsage", "displayStyle", "filledRing")
            root.showFiveHour = PluginService.loadPluginData("claudeUsage", "showFiveHour", true)
            root.showWeekly = PluginService.loadPluginData("claudeUsage", "showWeekly", true)
            root.showSonnetWeekly = PluginService.loadPluginData("claudeUsage", "showSonnetWeekly", false)
            root.warningThreshold = parseInt(PluginService.loadPluginData("claudeUsage", "warningThreshold", "70"))
            root.criticalThreshold = parseInt(PluginService.loadPluginData("claudeUsage", "criticalThreshold", "90"))
            root.pulseOnCritical = PluginService.loadPluginData("claudeUsage", "pulseOnCritical", true)
            root.staleMinutes = parseInt(PluginService.loadPluginData("claudeUsage", "staleMinutes", "60"))
            root.cachePath = PluginService.loadPluginData("claudeUsage", "cachePath", "")
        }
    }

    ClaudeUsageData { id: data; cachePath: root.cachePath }

    function rampColor(pct) {
        if (pct >= root.criticalThreshold) return Theme.error
        if (pct >= root.warningThreshold) return Theme.warning
        return Theme.primary
    }
    function isCritical(pct) { return pct >= root.criticalThreshold }

    // ---------- horizontal pill ----------
    horizontalBarPill: Component {
        StyledRect {
            id: pill
            implicitWidth: rowH.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            // pulse on any shown critical limit
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

                // placeholder when no data
                StyledText {
                    visible: !data.hasData
                    text: "✳ --"
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                }

                // filledRing / hollowRing
                Repeater {
                    model: data.hasData && (root.displayStyle === "filledRing" || root.displayStyle === "hollowRing")
                           ? root._shownLimits() : []
                    delegate: UsageRing {
                        percentage: modelData.pct
                        ringColor: root.rampColor(modelData.pct)
                        hollow: root.displayStyle === "hollowRing"
                        diameter: Math.min(parent.height - 4, 22)
                    }
                }

                // numbers
                StyledText {
                    visible: data.hasData && root.displayStyle === "numbers"
                    text: root._numbersText()
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                // bar
                Repeater {
                    model: data.hasData && root.displayStyle === "bar" ? root._shownLimits() : []
                    delegate: Row {
                        spacing: 4
                        Rectangle {
                            width: 34; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.surfaceVariant
                            Rectangle {
                                width: parent.width * Math.min(1, modelData.pct / 100)
                                height: parent.height; radius: 3
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

    // ---------- vertical pill (stacked, numbers/rings only) ----------
    verticalBarPill: Component {
        StyledRect {
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
                        diameter: Math.min(parent.width - 4, 20)
                    }
                }
            }
        }
    }

    // ---------- popout ----------
    popoutWidth: 320
    popoutHeight: 240
    popoutContent: Component {
        PopoutComponent {
            headerText: "Claude Usage"
            showCloseButton: true

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

    // ---------- helpers ----------
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
}
```

Note for implementer: confirm `PopoutComponent` content children layout (the docs show children render below the header). If `_shownLimits()` reactivity lags (computed functions don't auto-update on `data` change), convert it to a `property var shownLimits` recomputed in a `Connections` on `data.fiveHourChanged`/`sevenDayChanged`/`nowEpochChanged` is NOT needed for pct, but the popout countdown text already re-evaluates via `data.countdown(...)` binding to `data.nowEpoch`. Verify the popout countdown updates live; if not, bind the secondary text through a property that references `data.nowEpoch`.

- [ ] **Step 2: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add plugins/claudeUsage/ClaudeUsageWidget.qml
git commit -m "feat(plugin): widget with 4 pill styles + popout"
```

---

## Task 10: Settings component (`ClaudeUsageSettings.qml`)

**Files:**
- Create: `plugins/claudeUsage/ClaudeUsageSettings.qml`

- [ ] **Step 1: Write the settings UI**

```qml
// ClaudeUsageSettings.qml
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
        settingKey: "showFiveHour"; label: "Show 5-hour limit"
        description: "Display the rolling 5-hour window"; defaultValue: true
    }
    ToggleSetting {
        settingKey: "showWeekly"; label: "Show weekly limit"
        description: "Display the rolling 7-day window"; defaultValue: true
    }
    ToggleSetting {
        settingKey: "showSonnetWeekly"; label: "Show weekly Sonnet limit"
        description: "Display the Sonnet-specific weekly quota when available"; defaultValue: false
    }
    SelectionSetting {
        settingKey: "warningThreshold"; label: "Warning threshold"
        description: "Switch to the warning color at this %"
        options: [{label:"60%",value:"60"},{label:"70%",value:"70"},{label:"80%",value:"80"}]
        defaultValue: "70"
    }
    SelectionSetting {
        settingKey: "criticalThreshold"; label: "Critical threshold"
        description: "Switch to the error color (and pulse) at this %"
        options: [{label:"85%",value:"85"},{label:"90%",value:"90"},{label:"95%",value:"95"}]
        defaultValue: "90"
    }
    ToggleSetting {
        settingKey: "pulseOnCritical"; label: "Pulse when critical"
        description: "Animate the pill when a limit is critical"; defaultValue: true
    }
    SelectionSetting {
        settingKey: "staleMinutes"; label: "Stale after"
        description: "Flag the data as stale in the popout after this long"
        options: [{label:"30 min",value:"30"},{label:"1 hour",value:"60"},{label:"3 hours",value:"180"}]
        defaultValue: "60"
    }
    StringSetting {
        settingKey: "cachePath"; label: "Cache path override"
        description: "Leave blank for the default ($XDG_CACHE_HOME/dms-claude-usage.json)"
        placeholder: ""; defaultValue: ""
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add plugins/claudeUsage/ClaudeUsageSettings.qml
git commit -m "feat(plugin): settings UI"
```

---

## Task 11: Runtime integration, README, release prep

**Files:**
- Modify: `README.md`
- Create symlink (not committed): `~/.config/DankMaterialShell/plugins/claudeUsage`

- [ ] **Step 1: Symlink the plugin into DMS and seed a fixture cache**

```bash
ln -sfn ~/Projects/DankClaudeUsage/plugins/claudeUsage \
        ~/.config/DankMaterialShell/plugins/claudeUsage
cp ~/Projects/DankClaudeUsage/fixtures/cache-critical.json \
   "${XDG_CACHE_HOME:-$HOME/.cache}/dms-claude-usage.json"
```

- [ ] **Step 2: Load in DMS and verify each display style**

Using the nested-niri + locally-built quickshell flow: start the shell, open Settings → Plugins, Scan, enable "Claude Usage", add it to the bar. Then in Settings cycle `displayStyle` through filledRing / hollowRing / numbers / bar.
Expected: pill renders; with `cache-critical.json` the 5-hour ring is red and the pill pulses; clicking opens the popout with two rows and "resets in …" countdowns ticking each second; footer shows the stale warning (fixture `captured_at` is old).
Self-verify by screenshotting each style (Playwright/grim per the user's setup) rather than asking for manual checks.

- [ ] **Step 3: Verify live data path end-to-end**

```bash
sh ~/Projects/DankClaudeUsage/writer/install.sh
# open any Claude Code session so the statusline renders, then:
cat "${XDG_CACHE_HOME:-$HOME/.cache}/dms-claude-usage.json"
```
Expected: the cache now reflects real `five_hour`/`seven_day` values; the widget updates within a second or two (FileView watch). Clear the `cachePath` override in settings if it was pointed at a fixture.

- [ ] **Step 4: Run the full test suite**

Run:
```bash
cd ~/Projects/DankClaudeUsage
sh tests/test-writer.sh && sh tests/test-install.sh && sh tests/test-manifest.sh
```
Expected: all three print their PASS lines.

- [ ] **Step 5: Write the README**

Fill `README.md` with: what it does, screenshots of each style, install (clone, symlink the plugin, run `writer/install.sh`, enable in DMS), how the writer works + the OAuth alternative and its caveats, settings table, uninstall (`writer/uninstall.sh`), requirements (`jq`, Claude Code ≥2.1, Pro/Max), and a note that the plugin API is experimental. (Content assembled from `docs/superpowers/specs/2026-06-10-claude-usage-widget-design.md`.)

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/DankClaudeUsage
git add README.md
git commit -m "docs: README with install, styles, writer, settings"
```

- [ ] **Step 7: Release prep (manual, after the user is happy)**

Create the GitHub repo, push, add screenshots to the README, then submit to the DMS Plugin Registry (plugins.danklinux.com) per their contribution flow. Tag `v0.1.0`.

---

## Self-Review Notes

- **Spec coverage:** writer (T3), install/backup (T4), cache schema + atomic write (T3), manifest (T5), data reader + countdown + stale (T7), four display styles + theme ramp + pulse (T8/T9), popout with live countdown + stale footer (T9), all settings keys (T10), error/placeholder states (T9), fixtures for states (T2/T6), dev-loop symlink + runtime test + release (T11). OAuth alternative documented in README (T11 Step 5), not built — matches spec ("optional, not default").
- **Type consistency:** settings keys/defaults in T10 match the `loadPluginData` reads in T9; `_shownLimits()` object shape `{name,short,pct,reset}` is consumed consistently in pills and popout; `ClaudeUsageData` property names (`fiveHour`/`sevenDay`/`sevenDaySonnet`/`capturedAt`/`countdown`/`minutesSinceCapture`) match their uses in T9.
- **Known verification points flagged inline:** `Quickshell.Io` import + `FileView` reload semantics (T7), `_shownLimits()` reactivity / popout countdown live-update (T9), `PopoutComponent` child layout (T9). These are runtime checks, not placeholders — exact code is provided and adjusted only if the pinned build differs.
