# DankClaudeUsage

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) DankBar widget that shows your **Claude Code subscription limits** — the rolling 5‑hour window and the weekly (7‑day) window — as theme‑colored rings with a detailed popout. Same numbers as Claude Code's `/usage`.

> Status: **0.1.0**, experimental. The DMS plugin API is itself experimental and may change between minor versions.

## What it looks like

Four selectable bar styles (all use your active DMS theme palette, shifting
`primary → warning → error` as a limit fills, pulsing when critical):

- **Filled ring** — progress ring with the percentage in the center *(default)*
- **Hollow ring** — outline track + arc, percentage below
- **Numbers only** — `✳ 15% · 4%`
- **Mini bar** — a small horizontal progress bar

Clicking the pill opens a popout with one row per limit, each showing the
percentage and a live "resets in …" countdown, plus an "updated Xm ago" / stale
footer.

<!-- TODO: add screenshots of each style here before publishing -->

## How it works

```
Claude Code session
   └─ statusline stdin ──▶ writer (shell) ──▶ ~/.cache/dms-claude-usage.json ──▶ plugin (QML)
```

Claude Code ≥ 2.1 emits a `rate_limits` object on the statusline's stdin for
Pro/Max subscribers. A small **writer** consumes that and atomically writes a
cache file; the **plugin** is a pure consumer that reads the cache (no network,
no credentials). The reset countdowns tick client‑side, so the popout stays
useful even when no session is running.

## Requirements

- DankMaterialShell with the plugin system (`requires_dms >= 0.1.0`)
- `jq`
- Claude Code ≥ 2.1 on a Pro/Max plan (the `rate_limits` stdin payload only
  appears for subscription plans, not API‑key usage)

## Install

```bash
git clone https://github.com/<you>/DankClaudeUsage ~/Projects/DankClaudeUsage

# Make the plugin discoverable by DMS
ln -sfn ~/Projects/DankClaudeUsage/plugins/claudeUsage \
        ~/.config/DankMaterialShell/plugins/claudeUsage
```

Then in DMS: **Settings → Plugins → Scan**, enable **Claude Usage**, and add it
to a DankBar section (**Settings → DankBar Layout**).

To start the data flowing, click **Set up live updates** — in the widget's
popout, or in its plugin settings. That's it; no terminal. Open or continue a
Claude Code session and the rings populate.

### What "Set up live updates" does

It reads `~/.claude/settings.json`, backs it up to a timestamped
`settings.json.bak.<ts>`, and rewrites `statusLine.command` to run the bundled
writer *before* your existing statusline (your original output is preserved).
It's idempotent. **Remove** (in plugin settings) restores your original
statusline.

If you prefer the terminal, the same scripts live in the plugin folder:

```bash
sh ~/.config/DankMaterialShell/plugins/claudeUsage/install.sh
sh ~/.config/DankMaterialShell/plugins/claudeUsage/uninstall.sh
```

Or wire it yourself — point your statusline at:
`sh /path/to/plugins/claudeUsage/claude-usage-writer.sh <your existing statusline command>`
The writer passes stdin through to the wrapped command unchanged.

### Alternative: OAuth poller (no statusline edit, refreshes while idle)

If you want the data to refresh even when no Claude Code session is open, you
can instead poll the undocumented OAuth usage endpoint. Caveats: it reads your
access token from `~/.claude/.credentials.json`, it is **aggressively
rate‑limited** (safe only at ≥ 180 s intervals and only with the correct
`User-Agent: claude-code/<version>` header), and it cannot refresh an expired
token on its own. The statusline writer above is the recommended path. A
`writer/oauth-poller.sh` for users who accept these trade‑offs is planned but
not yet shipped. <!-- TODO: ship oauth-poller.sh + a systemd user timer example -->

## Settings

| Setting | Default | Notes |
|---|---|---|
| Display style | Filled ring | filled ring / hollow ring / numbers / mini bar |
| Show 5‑hour limit | on | |
| Show weekly limit | on | |
| Show weekly Sonnet limit | off | shown only when Claude Code emits it |
| Warning threshold | 70% | switch to the warning color |
| Critical threshold | 90% | switch to the error color and pulse |
| Pulse when critical | on | |
| Stale after | 1 hour | flag the data as stale in the popout |
| Cache path override | *(blank)* | default `$XDG_CACHE_HOME/dms-claude-usage.json` |

## Cache format

```json
{
  "captured_at": 1781090000,
  "five_hour":  { "used_percentage": 15, "resets_at": 1781091000 },
  "seven_day":  { "used_percentage": 4,  "resets_at": 1781575200 },
  "seven_day_sonnet": { "used_percentage": 3, "resets_at": 1781575200 }
}
```

`resets_at` is Unix epoch seconds. `seven_day_sonnet` is optional.

## Development & tests

The writer/installer scripts live in `plugins/claudeUsage/` so the plugin folder
is self-contained and can set itself up. Tests:

```bash
sh tests/test-writer.sh     # writer: cache schema, ISO/epoch normalization, passthrough
sh tests/test-install.sh    # installer: backup, idempotency, uninstall
sh tests/test-manifest.sh   # plugin.json validity
```

The QML widget is verified by loading it in a DMS instance (see
`docs/superpowers/specs/` and `docs/superpowers/plans/` for the full design and
build plan).

## License

MIT — see [LICENSE](LICENSE).
