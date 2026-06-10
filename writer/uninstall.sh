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
