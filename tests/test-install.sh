#!/bin/sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
SET="$WORK/settings.json"
fail() { echo "FAIL: $1"; exit 1; }
WRITER="$ROOT/plugins/claudeUsage/claude-usage-writer.sh"

# Case A: existing command gets wrapped, backup created
cat > "$SET" <<JSON
{"statusLine":{"type":"command","command":"bash /home/u/statusline.sh"}}
JSON
CLAUDE_SETTINGS="$SET" sh "$ROOT/plugins/claudeUsage/install.sh" >/dev/null || fail "install exit"
jq -e --arg w "$WRITER" '.statusLine.command | startswith("sh " + $w)' "$SET" >/dev/null \
  || fail "command not wrapped with writer"
jq -e '.statusLine.command | contains("bash /home/u/statusline.sh")' "$SET" >/dev/null \
  || fail "original command not preserved"
ls "$SET".bak.* >/dev/null 2>&1 || fail "no backup created"

# Case B: idempotent — second install does not double-wrap
CLAUDE_SETTINGS="$SET" sh "$ROOT/plugins/claudeUsage/install.sh" >/dev/null
COUNT=$(jq -r '.statusLine.command' "$SET" | grep -o "claude-usage-writer.sh" | wc -l)
[ "$COUNT" -eq 1 ] || fail "double-wrapped (count=$COUNT)"

# Case C: uninstall restores original command
CLAUDE_SETTINGS="$SET" sh "$ROOT/plugins/claudeUsage/uninstall.sh" >/dev/null || fail "uninstall exit"
jq -e '.statusLine.command == "bash /home/u/statusline.sh"' "$SET" >/dev/null \
  || fail "uninstall did not restore original"

# Case D: no statusLine at all -> installer sets writer as the statusline command
echo '{}' > "$SET"
CLAUDE_SETTINGS="$SET" sh "$ROOT/plugins/claudeUsage/install.sh" >/dev/null
jq -e --arg w "$WRITER" '.statusLine.command == ("sh " + $w)' "$SET" >/dev/null \
  || fail "no-statusline case"

rm -rf "$WORK"
echo "ALL INSTALL TESTS PASSED"
