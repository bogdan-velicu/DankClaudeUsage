#!/bin/sh
# fetch-usage.sh
# Query the Claude Code OAuth usage endpoint using the local credentials, normalize
# the response into the cache schema, write it atomically, and print it to stdout.
#
# Zero setup: reads the OAuth access token Claude Code already stores in
# ~/.claude/.credentials.json. No statusline wrapping, no config edits.
#
# Env:
#   CACHE_FILE          override cache path (default $XDG_CACHE_HOME/dms-claude-usage.json)
#   CLAUDE_USAGE_MOCK   path to a file with a sample API response (skips the network; for tests)
#
# Exit codes: 0 ok (cache written + printed), 1 no/invalid token or no credentials,
#             2 network/HTTP error or unparseable response.
set -u

cred="$HOME/.claude/.credentials.json"
cache="${CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/dms-claude-usage.json}"
mkdir -p "$(dirname "$cache")" 2>/dev/null

now=$(date +%s)

# Cross-instance / multi-monitor de-dupe: if the cache is fresh, reuse it and skip
# the network call entirely (keeps us well under the endpoint's rate limit).
if [ -r "$cache" ]; then
  prev=$(jq -r '.captured_at // 0' "$cache" 2>/dev/null || echo 0)
  age=$((now - prev))
  if [ "$age" -ge 0 ] && [ "$age" -lt 150 ]; then
    cat "$cache"
    exit 0
  fi
fi

if [ -n "${CLAUDE_USAGE_MOCK:-}" ]; then
  resp=$(cat "$CLAUDE_USAGE_MOCK")
else
  [ -r "$cred" ] || exit 1
  token=$(jq -r '.claudeAiOauth.accessToken // empty' "$cred" 2>/dev/null)
  [ -n "$token" ] || exit 1
  ver=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [ -n "$ver" ] || ver="2.1.0"
  resp=$(curl -s -m 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: claude-code/$ver" \
    -H "Content-Type: application/json" \
    https://api.anthropic.com/api/oauth/usage 2>/dev/null)
fi

# Must be a JSON object containing at least five_hour (error bodies won't have it).
echo "$resp" | jq -e 'type == "object" and has("five_hour")' >/dev/null 2>&1 || exit 2

out=$(echo "$resp" | jq --argjson now "$now" '
  def toepoch(s):
    # ISO-8601 with fractional seconds + offset -> epoch (interpret offset as UTC).
    s | sub("\\.[0-9]+"; "") | sub("(Z|[+-][0-9]{2}:?[0-9]{2})$"; "")
      | strptime("%Y-%m-%dT%H:%M:%S") | mktime;
  def norm(b):
    if b == null then null
    else { used_percentage: (b.utilization | floor), resets_at: toepoch(b.resets_at) }
    end;
  { captured_at: $now,
    five_hour: norm(.five_hour),
    seven_day: norm(.seven_day) }
  + (if .seven_day_sonnet then {seven_day_sonnet: norm(.seven_day_sonnet)} else {} end)
  + (if .seven_day_opus  then {seven_day_opus:  norm(.seven_day_opus)}  else {} end)
') || exit 2

[ -n "$out" ] || exit 2
tmp="$cache.tmp.$$"
printf '%s' "$out" > "$tmp" && mv -f "$tmp" "$cache"
printf '%s' "$out"
