# DankClaudeUsage — DMS DankBar Widget Design

**Date:** 2026-06-10
**Status:** Approved design, pre-implementation
**Target:** DankMaterialShell (DMS) plugin, distributed publicly + submitted to the DMS Plugin Registry (plugins.danklinux.com)

## Goal

A DankBar widget that displays the user's **official Claude Code subscription rate limits** —
the 5-hour window and the 7-day (weekly) window — as polished, theme-aware indicators with a
detailed click popout. Same numbers as Claude Code's `/usage` command.

Non-goals: token/cost accounting (ccusage territory), per-model breakdown beyond the optional
weekly-Sonnet quota, API-key (non-subscription) usage.

## Background / Data Source

Claude Code **2.1.x** passes a `rate_limits` object on the **statusline stdin** for Pro/Max
subscribers. Verified live against Claude Code 2.1.170 — actual payload:

```json
"rate_limits": {
  "five_hour": { "used_percentage": 15, "resets_at": 1781091000 },
  "seven_day": { "used_percentage": 4,  "resets_at": 1781575200 }
}
```

Key facts established during research:
- `used_percentage` — integer 0–100.
- `resets_at` — **Unix epoch seconds** (integer) in 2.1.170. (Older docs/tools describe an ISO
  8601 string; the writer normalizes both to epoch.)
- `seven_day_sonnet` — an optional sibling block on some accounts / when on Sonnet. Absent in the
  verified payload; handled as optional.
- The same data is also available from the undocumented OAuth endpoint
  `GET https://api.anthropic.com/api/oauth/usage` (Bearer token from `~/.claude/.credentials.json`,
  headers `anthropic-beta: oauth-2025-04-20` + `User-Agent: claude-code/<version>`), but that
  endpoint is aggressively 429-throttled (safe only ≥180s) and the token cannot be self-refreshed
  by a third party. Used only as an optional alternative writer, not the primary path.

**Chosen approach (A): statusline-fed cache.** A writer script consumes the `rate_limits` Claude
Code already emits and writes a small cache file. The widget is a pure consumer of that file.
Rationale: zero credential handling in the widget, zero network from the widget, accurate while a
session runs, and token refresh is handled by Claude Code itself. The reset countdown ticks
client-side from `resets_at`, so the popout stays useful even when idle.

## Architecture

Three well-bounded units communicating through one file contract:

```
Claude Code session
   └─ stdin JSON ──▶ statusline writer (shell)
                        ├─▶ prints the user's existing statusline (unchanged, byte-for-byte)
                        └─▶ writes ~/.cache/dms-claude-usage.json        ◀── the contract
                                                  │ FileView watch + poll
                              claudeUsage plugin (QML) ──▶ renders pill + popout
```

### Unit 1 — Writer (shell)
Two shipped artifacts in the repo (NOT installed automatically by the plugin):

- `writer/claude-usage-writer.sh` — reads statusline JSON on stdin, extracts `rate_limits`,
  normalizes `resets_at` to epoch, and atomically writes the cache file with a `captured_at`
  timestamp. Passes stdin through to an optional wrapped command so it can BE the statusline or
  chain into an existing one.
- `writer/install.sh` — idempotent installer. Detects the user's current
  `~/.claude/settings.json` `statusLine.command` (and/or `~/.claude/statusline-command.sh`),
  **backs it up** (timestamped), and wraps it so both the original output and the cache write
  happen. Prints manual instructions if it can't auto-detect. `writer/uninstall.sh` restores the
  backup.

Writer contract: if `rate_limits` is absent (non-Pro/Max, older CC, API-key mode), the writer
writes nothing new (leaves any prior cache intact) and exits 0 — never breaks the statusline.

Optional alternative writer (documented, not default): `writer/oauth-poller.sh` — a systemd
user-timer-friendly script that curls the OAuth endpoint with the correct User-Agent at ≥180s and
writes the same cache schema. For users who want idle refresh and accept the caveats.

### Unit 2 — Cache file (the contract)
Path: `${XDG_CACHE_HOME:-~/.cache}/dms-claude-usage.json`

```json
{
  "captured_at": 1781090000,
  "five_hour":  { "used_percentage": 15, "resets_at": 1781091000 },
  "seven_day":  { "used_percentage": 4,  "resets_at": 1781575200 },
  "seven_day_sonnet": { "used_percentage": 3, "resets_at": 1781575200 }
}
```
- `captured_at` — epoch seconds when the writer last saw fresh data. Drives the "updated Xm ago"
  and stale detection.
- `seven_day_sonnet` — present only when Claude Code emitted it.
- Written atomically (temp file + `mv`) so the widget never reads a half-written file.

### Unit 3 — Plugin (QML), pure consumer
Folder installed at `~/.config/DankMaterialShell/plugins/claudeUsage/`:

