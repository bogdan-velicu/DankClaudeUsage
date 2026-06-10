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
  "sh "*"claude-usage-writer.sh"*)
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
