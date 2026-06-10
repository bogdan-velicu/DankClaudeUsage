#!/bin/sh
# Query the Claude Code OAuth usage endpoint using the local credentials,
# normalize the response, write it to the cache, and print it.
#
# Zero setup: reads the access token Claude Code already keeps in
# ~/.claude/.credentials.json. The token never leaves the machine except in the
# request to api.anthropic.com — the same place Claude Code itself sends it.
#
# Env:
#   CACHE_FILE          override cache path (default $XDG_CACHE_HOME/dms-claude-usage.json)
#   CLAUDE_USAGE_MOCK   file with a sample API response (skips the network; for tests)
#
# Exit: 0 ok, 1 no/invalid credentials, 2 network/parse error.
set -u

cache="${CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/dms-claude-usage.json}"
mkdir -p "$(dirname "$cache")" 2>/dev/null
now=$(date +%s)

# Reuse a recent cache so multiple monitors don't each hit the rate-limited endpoint.
if [ -s "$cache" ]; then
  prev=$(jq -r '.captured_at // 0' "$cache" 2>/dev/null)
  case "$prev" in ''|*[!0-9]*) prev=0 ;; esac
  if [ "$prev" -gt 0 ] && [ $((now - prev)) -lt 150 ]; then
    cat "$cache"
    exit 0
  fi
fi

if [ -n "${CLAUDE_USAGE_MOCK:-}" ]; then
  resp=$(cat "$CLAUDE_USAGE_MOCK")
else
  cred="$HOME/.claude/.credentials.json"
  token=$(jq -r '.claudeAiOauth.accessToken // empty' "$cred" 2>/dev/null) || exit 1
  [ -n "$token" ] || exit 1
  ver=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  resp=$(curl -s -m 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: claude-code/${ver:-2.1.0}" \
    https://api.anthropic.com/api/oauth/usage 2>/dev/null)
fi

# A valid usage response is an object with a five_hour block (error bodies aren't).
echo "$resp" | jq -e 'type == "object" and has("five_hour")' >/dev/null 2>&1 || exit 2

out=$(echo "$resp" | jq --argjson now "$now" '
  def epoch(s): s | sub("\\.[0-9]+"; "") | sub("(Z|[+-][0-9]{2}:?[0-9]{2})$"; "")
                  | strptime("%Y-%m-%dT%H:%M:%S") | mktime;
  def norm(b): if b == null then null
               else {used_percentage: (b.utilization | floor), resets_at: epoch(b.resets_at)} end;
  {captured_at: $now, five_hour: norm(.five_hour), seven_day: norm(.seven_day)}
') || exit 2

tmp="$cache.tmp.$$"
printf '%s' "$out" > "$tmp" && mv -f "$tmp" "$cache"
printf '%s' "$out"