```
plugin.json              # manifest (validated against plugin-schema.json)
ClaudeUsageWidget.qml     # PluginComponent: pill(s) + popout
ClaudeUsageSettings.qml   # PluginSettings: all user options
README.md                 # usage + screenshots
```

`plugin.json` (draft):
```json
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
```

The widget reads the cache via Quickshell `FileView` (watch for change) with a low-frequency
poll fallback (e.g. 30s) in case the file is replaced on a filesystem that doesn't emit watch
events. A 1s `Timer` updates the live reset countdowns purely from the cached `resets_at`.

## Visual Design

All styles use **DMS theme-semantic colors** (adapt to the active scheme):
- Load ramp: `Theme.primary` (normal) → `Theme.warning` (≥ warning threshold) → `Theme.error`
  (≥ critical threshold).
- Ring/track background: `Theme.surfaceVariant`. Pill background: `Theme.surfaceContainerHigh`.
- Optional pulse animation (opacity/scale) at ≥ critical threshold.

### Pill — selectable `displayStyle` (the user-facing variety)
1. **Filled ring** *(default)* — circular progress ring per shown limit, `used_percentage`
   centered, small label ("5h" / "7d") beneath or as tooltip.
2. **Hollow ring** — thin outline track with a progress arc, hollow center, percentage rendered
   below the ring (minimal, "hollow center" look).
3. **Numbers only** — `✳ 15% · 4%`, each number color-ramped. Tiniest footprint.
4. **Mini bar** — horizontal progress bar(s), percentage trailing.

`horizontalBarPill` for top/bottom bars; `verticalBarPill` (stacked) for left/right bars. Pill
width adapts to which limits are enabled.

### Popout (`PopoutComponent`, header "Claude Usage")
- One row per shown limit: indicator + label + `used_percentage` + **live countdown** to
  `resets_at` ("resets in 3h 12m"), recomputed every second client-side.
- Optional weekly-Sonnet row when `seven_day_sonnet` is present.
- Footer: "updated 2m ago" from `captured_at`; when older than the stale threshold, a muted line:
  "data may be stale — open a Claude Code session to refresh."

## Settings (`PluginSettings`, pluginId `claudeUsage`)

| Key | Component | Default | Purpose |
|-----|-----------|---------|---------|
| `displayStyle` | SelectionSetting | `filledRing` | filledRing / hollowRing / numbers / bar |
| `showFiveHour` | ToggleSetting | `true` | show the 5h limit |
| `showWeekly` | ToggleSetting | `true` | show the 7d limit |
| `showSonnetWeekly` | ToggleSetting | `false` | show weekly-Sonnet when present |
| `warningThreshold` | SelectionSetting | `70` | 60 / 70 / 80 |
| `criticalThreshold` | SelectionSetting | `90` | 85 / 90 / 95 |
| `pulseOnCritical` | ToggleSetting | `true` | pulse animation at critical |
| `staleMinutes` | SelectionSetting | `60` | 30 / 60 / 180 |
| `cachePath` | StringSetting | `` | override cache path (blank = default) |

## Error / Edge Handling

- **Cache missing or unparseable** → pill shows a dimmed `✳ --` placeholder; popout explains
  "Run a Claude Code session (with the writer installed) to populate."
- **`rate_limits` never seen** (non-Pro/Max etc.) → same placeholder; README documents the
  requirement.
- **`resets_at` in the past** → show "resetting…" until the next payload arrives.
- **Half-written cache** → prevented by atomic writes; the widget also try/catches JSON parse and
  keeps the last good values.
- **Stale data** → still rendered, but flagged in the popout footer per `staleMinutes`.

## Dev Loop, Testing, Release

- **Repo:** `~/Projects/DankClaudeUsage` (this repo), MIT license. Plugin lives under
  `plugins/claudeUsage/`; during development it is **symlinked** into
  `~/.config/DankMaterialShell/plugins/claudeUsage` so edits are live.
- **Runtime testing:** nested-niri session + locally-built quickshell (the user's established DMS
  test flow), driving the bar and popout; self-verify visually rather than asking for manual
  browser checks. Validate `plugin.json` against `plugin-schema.json` with `jq`.
- **Test data:** a `fixtures/` set of sample cache files (low / mid / critical / stale / missing
  weekly-Sonnet) so visual states can be exercised without burning real usage.
- **Release:** README with screenshots of each `displayStyle`, document the writer install
  one-liner and the OAuth alternative + its caveats → push to GitHub → submit to
  plugins.danklinux.com.

## Open Questions (resolve during planning)

- Whether DMS exposes a `DankCircularProgress` widget to reuse, or the ring is drawn with a
  `Canvas`/`Shape` arc. (Check `quickshell/Widgets/` during planning.)
- Exact `FileView` API surface in the pinned quickshell build for change notifications.
